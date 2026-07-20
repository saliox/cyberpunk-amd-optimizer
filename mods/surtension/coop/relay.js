'use strict';
/**
 * NIGHT SHIFT — relais co-op. Transport réseau entre les mods CET (qui ne
 * peuvent pas ouvrir de sockets) : lit coop_out.json de son joueur, l'échange
 * avec les autres via TCP, et écrit coop_in.json (état d'équipe agrégé).
 *
 * L'hôte lance l'autorité :   node relay.js --host --port 7777 --dir "<mod dir>"
 * Un ami rejoint :            node relay.js --join <ip-hote> --port 7777 --dir "<mod dir>"
 *
 * <mod dir> = …/bin/x64/plugins/cyber_engine_tweaks/mods/night_shift/
 * (par défaut : le dossier courant). Aucune dépendance externe.
 *
 * Rappel honnête : ceci synchronise la LOGIQUE de mission (objectifs
 * d'équipe, votes), PAS le monde physique. Pour vous voir/partager les
 * ennemis à l'écran, lancez CyberpunkMP en parallèle.
 */

const fs = require('fs');
const net = require('net');
const path = require('path');

const STALE_MS = 6000;   // un pair sans nouvelle depuis 6 s est « parti »

// --- Fusion pure (testable) : agrège les coop_out des pairs en un coop_in ---
// peers: { id -> {id, role, mission, phaseIndex, phaseType, objective,
//                 remaining, vote, resolved, ts} }
function mergePeers(peers, nowMs) {
  const list = Object.values(peers).filter(p => nowMs - (p.ts || 0) <= STALE_MS);
  const host = list.find(p => p.role === 'host') || list[0] || {};
  let teamRemaining = 0;
  const votes = {};
  let voteCount = 0;
  for (const p of list) {
    teamRemaining += Number(p.remaining) || 0;
    if (p.vote && p.vote !== '') { votes[p.vote] = (votes[p.vote] || 0) + 1; voteCount++; }
  }
  // le choix ne se résout que quand TOUT LE MONDE a voté ; égalité -> l'hôte tranche
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
    code: host.code || '',
    host: host.id || '',
    peerCount: list.length,
    mission: host.mission || '',
    phaseIndex: host.phaseIndex || 0,
    phaseType: host.phaseType || '',
    objective: host.objective || '',
    teamRemaining,
    resolved,
    hostTs: host.ts || 0,
  };
}

module.exports = { mergePeers, STALE_MS };

// --- Le reste ne s'exécute que lancé directement (pas à l'import/au test) ---
if (require.main !== module) return;

const argv = process.argv.slice(2);
const opt = { port: 7777, dir: process.cwd(), mode: null, hostIp: null };
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--host') opt.mode = 'host';
  else if (a === '--join') { opt.mode = 'join'; opt.hostIp = argv[++i]; }
  else if (a === '--port') opt.port = parseInt(argv[++i], 10);
  else if (a === '--dir') opt.dir = argv[++i];
}
if (!opt.mode) {
  console.error('Usage: node relay.js --host --port 7777 --dir "<mod dir>"');
  console.error('       node relay.js --join <ip> --port 7777 --dir "<mod dir>"');
  process.exit(1);
}

const OUT = path.join(opt.dir, 'coop_out.json');
const IN = path.join(opt.dir, 'coop_in.json');

function readOut() {
  try { return JSON.parse(fs.readFileSync(OUT, 'utf8')); } catch (_) { return null; }
}
function writeIn(state) {
  try { fs.writeFileSync(IN, JSON.stringify(state)); } catch (_) {}
}
function now() { return Date.now(); }

if (opt.mode === 'host') {
  // Autorité : agrège tous les pairs et rediffuse l'état d'équipe.
  const peers = {};        // id -> dernier coop_out (+ ts)
  const clients = new Set();
  function recompute() {
    const merged = mergePeers(peers, now());
    writeIn(merged);       // pour le joueur local (l'hôte)
    const line = JSON.stringify({ type: 'in', state: merged }) + '\n';
    for (const c of clients) { try { c.write(line); } catch (_) {} }
  }
  // pousse l'état local de l'hôte
  setInterval(() => {
    const o = readOut();
    if (o && o.id) { o.ts = now(); peers[o.id] = o; recompute(); }
  }, 200);
  net.createServer(sock => {
    clients.add(sock);
    let buf = '';
    sock.on('data', d => {
      buf += d.toString();
      let nl;
      while ((nl = buf.indexOf('\n')) >= 0) {
        const line = buf.slice(0, nl); buf = buf.slice(nl + 1);
        try {
          const msg = JSON.parse(line);
          if (msg.type === 'out' && msg.peer && msg.peer.id) {
            msg.peer.ts = now(); peers[msg.peer.id] = msg.peer; recompute();
          }
        } catch (_) {}
      }
    });
    sock.on('close', () => clients.delete(sock));
    sock.on('error', () => clients.delete(sock));
  }).listen(opt.port, () => console.log(`[relay] hôte à l'écoute sur :${opt.port} (dir: ${opt.dir})`));
} else {
  // Client : envoie son coop_out, écrit le coop_in reçu.
  const sock = net.createConnection(opt.port, opt.hostIp, () =>
    console.log(`[relay] connecté à ${opt.hostIp}:${opt.port}`));
  let buf = '';
  sock.on('data', d => {
    buf += d.toString();
    let nl;
    while ((nl = buf.indexOf('\n')) >= 0) {
      const line = buf.slice(0, nl); buf = buf.slice(nl + 1);
      try { const msg = JSON.parse(line); if (msg.type === 'in') writeIn(msg.state); } catch (_) {}
    }
  });
  sock.on('error', e => console.error('[relay] erreur:', e.message));
  setInterval(() => {
    const o = readOut();
    if (o && o.id) { try { sock.write(JSON.stringify({ type: 'out', peer: o }) + '\n'); } catch (_) {} }
  }, 200);
}
