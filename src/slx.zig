const pd = @import("pd");
const h = @import("slope.zig");
const Self = h.Slope;

pub fn setK(self: *Self) void {
	if (self.log) {
		self.minmax();
		self.k = self.run / @log(self.max / self.min);
	} else {
		self.k = self.run / (self.max - self.min);
	}
}

fn float(self: *const Self, f: pd.Float) void {
	const res: pd.Float = @floatCast(if (self.log)
		@log(f / self.min) * self.k
		else (f - self.min) * self.k);
	self.out.float(res);
}

export fn slx_setup() void {
	Self.setup(pd.symbol("slx"), @ptrCast(&float));
}
