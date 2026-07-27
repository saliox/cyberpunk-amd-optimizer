'use strict';
/**
 * latency-bridge — moitié « application » du pont avec le mod CET
 * LATENCY OPTIMIZER. À importer dans le process principal Electron de
 * « Cyberpunk AMD Optimizer ». Aucune dépendance externe.
 *
 * Protocole (fichiers JSON dans le dossier du mod, sandbox CET) :
 *   bridge_status.json   — écrit par le mod  : stats live + heartbeat (ts)
 *   bridge_command.json  — écrit par l'app   : { id, cmd, cap?, value? }
 *   bridge_ack.json      — écrit par le mod   : { id, ok, message, ts }
 *
 * Le mod écrit le statut ~1×/s et lit les commandes ~2×/s. L'app poll le
 * statut à l'intervalle de son choix et envoie des commandes à la demande.
 *
 * Exemple (main process) :
 *   const { LatencyBridge } = require('./bridge/latency-bridge');
 *   const bridge = new LatencyBridge(gameInstallPath);   // chemin du jeu
 *   bridge.on('status', s => mainWindow.webContents.send('latency:status', s));
 *   bridge.start();                       // démarre le polling du statut
 *   // depuis un bouton du renderer -> IPC -> main :
 *   await bridge.applyLowLatency();       // ou .setCap(116), .reset(), .ping()
 */

const fs = require('fs');
const path = require('path');
const { EventEmitter } = require('events');

const MOD_SUBPATH = path.join(
  'bin', 'x64', 'plugins', 'cyber_engine_tweaks', 'mods', 'latency_optimizer');

const STATUS_FILE = 'bridge_status.json';
const COMMAND_FILE = 'bridge_command.json';
const ACK_FILE = 'bridge_ack.json';

class LatencyBridge extends EventEmitter {
  /**
   * @param {string} gameInstallPath racine d'installation de Cyberpunk 2077
   * @param {object} [opts] { pollMs=1000 } intervalle de lecture du statut
   */
  constructor(gameInstallPath, opts = {}) {
    super();
    this.modDir = path.join(gameInstallPath, MOD_SUBPATH);
    this.pollMs = opts.pollMs || 1000;
    this._timer = null;
    this._lastTs = null;
    this._cmdId = Date.now(); // ids croissants, uniques entre sessions
  }

  /** Chemin du dossier du mod (utile pour vérifier qu'il est installé). */
  modInstalled() {
    try {
      return fs.existsSync(path.join(this.modDir, 'init.lua'));
    } catch (_) {
      return false;
    }
  }

  _read(file) {
    try {
      const raw = fs.readFileSync(path.join(this.modDir, file), 'utf8');
      return JSON.parse(raw);
    } catch (_) {
      return null;
    }
  }

  /** Lit le dernier statut publié par le mod (ou null). */
  readStatus() {
    return this._read(STATUS_FILE);
  }

  /** Le mod tourne-t-il ? (heartbeat récent, < maxAgeSec) */
  isLive(status, maxAgeSec = 5) {
    if (!status || typeof status.ts !== 'number') return false;
    // ts du mod = os.time() (secondes epoch) quand disponible ; on tolère
    // aussi un compteur si os.time est absent (on se rabat sur le changement)
    const nowSec = Math.floor(Date.now() / 1000);
    if (status.ts > 1e9) return nowSec - status.ts <= maxAgeSec;
    return true; // ts non-epoch : on considère vivant si le fichier existe
  }

  /** Démarre le polling ; émet 'status' à chaque nouveau heartbeat. */
  start() {
    if (this._timer) return;
    const tick = () => {
      const s = this.readStatus();
      if (s && s.ts !== this._lastTs) {
        this._lastTs = s.ts;
        this.emit('status', s);
      }
    };
    tick();
    this._timer = setInterval(tick, this.pollMs);
    return this;
  }

  stop() {
    if (this._timer) clearInterval(this._timer);
    this._timer = null;
  }

  /**
   * Envoie une commande au mod et attend son accusé (bridge_ack.json).
   * @returns {Promise<object>} { id, ok, message } ou rejette au timeout.
   */
  sendCommand(cmd, extra = {}, opts = {}) {
    const id = ++this._cmdId;
    const payload = Object.assign({ id, cmd }, extra);
    const timeoutMs = opts.timeoutMs || 4000;
    return new Promise((resolve, reject) => {
      try {
        fs.writeFileSync(
          path.join(this.modDir, COMMAND_FILE), JSON.stringify(payload), 'utf8');
      } catch (e) {
        return reject(e);
      }
      const started = Date.now();
      const poll = setInterval(() => {
        const ack = this._read(ACK_FILE);
        if (ack && ack.id === id) {
          clearInterval(poll);
          resolve(ack);
        } else if (Date.now() - started > timeoutMs) {
          clearInterval(poll);
          reject(new Error('timeout: le mod n\'a pas répondu (jeu lancé ?)'));
        }
      }, 150);
    });
  }

  // Raccourcis de commandes -------------------------------------------------
  applyLowLatency(cap) { return this.sendCommand('apply_low_latency', cap ? { cap } : {}); }
  setCap(cap)          { return this.sendCommand('set_cap', { cap }); }
  applyClarity()       { return this.sendCommand('apply_clarity'); }
  autoTune(on)         { return this.sendCommand('auto_tune', { value: on ? 1 : 0 }); }
  restore()            { return this.sendCommand('restore'); }
  reset()              { return this.sendCommand('reset'); }
  setOverlay(on)       { return this.sendCommand('set_overlay', { value: on ? 1 : 0 }); }
  ping()               { return this.sendCommand('ping'); }
}

module.exports = { LatencyBridge, MOD_SUBPATH, STATUS_FILE, COMMAND_FILE, ACK_FILE };
