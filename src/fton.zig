const pd = @import("tet.zig");
const Self = pd.Tet;

const ln2 = @import("std").math.ln2;

fn set_min(self: *Self) void {
	self.min = @exp(ln2 * 69 / self.tet) / self.ref;
}

fn set_k(self: *Self) void {
	self.k = self.tet / ln2;
}

fn float(self: *const Self, f: pd.Float) void {
	self.obj.out.float(@floatCast(@log(f * self.min) * self.k));
}

export fn fton_setup() void {
	Self.set_k = set_k;
	Self.set_min = set_min;
	Self.setup(pd.symbol("fton"), @ptrCast(&float));
}
