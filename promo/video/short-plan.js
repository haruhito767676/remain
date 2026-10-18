// The short cut for X (about 45 s, almost everything at normal speed): which stretch of which scene plays, and how fast. The video (short.js) and the music
// (bgm.mjs, style "short") both read this, so the picture and the sound stay in step.
const SHORT = {
  dip: 0.18,                         // a short dip to black between two stretches
  segments: [
    { id: '0', a: 0.0, b: 6.3, s: 1 },       // 0 the hook: Just remain awake. -> remAIn
    { id: '2', a: 1.5, b: 9.2, s: 1 },       // 1 remAIn is opened from Finder and sits in the menu bar
    { id: '2', a: 12.2, b: 17.2, s: 1 },     // 2 an agent works: awake only while it works
    { id: '2', a: 22.2, b: 27.6, s: 1 },     // 3 finished, back to normal
    { id: '3', a: 20.2, b: 26.2, s: 1 },     // 4 stopped halfway: it notices
    { id: '5', a: 0.8, b: 6.6, s: 1 },       // 5 the lid closes, it keeps going
    { id: '7', a: 2.6, b: 7.2, s: 1 },       // 6 AI settles; download
  ],




};
SHORT.starts = []; SHORT.total = 0;
for (const sg of SHORT.segments) { SHORT.starts.push(SHORT.total); SHORT.total += (sg.b - sg.a) / sg.s; }
// output time of a moment of a scene (null when that stretch is not in the cut)
SHORT.at = (id, t) => { for (let i = 0; i < SHORT.segments.length; i++) { const g = SHORT.segments[i]; if (g.id === id && t >= g.a && t <= g.b) return SHORT.starts[i] + (t - g.a) / g.s; } return null; };
