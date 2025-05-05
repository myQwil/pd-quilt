const pd = @import("pd");

const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;

pub fn Tet(T: type) type { return extern struct {
	obj: pd.Object = undefined,
	out: *pd.Outlet,
	/// slope
	k: f64,
	/// frequency at index 0
	min: f64,
	/// reference pitch
	ref: Float,
	/// number of tones
	tet: Float,

	const Self = @This();
	var class: *pd.Class = undefined;

	const getK: fn(tet: Float) callconv(.@"inline") f64 = T.getK;
	const getMin: fn(k: f64, ref: Float) callconv(.@"inline") f64 = T.getMin;

	fn refC(self: *Self, f: Float) callconv(.c) void {
		self.ref = if (f == 0) 1 else f;
		self.min = getMin(self.k, self.ref);
	}

	fn tetC(self: *Self, f: Float) callconv(.c) void {
		self.tet = if (f == 0) 1 else f;
		self.k = getK(f);
		self.min = getMin(self.k, self.ref);
	}

	fn set(self: *Self, onset: u32, av: []const Atom) void {
		sw: switch (@min(av.len + onset, 2)) {
			2 => {
				if (av[1 - onset].getFloat()) |f| {
					self.tet = f;
					self.k = getK(f);
				}
				continue :sw 1;
			},
			1 => {
				if (onset == 0) {
					self.ref = av[0].getFloat() orelse self.ref;
				}
				self.min = getMin(self.k, self.ref);
			},
			else => {},
		}
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
		self.set(1, av[0..ac]);
	}

	pub fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Self {
		return pd.wrap(*Self, init(av[0..ac]), T.name);
	}
	inline fn init(av: []const Atom) !*Self {
		const self: *Self = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		const ref = pd.floatArg(0, av) catch 440;
		const tet = pd.floatArg(1, av) catch 12;
		const k = getK(tet);

		_ = try obj.inlet(&obj.g.pd, &pd.s_float, .gen("ref"));
		_ = try obj.inlet(&obj.g.pd, &pd.s_float, .gen("tet"));
		self.* = .{
			.out = try .init(obj, &pd.s_float),
			.ref = ref,
			.tet = tet,
			.k = k,
			.min = getMin(k, ref),
		};
		return self;
	}

	pub inline fn setup() !void {
		class = try .init(Self, T.name, &.{ .gimme }, &initC, null, .{});

		class.addFloat(@ptrCast(&T.floatC));
		class.addList(@ptrCast(&listC));
		class.addAnything(@ptrCast(&anythingC));
		class.addMethod(@ptrCast(&refC), .gen("ref"), &.{ .float });
		class.addMethod(@ptrCast(&tetC), .gen("tet"), &.{ .float });
		class.addMethod(@ptrCast(&setC), .gen("set"), &.{ .gimme });
		class.setHelpSymbol(.gen("tet"));
	}
};}
