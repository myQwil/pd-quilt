//! Float-encode. Creates floats out of sign, exponent, and mantissa integers.

const std = @import("std");
const pd = @import("pd");
const bf = @import("bitfloat.zig");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;

const fmt = blk: {
	var buf: [127:0]u8 = undefined;
	var w: std.Io.Writer = .fixed(&buf);
	w.print("{{b}} {{b:0>{}}} {{b:0>{}}}", .{ @bitSizeOf(bf.Ue), @bitSizeOf(bf.Um) })
		catch @compileError("Couldn't construct flenc.fmt");
	var sized_buf: [w.end]u8 = undefined;
	@memcpy(&sized_buf, w.buffered());
	break :blk sized_buf;
};

fn getUf(uf: bf.UnFloat, onset: u2, av: []const Atom) bf.UnFloat {
	var u: bf.UnFloat = uf;
	sw: switch (@min(av.len + onset, 3)) {
		3 => {
			if (av[2 - onset].getFloat()) |f| u.b.sign = @intFromFloat(f);
		continue :sw 2; }, 2 => {
			if (av[1 - onset].getFloat()) |f| u.b.exponent = @intFromFloat(f);
		continue :sw 1; }, 1 => if (onset == 0) {
			if (av[0].getFloat()) |f| u.b.mantissa = @intFromFloat(f);
		}, else => {},
	}
	return u;
}

const FlEnc = extern struct {
	obj: pd.Object,
	out: *pd.Outlet,
	uf: bf.UnFloat,

	const name = "flenc";
	var class: *pd.Class = undefined;
	const parentPtr = pd.parentPtr(FlEnc);
	const parentConstPtr = pd.parentConstPtr(FlEnc);

	inline fn err(self: *const FlEnc, e: anyerror) void {
		pd.post.err(self, name ++ ": %s", .{ @errorName(e).ptr });
	}

	fn printC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		self.print() catch |e| self.err(e);
	}
	inline fn print(self: *const FlEnc) !void {
		var buf: [@bitSizeOf(Float) + 3]u8 = undefined;
		const b = self.uf.b;
		const s = try std.fmt.bufPrintSentinel(
			&buf, &fmt, .{ b.sign, b.exponent, b.mantissa }, 0);
		pd.post.log(self, .normal, s, .{});
	}

	fn mantissaC(p: *Pd, f: Float) callconv(.c) void {
		parentPtr(p).uf.b.mantissa = @intFromFloat(f);
	}

	fn exponentC(p: *Pd, f: Float) callconv(.c) void {
		parentPtr(p).uf.b.exponent = @intFromFloat(f);
	}

	fn signC(p: *Pd, f: Float) callconv(.c) void {
		parentPtr(p).uf.b.sign = @intFromFloat(f);
	}

	fn intC(p: *Pd, f: Float) callconv(.c) void {
		parentPtr(p).uf = .{ .u = @intFromFloat(f) };
	}

	fn f1C(p: *Pd, f: Float) callconv(.c) void {
		parentPtr(p).uf = .{ .f = f };
	}

	fn bangC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		self.out.float(self.uf.f);
	}

	fn floatC(p: *Pd, f: Float) callconv(.c) void {
		mantissaC(p, f);
		bangC(p);
	}

	fn setC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = parentPtr(p);
		self.uf = getUf(self.uf, 0, av[0..ac]);
	}

	fn listC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = parentPtr(p);
		self.uf = getUf(self.uf, 0, av[0..ac]);
		bangC(p);
	}

	fn anythingC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = parentPtr(p);
		// first arg is a symbol, skip it
		self.uf = getUf(self.uf, 1, av[0..ac]);
		bangC(p);
	}

	fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(av[0..ac]), name);
	}
	inline fn init(av: []const Atom) !*Pd {
		const self: *FlEnc = try pd.gpa.create(FlEnc);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inlet(&obj.g.pd, pd.s.float(), .gen("e"));
		_ = try obj.inlet(&obj.g.pd, pd.s.float(), .gen("s"));
		self.* = .{
			.obj = self.obj,
			.out = try .init(obj, pd.s.float()),
			.uf = getUf(.{ .u = 0 }, 0, av),
		};
		return &obj.g.pd;
	}

	inline fn setup() !void {
		class = try .init(FlEnc, name, &.{ .gimme }, initC, null, .{});
		class.addBang(bangC);
		class.addFloat(floatC);
		class.addList(listC);
		class.addAnything(anythingC);
		class.addMethod(&.{}, printC, .gen("print"));
		class.addMethod(&.{ .float }, mantissaC, .gen("m"));
		class.addMethod(&.{ .float }, exponentC, .gen("e"));
		class.addMethod(&.{ .float }, signC, .gen("s"));
		class.addMethod(&.{ .float }, f1C, .gen("f"));
		class.addMethod(&.{ .float }, intC, .gen("u"));
		class.addMethod(&.{ .gimme }, setC, .gen("set"));
	}
};

export fn flenc_setup() void {
	_ = pd.wrap(void, FlEnc.setup(), @src().fn_name);
}
