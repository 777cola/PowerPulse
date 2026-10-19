// PowerPulse · Power bench — an isometric anatomy of the charge-measurement chain.
// Build: node build.mjs --audit   →  powerbench.html (light theme, kit inlined)
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import * as k from "/Users/qjh/.hermes/skills/creative/anatomy/kit/iso-kit.mjs";
import * as G from "/Users/qjh/.hermes/skills/creative/anatomy/kit/lathe.mjs";
import { tubePieces, tubeSvg } from "/Users/qjh/.hermes/skills/creative/anatomy/kit/tube.mjs";
import * as A from "/Users/qjh/.hermes/skills/creative/anatomy/kit/audit.mjs";
import { kitScript } from "/Users/qjh/.hermes/skills/creative/anatomy/scripts/inline-kit.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, "../../docs/assets");
const W = 600;
const H = 420;
const AZ = 40;
const EL = 30;
const DEG = Math.PI / 180;

/* ---------------------------------------------------------------- the bench */

const PLATE = { x: -152, y: -75, w: 304, d: 150, r: 11 };
const PLATE_Z = -15;
const FOOT_H = 8;
const FLOOR = PLATE_Z - FOOT_H;

const RULER = { x: -112, y: 66, w: 224, d: 6.5, r: 1 };
const NAME = { x: -140, y: 45, w: 42, d: 14, r: 1.6 };

const TERM = { x: -124, y: -4, w: 44, d: 34, r: 2.5 };
const TERM_TOP = 13;
const BAR = { x: -120, y: 14, w: 36, d: 14, r: 1 };
const BAR_TOP = 15;

const INLET = [-147, 36];
const CORD_Y = 24;
const CORD_Z = 6.6;

const DIAL = [-30, -8];
const DIAL_BASE_R = 33;
const DIAL_R = 26;
const FACE_Z = 22;
const BEZEL_Z = 25.4;
const POST_AT = [-55, -25.5];

const REC = { x: 40, y: -70, w: 66, d: 78, r: 3 };
const CASE_TOP = 24;
const DECK = { x: 40, y: -66, w: 66, d: 74, r: 2 };
const DECK_TOP = 24.6;
const PAPER = { x: 46, y: -62, w: 54, d: 68, r: 0.6 };
const PAPER_Z = 25.1;
const SUPPLY_Y = -58;
const TAKE_Y = 2;
const SUPPLY_R = 13.5;
const TAKE_R = 8;
const PEN_Y = -34.5;
const PEN_X0 = 56;
const PEN_SPAN = 40;
const BAR_Z = 31.2;
const BAR_H = 29;

const BOX = { x: 52, y: 14, w: 56, d: 32, r: 2 };
const BOX_TOP = 12;

const BELL = [128, -56];
const PIVOT = [148, -56];
const ESC = [-72, 44];
const ESC_R = 12;

const P = k.fitProjection(
  [
    ...k.boxCorners(PLATE, FLOOR, 0),
    [-146, INLET[1], 30],
    [-99, 8, 46],
    [DIAL[0], DIAL[1], BEZEL_Z + 2],
    [REC.x + REC.w, REC.y, 46],
    [BELL[0] + 10, BELL[1], 36],
    [PIVOT[0] + 4, PIVOT[1] + 4, 24],
    [100, 0, 42],
  ],
  W,
  H,
  { pad: 26, azimuth: AZ, elevation: EL },
);

const at = (p) => k.iso(p, P);
const S = (paths, style) => k.solidSvg(paths, style);
const Ln = (d, style) => k.lineSvg(d, style);
const Dots = (points, style) => k.dotsSvg(points, style);
const byDepth = (pts) => [...pts].sort((a, b) => k.depthOf([a[0], a[1], 0], P) - k.depthOf([b[0], b[1], 0], P));

/* ------------------------------------------------------------------ recorder */

const R = A.recorder(P, {});
const { items } = R;

function add(name, ref, svg, shapes, { bias = 0, part = null } = {}) {
  shapes.filter((shape) => shape.kind !== "tube").forEach((shape) => R.solid(shape));
  R.put({ name, at: ref, bias, svg, shapes, ...(part ? { part } : {}) });
}

function slab(name, plan, z, h, style = {}, { steps = 8, bevel = 0, inner = "", extra = "", bias = 0 } = {}) {
  const paths = k.slabOf(plan, z, h, P, steps, bevel);
  add(name, [plan.x + plan.w / 2, plan.y + plan.d / 2, z + h / 2], S(paths, { tone: style.tone ?? "mid", crease: style.crease, lit: style.lit, inner }) + extra, [A.slab(plan, z, h, { name }, steps)], { bias });
  return paths;
}

function cyl(name, x, y, r, z, h, style = {}, { steps = 40, bevel = 0, inner = "", extra = "", bias = 0 } = {}) {
  const paths = k.cylinder(x, y, r, z, h, P, steps, bevel);
  add(name, [x, y, z + h / 2], S(paths, { tone: style.tone ?? "mid", crease: style.crease, lit: style.lit, inner }) + extra, [A.cylinder(x, y, r, z, h, { name })], { bias });
  return paths;
}

function turned(name, F, profile, style = {}, { steps, smooth, inner = "", extra = "", bias = 0, part = null } = {}) {
  const paths = G.solidOf(profile, F, P, { steps, smooth });
  const mid = (profile[0][0] + profile[profile.length - 1][0]) / 2;
  add(name, G.add3(F.o, G.mul3(F.a, mid)), S(paths, { tone: style.tone ?? "hi", crease: style.crease, lit: style.lit, className: style.className, inner }) + extra, [A.solid(F, profile, { name })], { bias, part });
  return paths;
}

function band(name, F, s0, s1, rIn, rOut, style = {}, { steps = 56, extra = "", bias = 0 } = {}) {
  const paths = G.ringBand(s0, s1, rIn, rOut, F, P, { steps });
  add(name, G.add3(F.o, G.mul3(F.a, (s0 + s1) / 2)), S(paths, { tone: style.tone ?? "hi", crease: style.crease }) + extra, [A.ring(F, s0, s1, rIn, rOut, { name })], { bias });
}

/* ---------------------------------------------------------------------- base */

