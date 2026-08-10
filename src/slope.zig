const pd = @import("pd");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;

/// Non-gui slider objects.
pub fn Slope(T: type) type { return extern struct {
	obj: pd.Object,
	out: *pd.Outlet,
	min: f64,
	max: f64,
	run: f64,
	k: f64,

	const Self = @This();
	var class: *pd.Class = undefined;
	const parentPtr = pd.parentPtr(Self);
	pub const parentConstPtr = pd.parentConstPtr(Self);

	const getK: fn(min: f64, max: f64, run: f64) callconv(.@"inline") f64 = T.getK;

	fn minC(p: *Pd, f: Float) callconv(.c) void {
		const self = parentPtr(p);
		self.min = f;
		self.k = getK(self.min, self.max, self.run);
	}

	fn maxC(p: *Pd, f: Float) callconv(.c) void {
		const self = parentPtr(p);
		self.max = f;
		self.k = getK(self.min, self.max, self.run);
	}

	fn runC(p: *Pd, f: Float) callconv(.c) void {
		const self = parentPtr(p);
		self.run = f;
		self.k = getK(self.min, self.max, self.run);
	}

	fn set(self: *Self, onset: u32, av: []const Atom) void {
		sw: switch (@min(av.len + onset, 3)) {
			3 => {
				if (av[2 - onset].getFloat()) |f| self.run = f;
			continue :sw 2; }, 2 => {
				if (av[1 - onset].getFloat()) |f| self.max = f;
			continue :sw 1; }, 1 => if (onset == 0) {
				if (av[0].getFloat()) |f| self.min = f;
			}, else => {},
		}
		self.k = getK(self.min, self.max, self.run);
	}

	fn setC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		parentPtr(p).set(0, av[0..ac]);
	}

	fn listC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		parentPtr(p).set(0, av[0..ac]);
	}

	fn anythingC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		// first arg is a symbol, skip it
		parentPtr(p).set(1, av[0..ac]);
	}

	pub fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(av[0..ac]), T.name);
	}
	inline fn init(av: []const Atom) pd.Oom!*Pd {
		const self: *Self = try pd.gpa.create(Self);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inlet(&obj.g.pd, pd.s.float(), .gen("min"));
		_ = try obj.inlet(&obj.g.pd, pd.s.float(), .gen("max"));
		_ = try obj.inlet(&obj.g.pd, pd.s.float(), .gen("run"));

		// defaults
		var min: f64 = 0;
		var max: f64 = 1;
		var run: f64 = 1;

		sw: switch (@min(av.len, 3)) {
			3 => { if (av[2].getFloat()) |f| run = f; continue :sw 2; },
			2 => {
				if (av[1].getFloat()) |f| max = f;
				if (av[0].getFloat()) |f| min = f;
			},
			1 => { if (av[0].getFloat()) |f| max = f; },
			else => {},
		}
		self.* = .{
			.obj = self.obj,
			.out = try .init(obj, pd.s.float()),
			.min = min,
			.max = max,
			.run = run,
			.k = getK(min, max, run),
		};
		return &obj.g.pd;
	}

	pub inline fn setup() pd.Class.Error!void {
		class = try .init(Self, T.name, &.{ .gimme }, initC, null, .{});
		class.addFloat(&T.floatC);
		class.addList(listC);
		class.addAnything(anythingC);
		class.addMethod(&.{ .float }, minC, .gen("min"));
		class.addMethod(&.{ .float }, maxC, .gen("max"));
		class.addMethod(&.{ .float }, runC, .gen("run"));
		class.addMethod(&.{ .gimme }, setC, .gen("set"));
		class.setHelpSymbol(.gen("slope"));
	}
};}
