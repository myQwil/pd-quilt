const gm = @import("gme.zig");
pub const Self = gm.Gme;
pub const nch = 2;

export fn gme_tilde_setup() void {
	Self.setup(@import("pd").symbol("gme~"));
}