function bench() {
  for (const [x, y] of byDepth(k.corners(PLATE, 26))) {
    const F = G.frameOf([x, y, 0], [0, 0, 1], [1, 0, 0], [0, 1, 0]);
    const profile = [[FLOOR, 6], [FLOOR + FOOT_H, 6], [FLOOR + FOOT_H, 8], [FLOOR + 1.8, 8], [FLOOR + 1.8, 6]];
    const paths = G.solidOf(profile, F, P, { steps: 26 });
    add("stand.foot", [x, y, FLOOR], S(paths, { tone: "lo" }), [A.solid(F, profile, { name: "stand.foot" })]);
  }

  const groove = k.planOutline(k.insetPlan(PLATE, 6), 0, P, 10);
  const screws = k.corners(PLATE, 15);
  const screwRings = screws.map(([x, y]) => k.ring(x, y, 2.4, 0, P, 18)).join("");
  slab("stand.plate", PLATE, PLATE_Z, -PLATE_Z, { tone: "mid" }, {
    steps: 10, bevel: 1.6,
    extra: `<path class="iso-halo" d="${k.haloOf(PLATE, FLOOR, 1.2, P)}"/>` +
      Ln(groove, { tone: "faint" }) +
      Ln(screwRings, { tone: "lo" }) +
      Dots(screws.map(([x, y]) => at([x, y, 0])), { size: 0.55 }) +
      Dots(k.corners(PLATE, 34).map(([x, y]) => at([x, y, 0])), { size: 0.4, tone: "lo" }),
  });

  const ticks = k.topTicks(RULER.x + 5, RULER.x + RULER.w - 5, 4, 5, RULER.y + 0.6, 0.9, [2.4, 4.2], P);
  slab("stand.ruler", RULER, 0, 0.9, { tone: "lo" }, {
    steps: 3, crease: "none",
    extra: Ln(ticks.minor, { tone: "lo" }) + Ln(ticks.major, { tone: "mid" }) +
      Dots([at([RULER.x + 2, RULER.y + 3, 0.9]), at([RULER.x + RULER.w - 2, RULER.y + 3, 0.9])], { size: 0.45 }),
  });

  const rules = [
    k.lineOnTop([NAME.x + 4, NAME.y + 4.4], [NAME.x + 26, NAME.y + 4.4], 1, P),
    k.lineOnTop([NAME.x + 4, NAME.y + 7.4], [NAME.x + 34, NAME.y + 7.4], 1, P),
    k.lineOnTop([NAME.x + 4, NAME.y + 10.4], [NAME.x + 19, NAME.y + 10.4], 1, P),
  ].join("");
  slab("stand.nameplate", NAME, 0, 1, { tone: "hi" }, {
    steps: 4, bevel: 0.4,
    extra: Ln(k.planOutline(k.insetPlan(NAME, 1.4), 1, P, 4), { tone: "faint" }) +
      Ln(rules, { tone: "lo", free: true }) +
      Dots([[NAME.x + 2.2, NAME.y + NAME.d - 2.4, 1], [NAME.x + NAME.w - 2.2, NAME.y + NAME.d - 2.4, 1]].map(at), { size: 0.4 }),
  });

  cyl("stand.stud", 134, 30, 4.4, 0, 2.2, { tone: "hi" }, { steps: 24 });
  cyl("stand.studNut", 134, 30, 3, 2.2, 3.4, { tone: "hi" }, {
    steps: 20,
    inner: Ln(k.knurl(134, 30, 3, 2.2, 5.6, 14, P), { tone: "lo" }),
  });
  cyl("stand.decal", 128, 64, 6.4, 0, 0.5, { tone: "hi" }, {
    steps: 30, crease: "faint",
    extra: Ln(k.ring(128, 64, 4.6, 0.5, P, 30), { tone: "mid" }) +
      Ln(k.lineOnTop([123.8, 64], [132.2, 64], 0.5, P) + k.lineOnTop([128, 59.8], [128, 68.2], 0.5, P), { tone: "faint" }),
  });
}

/* ------------------------------------------------------- inlet, cable, clamp */

function inlet() {
  const GF = G.frameOf([INLET[0], INLET[1], 0], [0, 0, 1], [1, 0, 0], [0, 1, 0]);
  cyl("inlet.boss", INLET[0], INLET[1], 7, 0, 4, { tone: "mid" }, {
    steps: 30, bevel: 0.5,
    inner: Ln(k.sideArc(INLET[0], INLET[1], 7, 2.6, P, 26), { tone: "faint" }),
  });
  turned("inlet.gland", GF, [[4, 5.6], [4, 4.8], [9, 4.8], [9, 5.8], [15, 5.8], [16.4, 3.9], [17, 3.4]], { tone: "hi" }, {
    steps: 32,
    inner: Ln(G.arcOf(GF, 9, 5.8, P) + G.arcOf(GF, 15, 5.8, P), { tone: "faint" }) +
      Ln(G.ribsOf(GF, 9, 15, 5.82, 12, P, { least: 0.02 }) || "", { tone: "lo" }),
  });
  turned("inlet.boot", GF, [[17, 3.4, 1], [18.6, 2.4, 1]], { tone: "hi" }, { steps: 30, smooth: true });

  const sx = -130;
  slab("inlet.saddle", { x: sx - 4.5, y: CORD_Y - 5.4, w: 9, d: 10.8, r: 1 }, 0, 1.6, { tone: "mid" }, { steps: 3, bevel: 0.3 });
  for (const [j, sy] of [[0, -1], [1, 1]]) {
    const y0 = sy < 0 ? CORD_Y - 5.3 : CORD_Y + 3.7;
    slab(`inlet.cheek${j}`, { x: sx - 4.5, y: y0, w: 9, d: 1.6, r: 0.4 }, 1.6, CORD_Z - 2.4 - 1.6, { tone: "mid" }, { steps: 2, crease: "none" });
  }

  const line = G.fillet(
    [[INLET[0], INLET[1], 18.6], [INLET[0], INLET[1], 23.4], [INLET[0] + 3, INLET[1] + 1, 24.4],
      [INLET[0] + 6.5, INLET[1] - 2, 23], [INLET[0] + 10, INLET[1] - 8, 14], [INLET[0] + 12, INLET[1] - 12, CORD_Z],
      [-124, CORD_Y, CORD_Z]],
    4.2, 9, { P, tube: 2.4 },
  );
  R.route("inlet.cord", line, 2.4, { limp: true, rims: [2.4, 2.4] });
  tubePieces(line, 2.4, P, { maxLength: 16, spacing: 2.4 }).forEach((piece, index) => {
    add(`inlet.cord:${index}`, piece.mid, tubeSvg(piece, { tone: "hi" }), [A.tube(piece.points, piece.radii)], { part: index === 0 ? "cord" : null });
  });
}

/* ------------------------------------------------------ terminal block, shunt */

