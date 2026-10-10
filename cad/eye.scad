// Halloween eye module — one eye, 28BYJ-48 scotch-yoke eyelid.
//
// Stack, front (viewer side, z=0) to back:
//   front plate  z 0..3      lens-shaped opening, perimeter walls + lid guides
//   lid          z 3.3..5.3  slides vertically; solid face, pin channel on its rear (to z 7.8)
//   crank        z 10.3..16.3  arm at the bottom (10.3..13.3), 3 mm clear above it for motor
//                              screw tips; hub pushed on until it touches the back plate
//   back plate   z 16.3..19.3  glow/iris recess, motor on its rear, runners hold the lid forward
//
// Set `part` (or pass -D 'part="lid"') to: front, lid, crank, back, front_L, back_L, splice, fit_test, snap_test, assembly
// Print 2x each of front, back, lid, crank; 1x splice. (front_L/back_L only if mod_w != eye_spacing.)
part = "assembly";

$fn = 72;

// ---- eye geometry --------------------------------------------------------
mod_w     = 200;     // module width (x); two modules butt together = 400 mm. Min ~200 (lid + rails + posts)
eye_spacing = 200;   // centre-to-centre between the two eyes
// Eye is at x = 0; the outline's inner (seam) edge is at x0. With mod_w == eye_spacing the
// module is symmetric and both sides are the same part; otherwise use the _L mirrored exports.
x0        = -eye_spacing / 2;   // inner / seam edge
x1        = x0 + mod_w;         // outer edge
open_w    = 150;     // lens opening width
open_h    = 64;      // lens opening height
iris_d    = 60;      // glow iris diameter
pupil_w   = 7;
pupil_h   = 50;

lid_h     = 72;      // must be >= open_h + a few mm
lid_w     = 164;
crank_r   = 35;      // lid travel = 2 * crank_r; must be >= lid_h/2 + open_h/2 + margin
slot_off  = 6;       // lid slot sits this far above lid centre, so the crank hub clears the opening
axis_y    = crank_r + slot_off; // motor shaft sits half-way up the pin travel

tray_y0   = -42;     // 3 mm clear of the closed lid
tray_y1   = 112;     // 3 mm clear of the open lid
mod_h     = tray_y1 - tray_y0;
mod_cy    = (tray_y0 + tray_y1) / 2;

// ---- z layers ------------------------------------------------------------
t_front   = 3;
wall      = 3;
z_lid     = t_front + 0.3;  t_lid = 2;  // lid rides 0.3 mm off the front plate
rail_h    = 2.5;                       // channel walls on the lid's rear face
arm_clear = 2.5;                       // crank arm/hub above the channel walls
z_crank   = z_lid + t_lid + rail_h + arm_clear;  // hub bottom (10.3)
arm_t     = 3;                         // crank arm thickness
screw_gap = 3;                         // clear space for motor-screw tips (M3x6 pokes ~2 mm through)
z_back    = z_crank + arm_t + screw_gap;  // 16.3; hub top butts against the back plate
lid_float = 0.3;                       // back-plate runners stop the lid drifting back
t_back    = 3;

// ---- 28BYJ-48 ------------------------------------------------------------
m_body_d    = 28;
m_ear_span  = 35;      // hole-to-hole
m_ear_hole  = 4.2;
m_shaft_off = 8;       // shaft is this far from body centre
m_boss_d    = 9.2;     // + clearance in back plate
shaft_d     = 5.0;
shaft_flat  = 3.0;     // across flats
tol         = 0.15;

// ---- helpers -------------------------------------------------------------
module lens2d(w, h) {
    s = h / 2;
    R = (w * w / 4 + s * s) / (2 * s);
    intersection() {
        translate([0,  R - s]) circle(r = R, $fn = 200);
        translate([0, -(R - s)]) circle(r = R, $fn = 200);
    }
}

