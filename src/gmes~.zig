const wrap = @import("pd").wrap;
const main = @import("misc/player.gme_rabbit.zig");
pub const name = "gmes~";
pub const nch = 16;

export fn gmes_tilde_setup() void {
	_ = wrap(void, main.Impl(@This()).setup(), @src().fn_name);
}