function terminal() {
  slab("term.body", TERM, 0, TERM_TOP, { tone: "mid" }, {
    steps: 4, bevel: 0.8,
    extra: Ln(k.sideSeam(TERM, 5, P, 4), { tone: "faint" }) +
      Ln(k.planOutline(k.insetPlan(TERM, 1.6), TERM_TOP, P, 4), { tone: "faint" }) +
      Dots([[TERM.x + 4, TERM.y + 5, TERM_TOP], [TERM.x + TERM.w - 4, TERM.y + 5, TERM_TOP]].map(at), { size: 0.45 }),
  });
  slab("term.bus", BAR, TERM_TOP, BAR_TOP - TERM_TOP, { tone: "hi" }, {
    steps: 4, bevel: 0.4,
    extra: Ln(k.planOutline(k.insetPlan(BAR, 1), BAR_TOP, P, 4), { tone: "faint" }),
  });
  for (const [i, x] of [[0, -114], [1, -96]]) {
    const F = G.frameOf([x, 21, 0], [0, 0, 1], [1, 0, 0], [0, 1, 0]);
    turned(`term.post${i}`, F, [[BAR_TOP, 3], [BAR_TOP + 6.4, 3], [BAR_TOP + 6.4, 4.2], [BAR_TOP + 8.6, 4.2]], { tone: "hi" }, {
      steps: 24,
      inner: Ln(k.knurl(x, 21, 4.2, BAR_TOP + 6.4, BAR_TOP + 8.6, 16, P), { tone: "lo" }),
    });
  }

  const INSUL = { x: -120, y: 0, w: 17, d: 9, r: 1 };
  slab("shunt.insulator", INSUL, TERM_TOP, 4, { tone: "hi" }, {
    steps: 3, bevel: 0.3,
    extra: Ln(k.planOutline(k.insetPlan(INSUL, 1), 17, P, 3), { tone: "faint" }),
  });
  for (const [i, x] of [[0, -118.6], [1, -106]]) {
    slab(`shunt.blade${i}`, { x, y: 1, w: 2.6, d: 6.6, r: 0.6 }, 17, 33, { tone: "hi" }, {
      steps: 3, bevel: 0.4,
      extra: Ln(k.planOutline({ x, y: 1, w: 2.6, d: 6.6, r: 0.6 }, 50, P, 3), { tone: "faint" }),
    });
  }
  slab("shunt.bar", { x: -119.2, y: 1, w: 15.2, d: 6.6, r: 0.8 }, 50, 3, { tone: "hi" }, {
    steps: 3, bevel: 0.4,
    extra: Dots([at([-116, 4.2, 53]), at([-107.4, 4.2, 53])], { size: 0.5 }),
  });

  slab("coil.bracket", { x: -103, y: 2.4, w: 10, d: 10.6, r: 1 }, TERM_TOP, 4, { tone: "mid" }, { steps: 3, bevel: 0.3 });
  const CF = G.frameOf([-98, 7.7, 0], [0, 0, 1], [1, 0, 0], [0, 1, 0]);
  cyl("coil.cheekLow", -98, 7.7, 4.6, 17, 1.5, { tone: "hi" }, { steps: 34 });
  cyl("coil.winding", -98, 7.7, 4.0, 18.5, 8.2, { tone: "hi" }, {
    steps: 34,
    inner: Ln(k.knurl(-98, 7.7, 4.0, 18.5, 26.7, 18, P), { tone: "lo" }),
  });
  cyl("coil.cheekHigh", -98, 7.7, 4.6, 26.7, 1.5, { tone: "hi" }, { steps: 34 });
  cyl("coil.post", -98, 7.7, 1.5, 28, 3, { tone: "hi" }, { steps: 18 });
  cyl("coil.nut", -98, 7.7, 2.4, 31, 1.4, { tone: "hi" }, { steps: 18 });

  const wire = G.fillet(
    [[-98, 7.7, 32.4], [-98, 7.7, 41], [-72, 2, 41], [POST_AT[0], POST_AT[1], 41], [POST_AT[0], POST_AT[1], 14]],
    9, 8, { P, tube: 0.6 },
  );
  R.route("sense.wire", wire, 0.6, { rims: [1.6, 3] });
  tubePieces(wire, 0.6, P, { maxLength: 24, spacing: 1.8 }).forEach((piece, index) => {
    add(`sense.wire:${index}`, piece.mid, tubeSvg(piece, { tone: "mid" }), [A.tube(piece.points, piece.radii)]);
  });
}

/* ---------------------------------------------------------------------- dial */

const DIAL_F = G.frameOf([DIAL[0], DIAL[1], 0], [0, 0, 1], [1, 0, 0], [0, 1, 0]);

function dial() {
  const [x, y] = DIAL;
  turned("dial.base", DIAL_F, [
    [0, DIAL_BASE_R], [1.2, DIAL_BASE_R], [2.4, DIAL_BASE_R - 1.6], [7, DIAL_BASE_R - 1.6],
  ], { tone: "mid" }, {
    steps: 72,
    inner: Ln(G.arcOf(DIAL_F, 4.6, DIAL_BASE_R - 1.6, P), { tone: "faint" }) +
      Dots(G.dotsOf(DIAL_F, 7, DIAL_BASE_R - 5, 6, P, { all: true }), { size: 0.4 }),
  });
  cyl("dial.collar", x, y, 28.5, 7, 2, { tone: "mid" }, { steps: 60 });
  cyl("dial.body", x, y, DIAL_R, 9, 13, { tone: "hi" }, {
    steps: 76, crease: "lo",
    extra: (() => {
      const t = k.radialTicks(x, y, 22.9, 30, 5, 22, [1.3, 2.8], P, 45 * DEG, 180 * DEG);
      return Ln(t.minor, { tone: "lo" }) + Ln(t.major, { tone: "mid" }) +
        k.faceTextSvg(k.topMatrix([x, y - 12.5], 22, P, "x"), "W", { size: 4, tone: "lo", anchor: "middle" }) +
        Ln(k.ring(x, y, 22.9, 22, P, 64), { tone: "faint" }) +
        Ln(k.ring(x, y, 19.6, 22, P, 56), { tone: "faint" });
    })(),
    inner: Ln(k.sideArc(x, y, DIAL_R, 10.2, P, 40), { tone: "faint" }) +
      Ln(k.knurl(x, y, DIAL_R, 10.2, 13.4, 60, P), { tone: "lo" }) +
      Ln(k.sideArc(x, y, DIAL_R, 13.4, P, 40), { tone: "faint" }) +
      Ln(k.sideArc(x, y, DIAL_R, 19.4, P, 40), { tone: "faint" }),
  });
  const bez = [[22, 23.7], [22, 26.0], [23.2, 26.45], [25.0, 26.45], [25.4, 25.9], [25.4, 23.7], [22, 23.7]];
  add("dial.bezel", [x, y, 23.7], S(G.lathe(bez, DIAL_F, P, { steps: 76 }), {
    tone: "hi", crease: "lo", className: "pb-strong",
    inner: Ln(k.knurl(x, y, 26.45, 23.6, 24.9, 84, P, 0.2), { tone: "lo" }) +
      Ln(G.arcOf(DIAL_F, 22.4, 26.2, P), { tone: "mid" }),
  }), [A.lathe(DIAL_F, bez, { name: "dial.bezel" })]);

  cyl("dial.hub", x, y, 2.6, 22, 1.5, { tone: "hi" }, { steps: 20 });
  slab("dial.crownNeck", { x: x + 26.4, y: y - 3, w: 4.2, d: 6, r: 1.2 }, 23.2, 2.4, { tone: "hi" }, { steps: 3, crease: "none" });
  const CF = G.frameAlong([x + 30.6, y, 24.4], [1, 0, 0]);
  turned("dial.crown", CF, [[0, 3.2], [5.2, 3.2]], { tone: "hi" }, {
    steps: 26,
    inner: Ln(G.ribsOf(CF, 0, 5.2, 3.22, 16, P, { least: 0.02 }) || "", { tone: "lo" }),
  });

  cyl("dial.post", POST_AT[0], POST_AT[1], 2.2, 7, 5.4, { tone: "hi" }, { steps: 20 });
  cyl("dial.postNut", POST_AT[0], POST_AT[1], 3, 12.4, 1.6, { tone: "hi" }, { steps: 20 });

  add("dial.needle", [x, y - 10, 22.2], needleSvg(), [
    A.box([x - 0.6, y - 21.9, 22], [x + 0.6, y - 2.6, 22.3], { name: "dial.needle" }),
  ], { bias: 0.6, part: "needle" });
}

