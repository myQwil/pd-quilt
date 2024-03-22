const pd = @import("pd");

const Hsv = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	obj: pd.Object,
	out: *pd.Outlet,
	h: pd.Float,
	s: pd.Float,
	v: pd.Float,

	fn bang(self: *const Self) void {
		var r: pd.Float = undefined;
		var g: pd.Float = undefined;
		var b: pd.Float = undefined;

		const s = self.s;
		const v = self.v;
		if (s <= 0) {
			// Achromatic case
			r = v;
			g = v;
			b = v;
		} else {
			const h = @mod(self.h, 360) / 60;
			const i: i32 = @intFromFloat(h);

			const f = h - @as(pd.Float, @floatFromInt(i));
			const p = v * (1 - s);
			const q = v * (1 - (s * f));
			const t = v * (1 - (s * (1 - f)));

			switch (i) {
				0 =>    { r = v;  g = t;  b = p; },
				1 =>    { r = q;  g = v;  b = p; },
				2 =>    { r = p;  g = v;  b = t; },
				3 =>    { r = p;  g = q;  b = v; },
				4 =>    { r = t;  g = p;  b = v; },
				5 =>    { r = v;  g = p;  b = q; },
				else => { r = v;  g = v;  b = v; }
			}
		}
		const R = @as(u24, @intFromFloat(r * 0xff)) << 16;
		const G = @as(u24, @intFromFloat(g * 0xff)) << 8;
		const B = @as(u24, @intFromFloat(b * 0xff));
		self.out.float(@floatFromInt(R + G + B));
	}

	fn float(self: *Self, f: pd.Float) void {
		self.h = f;
		self.bang();
	}

	fn new(h: pd.Float, s: pd.Float, v: pd.Float) ?*Self {
		const self: *Self = @ptrCast(class.new() orelse return null);
		self.h = h;
		self.s = s;
		self.v = v;

		const obj = &self.obj;
		self.out = obj.outlet(pd.s.float).?;
		_ = obj.inletFloat(&self.s);
		_ = obj.inletFloat(&self.v);
		return self;
	}

	fn setup() void {
		class = pd.class(pd.symbol("hsv"), @ptrCast(&new), null,
			@sizeOf(Self), .{}, &.{ .deffloat, .deffloat, .deffloat }).?;

		class.addBang(@ptrCast(&bang));
		class.addFloat(@ptrCast(&float));
	}
};

export fn hsv_setup() void {
	Hsv.setup();
}
