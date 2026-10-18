// Synthesises the intro video's background music: no samples, no libraries, just sines, a little FM and a reverb.
//
//   node promo/video/bgm.mjs [style] [lang]   -> promo/video/out/bgm[-style].wav and remain-intro-<lang>-bgm[-style].mp4 (video + music)
//   styles: ambient (default), lullaby, pulse, sound
//
// The music follows the story: a calm opening, an uneasy stretch while the Mac misbehaves, silence when the power
// is gone, a warm D major once remAIn arrives, a wobble when the agent drops, and a long quiet ending.
import { readFileSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const SR = 44100;
const style = process.argv[2] || 'ambient';
const lang = process.argv[3] || 'en';
let G = 1;                                                    // gain applied to everything added below (used to mix layers)

// Scene lengths come from the timeline so the music follows any re-timing.
const durations = new Function(`return (${readFileSync(resolve(here, 'timeline.js'), 'utf8').match(/const DURATIONS = (\{[^}]*\})/)[1]})`)();
const order = ['0', '1', '2', '3', '5', '7'];
const start = {};
let total = 0;
for (const id of order) { start[id] = total; total += durations[id]; }
const SHORT = new Function(`${readFileSync(resolve(here, 'short-plan.js'), 'utf8')}; return SHORT;`)();   // the 45-second cut for X
if (style === 'short') total = SHORT.total;
const N = Math.ceil(total * SR);
const L = new Float32Array(N), R = new Float32Array(N);

const hz = (m) => 440 * Math.pow(2, (m - 69) / 12);
const clamp01 = (v) => Math.max(0, Math.min(1, v));
let seed = 7;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };

function add(t0, dur, fn, pan = 0) {
  const a = Math.max(0, Math.floor(t0 * SR)), b = Math.min(N, Math.floor((t0 + dur) * SR));
  const gl = Math.cos((pan + 1) * Math.PI / 4), gr = Math.sin((pan + 1) * Math.PI / 4);
  for (let i = a; i < b; i++) { const v = fn((i - a) / SR, i / SR) * G; L[i] += v * gl; R[i] += v * gr; }
}

// A soft pad: a few detuned partials with a slow attack. `bright(t)` (0..1) closes the tone like a low-pass.
function pad(t0, dur, midi, amp, { attack = 2, release = 2.5, bright = () => 1, pan = 0 } = {}) {
  const f = hz(midi), parts = [1, 2, 3, 4, 6].map((h, i) => ({ h, a: [1, 0.5, 0.28, 0.14, 0.07][i] }));
  const ph = rnd() * 6.28, vib = 0.12 + rnd() * 0.1;
  add(t0, dur + release, (t, T) => {
    const env = clamp01(t / attack) * (t < dur ? 1 : clamp01(1 - (t - dur) / release));
    const br = bright(T);
    let s = 0;
    for (const p of parts) {
      const w = Math.pow(br, p.h - 1) * p.a;
      s += w * (Math.sin(2 * Math.PI * f * p.h * 1.0012 * t + ph) + Math.sin(2 * Math.PI * f * p.h * 0.9988 * t + ph * 2)) * 0.5;
    }
    return s * amp * env * (1 + 0.05 * Math.sin(2 * Math.PI * vib * t));
  }, pan);
}
const chord = (t0, dur, notes, amp, opt = {}) => notes.forEach((m, i) => pad(t0, dur, m, amp / Math.sqrt(notes.length), { ...opt, pan: (i / (notes.length - 1 || 1) - 0.5) * 0.9 }));

