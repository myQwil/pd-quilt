const wrap = @import("pd").wrap;
const main = @import("misc/player.av_rabbit.zig");
pub const name = "av~";

export fn av_tilde_setup() void {
	_ = wrap(void, main.Impl(@This()).setup(), @src().fn_name);
}
