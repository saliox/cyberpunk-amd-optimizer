'use strict';
/**
 * Tests unitaires de durcissement du relais : validation/bornage des entrées
 * réseau (toute entrée d'un pair distant est considérée hostile).
 *   node test-security.js
 */
const { sanitizePeer, mergePeers, sInt, sStr, tokenEqual } = require('./relay.js');

let fail = 0;
function ok(c, m) { if (c) console.log('  PASS  ' + m); else { console.log('  FAIL  ' + m); fail++; } }

// --- bornage numérique ---
ok(sInt(1e309, 0, 100000, 0) === 100000, 'remaining géant borné au max');
ok(sInt(-50, 0, 100000, 0) === 0, 'remaining négatif ramené à 0');
ok(sInt('abc', 0, 9999, 7) === 7, 'valeur non numérique -> défaut');

// --- chaînes : pas d'injection dans le JSON/parseur Lua ---
ok(sStr('a"b}c\nd', 80) === 'abcd', 'guillemets / accolades / retours retirés');
ok(sStr('x'.repeat(500), 32).length === 32, 'chaîne longue tronquée');

// --- un pair distant NE PEUT PAS se déclarer hôte ---
const spoof = sanitizePeer({ id: 'evil', role: 'host', mission: 'HACK', remaining: 999999 }, 'join');
ok(spoof.role === 'join', 'rôle distant forcé à join (pas d\'usurpation d\'hôte)');
ok(spoof.remaining === 100000, 'remaining hostile borné');

// --- vote nettoyé (caractères non alphanumériques retirés) ---
ok(sanitizePeer({ vote: 'a";DROP' }, 'join').vote === 'aDROP', 'vote nettoyé aux [A-Za-z0-9_]');

// --- fusion avec des entrées hostiles : sortie toujours saine ---
const merged = mergePeers({
  h: { id: 'h', role: 'host', ts: 1000, mission: 'ns06', remaining: 2, vote: '' },
  bad: sanitizePeer({ id: 'b', role: 'host', remaining: 1e12, objective: 'z"'.repeat(200) }, 'join'),
}, 1000);
// le pair 'bad' a été rangé sous une clé et forcé join ; mais mergePeers reçoit
// des objets déjà nettoyés en production. On vérifie surtout la robustesse :
ok(merged.teamRemaining <= 100000, 'teamRemaining agrégé borné');
ok(!merged.objective.includes('"'), 'objectif de sortie sans guillemets');
ok(merged.mission === 'ns06', 'la mission vient bien de l\'hôte de confiance');

// --- comparaison de jeton à temps constant ---
ok(tokenEqual('secret', 'secret') === true, 'jetons identiques -> OK');
ok(tokenEqual('secret', 'secreta') === false, 'longueurs différentes -> refus');
ok(tokenEqual('secret', 'Secret') === false, 'casse différente -> refus');

console.log('\n' + (fail ? ('ÉCHECS : ' + fail) : 'Durcissement relais : tout OK'));
process.exit(fail ? 1 : 0);
