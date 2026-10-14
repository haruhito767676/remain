// Synthesises the intro video's background music: no samples, no libraries, just sines, a little FM and a reverb.
//
//   node promo/video/bgm.mjs            -> promo/video/out/bgm.wav and remain-intro-en-bgm.mp4 (video + music)
//
// The music follows the story: a calm opening, an uneasy stretch while the Mac misbehaves, silence when the power
// is gone, a warm D major once remAIn arrives, a wobble when the agent drops, and a long quiet ending.
import { readFileSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const SR = 44100;

// Scene lengths come from the timeline so the music follows any re-timing.
const durations = new Function(`return (${readFileSync(resolve(here, 'timeline.js'), 'utf8').match(/const DURATIONS = (\{[^}]*\})/)[1]})`)();
const order = ['0', '1', '2', '3', '5', '7'];
const start = {};
let total = 0;
for (const id of order) { start[id] = total; total += durations[id]; }
const N = Math.ceil(total * SR);
const L = new Float32Array(N), R = new Float32Array(N);

const hz = (m) => 440 * Math.pow(2, (m - 69) / 12);
const clamp01 = (v) => Math.max(0, Math.min(1, v));
let seed = 7;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };

function add(t0, dur, fn, pan = 0) {
  const a = Math.max(0, Math.floor(t0 * SR)), b = Math.min(N, Math.floor((t0 + dur) * SR));
  const gl = Math.cos((pan + 1) * Math.PI / 4), gr = Math.sin((pan + 1) * Math.PI / 4);
  for (let i = a; i < b; i++) { const v = fn((i - a) / SR, i / SR); L[i] += v * gl; R[i] += v * gr; }
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

// ---- Chords (MIDI) ----
const Dm9 = [50, 53, 57, 64], Dm7 = [50, 53, 57, 60], Dsus = [50, 55, 57, 60], Dcluster = [50, 51, 57, 58];
const Dmaj9 = [50, 54, 57, 61, 64], Dmaj7 = [50, 54, 57, 61], Gmaj7 = [55, 59, 62, 66], Bm7 = [47, 54, 57, 62], A69 = [45, 52, 57, 61, 66], Gm6 = [43, 50, 58, 64];
const DD = [38, 45];                                         // the low D and A that hold everything together

// ================= Scene 0: the hook =================
const s0 = start['0'];
pad(s0, 7.6, 38, 0.22, { attack: 2.5 }); pad(s0 + 0.4, 7.2, 45, 0.12, { attack: 2.5 });
chord(s0 + 0.6, 7.4, Dm9, 0.2, { attack: 2.2 });
bell(s0 + 1.1, 69, 0.1); bell(s0 + 2.0, 81, 0.09, { pan: 0.3 });                  // "ai" lights
arp(s0 + 2.8, [74, 77, 81, 86], 0.13, 0.1);                                        // "ai" -> "AI"
bell(s0 + 4.8, 86, 0.08, { pan: -0.2 });                                           // the icon

// ================= Scene 1: the trouble =================
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
for (let k = 0; core2 + k * 6 < at('3', 0.4); k++) {
  const c = prog2[k % 4], t = core2 + k * 6;
  chord(t, 6.6, c, 0.17, { attack: 1.8, release: 1.8 });
  if (k > 0) pad(t, 6.6, c[0] - 12, 0.12, { attack: 1.8, release: 1.8 });
  const up = c.map((m) => m + 12);
  for (let j = 0; j < 8; j++) pluck(t + 0.6 + j * 0.72, up[(j * 3) % up.length] + (j % 4 === 3 ? 12 : 0), 0.045, { pan: Math.sin(j) * 0.5 });
}
bell(at('2', 22.8), 81, 0.09); bell(at('2', 22.8) + 0.15, 86, 0.08);              // the run finishes
bell(at('2', 24.6), 88, 0.08, { pan: 0.3 });                                       // the notification

// ================= Scene 3: three agents =================
const s3 = start['3'];
[[0.5, 74], [1.8, 81], [3.1, 78]].forEach(([r, m]) => pluck(at('3', r), m, 0.08));  // each window opens
chord(at('3', 5.6), 5.0, [57, 61, 64, 69], 0.12, { attack: 1.4, release: 2 });
for (let k = 0; at('3', k * 6) < at('3', 19.4); k++) {
  const c = prog2[(k + 1) % 4], t = at('3', k * 6);
  if (t > at('3', 0.2)) { chord(t, 6.6, c, 0.17, { attack: 1.6, release: 1.6 }); pad(t, 6.6, c[0] - 12, 0.12, { attack: 1.6, release: 1.6 }); }
  const up = c.map((m) => m + 12);
  for (let j = 0; j < 12; j++) pluck(t + 0.3 + j * 0.5, up[(j * 2) % up.length] + (j % 4 === 3 ? 12 : 0), 0.05, { pan: Math.sin(j * 1.7) * 0.5 });
}
bell(at('3', 11.4), 81, 0.08); bell(at('3', 14.0), 86, 0.08);                      // the IDE and then the chat finish
// the last agent drops: the chord turns borrowed and the plucks stop
const drop = at('3', 20.0);
chord(drop - 0.1, 5.0, Gm6, 0.15, { attack: 0.5, release: 1.8 });
bell(at('3', 23.5), 70, 0.06);                                                    // the notification, a little sad
chord(at('3', 25.4), durations['3'] - 25.4 + 1.0, Dmaj9, 0.18, { attack: 2.2, release: 2 });  // "Sleeps as usual": home again

// ================= Scene 5: the lid =================
const s5 = start['5'];
const close0 = at('5', 0.8), close1 = at('5', 3.4), glow0 = at('5', 10.4), glow1 = at('5', 11.4);
const lidTone = (T) => 1 - 0.65 * clamp01((T - close0) / (close1 - close0)) - 0.3 * clamp01((T - glow0) / (glow1 - glow0));
pad(s5 - 0.3, durations['5'] + 1.0, 38, 0.2, { attack: 1.5, bright: lidTone }); pad(s5, durations['5'] + 1.0, 45, 0.12, { attack: 1.5 });
chord(s5, durations['5'] + 1.0, Dmaj9, 0.15, { attack: 1.5, bright: lidTone });
bell(at('5', 3.9), 74, 0.07); bell(at('5', 7.0), 78, 0.07);
[[7.6, 69], [8.2, 73], [8.8, 76]].forEach(([r, m]) => pluck(at('5', r), m, 0.08, { pan: (r - 8.2) / 2 }));  // three conditions

// ================= Scene 7: the end =================
const s7 = start['7'];
pad(s7 - 0.3, durations['7'] + 1, 38, 0.2, { attack: 1.8 }); pad(s7, durations['7'] + 1, 45, 0.12, { attack: 1.8 });
chord(s7, durations['7'] + 1, [50, 54, 57, 62, 64], 0.2, { attack: 2.0, release: 3 });
bell(at('7', 0.3), 74, 0.07); bell(at('7', 1.0), 81, 0.06);
bell(at('7', 3.2), 69, 0.07); bell(at('7', 3.9), 74, 0.1); bell(at('7', 3.95), 86, 0.05);   // "AI" settles into "ai": a small cadence
arp(at('7', 4.8), [74, 78, 81], 0.3, 0.06);

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
  g *= T < off ? 1 : T < off + 0.03 ? 1 - (T - off) / 0.03 : T < at('2', 0.4) ? 0 : clamp01((T - at('2', 0.4)) / 1.0);
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
const wav = resolve(here, 'out/bgm.wav');
writeFileSync(wav, Buffer.concat([header, data]));
console.log(`bgm.wav: ${total.toFixed(1)} s`);
execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', resolve(here, 'out/remain-intro-en.mp4'), '-i', wav, '-map', '0:v', '-map', '1:a', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-shortest', '-movflags', '+faststart', resolve(here, 'out/remain-intro-en-bgm.mp4')]);
console.log('remain-intro-en-bgm.mp4 written');
