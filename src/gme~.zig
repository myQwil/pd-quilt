const wrap = @import("pd").wrap;
const main = @import("misc/player.gme_rabbit.zig");
pub const name = "gme~";
pub const nch = 2;

export fn gme_tilde_setup() void {
	_ = wrap(void, main.Impl(@This()).setup(), @src().fn_name);
}