// A bell: two inharmonic partials, a fast attack and a long decay.
function bell(t0, midi, amp, { decay = 3.2, pan = 0 } = {}) {
  const f = hz(midi);
  add(t0, decay * 2.5, (t) => {
    const env = Math.min(1, t / 0.004) * Math.exp(-t / decay);
    return amp * env * (Math.sin(2 * Math.PI * f * t) + 0.35 * Math.sin(2 * Math.PI * f * 2.76 * t) * Math.exp(-t * 2.5) + 0.2 * Math.sin(2 * Math.PI * f * 5.4 * t) * Math.exp(-t * 6));
  }, pan);
}
// A pluck: a rounder, shorter note.
function pluck(t0, midi, amp, { pan = 0, decay = 0.9 } = {}) {
  const f = hz(midi);
  add(t0, decay * 4, (t) => {
    const env = Math.min(1, t / 0.006) * Math.exp(-t / decay);
    return amp * env * (Math.sin(2 * Math.PI * f * t) + 0.3 * Math.sin(2 * Math.PI * f * 2 * t) * Math.exp(-t * 3) + 0.1 * Math.sin(2 * Math.PI * f * 3 * t) * Math.exp(-t * 6));
  }, pan);
}
const thump = (t0, amp, midi = 26) => add(t0, 1.2, (t) => amp * Math.exp(-t * 5) * Math.sin(2 * Math.PI * hz(midi) * t * (1 + 0.3 * Math.exp(-t * 12))));
const arp = (t0, notes, gap, amp, fn = bell, opt = {}) => notes.forEach((m, i) => fn(t0 + i * gap, m, amp, opt));
const at = (id, rel) => start[id] + rel;

const K = {
  ambient: { s0: 1, s1: 1, s2: 1, s3: 1, s5: 1, s7: 1, arp: 1 },
  lullaby: { s0: 0.55, s1: 0.7, s2: 0.35, s3: 0.35, s5: 0.45, s7: 0.6, arp: 0 },
  pulse: { s0: 0.6, s1: 0.75, s2: 0.4, s3: 0.4, s5: 0.5, s7: 0.6, arp: 0 },
  sound: { s0: 0.3, s1: 0.3, s2: 0.25, s3: 0.25, s5: 0.25, s7: 0.3, arp: 0 },
}[style];
const CH = style === 'pulse' ? 5 : 6;                          // chord length in seconds
const OFF = style === 'short' ? SHORT.starts[3] - SHORT.dip : at('1', 42.8);   // the moment the power is gone
// ---- Chords (MIDI) ----
const Dm9 = [50, 53, 57, 64], Dm7 = [50, 53, 57, 60], Dsus = [50, 55, 57, 60], Dcluster = [50, 51, 57, 58];
const Dmaj9 = [50, 54, 57, 61, 64], Dmaj7 = [50, 54, 57, 61], Gmaj7 = [55, 59, 62, 66], Bm7 = [47, 54, 57, 62], A69 = [45, 52, 57, 61, 66], Gm6 = [43, 50, 58, 64];
const DD = [38, 45];                                         // the low D and A that hold everything together

// ---- helpers shared by the styles
G = 1;
const box = (t, m, a = 0.07, o = {}) => bell(t, m, a, { decay: 1.5, ...o });          // a music-box note
const tick = (t, a = 0.05, f = 1800) => add(t, 0.06, (x) => a * Math.exp(-x * 70) * Math.sin(2 * Math.PI * f * x));
function noiseBurst(t0, dur, amp, hp = 0.25, pan = 0) {
  let lp = 0;
  add(t0, dur, (t) => { const n = rnd() * 2 - 1; lp += hp * (n - lp); return (n - lp) * amp * Math.exp(-t / (dur / 4)); }, pan);
}
const kick = (t, amp = 0.2) => add(t, 0.5, (x) => amp * Math.exp(-x * 9) * Math.sin(2 * Math.PI * (45 + 75 * Math.exp(-x * 30)) * x));
const bassNote = (t, m, amp, len = 0.5) => add(t, len + 0.2, (x) => amp * clamp01(x / 0.01) * Math.exp(-x / len) * (Math.sin(2 * Math.PI * hz(m) * x) + 0.3 * Math.sin(4 * Math.PI * hz(m) * x)));
const T_MAJ = [74, 69, 66, 64], T_MIN = [74, 69, 65, 64];                                // the theme, in major and in minor
const roots = [50, 43, 47, 45];                                                         // D G B A, an octave up from the bass


