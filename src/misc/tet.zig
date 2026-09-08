//! Similar to `[mtof]` and `[ftom]`
//! but with adjustable reference pitch and number of tones in an octave.

const pd = @import("pd");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;

pub fn Tet(T: type) type { return struct {
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
	pub const Box = pd.Box(pd.Object, Self);

	const getK: fn(tet: Float) callconv(.@"inline") f64 = T.getK;
	const getMin: fn(k: f64, ref: Float) callconv(.@"inline") f64 = T.getMin;

	fn refC(p: *Pd, f: Float) callconv(.c) void {
		const self = Box.state(p);
		self.ref = if (f == 0) 1 else f;
		self.min = getMin(self.k, self.ref);
	}

	fn tetC(p: *Pd, f: Float) callconv(.c) void {
		const self = Box.state(p);
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
		Box.state(p).set(0, av[0..ac]);
	}

	fn listC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		Box.state(p).set(0, av[0..ac]);
	}

	fn anythingC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		Box.state(p).set(1, av[0..ac]);
	}

	pub fn createC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, create(av[0..ac]), T.name);
	}
	inline fn create(av: []const Atom) pd.Oom!*Pd {
		const obj: *pd.Object = @ptrCast(try class.pd());
		const self = Box.state(&obj.g.pd);
		errdefer obj.g.pd.destroy();

		const ref = pd.floatArg(0, av) catch 440;
		const tet = pd.floatArg(1, av) catch 12;
		const k = getK(tet);

		_ = try obj.inlet(&obj.g.pd, pd.s.float(), .gen("ref"));
		_ = try obj.inlet(&obj.g.pd, pd.s.float(), .gen("tet"));
		self.* = .{
			.out = try .create(obj, pd.s.float()),
			.ref = ref,
			.tet = tet,
			.k = k,
			.min = getMin(k, ref),
		};
		return &obj.g.pd;
	}

	pub inline fn setup() pd.Class.Error!void {
		class = try .create(T.name, &.{ .gimme }, createC, null, @sizeOf(Box), .{});

		class.addFloat(&T.floatC);
		class.addList(listC);
		class.addAnything(anythingC);
		class.addMethod(&.{ .float }, refC, .gen("ref"));
		class.addMethod(&.{ .float }, tetC, .gen("tet"));
		class.addMethod(&.{ .gimme }, setC, .gen("set"));
		class.setHelpSymbol(.gen("tet"));
	}
};}
