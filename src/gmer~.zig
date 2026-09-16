const wrap = @import("pd").wrap;
const main = @import("misc/player.gme_rubber.zig");
pub const name = "gmer~";
pub const nch = 2;

export fn gmer_tilde_setup() void {
	_ = wrap(void, main.Impl(@This()).setup(), @src().fn_name);
}
