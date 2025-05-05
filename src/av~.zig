const wrap = @import("pd").wrap;
pub const name = "av~";

export fn av_tilde_setup() void {
	_ = wrap(void, @import("player.av_rabbit.zig").Impl(@This()).setup(), @src().fn_name);
}
