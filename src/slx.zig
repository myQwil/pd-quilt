const pd = @import("slope.zig");
const Self = pd.Slope;

// -------------------------- sly --------------------------
fn set_k(self: *Self) void {
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
	self.obj.out.float(res);
}

export fn slx_setup() void {
	Self.set_k = set_k;
	Self.setup(pd.symbol("slx"), @ptrCast(&float));
}
