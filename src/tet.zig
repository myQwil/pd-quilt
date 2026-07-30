const pd = @import("pd");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;

/// Similar to `[mtof]` and `[ftom]`
/// but with adjustable reference pitch and number of tones in an octave.
pub fn Tet(T: type) type { return extern struct {
	obj: pd.Object,
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
	const parentPtr = pd.parentPtr(Self);
	pub const parentConstPtr = pd.parentConstPtr(Self);

	const getK: fn(tet: Float) callconv(.@"inline") f64 = T.getK;
	const getMin: fn(k: f64, ref: Float) callconv(.@"inline") f64 = T.getMin;

	fn refC(p: *Pd, f: Float) callconv(.c) void {
		const self = parentPtr(p);
		self.ref = if (f == 0) 1 else f;
		self.min = getMin(self.k, self.ref);
	}

	fn tetC(p: *Pd, f: Float) callconv(.c) void {
		const self = parentPtr(p);
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
					if (av[0].getFloat()) |f| self.ref = f;
				}
				self.min = getMin(self.k, self.ref);
			},
			else => {},
		}
	}

	fn setC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		parentPtr(p).set(0, av[0..ac]);
	}

	fn listC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		parentPtr(p).set(0, av[0..ac]);
	}

	fn anythingC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		parentPtr(p).set(1, av[0..ac]);
	}

	pub fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(av[0..ac]), T.name);
	}
	inline fn init(av: []const Atom) !*Pd {
		const self: *Self = try pd.gpa.create(Self);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		const ref = pd.floatArg(0, av) catch 440;
		const tet = pd.floatArg(1, av) catch 12;
		const k = getK(tet);

		_ = try obj.inlet(&obj.g.pd, pd.s.float(), .gen("ref"));
		_ = try obj.inlet(&obj.g.pd, pd.s.float(), .gen("tet"));
		self.* = .{
			.obj = self.obj,
			.out = try .init(obj, pd.s.float()),
			.ref = ref,
			.tet = tet,
			.k = k,
			.min = getMin(k, ref),
		};
		return &obj.g.pd;
	}

	pub inline fn setup() !void {
		class = try .init(Self, T.name, &.{ .gimme }, initC, null, .{});

		class.addFloat(&T.floatC);
		class.addList(listC);
		class.addAnything(anythingC);
		class.addMethod(&.{ .float }, refC, .gen("ref"));
		class.addMethod(&.{ .float }, tetC, .gen("tet"));
		class.addMethod(&.{ .gimme }, setC, .gen("set"));
		class.setHelpSymbol(.gen("tet"));
	}
};}