function needleSvg() {
  const [x, y] = DIAL;
  return Ln(k.lineOnTop([x, y + 2.6], [x, y - 21.9], 22.2, P), { tone: "lit", className: "pb-needle" });
}

/* ------------------------------------------------------------------- recorder */

function recorder() {
  const seam = k.sideSeam(REC, 16, P, 4);
  const vents = [0, 1, 2, 3].map((i) => k.planOutline({ x: REC.x + 8 + i * 5, y: REC.y + REC.d - 3.4, w: 3.4, d: 1.4, r: 0.6 }, CASE_TOP - 6, P, 2)).join("");
  slab("rec.case", REC, 0, CASE_TOP, { tone: "mid" }, {
    steps: 4, bevel: 1.2,
    extra: Ln(seam, { tone: "faint" }) +
      Ln(vents, { tone: "faint" }) +
      Ln(k.sideSeam(REC, CASE_TOP - 1.4, P, 4), { tone: "faint" }) +
      Dots([[REC.x + 6, REC.y + 6, CASE_TOP], [REC.x + REC.w - 6, REC.y + 6, CASE_TOP]].map(at), { size: 0.5 }),
  });
  slab("rec.deck", DECK, CASE_TOP, DECK_TOP - CASE_TOP, { tone: "hi" }, {
    steps: 4, bevel: 0.3,
    extra: Ln(k.planOutline(k.insetPlan(DECK, 3), DECK_TOP, P, 4), { tone: "faint" }),
  });

  const paperPaths = k.slabOf(PAPER, DECK_TOP, PAPER_Z - DECK_TOP, P, 3, 0);
  add("rec.paper", [PAPER.x + PAPER.w / 2, PAPER.y + PAPER.d / 2, PAPER_Z], S(paperPaths, { tone: "hi", crease: "lo" }) +
    `<path d="${paperPaths.top}" fill="url(#pbgrid)"/>` +
    `<path data-part="trace" class="iso-line" data-tone="lit" style="stroke-width:.8" d=""/>`,
  [A.slab(PAPER, DECK_TOP, PAPER_Z - DECK_TOP, { name: "rec.paper" }, 3)]);

  for (const [i, ry, top] of [[0, SUPPLY_Y, PAPER_Z + SUPPLY_R + 5.4], [1, TAKE_Y, PAPER_Z + TAKE_R + 5.4]]) {
    for (const [j, bx] of [[0, 40], [1, 100]]) {
      slab(`rec.bracket${i}${j}`, { x: bx, y: ry - 8, w: 6, d: 16, r: 1.4 }, DECK_TOP, top - DECK_TOP, { tone: "mid" }, {
        steps: 3, bevel: 0.4,
        extra: Dots([at([bx + 3, ry - 4, top - 3]), at([bx + 3, ry + 4, top - 3])], { size: 0.45 }),
      });
    }
  }

  roll("rec.supply", SUPPLY_Y, PAPER_Z + SUPPLY_R + 0.4, SUPPLY_R);
  roll("rec.take", TAKE_Y, PAPER_Z + TAKE_R + 0.4, TAKE_R);

  for (const [i, bx] of [[0, 42], [1, 100]]) {
    slab(`rec.barPost${i}`, { x: bx, y: PEN_Y - 5.5, w: 4, d: 5, r: 1 }, DECK_TOP, BAR_H - DECK_TOP, { tone: "mid" }, { steps: 3, bevel: 0.3 });
  }
  slab("rec.bar", { x: 46, y: PEN_Y - 5.5, w: 54, d: 5, r: 0.8 }, BAR_H, BAR_Z - BAR_H, { tone: "hi" }, {
    steps: 3, bevel: 0.3,
    extra: Ln(k.planOutline({ x: 46, y: PEN_Y - 5.5, w: 54, d: 5, r: 0.8 }, BAR_Z, P, 3), { tone: "faint" }),
  });

  add("rec.pen", [PEN_X0, PEN_Y - 2, 31], penSvg(), [
    A.box([PEN_X0 - 6, PEN_Y - 7, BAR_Z], [PEN_X0 + 6, PEN_Y + 1.5, 36.2], { name: "rec.carriage" }),
    A.box([PEN_X0 - 0.7, PEN_Y - 1, PAPER_Z + 1.2], [PEN_X0 + 0.7, PEN_Y + 1, BAR_Z], { name: "rec.arm" }),
    A.disc(G.frameOf([PEN_X0, PEN_Y, PAPER_Z + 0.1], [0, 0, 1], [1, 0, 0], [0, 1, 0]), 0, 1.3, 1.4, { name: "rec.nib" }),
  ], { bias: 3, part: "pen" });

  const lampF = G.frameAlong([REC.x + 10, REC.y + REC.d, 17], [0, 1, 0]);
  turned("rec.lamp", lampF, [[0, 2.2], [1.2, 2.2], [1.6, 1.7]], { tone: "hi" }, {
    steps: 22,
    extra: Ln(G.circleOf(lampF, 1.2, 1.36, P), { tone: "green" }),
  });
}

