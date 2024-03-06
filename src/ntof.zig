const pd = @import("pd");
const h = @import("tet.zig");
const Self = h.Tet;

const ln2 = @import("std").math.ln2;

pub fn setK(self: *Self) void {
	self.k = ln2 / self.tet;
}

pub fn setMin(self: *Self) void {
	self.min = @exp(-69 * self.k) * self.ref;
}

fn float(self: *const Self, f: pd.Float) void {
	self.out.float(@floatCast(@exp(f * self.k) * self.min));
}

export fn ntof_setup() void {
	Self.setup(pd.symbol("ntof"), @ptrCast(&float));
}
