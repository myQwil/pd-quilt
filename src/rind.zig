//! Float random number generator. Seed is initialized with Zig's `io.random()`.

const pd = @import("pd");
const std = @import("std");
const rn = @import("rng.zig");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;

const io = std.Io.Threaded.global_single_threaded.io();

pub const Rind = extern struct {
	obj: pd.Object,
	out: *pd.Outlet,
	min: Float,
	max: Float,
	rng: rn.Rng,

	const name = "rind";
	pub var class: *pd.Class = undefined;
	pub const parentPtr = pd.parentPtr(Rind);
	pub const parentConstPtr = pd.parentConstPtr(Rind);

	fn printC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		pd.post.log(self, .normal, "%g..%g", .{ self.min, self.max });
	}

	fn bangC(p: *Pd) callconv(.c) void {
		const self = parentPtr(p);
		const min = self.min;
		const range = self.max - min;
		self.out.float(self.rng.next() * range + min);
	}

	fn listC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = parentPtr(p);
		sw: switch (@min(ac, 2)) {
			2 => { if (av[1].getFloat()) |f| self.min = f; continue :sw 1; },
			1 => { if (av[0].getFloat()) |f| self.max = f; },
			else => {},
		}
	}

	fn anythingC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		if (ac >= 1 and av[0].type == .float) {
			parentPtr(p).min = av[0].w.float;
		}
	}

	fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(av[0..ac]), name);
	}
	inline fn init(av: []const Atom) !*Pd {
		const self: *Rind = try pd.gpa.create(Rind);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		// defaults
		var min: Float = 0;
		var max: Float = 1;

		sw: switch (@min(av.len, 2)) {
			2 => {
				if (av[0].getFloat()) |f| min = f;
				if (av[1].getFloat()) |f| max = f;
				continue :sw 0;
			},
			1 => {
				if (av[0].getFloat()) |f| max = f;
				_ = try obj.inletFloat(&self.max);
			},
			0 => {
				_ = try obj.inletFloat(&self.min);
				_ = try obj.inletFloat(&self.max);
			},
			else => unreachable,
		}
		self.* = .{
			.obj = self.obj,
			.out = try .init(obj, pd.s.float()),
			.rng = .init(),
			.min = min,
			.max = max,
		};
		return &obj.g.pd;
	}

	inline fn setup() !void {
		class = try .init(Rind, name, &.{ .gimme }, initC, null, .{});
		try rn.Impl(Rind).extend(io);
		class.addBang(bangC);
		class.addList(listC);
		class.addAnything(anythingC);
		class.addMethod(&.{}, printC, .gen("print"));
	}
};

export fn rind_setup() void {
	_ = pd.wrap(void, Rind.setup(), @src().fn_name);
}