function roll(name, y, z, r) {
  const F = G.frameAlong([46, y, z], [1, 0, 0]);
  const face = G.frameOf([46, y, z], [1, 0, 0], [0, 0, 1], [0, -1, 0]);
  turned(`${name}.body`, F, [[2, r], [52, r]], { tone: "hi" }, { steps: 48 });
  turned(`${name}.flangeA`, F, [[0, r + 0.4], [2, r + 0.4]], { tone: "hi" }, { steps: 48 });
  turned(`${name}.flangeB`, F, [[52, r + 0.4], [54, r + 0.4]], { tone: "hi" }, {
    steps: 48,
    extra: Ln([2.6, 4.8, r - 2.4].map((rr) => G.circleOf(face, 54, rr, P, 44)).join(""), { tone: "mid" }),
  });
}

function penSvg() {
  const x = PEN_X0;
  const out = [];
  out.push(S(k.slabOf({ x: x - 6, y: PEN_Y - 7, w: 12, d: 8.5, r: 1.2 }, BAR_Z, 5, P, 3, 0.4), { tone: "hi" }));
  out.push(S(k.slabOf({ x: x - 3.4, y: PEN_Y + 1.2, w: 6.8, d: 2.4, r: 0.8 }, BAR_Z + 1.4, 3.2, P, 3), { tone: "mid" }));
  out.push(S(k.slabOf({ x: x - 0.7, y: PEN_Y - 1, w: 1.4, d: 2, r: 0.3 }, PAPER_Z + 1.2, BAR_Z - PAPER_Z - 1.2, P, 2), { tone: "mid", crease: "none" }));
  out.push(S(k.cylinder(x, PEN_Y, 1.4, PAPER_Z + 0.1, 1.3, P, 16), { tone: "hi", lit: true }));
  return out.join("");
}

/* ------------------------------------------------------------- archive box */

function archive() {
  const b = BOX;
  slab("box.floor", b, 0, 2.2, { tone: "mid" }, { steps: 3, bevel: 0.3 });
  const walls = [
    { x: b.x, y: b.y, w: b.w, d: 2.2, r: 0.6 },
    { x: b.x, y: b.y + b.d - 2.2, w: b.w, d: 2.2, r: 0.6 },
    { x: b.x, y: b.y + 2.2, w: 2.2, d: b.d - 4.4, r: 0.6 },
    { x: b.x + b.w - 2.2, y: b.y + 2.2, w: 2.2, d: b.d - 4.4, r: 0.6 },
  ];
  walls.forEach((wall, i) => {
    slab(`box.wall${i}`, wall, 2.2, BOX_TOP - 2.2, { tone: "mid" }, {
      steps: 3, bevel: 0.3,
      extra: i === 1 ? Ln(k.planOutline({ x: b.x + 7, y: b.y + b.d - 1.6, w: 26, d: 0.9, r: 0.3 }, BOX_TOP - 4, P, 2), { tone: "faint" }) : "",
    });
  });
  for (const [i, y] of [[0, b.y + 10], [1, b.y + 23]]) {
    const F = G.frameAlong([b.x + 5, y, 7.9], [1, 0, 0]);
    const face = G.frameOf([b.x + 5, y, 7.9], [1, 0, 0], [0, 0, 1], [0, -1, 0]);
    turned(`box.roll${i}`, F, [[0, 5.6], [b.w - 10, 5.6]], { tone: "hi" }, {
      steps: 40,
      extra: Ln(G.circleOf(face, b.w - 10, 3.6, P, 30) + G.circleOf(face, b.w - 10, 1.9, P, 24), { tone: "mid" }),
    });
  }
}

/* --------------------------------------------------------------------- bell */

function bell() {
  const [x, y] = BELL;
  cyl("bell.flange", x, y, 6.2, 0, 2.4, { tone: "hi" }, { steps: 28 });
  cyl("bell.post", x, y, 2.6, 2.4, 18, { tone: "hi" }, { steps: 24 });
  const BF = G.frameOf([x, y, 0], [0, 0, 1], [1, 0, 0], [0, 1, 0]);
  turned("bell.body", BF, [
    [20.4, 3.4], [21.4, 9.2, 1], [23.6, 9.4, 1], [30, 6.2, 1], [32.6, 2.2, 1], [33.4, 0],
  ], { tone: "hi", className: "pb-strong" }, {
    steps: 56, smooth: true,
    inner: Ln(G.arcOf(BF, 21.6, 9.3, P), { tone: "mid" }),
  });
  cyl("bell.pivot", PIVOT[0], PIVOT[1], 2.6, 0, 19, { tone: "mid" }, { steps: 22 });
  add("bell.hammer", [PIVOT[0] - 8, PIVOT[1] + 1, 21], hammerSvg(), [
    A.box([PIVOT[0] - 9, PIVOT[1] - 2, 19], [PIVOT[0] + 1, PIVOT[1] + 2, 22], { name: "bell.arm" }),
    A.disc(G.frameOf([PIVOT[0] - 6.5, PIVOT[1], 22], [0, 0, 1], [1, 0, 0], [0, 1, 0]), 0, 3.4, 2.6, { name: "bell.head" }),
  ], { bias: 1, part: "hammer" });
  cyl("bell.pivotCap", PIVOT[0], PIVOT[1], 3.3, 22, 1.2, { tone: "mid" }, { steps: 22 });
}

function hammerSvg() {
  const [px, py] = PIVOT;
  const out = [];
  out.push(S(k.slabOf({ x: px - 9, y: py - 2, w: 10, d: 4, r: 1.4 }, 19, 3, P, 3, 0.4), { tone: "mid" }));
  out.push(S(k.cylinder(px - 6.5, py, 2.6, 22, 3.4, P, 20), { tone: "hi", lit: true }));
  out.push(S(k.cylinder(px - 6.5, py, 1.2, 22.4, 3, P, 12), { tone: "mid" }));
  out.push(S(k.slabOf({ x: px - 1.8, y: py - 2.2, w: 3.6, d: 4.4, r: 0.8 }, 21, 1, P, 3), { tone: "mid" }));
  return out.join("");
}

/* --------------------------------------------------------------- escapement */

function toothed(angle) {
  const pts = [];
  const n = 20;
  for (let i = 0; i < n; i++) {
    const a0 = (i / n) * Math.PI * 2 + angle;
    const step = (Math.PI * 2) / n;
    pts.push([ESC[0] + Math.cos(a0) * ESC_R, ESC[1] + Math.sin(a0) * ESC_R]);
    pts.push([ESC[0] + Math.cos(a0 + step * 0.72) * (ESC_R + 1.6), ESC[1] + Math.sin(a0 + step * 0.72) * (ESC_R + 1.6)]);
  }
  return pts;
}

function ratchetSvg(angle) {
  const ring = toothed(angle);
  const paths = k.extrude(ring, 10, 3.4, P, { convex: false }, 2, 0);
  return S(paths, { tone: "hi", className: "pb-strong" }) + Ln(k.planOutline({ x: ESC[0] - 3.4, y: ESC[1] - 3.4, w: 6.8, d: 6.8, r: 1.1 }, 13.4, P, 4), { tone: "faint" });
}