if (style !== 'short') {
// ================= Scene 0: the hook =================
G = K.s0;
const s0 = start['0'];
pad(s0, 7.6, 38, 0.22, { attack: 2.5 }); pad(s0 + 0.4, 7.2, 45, 0.12, { attack: 2.5 });
chord(s0 + 0.6, 7.4, Dm9, 0.2, { attack: 2.2 });
bell(s0 + 1.1, 69, 0.1); bell(s0 + 2.0, 81, 0.09, { pan: 0.3 });                  // "ai" lights
arp(s0 + 2.8, [74, 77, 81, 86], 0.13, 0.1);                                        // "ai" -> "AI"
bell(s0 + 4.8, 86, 0.08, { pan: -0.2 });                                           // the icon

// ================= Scene 1: the trouble =================
G = K.s1;
const s1 = start['1'];
const dim0 = at('1', 7.8), dim1 = at('1', 9.2), wake = at('1', 10.8), cutA = at('1', 14.4), partB = at('1', 16.2);
const finish = at('1', 27.6), push = at('1', 31.4), nightA = at('1', 33.0), nightB = at('1', 37.0), red = at('1', 37.4), off = at('1', 42.8);
pad(s1 - 0.2, off - s1 + 0.2, 38, 0.2, { attack: 1.5, release: 0.3 });             // the low D keeps going until the power is gone
const sink = (T) => 1 - 0.86 * clamp01((T - dim0) / (dim1 - dim0)) + 0.86 * clamp01((T - wake) / 1.0);
chord(s1 + 0.2, dim0 - s1 + 1.0, Dm7, 0.17, { attack: 2.0, release: 1.2, bright: sink });
[[s1 + 2.4, 69], [s1 + 5.0, 72], [s1 + 7.4, 74], [s1 + 9.6, 65]].forEach(([t, m]) => { if (t < dim0) bell(t, m, 0.07, { pan: (m % 7) / 7 - 0.5 }); });
pluck(at('1', 4.2), 62, 0.06);                                                     // the terminal opens
add(dim0, 2.2, (t) => 0.13 * Math.sin(2 * Math.PI * (220 * Math.exp(-t * 0.65)) * t) * clamp01(t / 0.2) * clamp01(1 - (t - 1.4) / 0.8));  // the Mac falls asleep
chord(wake, cutA - wake + 0.3, Dcluster, 0.14, { attack: 0.7, release: 0.9 });     // found dead: "request timed out"
chord(partB, off - partB + 0.2, Dsus, 0.11, { attack: 2.0, release: 0.3 });        // caffeinate: awake, but uneasy
for (let t = partB + 1.0; t < nightA; t += 1.6) thump(t, 0.10);
[[at('1', 20.0), 69], [at('1', 24.0), 72]].forEach(([t, m]) => bell(t, m, 0.05));
bell(finish, 74, 0.07); bell(finish + 0.12, 77, 0.06);                             // "Worked for 14m 32s"
// the long climb: a tone creeps upward while the clock and battery run ahead, a pulse speeds up, the power cuts out
add(push, off - push, (t, T) => {
  const k = (T - push) / (off - push);
  const f = 196 * Math.pow(2.2, k);
  return (0.02 + 0.11 * k * k) * (Math.sin(2 * Math.PI * f * t) + 0.8 * Math.sin(2 * Math.PI * f * 1.007 * t));
});
for (let t = nightA; t < red; t += 1.0) thump(t, 0.12, 31);
for (let t = red; t < off; t += 0.5) thump(t, 0.16, 33);

// ================= Scene 2: remAIn arrives =================
G = K.s2;
const s2 = start['2'];
const warm0 = s2 + 0.4;
pad(warm0, durations['2'] + 1.5, 38, 0.2, { attack: 2.5 }); pad(warm0 + 0.5, durations['2'] + 1.0, 45, 0.11, { attack: 2.5 });
chord(warm0, 10.4, Dmaj9, 0.2, { attack: 2.5, release: 2 });
bell(at('2', 1.2), 69, 0.07);                                                      // Finder opens
pluck(at('2', 3.2), 74, 0.07); pluck(at('2', 3.7), 74, 0.08);                      // click, double-click
arp(at('2', 4.9), [74, 78, 81, 86, 90], 0.14, 0.1);                               // the icon appears in the menu bar
chord(at('2', 5.6), 4.6, [57, 61, 64, 69], 0.12, { attack: 1.4, release: 2 });    // the camera visits it
pluck(at('2', 10.3), 62, 0.06);                                                   // the terminal launches
const prog2 = [Dmaj7, Gmaj7, Bm7, A69];
const core2 = at('2', 11.6);
for (let k = 0; core2 + k * CH < at('3', 0.4); k++) {
  const c = prog2[k % 4], t = core2 + k * CH;
  chord(t, CH + 0.6, c, 0.17, { attack: 1.8, release: 1.8 });
  if (k > 0) pad(t, CH + 0.6, c[0] - 12, 0.12, { attack: 1.8, release: 1.8 });
  const up = c.map((m) => m + 12);
  const gk = G; G = gk * K.arp / (K.s2 || 1);
  for (let j = 0; j < 8; j++) pluck(t + 0.6 + j * 0.72, up[(j * 3) % up.length] + (j % 4 === 3 ? 12 : 0), 0.045, { pan: Math.sin(j) * 0.5 });
  G = gk;
}
bell(at('2', 22.8), 81, 0.09); bell(at('2', 22.8) + 0.15, 86, 0.08);              // the run finishes
bell(at('2', 24.6), 88, 0.08, { pan: 0.3 });                                       // the notification

// ================= Scene 3: three agents =================
G = K.s3;
const s3 = start['3'];
[[0.5, 74], [1.8, 81], [3.1, 78]].forEach(([r, m]) => pluck(at('3', r), m, 0.08));  // each window opens
chord(at('3', 5.6), 5.0, [57, 61, 64, 69], 0.12, { attack: 1.4, release: 2 });
// one chord grid for scenes 2 and 3, so the chords never overlap each other
for (let k = Math.ceil((at('3', 0.4) - core2) / CH); core2 + k * CH < at('3', 19.4); k++) {
  const c = prog2[k % 4], t = core2 + k * CH;
  const len = Math.min(CH + 0.6, at('3', 20.0) - t + 0.2);                        // the last chord lets go when the agent drops
  chord(t, len, c, 0.17, { attack: 1.6, release: 1.2 }); pad(t, len, c[0] - 12, 0.12, { attack: 1.6, release: 1.2 });
  const up = c.map((m) => m + 12);
  const gk = G; G = gk * K.arp / (K.s3 || 1);
  for (let j = 0; j < 12; j++) pluck(t + 0.3 + j * 0.5, up[(j * 2) % up.length] + (j % 4 === 3 ? 12 : 0), 0.05, { pan: Math.sin(j * 1.7) * 0.5 });
  G = gk;
}
bell(at('3', 11.4), 81, 0.08); bell(at('3', 14.0), 86, 0.08);                      // the IDE and then the chat finish
// the last agent drops: the chord turns borrowed and the plucks stop
const drop = at('3', 20.0);
chord(drop - 0.1, 5.0, Gm6, 0.15, { attack: 0.5, release: 1.8 });
bell(at('3', 23.5), 70, 0.06);                                                    // the notification, a little sad
chord(at('3', 25.4), durations['3'] - 25.4 + 1.0, Dmaj9, 0.18, { attack: 2.2, release: 2 });  // "Sleeps as usual": home again

// ================= Scene 5: the lid =================
G = K.s5;
const s5 = start['5'];
const close0 = at('5', 0.8), close1 = at('5', 3.4), glow0 = at('5', 10.4), glow1 = at('5', 11.4);
const lidTone = (T) => 1 - 0.65 * clamp01((T - close0) / (close1 - close0)) - 0.3 * clamp01((T - glow0) / (glow1 - glow0));
pad(s5 - 0.3, durations['5'] + 1.0, 38, 0.2, { attack: 1.5, bright: lidTone }); pad(s5, durations['5'] + 1.0, 45, 0.12, { attack: 1.5 });
chord(s5, durations['5'] + 1.0, Dmaj9, 0.15, { attack: 1.5, bright: lidTone });
bell(at('5', 3.9), 74, 0.07); bell(at('5', 7.0), 78, 0.07);
[[7.6, 69], [8.2, 73], [8.8, 76]].forEach(([r, m]) => pluck(at('5', r), m, 0.08, { pan: (r - 8.2) / 2 }));  // three conditions

// ================= Scene 7: the end =================
G = K.s7;
const s7 = start['7'];
pad(s7 - 0.3, durations['7'] + 1, 38, 0.2, { attack: 1.8 }); pad(s7, durations['7'] + 1, 45, 0.12, { attack: 1.8 });
chord(s7, durations['7'] + 1, [50, 54, 57, 62, 64], 0.2, { attack: 2.0, release: 3 });
bell(at('7', 0.3), 74, 0.07); bell(at('7', 1.0), 81, 0.06);
bell(at('7', 3.2), 69, 0.07); bell(at('7', 3.9), 74, 0.1); bell(at('7', 3.95), 86, 0.05);   // "AI" settles into "ai": a small cadence
arp(at('7', 4.8), [74, 78, 81], 0.3, 0.06);


// ================= Style layers (everything above is the shared ambient bed) =================
if (style === 'lullaby') {
  const beat = 60 / 66;
  arp(s0 + 1.2, T_MAJ, 0.62, 0.07, box); arp(s0 + 4.2, T_MAJ.map((m) => m + 12), 0.5, 0.05, box);
  [s1 + 2.0, s1 + 7.0].forEach((t) => { if (t < dim0) arp(t, T_MIN, 0.7, 0.06, box); });
  arp(dim0, [69, 65, 62, 57], 0.55, 0.06, box);                                       // the notes slow down as the Mac falls asleep
  box(dim0 + 2.4, 50, 0.07, { decay: 3 });
  box(wake + 0.1, 51, 0.05, { decay: 2.5 }); box(wake + 0.1, 62, 0.05, { decay: 2.5 });   // an out-of-tune note: the run is dead
  for (let t = partB + 0.5; t < nightA; t += 1.0) tick(t, 0.035);                          // a clock ticks while the Mac stays awake
  arp(finish, [74, 69, 66], 0.4, 0.06, box);                                              // "Worked for 14m 32s": the theme starts, and is not finished
  for (let t = nightA, d = 1.0; t < OFF; t += d) { const k = (t - nightA) / (OFF - nightA); tick(t, 0.04 + 0.05 * k, 1800 + 1400 * k); d = Math.max(0.2, 1.0 - 0.85 * k); }
  // remAIn arrives: the theme in D major, then a gentle loop over the chords
  arp(at('2', 4.9), [62, 66, 69, 74, 78], 0.2, 0.08, box);
  const grid = (t0, t1, voices) => {
    for (let k = 0; t0 + k * 4 * beat < t1; k++) {
      const r = roots[k % 4], t = t0 + k * 4 * beat, tri = [r + 12, r + 16 - (k % 4 === 2 ? 1 : 0), r + 19];
      bassNote(t, r - 12, 0.06, 1.2);
      for (let j = 0; j < 8; j++) box(t + j * beat / 2, tri[j % 3] + 12 * (voices > 1 && j % 4 === 3 ? 1 : 0), 0.045, { pan: Math.sin(j) * 0.4 });
      if (k % 2 === 1) arp(t + 0.5, T_MAJ.map((m) => m + 12), beat, 0.05, box);
    }
  };
  grid(core2, at('3', 19.6), 1);
  grid(at('3', 25.6), at('5', 4), 2);
  box(at('3', 20.0), 51, 0.06, { decay: 3 }); box(at('3', 23.5), 82, 0.06);                // the agent drops; the notification
  [[at('5', 3.9), 74], [at('5', 7.0), 69], [at('5', 7.6), 69], [at('5', 8.2), 73], [at('5', 8.8), 76]].forEach(([t, m]) => box(t, m, 0.06));
  arp(at('5', 0.8), [81, 78, 74, 69, 66, 62], 0.45, 0.05, box);                            // the lid closes
  arp(s7 + 3.2, [74, 69, 66, 62, 57], 0.55, 0.07, box);                                    // the theme comes home
  box(s7 + 6.4, 50, 0.08, { decay: 4 });
}

if (style === 'pulse') {
  const beat = 60 / 96;
  // the Mac is troubled: no beat, only a clock-like tick that speeds up with the climb
  for (let t = partB + 0.5; t < nightA; t += beat * 2) noiseBurst(t, 0.05, 0.04, 0.5);
  for (let t = nightA; t < red; t += beat * 2) { kick(t, 0.12 + 0.1 * (t - nightA) / (red - nightA)); noiseBurst(t + beat, 0.05, 0.04, 0.5); }
  for (let t = red; t < OFF; t += beat) { kick(t, 0.24); noiseBurst(t + beat / 2, 0.05, 0.06, 0.5); }
  // remAIn arrives: the beat begins when the agent is launched
  // One groove for the whole stretch (it grows into the full pattern when the three agents are working), on the same grid as the chords.
  const groove = (t0, t1, fullFrom, pedal) => {
    for (let k = 0; t0 + k * 8 * beat < t1; k++) {
      const r = pedal ? 50 : roots[k % 4], t = t0 + k * 8 * beat, tri = [r + 12, r + 16 - (!pedal && k % 4 === 2 ? 1 : 0), r + 19];
      bassNote(t, r - 12, 0.1, 0.9); bassNote(t + 3 * beat, r - 12, 0.07, 0.5); bassNote(t + 6 * beat, r - 5, 0.06, 0.4);
      for (let b = 0; b < 8; b++) {
        const tb = t + b * beat, full = tb >= fullFrom;
        if (tb >= t1) break;
        kick(tb, 0.16);
        noiseBurst(tb + beat / 2, 0.06, full ? 0.06 : 0.045, 0.5, 0.2);
        if (full && b % 2 === 1) noiseBurst(tb, 0.12, 0.05, 0.12, -0.2);                    // a soft clap on 2 and 4
        for (let j = 0; j < 4; j++) pluck(tb + j * beat / 4, tri[(b * 4 + j) % 3] + 12 * (j === 3 ? 1 : 0), full ? 0.038 : 0.03, { decay: 0.25, pan: Math.sin(b + j) * 0.4 });
      }
    }
  };
  arp(at('2', 4.9), [74, 78, 81, 86, 90], 0.14, 0.05);
  groove(core2, at('3', 20.0), at('3', 4.0), false);                                          // the full pattern once three agents are working
  groove(at('3', 25.6), at('5', 0.8), at('3', 25.6), true);                                    // back to it when everything is calm again (on a D pedal)
  for (let t = at('5', 0.8); t < at('5', 10.4); t += 2 * beat) kick(t, 0.09 * (1 - (t - at('5', 0.8)) / 9.6));   // the beat slows to a heartbeat under the lid
}

if (style === 'sound') {
  const ping = (t, m, a = 0.08) => { bell(t, m, a, { decay: 1.1 }); bell(t + 0.11, m + 7, a * 0.8, { decay: 1.1 }); };
  const whoosh = (t, d = 0.5) => noiseBurst(t, d, 0.05, 0.05 + 0.1 * rnd());
  whoosh(at('1', 1.8), 0.6); bell(at('1', 2.4), 69, 0.05);                                  // the terminal opens
  add(dim0, 1.8, (t) => 0.1 * Math.exp(-t * 1.2) * Math.sin(2 * Math.PI * (160 * Math.exp(-t * 0.5)) * t));   // the Mac falls asleep
  box(wake, 50, 0.06, { decay: 2 });
  for (let t = at('1', 14.0); t < nightA; t += 0.9) tick(t, 0.025);                           // a small clock while caffeinate runs
  for (let t = nightA, d = 0.5; t < OFF; t += d) { const k = (t - nightA) / (OFF - nightA); tick(t, 0.03 + 0.07 * k, 1500 + 2600 * k); d = Math.max(0.07, 0.5 - 0.43 * k); }   // the clock races
  bassNote(OFF - 0.05, 26, 0.2, 0.25);                                                        // thud, then nothing
  whoosh(at('2', 1.0)); box(at('2', 3.2), 74, 0.06); box(at('2', 3.7), 74, 0.07);
  arp(at('2', 4.9), [74, 78, 81, 86, 90], 0.14, 0.09);
  whoosh(at('2', 10.3)); ping(at('2', 22.8), 81); ping(at('2', 24.6), 86, 0.07);
  [0.5, 1.8, 3.1].forEach((r, i) => { whoosh(at('3', r - 0.1), 0.4); box(at('3', r + 0.1), 74 + [0, 7, 4][i], 0.06); });
  ping(at('3', 11.4), 81); ping(at('3', 14.0), 86);
  box(at('3', 20.0), 51, 0.07, { decay: 3 }); ping(at('3', 23.5), 70, 0.06);
  add(at('5', 0.8), 2.6, (t) => 0.1 * Math.sin(2 * Math.PI * (330 * Math.exp(-t * 0.5)) * t) * Math.exp(-t * 0.5));  // the lid
  [7.6, 8.2, 8.8].forEach((r, i) => box(at('5', r), 69 + [0, 4, 7][i], 0.06));
  ping(at('7', 3.5), 74, 0.07);
}

}