module d_hole2d() {
    intersection() {
        circle(d = shaft_d + tol * 2);
        square([shaft_d + 1, shaft_flat + tol * 2], center = true);
    }
}

module motor_holes2d() {
    // shaft at (0, axis_y); body centre is m_shaft_off further up (+y)
    translate([0, axis_y]) circle(d = m_boss_d + 0.4);
    for (sx = [-1, 1])
        translate([sx * m_ear_span / 2, axis_y + m_shaft_off]) circle(d = 2.8);  // M3 thread-forming into PETG
}

splice_ys  = [0, 70];   // extra posts on both side walls; the splice plate screws into these
splice_pts = [for (x = [x0 + 8, x1 - 8], y = splice_ys) [x, y]];
corner_pts = [for (x = [x0 + 8, x1 - 8], y = [tray_y0 + 8, tray_y1 - 8]) [x, y]];  // support posts, no screws

// ---- snap hooks ----------------------------------------------------------
// Window-and-tab snaps. Cantilever beams are cut out of the top and bottom walls of the
// front tray and run past the rim; each has a window through it. A wedge tab on the back
// plate's edge pushes the beam outward and clicks into the window.
// Printability: the window's catch edge is a short bridge, and the tab's catch face is the
// back plate's bed-side face, so both print flat (no sagging overhang).
// Release: pull a beam outward with a fingernail / small screwdriver.
hook_xs   = [-70, 0, 70];  // on top wall; bottom wall uses the outer two (centre has wire notch)
hook_w    = 12;
hook_t    = 2;      // beam thickness (wall is thinned to this at each hook)
hook_slit = 0.8;
tab_w     = 8;
tab_reach = 1.0;    // how far the tab sits inside the window
hook_gap  = 0.3;    // play between the plate's rear face and the window's catch edge
notch_gap = 0.3;    // plate edge to beam inner face
hook_pts  = concat([for (x = hook_xs) [x, 1]], [for (x = [hook_xs[0], hook_xs[2]]) [x, -1]]);

function wall_out(s) = s > 0 ? tray_y1 : tray_y0;

// (y, z) polygon extruded along x
module yz_prism(x, w, pts) translate([x - w / 2, 0, 0]) rotate([90, 0, 90]) linear_extrude(w) polygon(pts);

// region of wall to remove: two slits + inner 1 mm thinning + the window
module hook_cut(x, s) {
    yo = wall_out(s);
    for (dx = [-1, 1])
        translate([x + dx * (hook_w + hook_slit) / 2 - hook_slit / 2, min(yo, yo - s * (wall + 1)), t_front + 0.6])
            cube([hook_slit, wall + 1, z_back]);
    translate([x - hook_w / 2, min(yo - s * hook_t, yo - s * (wall + 1)), t_front + 0.6])
        cube([hook_w, wall + 1 - hook_t, z_back]);
    // window
    translate([x - (tab_w + 1) / 2, min(yo + s, yo - s * (hook_t + 1)), z_back - 0.5])
        cube([tab_w + 1, hook_t + 2, t_back + hook_gap + 0.5]);
}

module hook_add(x, s) {
    yo = wall_out(s);
    // beam extension past the rim, 1.8 mm of material above the window
    translate([x - hook_w / 2, min(yo, yo - s * hook_t), z_back - 0.01])
        cube([hook_w, hook_t, t_back + hook_gap + 1.8]);
}

// back plate: notch so the hook beam can pass its edge
module hook_notch(x, s) {
    yo = wall_out(s);
    translate([x - (hook_w + 2 * hook_slit) / 2, min(yo, yo - s * (hook_t + notch_gap)) - (s > 0 ? 0 : 1), -1])
        cube([hook_w + 2 * hook_slit, hook_t + notch_gap + 1, t_back + 2]);
}