function pawlSvg() {
  const px = ESC[0], py = ESC[1] + 20;
  const out = [];
  out.push(S(k.slabOf({ x: px - 2.4, y: py - 9, w: 4.8, d: 11, r: 1.2 }, 13.5, 2, P, 3, 0.3), { tone: "mid" }));
  out.push(S(k.slabOf({ x: px - 1.5, y: py - 10.4, w: 3, d: 3.4, r: 0.8 }, 13.5, 2.4, P, 3, 0.3), { tone: "hi" }));
  out.push(S(k.cylinder(px, py, 2.8, 15.5, 1, P, 20), { tone: "mid" }));
  return out.join("");
}

function escapement() {
  slab("esc.plate", { x: ESC[0] - 14, y: ESC[1] - 12, w: 28, d: 24, r: 3 }, 0, 3, { tone: "mid" }, {
    steps: 4, bevel: 0.5,
    extra: Dots([at([ESC[0] - 10, ESC[1] - 8, 3]), at([ESC[0] + 10, ESC[1] - 8, 3])], { size: 0.45 }),
  });
  cyl("esc.boss", ESC[0], ESC[1], 5, 3, 7, { tone: "mid" }, { steps: 30 });
  add("esc.wheel", [ESC[0], ESC[1], 11.7], ratchetSvg(0), [A.cylinder(ESC[0], ESC[1], ESC_R + 1.6, 10, 3.4, { name: "esc.wheel" })], { bias: 1, part: "ratchet" });
  cyl("esc.hub", ESC[0], ESC[1], 2.4, 13.4, 1.6, { tone: "hi" }, { steps: 18 });
  cyl("esc.pin", ESC[0], ESC[1], 1, 15, 2.2, { tone: "hi" }, { steps: 14 });

  const py = ESC[1] + 20;
  cyl("esc.pawlPost", ESC[0], py, 2.4, 0, 13.5, { tone: "mid" }, { steps: 20 });
  add("esc.pawl", [ESC[0], py - 4, 14.5], pawlSvg(), [
    A.box([ESC[0] - 2.4, py - 9, 13.5], [ESC[0] + 2.4, py + 2, 15.5], { name: "esc.pawl" }),
    A.disc(G.frameOf([ESC[0], py, 15.5], [0, 0, 1], [1, 0, 0], [0, 1, 0]), 0, 1, 2.8, { name: "esc.pawlCap" }),
  ], { bias: 2, part: "pawl" });
}

/* ------------------------------------------------------------------ assemble */

bench();
inlet();
terminal();
dial();
recorder();
archive();
bell();
escapement();

const PAPER_GRID = (() => {
  const o = at([PAPER.x, PAPER.y, PAPER_Z]);
  const u = at([PAPER.x + 1, PAPER.y, PAPER_Z]);
  const v = at([PAPER.x, PAPER.y + 1, PAPER_Z]);
  return { o, u: [u[0] - o[0], u[1] - o[1]], v: [v[0] - o[0], v[1] - o[1]] };
})();

A.settle(R, P);
items.sort((a, b) => a.key - b.key);

const art = items.map((item) => (item.part ? `<g data-part="${item.part}">${item.svg}</g>` : item.svg)).join("\n");

/* ------------------------------------------------------------------- output */

const gridMatrix = (phase) => {
  const { o, u, v } = PAPER_GRID;
  return `matrix(${u[0].toFixed(4)} ${u[1].toFixed(4)} ${v[0].toFixed(4)} ${v[1].toFixed(4)} ${(o[0] + v[0] * phase).toFixed(2)} ${(o[1] + v[1] * phase).toFixed(2)})`;
};

const defs = `<defs>
  <pattern id="pbgrid" patternUnits="userSpaceOnUse" width="4" height="8" patternTransform="${gridMatrix(0)}">
    <rect width="4" height="8" fill="var(--anatomy-paper)"/>
    <path d="M0 0V8" stroke="var(--anatomy-faint)" stroke-width="0.22" fill="none"/>
    <path d="M0 0H4" stroke="var(--anatomy-faint)" stroke-width="0.16" fill="none"/>
  </pattern>
</defs>`;

const svg = k.figureSvg({
  width: W,
  height: H,
  label:
    "A power-measurement bench drawn in isometric view. A cord rises through a gland at the left into a two-screw terminal block, where a vertical shunt and its sampling coil turn the current into a small voltage; a fine sense wire carries it to the dial, whose needle reads the wall draw. To the right a strip-chart recorder draws the same power on paper running from a full supply roll to a take-up roll; an archive box below holds wound tapes, a brass bell at the back rings when draw passes its limit, and a ratchet wheel at the front steps one tooth a second for every sample.",
  body: defs + art,
});

