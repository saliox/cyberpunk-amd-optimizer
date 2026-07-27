'use strict';
/**
 * Test d'INTÉGRATION du relais co-op : lance le vrai relais (hôte + clients)
 * en processus séparés, communiquant par de VRAIES sockets TCP sur
 * 127.0.0.1. Chaque « pair » a son propre dossier avec coop_out.json /
 * coop_in.json (comme le mod en jeu). On vérifie que le relais agrège et
 * propage réellement l'état d'équipe à travers le réseau.
 *
 *   node test-relay.js
 *
 * Couvre : connexion TCP, somme des hostiles, propagation mission/phase,
 * résolution des votes, et déconnexion (heartbeat périmé). Ne couvre PAS le
 * pare-feu/NAT d'un vrai WAN (config réseau, pas code) ni le jeu.
 */

const fs = require('fs');
const os = require('os');
const net = require('net');
const path = require('path');
const { spawn } = require('child_process');

const RELAY = path.join(__dirname, 'relay.js');
const PORT = 7801;
const TOKEN = 'testsecret';
const procs = [];
let failures = 0;

function mkdir() { return fs.mkdtempSync(path.join(os.tmpdir(), 'coop-')); }
function writeOut(dir, o) { fs.writeFileSync(path.join(dir, 'coop_out.json'), JSON.stringify(o)); }
function readIn(dir) {
  try { return JSON.parse(fs.readFileSync(path.join(dir, 'coop_in.json'), 'utf8')); }
  catch (_) { return null; }
}
function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function waitFor(fn, timeoutMs, label) {
  const start = Date.now();
  for (;;) {
    let v; try { v = fn(); } catch (_) { v = false; }
    if (v) return v;
    if (Date.now() - start > timeoutMs) throw new Error('timeout: ' + label);
    await sleep(100);
  }
}

function ok(cond, msg) {
  if (cond) { console.log('  PASS  ' + msg); }
  else { console.log('  FAIL  ' + msg); failures++; }
}

function startRelay(args, name) {
  const p = spawn('node', [RELAY, ...args], { stdio: ['ignore', 'pipe', 'pipe'] });
  p.stderr.on('data', d => process.stderr.write(`[${name}] ${d}`));
  procs.push(p);
  return p;
}

