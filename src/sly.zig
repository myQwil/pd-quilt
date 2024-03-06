const pd = @import("slope.zig");
const Self = pd.Slope;

// -------------------------- sly --------------------------
fn set_k(self: *Self) void {
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
	self.obj.out.float(res);
}

export fn sly_setup() void {
	Self.set_k = set_k;
	Self.setup(pd.symbol("sly"), @ptrCast(&float));
}
