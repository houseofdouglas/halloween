// Animation scenes for the eye module. Driven by render_video.py, which sets
// `seg` (1 = assembly, 2 = mechanism cutaway, 3 = performance) and `tt` (seconds into the scene).
include <eye.scad>  // part = "none" below suppresses eye.scad's own part dispatch

part = "none";
seg  = 3;
tt   = 0;

GLOW_ON  = [0.55, 1.0, 0.45];
GLOW_OFF = [0.10, 0.12, 0.10];
DARK     = [0.09, 0.09, 0.10];

function ease(x) = let(t = max(0, min(1, x))) t * t * (3 - 2 * t);
function lerp(a, b, t) = a + (b - a) * t;
function seg_t(t, t0, t1) = ease((t - t0) / (t1 - t0));

// crank angle: 0 = open (pin up), 180 = closed (pin down)
module eye_at(theta, glow, front_col = DARK, front_alpha = 1, lid_col = DARK, crank_col = [0.2, 0.5, 0.8],
              explode = 0, show_motor = true, show_back = true) {
    lid_y = axis_y + crank_r * cos(theta) - slot_off;
    color(front_col, front_alpha) translate([0, 0, -explode * 60]) front_plate();
    color(lid_col) translate([0, lid_y, z_lid - explode * 30]) lid();
    color(crank_col) translate([0, axis_y, z_crank]) rotate([0, 0, 180 - theta]) crank();
    if (show_back) color([0.35, 0.35, 0.37]) translate([0, 0, z_back + explode * 40]) back_plate();
    // glowing iris (sits in the recess on the back plate's front face)
    if (show_back) color(lerp(GLOW_OFF, GLOW_ON, glow)) translate([0, 0, z_back - 0.05 + explode * 40])
        linear_extrude(0.4) difference() {
            circle(d = iris_d - 0.4);
            square([pupil_w, pupil_h], center = true);
        }
    if (show_motor && show_back) translate([0, 0, explode * 80]) motor();
}

module motor() {
    zc = z_back + t_back;
    color([0.85, 0.7, 0.2]) translate([0, axis_y + m_shaft_off, zc]) cylinder(d = m_body_d, h = 19);
    color([0.75, 0.75, 0.78]) translate([0, axis_y + m_shaft_off, zc]) linear_extrude(0.8)
        hull() for (sx = [-1, 1]) translate([sx * m_ear_span / 2, 0]) circle(d = 7);
    color([0.2, 0.3, 0.9]) translate([-8.5, axis_y + m_shaft_off + 12, zc + 2]) cube([17, 6, 15]);
}

// ---- scene 1: parts fly together (rear 3/4 view) ---------------------------
if (seg == 1) {
    ex = 1 - seg_t(tt, 0.6, 4.2);
    eye_at(180, 0, front_col = [0.25, 0.25, 0.27], lid_col = [0.8, 0.25, 0.2], explode = ex);
}

// ---- scene 2: mechanism from behind, back plate removed ---------------------
if (seg == 2) {
    // one slow open/close cycle
    th = tt < 2.5 ? lerp(180, 0, seg_t(tt, 0.3, 2.5)) : lerp(0, 180, seg_t(tt, 3.2, 5.4));
    eye_at(th, 0.6, front_col = [0.25, 0.25, 0.27], lid_col = [0.8, 0.25, 0.2], show_back = false);
    // ghost of the motor shaft so you can see what turns the crank
    color([0.85, 0.7, 0.2], 0.5) translate([0, axis_y, z_crank]) cylinder(d = 5, h = 14);
}

// ---- scene 3: the performance, two eyes as a face --------------------------
// 0-1 dark | 1-5 open + glow up | blink 6-8.6 | 10-13.5 close + fade | dark
function perf_theta(t) =
    t < 1    ? 180 :
    t < 5    ? lerp(180, 0, seg_t(t, 1, 5)) :
    t < 6    ? 0 :
    t < 7.2  ? lerp(0, 180, seg_t(t, 6, 7.2)) :
    t < 8.6  ? lerp(180, 0, seg_t(t, 7.3, 8.6)) :
    t < 10   ? 0 :
               lerp(0, 180, seg_t(t, 10, 13.5));
function perf_glow(t) =
    t < 5 ? seg_t(t, 1, 5) : t < 10 ? 1 : 1 - seg_t(t, 10, 13.8);

if (seg == 3) {
    for (i = [0, 1]) {
        lag = i * 0.25;
        translate([(i == 0 ? -1 : 1) * eye_spacing / 2, 0, 0]) mirror([i == 0 ? 1 : 0, 0, 0])
            eye_at(perf_theta(tt - lag), perf_glow(tt - lag), show_motor = false);
    }
}