// ================= The 45-second cut for X: its own short arc (hook, trouble, power cut, groove, drop, end) =================
if (style === 'short') {
  const m = (id, rel) => SHORT.at(id, rel);
  const st = SHORT.starts, beat = 60 / 96;
  G = 1;
  // hook
  pad(0, 7.5, 38, 0.22, { attack: 2.2 }); pad(0.4, 7, 45, 0.12, { attack: 2.2 }); chord(0.5, 6.2, Dm9, 0.2, { attack: 1.8 });
  bell(1.1, 69, 0.1); bell(2.0, 81, 0.09, { pan: 0.3 }); arp(2.8, [74, 77, 81, 86], 0.13, 0.1); bell(4.8, 86, 0.08, { pan: -0.2 });
  // trouble: the sound sinks with the screen, wakes uneasy, and keeps humming while the Mac stays up for nothing
  const t1 = st[1], dim0 = m('1', 7.8), dim1 = m('1', 9.2), wake = m('1', 10.8), seg2 = st[2];
  pad(t1 - 0.3, OFF - t1 + 0.3, 38, 0.2, { attack: 1.2, release: 0.2 });
  const sinkS = (T) => 1 - 0.86 * clamp01((T - dim0) / (dim1 - dim0)) + 0.86 * clamp01((T - wake) / 0.8);
  chord(t1, dim0 - t1 + 0.8, Dm7, 0.17, { attack: 1.2, release: 1, bright: sinkS });
  add(dim0, 1.6, (t) => 0.13 * Math.sin(2 * Math.PI * (220 * Math.exp(-t * 0.9)) * t) * clamp01(t / 0.15) * clamp01(1 - (t - 1) / 0.6));
  chord(wake, seg2 - wake + 0.2, Dcluster, 0.14, { attack: 0.5, release: 0.6 });
  chord(seg2, OFF - seg2 + 0.2, Dsus, 0.12, { attack: 0.6, release: 0.4 });
  for (let t = seg2 + 0.3; t < OFF; t += 1.0) thump(t, 0.1);
  // remAIn arrives after a breath of silence: warm D major; the beat starts when the agent starts working
  const t4 = st[3] + 0.35, t5 = st[4], drop = st[7], calm = st[7] + 3.6;
  pad(t4, total - t4 + 1, 38, 0.2, { attack: 1.8 }); pad(t4 + 0.4, total - t4, 45, 0.11, { attack: 1.8 });
  chord(t4, 8, Dmaj9, 0.2, { attack: 1.8, release: 1.5 });
  const ic = m('2', 4.9); if (ic != null) arp(ic, [74, 78, 81, 86, 90], 0.14, 0.1);
  for (const r of [3.2, 3.7]) { const x = m('2', r); if (x != null) pluck(x, 74, 0.07); }
  const grooveBars = (t0, t1b, full) => {
    for (let k = 0; t0 + k * 8 * beat < t1b; k++) {
      const r = roots[k % 4], t = t0 + k * 8 * beat, tri = [r + 12, r + 16 - (k % 4 === 2 ? 1 : 0), r + 19];
      bassNote(t, r - 12, 0.1, 0.9); bassNote(t + 3 * beat, r - 12, 0.07, 0.5); bassNote(t + 6 * beat, r - 5, 0.06, 0.4);
      chord(t, 5.4, [r + 12, r + 16 - (k % 4 === 2 ? 1 : 0), r + 19, r + 24], 0.16, { attack: 1.0, release: 1.2 });
      for (let b = 0; b < 8; b++) {
        const tb = t + b * beat; if (tb >= t1b) break;
        kick(tb, 0.16); noiseBurst(tb + beat / 2, 0.06, full ? 0.06 : 0.045, 0.5, 0.2);
        if (full && b % 2 === 1) noiseBurst(tb, 0.12, 0.05, 0.12, -0.2);
        for (let j = 0; j < 4; j++) pluck(tb + j * beat / 4, tri[(b * 4 + j) % 3] + 12 * (j === 3 ? 1 : 0), full ? 0.036 : 0.028, { decay: 0.25, pan: Math.sin(b + j) * 0.4 });
      }
    }
  };
  grooveBars(t5, drop - 0.1, true);
  const f = m('2', 22.8); if (f != null) { bell(f, 81, 0.09); bell(f + 0.15, 86, 0.08); }
  const n = m('3', 23.5); if (n != null) bell(n, 70, 0.07);
  chord(drop - 0.1, 3.6, Gm6, 0.15, { attack: 0.4, release: 1.4 });           // the agent drops: the chord turns, the beat stops
  chord(calm, st[8] - calm + 1.2, Dmaj9, 0.18, { attack: 1.0, release: 1.2 });
  // the end
  const t9 = st[8];
  chord(t9, total - t9 + 1, [50, 54, 57, 62, 64], 0.2, { attack: 1.2, release: 2.5 });
  const ai0 = m('7', 3.2); if (ai0 != null) { bell(ai0, 69, 0.07); bell(ai0 + 0.7, 74, 0.1); bell(ai0 + 0.75, 86, 0.05); }
  const ai1 = m('7', 4.8); if (ai1 != null) arp(ai1, [74, 78, 81], 0.3, 0.06);
}

