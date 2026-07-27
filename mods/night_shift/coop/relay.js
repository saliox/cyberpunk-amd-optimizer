'use strict';
/**
 * NIGHT SHIFT / SURTENSION — relais co-op (transport réseau durci).
 *
 * Les mods CET ne peuvent pas ouvrir de sockets : ce relais fait le réseau.
 * Il lit coop_out.json de son joueur, l'échange avec les autres par TCP, et
 * écrit coop_in.json (état d'équipe agrégé).
 *
 * L'hôte lance l'autorité :   node relay.js --host --port 7777 --token <code> --dir "<mod dir>"
 * Un ami rejoint :            node relay.js --join <ip> --port 7777 --token <code> --dir "<mod dir>"
 *
 * SÉCURITÉ (le serveur peut être exposé à Internet via redirection de port) :
 *  - Authentification par JETON partagé (généré et affiché si non fourni) ;
 *    comparaison à temps constant. Pas de handshake valide -> connexion fermée.
 *  - Les pairs distants sont FORCÉS au rôle « join » : impossible d'usurper
 *    l'hôte (le seul hôte est le fichier local de la machine --host).
 *  - Toutes les entrées réseau sont validées et BORNÉES (types, longueurs,
 *    plages) avant usage/écriture — pas d'injection dans coop_in.json.
 *  - Anti-DoS : limite de connexions, de débit, de taille de tampon/message,
 *    timeout d'inactivité, et fenêtre de handshake courte.
 *
 * Rappel : ceci synchronise la LOGIQUE de mission, pas le monde physique
 * (pour vous voir à l'écran, lancez CyberpunkMP). Aucune dépendance externe.
 */

const fs = require('fs');
const net = require('net');
const path = require('path');
const crypto = require('crypto');

// --- Limites de sécurité -----------------------------------------------------
const STALE_MS       = 6000;    // pair sans nouvelle depuis 6 s = parti
const MAX_CLIENTS     = 8;      // connexions simultanées max (défaut)
const HELLO_TIMEOUT   = 3000;   // délai pour s'authentifier après connexion
const IDLE_TIMEOUT    = 30000;  // fermeture d'une socket muette 30 s
const MAX_BUF         = 16384;  // tampon max sans '\n' -> anti mémoire
const MAX_MSG         = 8192;   // longueur max d'une ligne JSON
const RATE_WINDOW_MS  = 1000;   // fenêtre de comptage de débit
const RATE_MAX        = 50;     // messages max par fenêtre (le mod en envoie ~5/s)
const IN_MAX_BYTES    = 16384;  // coop_in écrit borné

