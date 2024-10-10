const gme = @import("gme.zig");
pub const Self = gme.Gme;
pub const nch = 16;

export fn gmes_tilde_setup() void {
	Self.setup(@import("pd").symbol("gmes~"));
}
