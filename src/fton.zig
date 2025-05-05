const pd = @import("pd");
const Tet = @import("tet.zig").Tet(@This());
pub const name = "fton";

const Float = pd.Float;

pub inline fn getK(tet: Float) f64 {
	return tet;
}

pub inline fn getMin(k: f64, ref: Float) f64 {
	return @exp2(69 / k) / ref;
}

pub fn floatC(self: *const Tet, f: Float) callconv(.c) void {
	self.out.float(@floatCast(@log2(f * self.min) * self.k));
}

export fn fton_setup() void {
	_ = pd.wrap(void, Tet.setup(), @src().fn_name);
}