// --- Validation / bornage des champs (toute entrée réseau est hostile) -------
function sInt(v, min, max, dflt) {
  const n = Number(v);
  if (Number.isNaN(n)) return dflt;
  if (n === Infinity) return max;      // valeur qui déborde -> plafond
  if (n === -Infinity) return min;
  return Math.min(max, Math.max(min, Math.floor(n)));
}
// chaîne sûre : retire ce qui casse le JSON/le parseur Lua ("{}\ contrôles),
// puis borne la longueur
function sStr(v, maxLen) {
  let s = (v === undefined || v === null) ? '' : String(v);
  s = s.replace(/["\\{}\r\n\t\x00-\x1f\x7f]/g, '');
  if (s.length > maxLen) s = s.slice(0, maxLen);
  return s;
}
function sToken(v) { return sStr(v, 64); }

// Nettoie un coop_out reçu. forceRole='join' pour les pairs distants.
function sanitizePeer(raw, forceRole) {
  if (!raw || typeof raw !== 'object') return null;
  const role = forceRole || (raw.role === 'host' ? 'host' : 'join');
  return {
    id:         sStr(raw.id, 48),
    role,
    code:       sStr(raw.code, 32),
    mission:    sStr(raw.mission, 32),
    phaseIndex: sInt(raw.phaseIndex, 0, 9999, 0),
    phaseType:  sStr(raw.phaseType, 24),
    objective:  sStr(raw.objective, 80),
    remaining:  sInt(raw.remaining, 0, 100000, 0),
    vote:       (raw.vote ? sStr(raw.vote, 16).replace(/[^A-Za-z0-9_]/g, '') : ''),
    ts:         0,
  };
}

// --- Fusion pure (testable) : agrège les coop_out des pairs en un coop_in ---
function mergePeers(peers, nowMs) {
  const list = Object.values(peers).filter(p => nowMs - (p.ts || 0) <= STALE_MS);
  const host = list.find(p => p.role === 'host') || list[0] || {};
  let teamRemaining = 0;
  const votes = {};
  let voteCount = 0;
  for (const p of list) {
    teamRemaining += sInt(p.remaining, 0, 100000, 0);
    if (p.vote && p.vote !== '') { votes[p.vote] = (votes[p.vote] || 0) + 1; voteCount++; }
  }
  let resolved = '';
  if (list.length > 0 && voteCount >= list.length) {
    let best = null, bestN = -1, tie = false;
    for (const [k, n] of Object.entries(votes)) {
      if (n > bestN) { best = k; bestN = n; tie = false; }
      else if (n === bestN) { tie = true; }
    }
    resolved = (tie && host.vote) ? host.vote : best;
  }
  return {
    schema: 1,
    code: sStr(host.code, 32),
    host: sStr(host.id, 48),
    peerCount: Math.min(list.length, 999),
    mission: sStr(host.mission, 32),
    phaseIndex: sInt(host.phaseIndex, 0, 9999, 0),
    phaseType: sStr(host.phaseType, 24),
    objective: sStr(host.objective, 80),
    teamRemaining: Math.min(teamRemaining, 100000),
    resolved: sStr(resolved, 16),
    hostTs: sInt(host.ts, 0, Number.MAX_SAFE_INTEGER, 0),
  };
}

// comparaison de jetons à temps constant (anti timing-attack)
function tokenEqual(a, b) {
  const ba = Buffer.from(String(a)), bb = Buffer.from(String(b));
  if (ba.length !== bb.length) return false;
  try { return crypto.timingSafeEqual(ba, bb); } catch (_) { return false; }
}

module.exports = { mergePeers, sanitizePeer, sInt, sStr, tokenEqual, STALE_MS };

// --- Le reste ne s'exécute que lancé directement (pas à l'import/au test) ---
if (require.main !== module) return;

const argv = process.argv.slice(2);
const opt = { port: 7777, dir: process.cwd(), mode: null, hostIp: null,
              token: null, bind: '0.0.0.0', maxClients: MAX_CLIENTS };
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--host') opt.mode = 'host';
  else if (a === '--join') { opt.mode = 'join'; opt.hostIp = argv[++i]; }
  else if (a === '--port') opt.port = sInt(argv[++i], 1, 65535, 7777);
  else if (a === '--dir') opt.dir = argv[++i];
  else if (a === '--token') opt.token = sToken(argv[++i]);
  else if (a === '--bind') opt.bind = String(argv[++i]);
  else if (a === '--max-clients') opt.maxClients = sInt(argv[++i], 1, 64, MAX_CLIENTS);
}
if (!opt.mode) {
  console.error('Usage: node relay.js --host --port 7777 --token <code> --dir "<mod dir>"');
  console.error('       node relay.js --join <ip> --port 7777 --token <code> --dir "<mod dir>"');
  process.exit(1);
}
// Jamais de serveur ouvert : sans jeton, on en génère un et on l'affiche.
if (!opt.token) {
  if (opt.mode === 'host') {
    opt.token = crypto.randomBytes(4).toString('hex');
    console.log('==================================================================');
    console.log(' JETON DE SESSION (mot de passe) — partage-le UNIQUEMENT à tes amis :');
    console.log('     ' + opt.token);
    console.log(' Ils le passent avec --token ' + opt.token);
    console.log('==================================================================');
  } else {
    console.error('Erreur : --token <code> requis pour rejoindre (demande-le à l\'hôte).');
    process.exit(1);
  }
}

const OUT = path.join(opt.dir, 'coop_out.json');
const IN = path.join(opt.dir, 'coop_in.json');

function readOut() {
  try {
    const st = fs.statSync(OUT);
    if (st.size > MAX_MSG) return null;          // fichier local anormal, ignoré
    return JSON.parse(fs.readFileSync(OUT, 'utf8'));
  } catch (_) { return null; }
}
function writeIn(state) {
  try {
    const s = JSON.stringify(state);
    if (s.length > IN_MAX_BYTES) return;
    fs.writeFileSync(IN, s);
  } catch (_) {}
}
function now() { return Date.now(); }

if (opt.mode === 'host') {
  const peers = {};            // key -> coop_out nettoyé (+ ts)
  const clients = new Set();   // sockets AUTHENTIFIÉES (dans l'équipe)
  const allSockets = new Set();// TOUTES les sockets vivantes (même non authentifiées)
  function recompute() {
    const merged = mergePeers(peers, now());
    // pire ping parmi les joueurs ENCORE dans l'équipe ET déjà mesurés :
    //  - un client pas encore « ponged » (RTT inconnu) n'est PAS compté comme 0 ;
    //  - un client dont le pair est périmé (sorti de l'équipe) ne compte plus.
    let worst = 0;
    for (const c of clients) {
      if (!c._peerKey || !peers[c._peerKey]) continue;         // hors équipe
      if (typeof c._rtt === 'number' && c._rtt > worst) worst = c._rtt;
    }
    merged.worstPingMs = worst;
    // l'hôte est le serveur : son ping vers la logique autoritaire = 0
    writeIn(Object.assign({}, merged, { selfPingMs: 0 }));
    // chaque client reçoit SON propre ping (RTT mesuré, 0 tant qu'inconnu)
    for (const c of clients) {
      const rtt = (typeof c._rtt === 'number') ? c._rtt : 0;
      const line = JSON.stringify({ type: 'in',
        state: Object.assign({}, merged, { selfPingMs: rtt }) }) + '\n';
      try { c.write(line); } catch (_) {}
    }
  }
  // mesure du ping : on envoie un ping horodaté à chaque client toutes les
  // secondes ; il renvoie un pong avec le même horodatage -> RTT = maintenant - t.
  // On garde les DERNIERS horodatages envoyés (pas seulement le dernier) : un
  // client à RTT > 1 s renverrait sinon un pong « périmé » qui serait rejeté,
  // et le joueur le plus lent — celui que l'avertissement veut montrer —
  // s'afficherait à tort à 0 ms.
  const PING_HISTORY = 5;   // tolère un RTT jusqu'à ~5 s
  setInterval(() => {
    const t = now();
    for (const c of clients) {
      if (!c._pings) c._pings = [];
      c._pings.push(t);
      if (c._pings.length > PING_HISTORY) c._pings.shift();
      try { c.write(JSON.stringify({ type: 'ping', t }) + '\n'); } catch (_) {}
    }
  }, 1000);
  // l'état local de l'hôte (fichier de confiance, mais borné quand même)
  setInterval(() => {
    const o = readOut();
    if (o) { const p = sanitizePeer(o, 'host'); if (p) { p.id = 'local-host'; p.ts = now(); peers['local-host'] = p; recompute(); } }
  }, 200);
  // purge des pairs périmés (déconnexions silencieuses) + reap des sockets muettes
  setInterval(() => {
    const n = now(); let changed = false;
    for (const k of Object.keys(peers)) {
      if (k !== 'local-host' && n - peers[k].ts > STALE_MS) { delete peers[k]; changed = true; }
    }
    if (changed) recompute();
    // Le timeout natif de la socket est remis à zéro par NOS écritures (pings),
    // il ne détecte donc plus un client muet. On juge sur la dernière DONNÉE
    // REÇUE et on ferme au-delà de IDLE_TIMEOUT (anti-slot squatté).
    for (const s of allSockets) {
      if (n - (s._lastRecv || 0) > IDLE_TIMEOUT) { try { s.destroy(); } catch (_) {} }
    }
  }, 1000);

  const server = net.createServer(sock => {
    // le plafond compte TOUTES les sockets (même pas encore authentifiées) :
    // sinon un flood de connexions muettes non authentifiées le contourne.
    if (allSockets.size >= opt.maxClients) {
      try { sock.destroy(); } catch (_) {}
      console.error('[relay] connexion refusée (max ' + opt.maxClients + ' atteint)');
      return;
    }
    allSockets.add(sock);
    sock._lastRecv = now();
    const ip = sock.remoteAddress;
    let authed = false;
    let buf = '';
    let peerKey = 'c' + crypto.randomBytes(4).toString('hex'); // id serveur, pas celui du client
    let msgTimes = [];
    sock.setTimeout(IDLE_TIMEOUT);
    const helloTimer = setTimeout(() => {
      if (!authed) { console.error('[relay] handshake absent de ' + ip + ' — fermeture'); try { sock.destroy(); } catch (_) {} }
    }, HELLO_TIMEOUT);

    function drop(reason) {
      console.error('[relay] ' + ip + ' rejeté : ' + reason);
      try { sock.destroy(); } catch (_) {}
    }
    function handle(line) {
      if (line.length > MAX_MSG) return drop('message trop long');
      // limite de débit
      const t = now(); msgTimes.push(t);
      msgTimes = msgTimes.filter(x => t - x <= RATE_WINDOW_MS);
      if (msgTimes.length > RATE_MAX) return drop('débit excessif');

      let msg;
      try { msg = JSON.parse(line); } catch (_) { return; } // ligne invalide ignorée
      if (!msg || typeof msg !== 'object') return;

      if (!authed) {
        if (msg.type !== 'hello' || !tokenEqual(msg.token, opt.token)) return drop('authentification échouée');
        authed = true; clearTimeout(helloTimer);
        clients.add(sock);
        sock._peerKey = peerKey;   // lie la socket à son entrée d'équipe (ping)
        console.error('[relay] ' + ip + ' authentifié (' + peerKey + ')');
        if (msg.peer) { const p = sanitizePeer(msg.peer, 'join'); if (p) { p.ts = now(); peers[peerKey] = p; recompute(); } }
        return;
      }
      if (msg.type === 'pong') {   // réponse à NOTRE ping -> RTT mesuré
        // on n'accepte qu'un horodatage qu'on a RÉELLEMENT envoyé récemment :
        // un pong forgé ({ t: 0/null/deviné }) ne peut pas gonfler worstPingMs.
        const t = Number(msg.t);
        const arr = sock._pings;
        if (arr) {
          const idx = arr.indexOf(t);
          if (idx >= 0) {
            sock._rtt = sInt(now() - t, 0, 60000, 0);
            arr.splice(0, idx + 1);   // consomme ce ping et les plus anciens
          }
        }
        return;
      }
      if (msg.type === 'out' && msg.peer) {
        const p = sanitizePeer(msg.peer, 'join');   // rôle distant TOUJOURS join
        if (p) { p.ts = now(); peers[peerKey] = p; recompute(); }
      }
    }

    sock.on('data', d => {
      sock._lastRecv = now();
      buf += d.toString('utf8');
      // on traite d'abord les lignes complètes, PUIS on vérifie le reste :
      // un segment TCP portant plusieurs messages ne doit pas être jeté en bloc.
      let nl;
      while ((nl = buf.indexOf('\n')) >= 0) {
        const line = buf.slice(0, nl); buf = buf.slice(nl + 1);
        try { handle(line); } catch (_) {}
      }
      if (buf.length > MAX_BUF) return drop('tampon saturé (pas de fin de ligne)');
    });
    const cleanup = () => {
      allSockets.delete(sock); clients.delete(sock);
      if (peers[peerKey]) { delete peers[peerKey]; recompute(); }
    };
    sock.on('timeout', () => drop('inactif'));
    sock.on('close', cleanup);
    sock.on('error', () => cleanup());
  });
  server.on('error', e => { console.error('[relay] erreur serveur :', e.message); process.exit(1); });
  server.listen(opt.port, opt.bind, () =>
    console.log(`[relay] hôte à l'écoute sur ${opt.bind}:${opt.port} (dir: ${opt.dir})`));
} else {
  // Client : s'authentifie, envoie son coop_out, écrit le coop_in reçu.
  const sock = net.createConnection(opt.port, opt.hostIp, () => {
    console.log(`[relay] connecté à ${opt.hostIp}:${opt.port} — authentification…`);
    const o = readOut();
    try { sock.write(JSON.stringify({ type: 'hello', token: opt.token, peer: o || {} }) + '\n'); } catch (_) {}
  });
  sock.setTimeout(IDLE_TIMEOUT);
  let buf = '';
  sock.on('data', d => {
    buf += d.toString('utf8');
    let nl;
    while ((nl = buf.indexOf('\n')) >= 0) {
      const line = buf.slice(0, nl); buf = buf.slice(nl + 1);
      if (line.length > MAX_MSG) continue;
      try {
        const msg = JSON.parse(line);
        if (!msg) continue;
        if (msg.type === 'ping') { try { sock.write(JSON.stringify({ type: 'pong', t: msg.t }) + '\n'); } catch (_) {} }
        else if (msg.type === 'in') writeIn(msg.state);
      } catch (_) {}
    }
    if (buf.length > MAX_BUF) { try { sock.destroy(); } catch (_) {} return; }
  });
  const outTimer = setInterval(() => {
    const o = readOut();
    if (o) { try { sock.write(JSON.stringify({ type: 'out', peer: o }) + '\n'); } catch (_) {} }
  }, 200);
  sock.on('timeout', () => { console.error('[relay] hôte muet — fermeture'); try { sock.destroy(); } catch (_) {} });
  sock.on('error', e => console.error('[relay] erreur:', e.message));
  // hôte parti : on arrête d'écrire dans le vide et on sort proprement
  sock.on('close', () => { clearInterval(outTimer); console.error('[relay] connexion fermée'); process.exit(0); });
}
