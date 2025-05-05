const wrap = @import("pd").wrap;
pub const name = "avr~";

export fn avr_tilde_setup() void {
	_ = wrap(void, @import("player.av_rubber.zig").Impl(@This()).setup(), @src().fn_name);
}
