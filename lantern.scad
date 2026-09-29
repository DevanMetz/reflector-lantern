// Reflector lantern — RGB(W) LED ring pointing up into a curved mirror.
// Parts: base (battery/electronics housing), lid, diffuser tube, reflector.
// Set `part` to export a single STL; "assembly" / "section" are for viewing.
//
// Units: mm. z = 0 is the top face of the base.

part = "section"; // [assembly, section, base, lid, tube, tube_vase, reflector]

$fn = 160;

// ---------- LED ring (Adafruit 24x RGBW NeoPixel ring #2862 by default) ----------
ring_od     = 66.0;
ring_id     = 52.3;
ring_pcb_t  = 1.6;
led_h       = 1.6;
ring_pocket = 1.2;                        // pocket depth in base top
led_r       = (ring_od + ring_id) / 4;    // LED centerline radius
led_z       = -ring_pocket + ring_pcb_t + led_h; // LED emitting face height

// ---------- Reflector optics (keep in sync with raysim.py) ----------
// Mirror slope (from horizontal) sweeps linearly th_in -> th_out from axis to rim.
// Beam elevation = 2*slope - 90, so 35..62 deg gives roughly -20..+34 deg per LED ray.
z_tip  = 14;    // tip height above LED faces
th_in  = 35;
th_out = 62;
R_ref  = 50;    // reflector rim radius

// ---------- Diffuser tube ----------
R_tube      = 54;   // inner radius
tube_wall   = 1.6;
groove_d    = 2.5;  // depth of the seats in base & reflector flange
groove_clr  = 0.3;

// ---------- Base / batteries ----------
wall        = 2.4;
base_r      = R_tube + tube_wall + groove_clr + 3;
top_t       = 4.5;
// Two DFRobot single 18650 holders side by side (or one 2x holder).
// MEASURE YOURS and adjust — these are typical 18650 holder dims.
holder_l    = 78;
holder_w    = 42;   // two singles side by side
holder_h    = 21;
fit         = 0.6;  // clearance around holders
wire_space  = 4;
base_h      = holder_h + wire_space + top_t;  // lid top to base top

lid_t       = 2.4;
boss_r      = 4;
boss_pos_r  = base_r - wall - boss_r;
screw_pilot = 2.6;  // M3 self-tapping into plastic
screw_clear = 3.4;
screw_head  = 6.2;

usb_w = 13; usb_h = 8;     // USB-C notch at the bottom edge (charger board sits on the lid)
switch_d = 12.2;           // 12 mm latching push button
switch_z = -base_h + 14;

top_hole_d = 4.2;          // M4 eye bolt for hanging (0 to disable)

// ---------- Reflector profile ----------
k_deg = (th_out - th_in) / R_ref;
function th(r) = th_in + k_deg * r;
function zp(r) = z_tip + (ln(cos(th_in)) - ln(cos(th(r)))) / (k_deg * PI / 180);
z_rim   = led_z + zp(R_ref);   // absolute height of reflector rim
flange_t = groove_d + 2.5;
tube_h   = z_rim + 2 * groove_d - 0.4;

echo(str("Reflector rim height above base top: ", z_rim, " mm"));
echo(str("Tube height: ", tube_h, " mm   Overall height ~", base_h + lid_t + z_rim + flange_t, " mm"));

// ================= parts =================

module base() {
    difference() {
        union() {
            translate([0, 0, -base_h]) difference() {
                cylinder(r = base_r, h = base_h);
                translate([0, 0, -1]) cylinder(r = base_r - wall, h = base_h - top_t + 1);
            }
            for (a = [45:90:315]) rotate(a)
                translate([boss_pos_r, 0, -base_h]) {
                    cylinder(r = boss_r, h = base_h - 0.01);
                    translate([0, -boss_r, 0]) cube([wall + boss_r, 2 * boss_r, base_h - 0.01]);
                }
        }
        // LED ring pocket
        translate([0, 0, -ring_pocket]) cylinder(r = ring_od / 2 + 0.4, h = 10);
        // wire slot under the ring's pads
        rotate(90) translate([led_r, 0, -top_t - 1]) cube([6, 10, 20], center = true);
        // diffuser tube seat
        translate([0, 0, -groove_d]) difference() {
            cylinder(r = R_tube + tube_wall + groove_clr, h = 10);
            translate([0, 0, -1]) cylinder(r = R_tube - groove_clr, h = 12);
        }
        // screw pilots
        for (a = [45:90:315]) rotate(a)
            translate([boss_pos_r, 0, -base_h - 1]) cylinder(d = screw_pilot, h = 14);
        // USB-C notch (open to bottom edge)
        rotate(90) translate([base_r - wall / 2, 0, -base_h - 1 + (usb_h + 1) / 2])
            cube([wall * 3, usb_w, usb_h + 1], center = true);
        // power button
        rotate(270) translate([base_r - wall / 2, 0, switch_z])
            rotate([0, 90, 0]) cylinder(d = switch_d, h = wall * 3, center = true);
    }
}