// back plate: wedge tab in the notch. Local z = 0 is the front face (leads into the tray),
// so the ramp starts there; full reach at the rear face, which is the catch face.
module hook_tab(x, s) {
    ye = wall_out(s) - s * (hook_t + notch_gap);   // plate edge inside the notch
    yz_prism(x, tab_w, [[ye - s * 0.5, 0], [ye + s * 0.15, 0],
                        [ye + s * (notch_gap + tab_reach), t_back - 0.6],
                        [ye + s * (notch_gap + tab_reach), t_back], [ye - s * 0.5, t_back]]);
}

// ---- parts ---------------------------------------------------------------
module front_plate() {
    difference() {
        union() {
            // face
            translate([x0, tray_y0, 0]) cube([mod_w, mod_h, t_front]);
            // perimeter wall
            difference() {
                translate([x0, tray_y0, 0]) cube([mod_w, mod_h, z_back]);
                translate([x0 + wall, tray_y0 + wall, t_front - 0.01])
                    cube([mod_w - 2 * wall, mod_h - 2 * wall, z_back]);
            }
            // lid guide rails
            for (sx = [-1, 1])
                translate([sx > 0 ? lid_w / 2 + 0.8 : -(lid_w / 2 + 0.8) - 2, tray_y0 + wall, 0])
                    cube([2, mod_h - 2 * wall, 7.2]);
            // support posts (corners) and splice-screw posts (side walls)
            for (p = concat(corner_pts, splice_pts))
                translate([p[0], p[1], 0]) cylinder(d = 9, h = z_back);
            for (h = hook_pts) hook_add(h[0], h[1]);
        }
        for (h = hook_pts) hook_cut(h[0], h[1]);
        // eye opening
        translate([0, 0, -1]) linear_extrude(t_front + 2) lens2d(open_w, open_h);
        // splice screw pilot holes (self-tapping M3)
        for (p = splice_pts) translate([p[0], p[1], 4]) cylinder(d = 2.6, h = z_back);
        // wire/ventilation notch on bottom wall for motor leads
        translate([-8, tray_y0 - 1, z_back - 5]) cube([16, wall + 2, 6]);
    }
}

// Face is solid (no light leaks through when closed); the crank pin rides in a
// closed channel built up on the rear face.
module lid() {
    slot_len = 2 * crank_r + 5;
    module slot2d(grow = 0)
        hull() for (sx = [-1, 1]) translate([sx * (slot_len - 4.8) / 2, 0]) circle(d = 4.8 + 2 * grow);
    translate([-lid_w / 2, -lid_h / 2, 0]) cube([lid_w, lid_h, t_lid]);
    translate([0, slot_off, t_lid - 0.01]) linear_extrude(rail_h + 0.01)
        difference() { slot2d(2); slot2d(0); }
}

module crank() {
    hub_d = 14;
    pin_d = 4;
    collar = 0.5;   // small-diameter ring that bears on the back plate (less rubbing)
    difference() {
        union() {
            // hub; its collar touches the back plate, which sets the crank's height on the shaft
            cylinder(d = hub_d, h = z_back - z_crank - collar);
            cylinder(d = 8, h = z_back - z_crank);
            // arm
            linear_extrude(arm_t)
                hull() { circle(d = hub_d); translate([0, -crank_r]) circle(d = 8); }
            // pin: runs forward (toward -z) into the lid's channel
            pin_z0 = (z_lid + t_lid + 0.4) - z_crank;   // stops 0.4 mm above the lid face
            translate([0, -crank_r, pin_z0]) cylinder(d = pin_d, h = arm_t - pin_z0);
        }
        translate([0, 0, -1]) linear_extrude(z_back) d_hole2d();
    }
}

