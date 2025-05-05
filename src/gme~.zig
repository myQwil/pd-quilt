const wrap = @import("pd").wrap;
pub const name = "gme~";
pub const nch = 2;

export fn gme_tilde_setup() void {
	_ = wrap(void, @import("player.gme_rabbit.zig").Impl(@This()).setup(), @src().fn_name);
}
