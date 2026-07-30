const pd = @import("pd");
const Tet = @import("tet.zig").Tet(@This());
pub const name = "ntof";

const Float = pd.Float;

pub inline fn getK(tet: Float) f64 {
	return 1.0 / tet;
}

pub inline fn getMin(k: f64, ref: Float) f64 {
	return @exp2(-69 * k) * ref;
}

pub fn floatC(p: *const pd.Pd, f: Float) callconv(.c) void {
	const self = Tet.parentConstPtr(p);
	self.out.float(@floatCast(@exp2(f * self.k) * self.min));
}

export fn ntof_setup() void {
	_ = pd.wrap(void, Tet.setup(), @src().fn_name);
}