module lid() {
    fence = 1.6; fence_h = 5;
    difference() {
        cylinder(r = base_r, h = lid_t);
        for (a = [45:90:315]) rotate(a) translate([boss_pos_r, 0, -1]) {
            cylinder(d = screw_clear, h = lid_t + 2);
            cylinder(d1 = screw_head, d2 = screw_clear, h = 1 + (screw_head - screw_clear) / 2);
        }
    }
    // battery holder locating fence
    translate([0, 0, lid_t + fence_h / 2]) difference() {
        cube([holder_l + fit + 2 * fence, holder_w + fit + 2 * fence, fence_h], center = true);
        cube([holder_l + fit, holder_w + fit, fence_h + 1], center = true);
    }
}

module tube(solid = false) {
    translate([0, 0, -groove_d]) difference() {
        cylinder(r = R_tube + tube_wall, h = tube_h);
        if (!solid) translate([0, 0, -1]) cylinder(r = R_tube, h = tube_h + 2);
    }
}

module reflector() {
    n = 120;
    prof = concat(
        [[0, zp(0)]],
        [for (i = [1:n]) let(r = R_ref * i / n) [r, zp(r)]],
        [[base_r, zp(R_ref)], [base_r, zp(R_ref) + flange_t], [0, zp(R_ref) + flange_t]]
    );
    translate([0, 0, led_z]) difference() {
        rotate_extrude($fn = 240) polygon(prof);
        // tube seat in flange underside
        translate([0, 0, zp(R_ref) - 1]) difference() {
            cylinder(r = R_tube + tube_wall + groove_clr, h = groove_d + 1);
            translate([0, 0, -1]) cylinder(r = R_tube - groove_clr, h = groove_d + 3);
        }
        if (top_hole_d > 0) translate([0, 0, zp(R_ref) - 20]) cylinder(d = top_hole_d, h = 50);
    }
}

module led_ring_dummy() {
    translate([0, 0, -ring_pocket]) color("white") difference() {
        cylinder(r = ring_od / 2, h = ring_pcb_t);
        translate([0, 0, -1]) cylinder(r = ring_id / 2, h = 5);
    }
    for (i = [0:23]) rotate(i * 15) translate([led_r, 0, -ring_pocket + ring_pcb_t])
        color("gold") translate([-2.5, -2.5, 0]) cube([5, 5, led_h]);
}

module batteries_dummy() {
    translate([0, 0, -base_h - 0.01 + holder_h / 2 + 0.5])
        color("dimgray") cube([holder_l, holder_w, holder_h], center = true);
}

module assembly() {
    color("#444") base();
    color("#333") translate([0, 0, -base_h - lid_t]) lid();
    led_ring_dummy();
    batteries_dummy();
    color("white", part == "section" ? 1 : 0.35) tube();
    color("silver") reflector();
}

// ================= select =================
if (part == "assembly") assembly();
else if (part == "section") difference() {
    assembly();
    translate([-200, -400, -100]) cube([400, 400, 400]);
}
else if (part == "base") rotate([180, 0, 0]) base();                   // print top-face down
else if (part == "lid") lid();
else if (part == "tube") translate([0, 0, groove_d]) tube();
else if (part == "tube_vase") translate([0, 0, groove_d]) tube(true);   // slice in spiral/vase mode
else if (part == "reflector") rotate([180, 0, 0]) translate([0, 0, -z_rim - flange_t]) reflector(); // flange down
