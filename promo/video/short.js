// Scene "short": the 45-second cut for X, assembled from stretches of the other scenes (see short-plan.js).
function sceneShort(t) {
  let i = SHORT.segments.length - 1;
  while (i > 0 && t < SHORT.starts[i]) i--;
  const g = SHORT.segments[i], local = t - SHORT.starts[i], len = (g.b - g.a) / g.s;
  const spec = SCENE_FNS[g.id](g.a + local * g.s);
  // a quick dip to black where two stretches meet (not at the very start or end of the cut)
  const dip = SHORT.dip;
  const into = i > 0 ? 1 - prog(local, 0, dip) : 0, out = i < SHORT.segments.length - 1 ? prog(local, len - dip, len) : 0;
  spec.black = Math.max(spec.black || 0, into * 0.97, out * 0.97);
  return spec;
}
SCENE_FNS.short = sceneShort;
DURATIONS.short = SHORT.total;
