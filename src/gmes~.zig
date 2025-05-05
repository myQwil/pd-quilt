const wrap = @import("pd").wrap;
pub const name = "gmes~";
pub const nch = 16;

export fn gmes_tilde_setup() void {
	_ = wrap(void, @import("player.gme_rabbit.zig").Impl(@This()).setup(), @src().fn_name);
}
