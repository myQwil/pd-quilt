const pd = @import("pd.zig");

// -------------------------- same --------------------------
const Same = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	obj: pd.Object,
	out2: *pd.Outlet,
	f: pd.Float,

	fn bang(self: *const Self) void {
		self.obj.out.float(self.f);
	}

	fn float(self: *Self, f: pd.Float) void {
		if (self.f != f) {
			self.f = f;
			self.obj.out.float(f);
		} else {
			self.out2.float(f);
		}
	}

	fn set(self: *Self, f: pd.Float) void {
		self.f = f;
	}

	fn new(f: pd.Float) *Self {
		const self: *Self = @ptrCast(class.new());
		self.f = f;

		const obj = &self.obj;
		_ = obj.outlet(pd.s.float);
		self.out2 = obj.outlet(pd.s.float);
		return self;
	}

	fn setup() void {
		const A = pd.AtomType;
		class = pd.class(pd.symbol("same"), @ptrCast(&new), null,
			@sizeOf(Self), pd.Class.DEFAULT, A.DEFFLOAT, A.NULL);

		class.addBang(@ptrCast(&bang));
		class.addFloat(@ptrCast(&float));
		class.addMethod(@ptrCast(&set), pd.symbol("set"), A.DEFFLOAT, A.NULL);
	}
};

export fn same_setup() void {
	Same.setup();
}
