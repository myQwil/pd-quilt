const pd = @import("pd");
const Slope = @import("slope.zig").Slope(@This());
pub const name = "slx";

pub inline fn getK(min: f64, max: f64, run: f64) f64 {
	return run / (max - min);
}

pub fn floatC(self: *const Slope, f: pd.Float) callconv(.c) void {
	self.out.float(@floatCast((f - self.min) * self.k));
}

export fn slx_setup() void {
	_ = pd.wrap(void, Slope.setup(), @src().fn_name);
}