const live = `
const PB_P = ${JSON.stringify(P)};
const PB_DIAL = ${JSON.stringify(DIAL)};
const PB_FACE = ${FACE_Z};
const PB_PAPER_Z = ${PAPER_Z};
const PB_PEN = { x0: ${PEN_X0}, span: ${PEN_SPAN}, y: ${PEN_Y} };
const PB_GRID = ${JSON.stringify(PAPER_GRID)};
const PB_EDGE = ${PAPER.y + PAPER.d};
const PB_SPEED = 1.6;
const PB_MAX = 60;
const PB_SYSTEM = 11.4;
const PB_MEASURED = { wall: 33.7, charge: 22.2, temp: 34 };
const PB_ESC = ${JSON.stringify(ESC)};
const PB_PIVOT = ${JSON.stringify(PIVOT)};
const stage = document.querySelector(".iso-stage");
const pbRoot = stage.querySelector("svg");
const needleEl = pbRoot.querySelector('[data-part="needle"]');
const penEl = pbRoot.querySelector('[data-part="pen"]');
const traceEl = pbRoot.querySelector('[data-part="trace"]');
const hammerEl = pbRoot.querySelector('[data-part="hammer"]');
const pawlEl = pbRoot.querySelector('[data-part="pawl"]');
const ratchetEl = pbRoot.querySelector('[data-part="ratchet"]');
const gridEl = pbRoot.querySelector("#pbgrid");
const readout = document.querySelector("[data-readout]");
const still = matchMedia("(prefers-reduced-motion: reduce)");
const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));

function rotZ(pivot, deg) {
  const cam = cameraOf(PB_P);
  const t = (deg * Math.PI) / 180, ct = Math.cos(t), st = Math.sin(t);
  const ux = [cam.sinA * cam.k, cam.cosA * cam.sinE * cam.k];
  const vy = [-cam.cosA * cam.k, cam.sinA * cam.sinE * cam.k];
  const u2 = [ct * ux[0] + st * vy[0], ct * ux[1] + st * vy[1]];
  const v2 = [-st * ux[0] + ct * vy[0], -st * ux[1] + ct * vy[1]];
  const det = ux[0] * vy[1] - ux[1] * vy[0];
  const i00 = vy[1] / det, i01 = -vy[0] / det, i10 = -ux[1] / det, i11 = ux[0] / det;
  const a = u2[0] * i00 + v2[0] * i10, b = u2[1] * i00 + v2[1] * i10;
  const c = u2[0] * i01 + v2[0] * i11, d = u2[1] * i01 + v2[1] * i11;
  const o = iso(pivot, PB_P);
  return "matrix(" + [a, b, c, d, o[0] - a * o[0] - c * o[1], o[1] - b * o[0] - d * o[1]]
    .map((v) => v.toFixed(5)).join(" ") + ")";
}

const penX = (v) => PB_PEN.x0 + (v / PB_MAX) * PB_PEN.span;
const needleDeg = (v) => 225 - (180 * v) / PB_MAX;

function noiseAt(t0) {
  return 33.7 + 5.6 * Math.sin(t0 * 0.45) + 2.3 * Math.sin(t0 * 1.31 + 1.2) + 1.2 * Math.sin(t0 * 2.9 + 0.4);
}

let clock = 0, load = 33.7, target = 33.7, last = 0, frame = 0, visible = false, touring = true, idle = 0;
let nextSample = 1, steps = 0, tapAge = 99, interacting = false, selfTest = false;
const HISTORY = [];
for (let i = 26; i >= 0; i--) HISTORY.push({ t: -i, v: noiseAt(-i) });

const k = { extrude, planOutline, slabOf, cylinder, solidSvg, knurl, coil };
const S = (paths, style) => solidSvg(paths, style);
const Ln = (d, style) => lineSvg(d, style);
const P = PB_P;
const ESC = PB_ESC;
const ESC_R = ${ESC_R};
const PIVOT = PB_PIVOT;

${toothed.toString()}
${ratchetSvg.toString()}
${pawlSvg.toString()}
${hammerSvg.toString()}

function traceD(now, newest) {
  const pts = [[penX(newest), PB_PEN.y]];
  for (let i = HISTORY.length - 1; i >= 0; i--) {
    const s = HISTORY[i];
    const y = (now - s.t) * PB_SPEED;
    if (y > PB_EDGE - PB_PEN.y + 0.6) break;
    pts.push([penX(s.v), PB_PEN.y + y]);
  }
  const out = [];
  for (let i = 0; i < pts.length; i++) {
    const p = pts[i];
    if (p[1] <= PB_EDGE) { out.push(p); continue; }
    const q = pts[i - 1];
    if (!q) break;
    const share = (PB_EDGE - q[1]) / (p[1] - q[1]);
    out.push([q[0] + (p[0] - q[0]) * share, PB_EDGE]);
    break;
  }
  return out.length > 2 ? onTop(out, PB_PAPER_Z + 0.1, PB_P) : "";
}

function draw(now) {
  needleEl.setAttribute("transform", rotZ([PB_DIAL[0], PB_DIAL[1], PB_FACE], needleDeg(load)));
  penEl.setAttribute("transform", translateAlong(PB_P, [penX(load) - PB_PEN.x0, 0, 0]));
  const swing = tapAge < 0.5 ? Math.sin((tapAge / 0.5) * Math.PI * 2) * 6 * (1 - tapAge / 0.5) : 0;
  hammerEl.setAttribute("transform", rotZ([PB_PIVOT[0], PB_PIVOT[1], 21], -swing));
  const phase = now % 1;
  const lift = phase < 0.1 ? Math.sin((phase / 0.1) * Math.PI) * 5 : 0;
  pawlEl.setAttribute("transform", rotZ([PB_ESC[0], PB_ESC[1] + 20, 15.5], lift));
  ratchetEl.innerHTML = ratchetSvg(-((steps % 20) * Math.PI) / 10);
  const shift = (now * PB_SPEED) % 8;
  const g = PB_GRID;
  gridEl.setAttribute("patternTransform", "matrix(" + [g.u[0], g.u[1], g.v[0], g.v[1],
    g.o[0] + g.v[0] * shift, g.o[1] + g.v[1] * shift].map((v) => Math.round(v * 1e4) / 1e4).join(" ") + ")");
  const d = traceD(now, load);
  if (d) traceEl.setAttribute("d", d);
  const wall = (interacting ? load : PB_MEASURED.wall).toFixed(1);
  const charge = (interacting ? Math.max(0, load - PB_SYSTEM) : PB_MEASURED.charge).toFixed(1);
  const temp = (interacting ? 32.4 + 2.4 * clamp(load / 42, 0, 1) : PB_MEASURED.temp).toFixed(0);
  const text = wall + " W IN · " + charge + " W TO BATTERY · " + temp + " °C · 92.9%";
  if (readout.textContent !== text) readout.textContent = text;
  stage.setAttribute("aria-valuenow", wall);
  stage.setAttribute("aria-valuetext", wall + " watts at the wall");
}

function tick(nowMs) {
  const dt = last ? Math.min((nowMs - last) / 1000, 1 / 30) : 1 / 60;
  last = nowMs;
  clock += dt;
  if (touring) target = 33.7 + 0.9 * Math.sin(clock * 0.9);
  load += (target - load) * (1 - Math.exp(-dt / 0.28));
  if (clock >= nextSample) {
    nextSample += 1;
    steps += 1;
    HISTORY.push({ t: clock, v: load });
    while (HISTORY.length && (clock - HISTORY[0].t) * PB_SPEED > 70) HISTORY.shift();
    if (load > 40 && tapAge > 1.1) tapAge = 0;
    if (!selfTest && clock > 2.2) { selfTest = true; tapAge = 0; }
  }
  tapAge += dt;
  draw(clock);
  frame = visible ? requestAnimationFrame(tick) : 0;
}

const run = () => { if (!frame && visible && !still.matches) { last = 0; frame = requestAnimationFrame(tick); } };
new IntersectionObserver((entries) => {
  visible = entries[entries.length - 1].isIntersecting;
  if (visible) run();
}, { rootMargin: "140px 0px" }).observe(stage);

stage.addEventListener("pointermove", (event) => {
  const box = pbRoot.getBoundingClientRect();
  const share = clamp((event.clientX - box.left) / box.width, 0.08, 0.94);
  touring = false;
  interacting = true;
  target = 6 + share * 54;
  clearTimeout(idle);
  idle = setTimeout(() => { touring = !still.matches; interacting = false; }, 4200);
});
stage.addEventListener("pointerleave", () => {
  touring = !still.matches;
  clearTimeout(idle);
  idle = setTimeout(() => { interacting = false; }, 1200);
});
stage.addEventListener("keydown", (event) => {
  const step = event.key === "ArrowRight" || event.key === "ArrowUp" ? 2 : event.key === "ArrowLeft" || event.key === "ArrowDown" ? -2 : 0;
  if (!step) return;
  event.preventDefault();
  touring = false;
  interacting = true;
  target = clamp(target + step, 4, 58);
  clearTimeout(idle);
  idle = setTimeout(() => { touring = !still.matches; interacting = false; }, 4200);
});
if (still.matches) { touring = false; load = 33.7; draw(0); }
else run();
`;