async function main() {
  const hostDir = mkdir(), c1 = mkdir(), c2 = mkdir();

  // état initial de chaque pair (ce que le mod écrirait en jeu)
  writeOut(hostDir, { id: 'host', role: 'host', code: 'ABCD', mission: 'ns06',
    phaseIndex: 2, phaseType: 'wave', objective: 'Nettoie le nid',
    remaining: 2, vote: '', resolved: '' });
  writeOut(c1, { id: 'c1', role: 'join', code: 'ABCD', mission: '', phaseIndex: 0,
    phaseType: '', objective: '', remaining: 3, vote: '', resolved: '' });
  writeOut(c2, { id: 'c2', role: 'join', code: 'ABCD', mission: '', phaseIndex: 0,
    phaseType: '', objective: '', remaining: 4, vote: '', resolved: '' });

  console.log('Démarrage du relais (hôte + 2 clients) sur 127.0.0.1:' + PORT + ' …');
  startRelay(['--host', '--port', String(PORT), '--token', TOKEN, '--dir', hostDir], 'host');
  await sleep(400);
  startRelay(['--join', '127.0.0.1', '--port', String(PORT), '--token', TOKEN, '--dir', c1], 'c1');
  startRelay(['--join', '127.0.0.1', '--port', String(PORT), '--token', TOKEN, '--dir', c2], 'c2');

  // 1) l'équipe converge : teamRemaining = 2+3+4 = 9, sur les 3 dossiers
  await waitFor(() => { const s = readIn(hostDir); return s && s.teamRemaining === 9; },
    5000, 'agrégation initiale (hôte)');
  ok(readIn(hostDir).teamRemaining === 9, 'teamRemaining = 9 (2+3+4) côté hôte');
  await waitFor(() => { const s = readIn(c1); return s && s.teamRemaining === 9; },
    5000, 'propagation vers c1');
  ok(readIn(c1).teamRemaining === 9, 'teamRemaining propagé au client 1 via TCP');
  ok(readIn(c2) && readIn(c2).teamRemaining === 9, 'teamRemaining propagé au client 2 via TCP');
  ok(readIn(c1).mission === 'ns06' && readIn(c1).phaseType === 'wave',
    'mission/phase de l\'hôte propagées aux clients');
  ok(readIn(hostDir).peerCount === 3, 'peerCount = 3');

  // 1a) SÉCURITÉ : un intrus au mauvais jeton est rejeté, aucune injection
  function attack(token, peer) {
    return new Promise(res => {
      const s = net.createConnection(PORT, '127.0.0.1', () => {
        s.write(JSON.stringify({ type: 'hello', token, peer }) + '\n');
        setTimeout(() => { try { s.write(JSON.stringify({ type: 'out', peer }) + '\n'); } catch (_) {} }, 150);
        setTimeout(() => { try { s.destroy(); } catch (_) {} res(); }, 500);
      });
      s.on('error', () => res());
    });
  }
  const before = readIn(hostDir).teamRemaining;
  await attack('MAUVAIS_JETON', { id: 'evil', role: 'host', remaining: 999999, mission: 'HACKED' });
  await sleep(300);
  ok(readIn(hostDir).teamRemaining === before && readIn(hostDir).peerCount === 3,
    'intrus au mauvais jeton rejeté (aucun état injecté, teamRemaining intact)');
  ok(readIn(hostDir).mission === 'ns06',
    'intrus ne peut pas usurper la mission de l\'hôte');

  // 1b) latence de propagation réelle hôte -> client (localhost)
  writeOut(hostDir, { id: 'host', role: 'host', code: 'ABCD', mission: 'PROBE',
    phaseType: 'wave', remaining: 2, vote: '' });
  const t0 = Date.now();
  for (;;) { const s = readIn(c1); if (s && s.mission === 'PROBE') break;
    if (Date.now() - t0 > 5000) throw new Error('timeout probe'); await sleep(5); }
  const propMs = Date.now() - t0;
  console.log('  INFO  latence de propagation relais hôte->client : ~' + propMs + ' ms (localhost)');
  ok(propMs < 1500, 'propagation sous 1,5 s (attendu : borné par le poll 200 ms du relais)');

  // 1c) mesure du ping : le relais horodate un ping/pong et écrit selfPingMs
  //     (RTT du pair vers l'hôte, 0 pour l'hôte) + worstPingMs (pire joueur).
  await waitFor(() => { const s = readIn(c1); return s && typeof s.selfPingMs === 'number'; },
    5000, 'champ de ping écrit côté client');
  const hp = readIn(hostDir), cp = readIn(c1);
  ok(typeof hp.selfPingMs === 'number' && typeof hp.worstPingMs === 'number',
    'coop_in de l\'hôte contient selfPingMs + worstPingMs');
  ok(hp.selfPingMs === 0, 'ping de l\'hôte vers lui-même = 0 (il est le serveur)');
  ok(typeof cp.selfPingMs === 'number' && cp.selfPingMs >= 0 && cp.selfPingMs < 60000,
    'ping du client mesuré et borné (RTT vers l\'hôte)');
  ok(typeof cp.worstPingMs === 'number' && cp.worstPingMs >= 0,
    'worstPingMs propagé au client');
  console.log('  INFO  ping mesuré (localhost) : hôte ' + hp.worstPingMs +
    ' ms (pire joueur) · client ' + cp.selfPingMs + ' ms');

  // 1d) battement de cœur : le ts de coop_in doit AVANCER (le mod s'en sert
  //     pour détecter un relais mort/injoignable). On lit deux fois.
  const ts1 = readIn(hostDir).ts;
  await sleep(400);
  const ts2 = readIn(hostDir).ts;
  ok(typeof ts1 === 'number' && typeof ts2 === 'number' && ts2 > ts1,
    'le ts du relais avance (heartbeat vivant) : ' + ts1 + ' -> ' + ts2);

  // 2) l'équipe nettoie : chacun met remaining à 0 -> teamRemaining converge à 0
  writeOut(hostDir, { id: 'host', role: 'host', code: 'ABCD', mission: 'ns06',
    phaseIndex: 2, phaseType: 'wave', remaining: 0, vote: '', resolved: '' });
  writeOut(c1, { id: 'c1', role: 'join', code: 'ABCD', remaining: 0, vote: '' });
  writeOut(c2, { id: 'c2', role: 'join', code: 'ABCD', remaining: 0, vote: '' });
  await waitFor(() => { const s = readIn(c1); return s && s.teamRemaining === 0; },
    5000, 'team clear propagé');
  ok(readIn(c1).teamRemaining === 0, 'team clear (0 hostiles) propagé à tous');

  // 3) vote : tout le monde vote, la majorité l'emporte (a,a,b -> a)
  writeOut(hostDir, { id: 'host', role: 'host', code: 'ABCD', mission: 'ns15',
    phaseType: 'choice', remaining: 0, vote: 'a' });
  writeOut(c1, { id: 'c1', role: 'join', code: 'ABCD', remaining: 0, vote: 'a' });
  writeOut(c2, { id: 'c2', role: 'join', code: 'ABCD', remaining: 0, vote: 'b' });
  await waitFor(() => { const s = readIn(c2); return s && s.resolved === 'a'; },
    5000, 'résolution du vote');
  ok(readIn(c2).resolved === 'a', 'vote résolu à la majorité (a,a,b -> a) et propagé');

  // 4) déconnexion : on tue le client 2 -> après le seuil, il sort de l'équipe
  const c2proc = procs[2];
  c2proc.kill('SIGKILL');
  await waitFor(() => { const s = readIn(hostDir); return s && s.peerCount === 2; },
    9000, 'détection de déconnexion');
  ok(readIn(hostDir).peerCount === 2, 'client déconnecté retiré de l\'équipe (heartbeat périmé)');

  // 5) SÉCURITÉ ping : un pair authentifié qui envoie des pong FALSIFIÉS
  //    (t=0/1, pas l'horodatage qu'on lui a envoyé) ne doit pas gonfler le ping.
  const forger = await new Promise(res => {
    const s = net.createConnection(PORT, '127.0.0.1', () => {
      s.write(JSON.stringify({ type: 'hello', token: TOKEN,
        peer: { id: 'forger', role: 'join', remaining: 0 } }) + '\n');
      const iv = setInterval(() => {
        try { s.write(JSON.stringify({ type: 'pong', t: 0 }) + '\n'); } catch (_) {}
        try { s.write(JSON.stringify({ type: 'pong', t: 1 }) + '\n'); } catch (_) {}
      }, 120);
      setTimeout(() => { clearInterval(iv); res(s); }, 1500);
    });
    s.on('error', () => res(null));
  });
  await sleep(300);
  const wp = readIn(hostDir).worstPingMs;
  ok(typeof wp === 'number' && wp < 5000,
    'un pong falsifié ne gonfle pas worstPingMs (=' + wp + ' ms, resté borné)');
  if (forger) { try { forger.destroy(); } catch (_) {} }

  // nettoyage
  for (const p of procs) { try { p.kill('SIGKILL'); } catch (_) {} }
  for (const d of [hostDir, c1, c2]) { try { fs.rmSync(d, { recursive: true, force: true }); } catch (_) {} }

  console.log('\n' + (failures ? ('ÉCHECS : ' + failures) : 'Relais réseau réel : tout OK'));
  process.exit(failures ? 1 : 0);
}

main().catch(e => {
  console.error('Erreur:', e.message);
  for (const p of procs) { try { p.kill('SIGKILL'); } catch (_) {} }
  process.exit(1);
});
