// The short cut for X (about 45 s, almost everything at normal speed): which stretch of which scene plays, and how fast. The video (short.js) and the music
// (bgm.mjs, style "short") both read this, so the picture and the sound stay in step.
const SHORT = {
  dip: 0.18,                         // a short dip to black between two stretches
  segments: [
    { id: '0', a: 0.0, b: 5.7, s: 1 },       // 0 the hook: Just remain awake. -> remAIn
    { id: '1', a: 6.2, b: 13.6, s: 1 },      // 1 a long run, the Mac falls asleep, the run is found dead
    { id: '1', a: 28.6, b: 31.0, s: 1 },     // 2 the work is done, the Mac stays awake
    { id: '1', a: 33.4, b: 37.4, s: 1 },     // 3 all night
    { id: '1', a: 40.6, b: 44.4, s: 1 },     // 4 until the battery gives out
    { id: '2', a: 12.0, b: 17.0, s: 1 },     // 5 an agent works: awake only while it works
    { id: '2', a: 22.4, b: 27.4, s: 1 },     // 6 finished, back to normal
    { id: '3', a: 20.4, b: 25.6, s: 1 },     // 7 stopped halfway: it notices
    { id: '7', a: 2.8, b: 7.0, s: 1 },       // 8 AI settles; download
  ],


};
SHORT.starts = []; SHORT.total = 0;
for (const sg of SHORT.segments) { SHORT.starts.push(SHORT.total); SHORT.total += (sg.b - sg.a) / sg.s; }
// output time of a moment of a scene (null when that stretch is not in the cut)
SHORT.at = (id, t) => { for (let i = 0; i < SHORT.segments.length; i++) { const g = SHORT.segments[i]; if (g.id === id && t >= g.a && t <= g.b) return SHORT.starts[i] + (t - g.a) / g.s; } return null; };
