const pd = @import("pd");
const rn = @import("rng.zig");

const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;

pub const Rind = extern struct {
	obj: pd.Object = undefined,
	out: *pd.Outlet,
	min: Float,
	max: Float,
	rng: rn.Rng,

	const name = "rind";
	pub var class: *pd.Class = undefined;

	fn printC(self: *const Rind) callconv(.c) void {
		pd.post.log(self, .normal, "%g..%g", .{ self.min, self.max });
	}

	fn bangC(self: *Rind) callconv(.c) void {
		const min = self.min;
		const range = self.max - min;
		self.out.float(self.rng.next() * range + min);
	}

	fn listC(
		self: *Rind,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		sw: switch (@min(ac, 2)) {
			2 => {
				if (av[1].type == .float) {
					self.min = av[1].w.float;
				}
				continue :sw 1;
			},
			1 => {
				if (av[0].type == .float) {
					self.max = av[0].w.float;
				}
			},
			else => {},
		}
	}

	fn anythingC(
		self: *Rind,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		if (ac >= 1 and av[0].type == .float) {
			self.min = av[0].w.float;
		}
	}

	fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Rind {
		return pd.wrap(*Rind, init(av[0..ac]), name);
	}
	inline fn init(av: []const Atom) !*Rind {
		const self: *Rind = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		// defaults
		var min: Float = 0;
		var max: Float = 1;

		sw: switch (@min(av.len, 2)) {
			2 => {
				min = av[0].getFloat() orelse min;
				max = av[1].getFloat() orelse max;
				continue :sw 0;
			},
			1 => {
				max = av[0].getFloat() orelse max;
				_ = try obj.inletFloat(&self.max);
			},
			0 => {
				_ = try obj.inletFloat(&self.min);
				_ = try obj.inletFloat(&self.max);
			},
			else => unreachable,
		}
		self.* = .{
			.out = try .init(obj, &pd.s_float),
			.rng = .init(),
			.min = min,
			.max = max,
		};
		return self;
	}

	inline fn setup() !void {
		class = try .init(Rind, name, &.{ .gimme }, &initC, null, .{});
		try rn.Impl(Rind).extend();
		class.addBang(@ptrCast(&bangC));
		class.addList(@ptrCast(&listC));
		class.addAnything(@ptrCast(&anythingC));
		class.addMethod(@ptrCast(&printC), .gen("print"), &.{});
	}
};

export fn rind_setup() void {
	_ = pd.wrap(void, Rind.setup(), @src().fn_name);
}
