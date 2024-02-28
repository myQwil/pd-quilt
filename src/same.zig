const pd = @import("pd");

const Same = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	obj: pd.Object,
	out: [2]*pd.Outlet,
	f: pd.Float,

	fn bang(self: *const Self) void {
		self.out[0].float(self.f);
	}

	fn float(self: *Self, f: pd.Float) void {
		if (self.f != f) {
			self.f = f;
			self.out[0].float(f);
		} else {
			self.out[1].float(f);
		}
	}

	fn set(self: *Self, f: pd.Float) void {
		self.f = f;
	}

	fn new(f: pd.Float) ?*Self {
		const self: *Self = @ptrCast(class.new() orelse return null);
		self.f = f;

		const obj = &self.obj;
		self.out[0] = obj.outlet(pd.s.float).?;
		self.out[1] = obj.outlet(pd.s.float).?;
		return self;
	}

	fn setup() void {
		class = pd.class(pd.symbol("same"), @ptrCast(&new), null,
			@sizeOf(Self), .{}, &.{ .deffloat }).?;

		class.addBang(@ptrCast(&bang));
		class.addFloat(@ptrCast(&float));
		class.addMethod(@ptrCast(&set), pd.symbol("set"), &.{ .deffloat });
	}
};

export fn same_setup() void {
	Same.setup();
}
