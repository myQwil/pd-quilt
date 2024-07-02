const pd = @import("pd");
const h = @import("slope.zig");
const Self = h.Slope;

pub fn setK(self: *Self) void {
	if (self.log) {
		self.minmax();
		self.k = @log(self.max / self.min) / self.run;
	} else {
		self.k = (self.max - self.min) / self.run;
	}
}

fn float(self: *const Self, f: pd.Float) void {
	const res: pd.Float = @floatCast(if (self.log)
		@exp(f * self.k) * self.min
		else (f * self.k) + self.min);
	self.out.float(res);
}

export fn sly_setup() void {
	Self.setup(pd.symbol("sly"), @ptrCast(&float));
}