// ================= Reverb (Freeverb-like) and mix =================
function reverb(x, spread) {
  const combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617].map((n) => n + spread);
  const aps = [556, 441, 341, 225].map((n) => n + spread);
  const out = new Float32Array(x.length);
  const cb = combs.map((n) => ({ b: new Float32Array(n), i: 0, s: 0 }));
  const ab = aps.map((n) => ({ b: new Float32Array(n), i: 0 }));
  const fb = 0.9, damp = 0.28;
  for (let n = 0; n < x.length; n++) {
    const inp = x[n] * 0.015;
    let acc = 0;
    for (const c of cb) { const y = c.b[c.i]; c.s = y * (1 - damp) + c.s * damp; c.b[c.i] = inp + c.s * fb; if (++c.i >= c.b.length) c.i = 0; acc += y; }
    for (const a of ab) { const y = a.b[a.i]; const z = acc + y * 0.5; a.b[a.i] = z; acc = y - acc; if (++a.i >= a.b.length) a.i = 0; }
    out[n] = acc;
  }
  return out;
}
const wl = reverb(L, 0), wr = reverb(R, 23);
// Master gain: silence when the power is gone (the cut is sudden on purpose), fades at both ends.
const gain = (T) => {
  let g = 1;
  const resume = style === 'short' ? SHORT.starts[3] + 0.35 : at('2', 0.4);
  g *= T < OFF ? 1 : T < OFF + 0.03 ? 1 - (T - OFF) / 0.03 : T < resume ? 0 : clamp01((T - resume) / (style === 'short' ? 0.5 : 1.0));
  g *= clamp01(T / 1.2);
  g *= clamp01((total - T) / 3.0);
  return g;
};
const wetMix = 0.9;
let peak = 0;
const outL = new Float32Array(N), outR = new Float32Array(N);
for (let i = 0; i < N; i++) {
  const T = i / SR, g = gain(T);
  outL[i] = Math.tanh((L[i] * 0.8 + wl[i] * wetMix) * g);
  outR[i] = Math.tanh((R[i] * 0.8 + wr[i] * wetMix) * g);
  peak = Math.max(peak, Math.abs(outL[i]), Math.abs(outR[i]));
}
const norm = 0.8 / (peak || 1);

