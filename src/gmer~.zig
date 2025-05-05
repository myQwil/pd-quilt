const wrap = @import("pd").wrap;
pub const name = "gmer~";
pub const nch = 2;

export fn gmer_tilde_setup() void {
	_ = wrap(void, @import("player.gme_rubber.zig").Impl(@This()).setup(), @src().fn_name);
}
