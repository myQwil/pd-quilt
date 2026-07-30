const pd = @import("pd");
const Slope = @import("slope.zig").Slope(@This());
pub const name = "sly";

pub inline fn getK(min: f64, max: f64, run: f64) f64 {
	return (max - min) / run;
}

pub fn floatC(p: *const pd.Pd, f: pd.Float) callconv(.c) void {
	const self = Slope.parentConstPtr(p);
	self.out.float(@floatCast((f * self.k) + self.min));
}

export fn sly_setup() void {
	_ = pd.wrap(void, Slope.setup(), @src().fn_name);
}
