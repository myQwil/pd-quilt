//! Float random number generator. Seed is initialized with Zig's `io.random()`.

const Rind = @This();
const pd = @import("pd");
const std = @import("std");
const Rng = @import("Rng.zig");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;

const io = std.Io.Threaded.global_single_threaded.io();

out: *pd.Outlet,
min: Float,
max: Float,
rng: Rng,

const name = "rind";
pub var class: *pd.Class = undefined;
pub const Box = pd.Box(pd.Object, Rind);

fn printC(p: *const Pd) callconv(.c) void {
	const self = Box.stateConst(p);
	pd.post.log(p, .normal, "%g..%g", .{ self.min, self.max });
}

fn bangC(p: *Pd) callconv(.c) void {
	const self = Box.state(p);
	const min = self.min;
	const range = self.max - min;
	self.out.float(self.rng.next() * range + min);
}

fn listC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	const self = Box.state(p);
	sw: switch (@min(ac, 2)) {
		2 => { if (av[1].getFloat()) |f| self.min = f; continue :sw 1; },
		1 => { if (av[0].getFloat()) |f| self.max = f; },
		else => {},
	}
}

fn anythingC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	if (ac >= 1 and av[0].type == .float) {
		Box.state(p).min = av[0].w.float;
	}
}

fn createC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
	return pd.wrap(*Pd, create(av[0..ac]), name);
}
inline fn create(av: []const Atom) pd.Oom!*Pd {
	const obj: *pd.Object = @ptrCast(try class.pd());
	const self = Box.state(&obj.g.pd);
	errdefer obj.g.pd.destroy();

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
		.out = try .create(obj, pd.s.float()),
		.rng = .init(),
		.min = min,
		.max = max,
	};
	return &obj.g.pd;
}

inline fn setup() pd.Class.Error!void {
	class = try .create(name, &.{ .gimme }, createC, null, @sizeOf(Box), .{});
	Rng.Impl(Rind).extend(io);
	class.addBang(bangC);
	class.addList(listC);
	class.addAnything(anythingC);
	class.addMethod(&.{}, printC, .gen("print"));
}

export fn rind_setup() void {
	_ = pd.wrap(void, setup(), @src().fn_name);
}