const PALETTE = `
.iso[data-theme="light"]{
  --anatomy-page:#f5f8fc;--anatomy-card:#ffffff;
  --anatomy-text:#475569;--anatomy-strong:#1A4B8C;--anatomy-muted:#64748b;
  --anatomy-paper:#ffffff;--anatomy-face:#fbfdff;--anatomy-top:#ffffff;
  --anatomy-shade-0:#a8bed6;--anatomy-shade-1:#c2d3e5;--anatomy-shade-2:#d9e5f2;--anatomy-shade-3:#edf4fa;
  --anatomy-lit-top:#fff1e2;--anatomy-lit-shade:#f8d0a8;
  --anatomy-hi:#1A4B8C;--anatomy-mid:#64748b;--anatomy-lo:#9db2ca;--anatomy-faint:#c9d8e8;--anatomy-lit:#E86C00;
  --anatomy-halo:#1A4B8C;--anatomy-halo-opacity:.14;--anatomy-dot:#1A4B8C;
  --anatomy-red:#c2410c;--anatomy-green:#0f8a4a;--anatomy-blue:#1A4B8C;
  --anatomy-weight:.6px;
}
.iso-solid.pb-strong>.iso-shade[data-shade="0"]{fill:#8aa4c2;stroke:#8aa4c2}
.iso-solid.pb-strong>.iso-shade[data-shade="1"]{fill:#9db5ce;stroke:#9db5ce}
.iso-solid.pb-strong>.iso-shade[data-shade="2"]{fill:#b1c5da;stroke:#b1c5da}
.iso-solid.pb-strong>.iso-shade[data-shade="3"]{fill:#c6d6e6;stroke:#c6d6e6}
.iso-solid.pb-strong>.iso-top{fill:#e2ecf7;stroke:#e2ecf7}
.iso-solid.pb-strong>.iso-edge{stroke:#1A4B8C}
.iso-page{width:min(700px,100% - 32px);margin:26px auto 96px}
.pb-back{display:inline-block;margin:2px 0 16px;font-size:12.5px;line-height:1.4;letter-spacing:.01em;color:#64748b;text-decoration:none;transition:color .15s ease}
.pb-back:hover,.pb-back:focus-visible{color:#1A4B8C}
.iso-plate{box-shadow:0 0 0 1px #dbe6f2,0 1px 2px #1a4b8c0a}
.iso-plate-corners{inset:16px 18px}
.iso-plate-corner[data-corner="title"]{color:#1A4B8C;letter-spacing:.12em}
.iso-plate-corner[data-corner="hint"]{color:#94a3b8}
.iso-legend{color:#64748b}
@media (max-width:560px){
  .iso-plate{padding:42px 6px 78px}
  .iso-plate-corners{inset:14px 10px}
  .iso-plate-corner{font-size:9.5px}
  .iso-plate-corner[data-corner="hint"]{bottom:0}
  .iso-plate-corner[data-corner="readout"]{bottom:17px}
  .iso-stage .iso-svg{transform:scale(1.07);transform-origin:50% 52%}
}
`;

let page = k.pageHtml({
  title: "PowerPulse · the measurement chain",
  theme: "light",
  body: k.plateHtml({
    fig: "Fig 1",
    title: "Power bench",
    hint: "Hover to load",
    readout: "33.7 W IN · 22.2 W TO BATTERY · 34 °C · 92.9%",
    caption:
      "PowerPulse 的测量链路做成一台实验台上的功率测量仪：电缆从台面下经压盖进来，两根螺钉压住的分流器把电流变成毫伏信号，细导线送到中央的指针表。右侧走纸记录仪把同一路功率画在纸带上（满卷进、收卷出），下方收纳盒存 30 天纸带，台前棘轮每秒跳一格就是采样节拍，超阈值的铜铃负责告警。实测 33.7 W 进、22.2 W 充入电池，健康度 92.9%（4297 / 4629 mAh）。",
    keys: [
      { mark: "lit", label: "What moves: needle, pen, hammer, the ratchet stepping once a second" },
      { mark: "raised", label: "Shunt and sampling coil · the sense path into the dial" },
      { mark: "dim", label: "Cast bench plate, feet, rule and name plate" },
    ],
    body: `<div class="iso-stage" tabindex="0" role="slider" aria-label="Power bench: pointer or arrow keys set the wall load" aria-valuemin="4" aria-valuemax="58" aria-valuenow="33.7">${svg}</div>`,
  }),
  script: kitScript() + live,
  width: 700,
});

page = page.replace("</head>", `<style>${PALETTE}</style>
<style>
@media (hover: none){
  .iso-plate-corner[data-corner="hint"]{font-size:0}
  .iso-plate-corner[data-corner="hint"]::after{
    content:"Tap to load";font-size:11px;letter-spacing:.08em;text-transform:uppercase}
}
</style></head>`);
page = page.replace('<html lang="en">', '<html lang="zh-CN">');
page = page.replace('<main class="iso-page">', '<main class="iso-page"><a class="pb-back" href="../index.html">← PowerPulse</a>');

const EMBED = `<style>
html.embed .pb-back{display:none}
html.embed,html.embed body{background:#fff;color-scheme:light}
html.embed .iso-page{padding:0;margin:0 auto;width:100%;max-width:880px}
</style>
<script>
(function(){
  if(!new URLSearchParams(location.search).has("embed")) return;
  document.documentElement.classList.add("embed");
  var last=0;
  function post(){
    var h=Math.ceil(document.documentElement.scrollHeight);
    if(Math.abs(h-last)>2){last=h;parent.postMessage({type:"pb-height",h:h},"*");}
  }
  addEventListener("load",post);
  if(window.ResizeObserver) new ResizeObserver(post).observe(document.body);
  setTimeout(post,300); setTimeout(post,1200);
})();
</script>`;
{ const at = page.lastIndexOf("</body>"); page = page.slice(0, at) + EMBED + page.slice(at); }

mkdirSync(join(HERE, "shots"), { recursive: true });
mkdirSync(OUT, { recursive: true });
writeFileSync(join(OUT, "powerbench.html"), page);

A.auditOrExit(R, P);
console.log("wrote powerbench.html ·", items.length, "items ·", R.solids.length, "solids ·", R.tubes.length, "tube runs");
