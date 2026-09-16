const wrap = @import("pd").wrap;
const main = @import("misc/player.av_rubber.zig");
pub const name = "avr~";

export fn avr_tilde_setup() void {
	_ = wrap(void, main.Impl(@This()).setup(), @src().fn_name);
}
