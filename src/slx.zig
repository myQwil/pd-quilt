const pd = @import("pd");
const Slope = @import("slope.zig").Slope(@This());
pub const name = "slx";

pub inline fn getK(min: f64, max: f64, run: f64) f64 {
	return run / (max - min);
}

pub fn floatC(p: *const pd.Pd, f: pd.Float) callconv(.c) void {
	const self = Slope.parentConstPtr(p);
	self.out.float(@floatCast((f - self.min) * self.k));
}

export fn slx_setup() void {
	_ = pd.wrap(void, Slope.setup(), @src().fn_name);
}