// 16-bit WAV
const data = Buffer.alloc(N * 4);
for (let i = 0; i < N; i++) {
  data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, outL[i] * norm)) * 32767), i * 4);
  data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, outR[i] * norm)) * 32767), i * 4 + 2);
}
const header = Buffer.alloc(44);
header.write('RIFF', 0); header.writeUInt32LE(36 + data.length, 4); header.write('WAVEfmt ', 8); header.writeUInt32LE(16, 16);
header.writeUInt16LE(1, 20); header.writeUInt16LE(2, 22); header.writeUInt32LE(SR, 24); header.writeUInt32LE(SR * 4, 28);
header.writeUInt16LE(4, 32); header.writeUInt16LE(16, 34); header.write('data', 36); header.writeUInt32LE(data.length, 40);
const suffix = `${style === 'ambient' ? '' : `-${style}`}`;
const wav = resolve(here, `out/bgm${suffix}.wav`);
writeFileSync(wav, Buffer.concat([header, data]));
console.log(`bgm${suffix}.wav: ${total.toFixed(1)} s`);
execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', resolve(here, style === 'short' ? `out/clip-short-${lang}.mp4` : `out/remain-intro-${lang}.mp4`), '-i', wav, '-map', '0:v', '-map', '1:a', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-shortest', '-movflags', '+faststart', resolve(here, style === 'short' ? `out/remain-short-${lang}.mp4` : `out/remain-intro-${lang}-bgm${suffix}.mp4`)]);
console.log(style === 'short' ? `remain-short-${lang}.mp4 written` : `remain-intro-${lang}-bgm${suffix}.mp4 written`);