// local z = 0 is the FRONT face (toward the lid); the motor mounts on the rear (z = t_back).
module back_plate() {
    difference() {
        union() {
            translate([x0, tray_y0, 0]) cube([mod_w, mod_h, t_back]);
            // locating ribs: drop inside the side walls so the plate can't shift sideways
            for (sx = [-1, 1])
                translate([sx > 0 ? x1 - wall - 0.3 - 2 : x0 + wall + 0.3, 15, -1.5]) cube([2, 40, 1.6]);
            // lid runners: reach down to just behind the lid's edges along its whole travel,
            // outside the eye opening and the crank's sweep
            run_len = z_back - (z_lid + t_lid + lid_float);
            for (sx = [-1, 1])
                translate([sx * (lid_w / 2 - 3) - 1, -lid_h / 2 - 2, -run_len])
                    cube([2, 2 * crank_r + lid_h + 4, run_len + 0.01]);
        }
        // iris recess on the FRONT face (glow paint / epoxy goes here) with raised pupil slit
        difference() {
            translate([0, 0, -1]) cylinder(d = iris_d, h = 2.2);
            translate([-pupil_w / 2, -pupil_h / 2, -2]) cube([pupil_w, pupil_h, 4]);
        }
        translate([0, 0, -1]) linear_extrude(t_back + 2) motor_holes2d();
        for (p = splice_pts) translate([p[0], p[1], -1]) cylinder(d = 3.4, h = t_back + 2);
        for (h = hook_pts) hook_notch(h[0], h[1]);
    }
    for (h = hook_pts) hook_tab(h[0], h[1]);
}

// Joins two modules across the seam (behind the back plates) and carries the electronics.
// Long M3 screws go splice -> back plate -> post. Zip-tie slots for ESP32 + 2x ULN2003.
module splice() {
    w = 80; y0 = tray_y0 + 4; y1 = tray_y1 - 4;
    difference() {
        translate([-w / 2, y0, 0]) cube([w, y1 - y0, t_back]);
        for (sx = [-1, 1], y = splice_ys) translate([sx * 8, y, -1]) cylinder(d = 3.4, h = t_back + 2);
        for (sx = [-1, 1], y = [-25, -5, 20, 50, 85]) for (dx = [-1, 1])
            translate([sx * 26 + dx * 9 - 1.5, y - 2, -1]) cube([3, 4, t_back + 2]);
    }
}

// snap-fit test: a 40 mm slice of the top wall with one hook, plus the matching back-plate strip
module snap_test() {
    box = [40, 30];
    intersection() {
        front_plate();
        translate([-box[0] / 2, tray_y1 - box[1], -1]) cube([box[0], box[1], 40]);
    }
    translate([0, -40, t_back]) rotate([180, 0, 0])
        intersection() {
            back_plate();
            translate([-box[0] / 2, tray_y1 - box[1], -5]) cube([box[0], box[1], 20]);
        }
}

// quick mount test: just the motor hole pattern, print this first (10 minutes)
module fit_test() {
    difference() {
        translate([-26, axis_y - 14, 0]) cube([52, 44, t_back]);
        translate([0, 0, -1]) linear_extrude(t_back + 2) motor_holes2d();
    }
}

module assembly() {
    color("#444") front_plate();
    // lid shown closed (centre on eye)
    color("#c33") translate([0, 0, z_lid]) lid();
    // crank pointing down = lid closed
    color("#39c") translate([0, axis_y, z_crank]) crank();
    color("#999") translate([0, 0, z_back]) back_plate();
    // motor
    color("#da3") translate([0, axis_y + m_shaft_off, z_back + t_back]) cylinder(d = m_body_d, h = 19);
}

if (part == "front") front_plate();
else if (part == "front_L") mirror([1, 0, 0]) front_plate();
else if (part == "lid") lid();
else if (part == "crank") crank();
else if (part == "back") translate([0, 0, t_back]) rotate([180, 0, 0]) back_plate();
else if (part == "back_L") mirror([1, 0, 0]) translate([0, 0, t_back]) rotate([180, 0, 0]) back_plate();
else if (part == "splice") splice();
else if (part == "fit_test") fit_test();
else if (part == "snap_test") snap_test();
else if (part == "assembly") assembly();
