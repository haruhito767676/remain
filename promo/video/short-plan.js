// The short cut for X (about 45 s): which stretch of which scene plays, and how fast. The video (short.js) and the music
// (bgm.mjs, style "short") both read this, so the picture and the sound stay in step.
const SHORT = {
  dip: 0.18,                         // a short dip to black between two stretches
  segments: [
    { id: '0', a: 0.0, b: 5.7, s: 1 },       // the hook: Just remain awake. -> remAIn
    { id: '1', a: 4.6, b: 11.9, s: 1.3 },    // a long run, the Mac falls asleep, the run is found dead
    { id: '1', a: 27.0, b: 29.6, s: 1 },     // the work is done, the Mac stays awake
    { id: '1', a: 31.2, b: 43.4, s: 2.2 },   // all night, until the battery gives out
    { id: '2', a: 0.9, b: 7.8, s: 1.3 },     // remAIn is opened and sits in the menu bar
    { id: '2', a: 17.0, b: 27.0, s: 1.7 },   // awake only while it works; finished, back to normal
    { id: '3', a: 0.6, b: 6.2, s: 1.5 },     // any agent, all at once
    { id: '3', a: 19.4, b: 26.6, s: 1.6 },   // stopped halfway: it notices
    { id: '5', a: 0.9, b: 6.6, s: 1.5 },     // the lid closes, it keeps going
    { id: '7', a: 2.6, b: 7.0, s: 1 },       // AI settles; download
  ],
};
SHORT.starts = []; SHORT.total = 0;
for (const sg of SHORT.segments) { SHORT.starts.push(SHORT.total); SHORT.total += (sg.b - sg.a) / sg.s; }
// output time of a moment of a scene (null when that stretch is not in the cut)
SHORT.at = (id, t) => { for (let i = 0; i < SHORT.segments.length; i++) { const g = SHORT.segments[i]; if (g.id === id && t >= g.a && t <= g.b) return SHORT.starts[i] + (t - g.a) / g.s; } return null; };
