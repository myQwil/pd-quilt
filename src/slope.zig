const pd = @import("pd");

const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;

pub fn Slope(T: type) type { return extern struct {
	obj: pd.Object = undefined,
	out: *pd.Outlet,
	min: f64,
	max: f64,
	run: f64,
	k: f64,

	const Self = @This();
	var class: *pd.Class = undefined;

	const getK: fn(min: f64, max: f64, run: f64) callconv(.@"inline") f64 = T.getK;

	fn minC(self: *Self, f: Float) callconv(.c) void {
		self.min = f;
		self.k = getK(self.min, self.max, self.run);
	}

	fn maxC(self: *Self, f: Float) callconv(.c) void {
		self.max = f;
		self.k = getK(self.min, self.max, self.run);
	}

	fn runC(self: *Self, f: Float) callconv(.c) void {
		self.run = f;
		self.k = getK(self.min, self.max, self.run);
	}

	fn set(self: *Self, onset: u32, av: []const Atom) void {
		sw: switch (@min(av.len + onset, 3)) {
			3 => {
				self.run = av[2 - onset].getFloat() orelse self.run;
				continue :sw 2;
			},
			2 => {
				self.max = av[1 - onset].getFloat() orelse self.max;
				continue :sw 1;
			},
			1 => {
				if (onset == 0) {
					self.min = av[0].getFloat() orelse self.min;
				}
			},
			else => {},
		}
		self.k = getK(self.min, self.max, self.run);
	}

	fn setC(
		self: *Self,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		self.set(0, av[0..ac]);
	}

	fn listC(
		self: *Self,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		self.set(0, av[0..ac]);
	}

	fn anythingC(
		self: *Self,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		// first arg is a symbol, skip it
		self.set(1, av[0..ac]);
	}

	pub fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Self {
		return pd.wrap(*Self, init(av[0..ac]), T.name);
	}
	inline fn init(av: []const Atom) !*Self {
		const self: *Self = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inlet(&obj.g.pd, &pd.s_float, .gen("min"));
		_ = try obj.inlet(&obj.g.pd, &pd.s_float, .gen("max"));
		_ = try obj.inlet(&obj.g.pd, &pd.s_float, .gen("run"));

		// defaults
		var min: f64 = 0;
		var max: f64 = 1;
		var run: f64 = 1;

		sw: switch (@min(av.len, 3)) {
			3 => {
				run = av[2].getFloat() orelse run;
				continue :sw 2;
			},
			2 => {
				max = av[1].getFloat() orelse max;
				min = av[0].getFloat() orelse min;
			},
			1 => {
				max = av[0].getFloat() orelse max;
			},
			else => {},
		}
		self.* = .{
			.out = try .init(obj, &pd.s_float),
			.min = min,
			.max = max,
			.run = run,
			.k = getK(min, max, run),
		};
		return self;
	}

	pub inline fn setup() !void {
		class = try .init(Self, T.name, &.{ .gimme }, &initC, null, .{});
		class.addFloat(@ptrCast(&T.floatC));
		class.addList(@ptrCast(&listC));
		class.addAnything(@ptrCast(&anythingC));
		class.addMethod(@ptrCast(&minC), .gen("min"), &.{ .float });
		class.addMethod(@ptrCast(&maxC), .gen("max"), &.{ .float });
		class.addMethod(@ptrCast(&runC), .gen("run"), &.{ .float });
		class.addMethod(@ptrCast(&setC), .gen("set"), &.{ .gimme });
		class.setHelpSymbol(.gen("slope"));
	}
};}
