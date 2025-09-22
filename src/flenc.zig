const std = @import("std");
const pd = @import("pd");
const bf = @import("bitfloat.zig");

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
			if (av[2 - onset].getFloat()) |f| {
				u.b.sign = @intFromFloat(f);
			}
			continue :sw 2;
		},
		2 => {
			if (av[1 - onset].getFloat()) |f| {
				u.b.exponent = @intFromFloat(f);
			}
			continue :sw 1;
		},
		1 => if (onset == 0) {
			if (av[0].getFloat()) |f| {
				u.b.mantissa = @intFromFloat(f);
			}
		},
		else => {},
	}
	return u;
}

const FlEnc = extern struct {
	obj: pd.Object = undefined,
	out: *pd.Outlet,
	uf: bf.UnFloat,

	const name = "flenc";
	var class: *pd.Class = undefined;

	inline fn err(self: *const FlEnc, e: anyerror) void {
		pd.post.err(self, name ++ ": %s", .{ @errorName(e).ptr });
	}

	fn printC(self: *const FlEnc) callconv(.c) void {
		self.print() catch |e| self.err(e);
	}
	inline fn print(self: *const FlEnc) !void {
		var buf: [@bitSizeOf(Float) + 3]u8 = undefined;
		const b = self.uf.b;
		const s = try std.fmt.bufPrintZ(&buf, &fmt, .{ b.sign, b.exponent, b.mantissa });
		pd.post.log(self, .normal, "%s", .{ s.ptr });
	}

	fn mantissaC(self: *FlEnc, f: Float) callconv(.c) void {
		self.uf.b.mantissa = @intFromFloat(f);
	}

	fn exponentC(self: *FlEnc, f: Float) callconv(.c) void {
		self.uf.b.exponent = @intFromFloat(f);
	}

	fn signC(self: *FlEnc, f: Float) callconv(.c) void {
		self.uf.b.sign = @intFromFloat(f);
	}

	fn intC(self: *FlEnc, f: Float) callconv(.c) void {
		self.uf = .{ .u = @intFromFloat(f) };
	}

	fn f1C(self: *FlEnc, f: Float) callconv(.c) void {
		self.uf = .{ .f = f };
	}

	fn bangC(self: *const FlEnc) callconv(.c) void {
		self.out.float(self.uf.f);
	}

	fn floatC(self: *FlEnc, f: Float) callconv(.c) void {
		self.mantissaC(f);
		self.bangC();
	}

	fn setC(
		self: *FlEnc,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		self.uf = getUf(self.uf, 0, av[0..ac]);
	}

	fn listC(
		self: *FlEnc,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		self.uf = getUf(self.uf, 0, av[0..ac]);
		self.bangC();
	}

	fn anythingC(
		self: *FlEnc,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		// first arg is a symbol, skip it
		self.uf = getUf(self.uf, 1, av[0..ac]);
		self.bangC();
	}

	fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*FlEnc {
		return pd.wrap(*FlEnc, init(av[0..ac]), name);
	}
	inline fn init(av: []const Atom) !*FlEnc {
		const self: *FlEnc = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inlet(&obj.g.pd, &pd.s_float, .gen("e"));
		_ = try obj.inlet(&obj.g.pd, &pd.s_float, .gen("s"));
		self.* = .{
			.out = try .init(obj, &pd.s_float),
			.uf = getUf(.{ .u = 0 }, 0, av),
		};
		return self;
	}

	inline fn setup() !void {
		class = try .init(FlEnc, name, &.{ .gimme }, &initC, null, .{});
		class.addBang(@ptrCast(&bangC));
		class.addFloat(@ptrCast(&floatC));
		class.addList(@ptrCast(&listC));
		class.addAnything(@ptrCast(&anythingC));
		class.addMethod(@ptrCast(&printC), .gen("print"), &.{});
		class.addMethod(@ptrCast(&mantissaC), .gen("m"), &.{ .float });
		class.addMethod(@ptrCast(&exponentC), .gen("e"), &.{ .float });
		class.addMethod(@ptrCast(&signC), .gen("s"), &.{ .float });
		class.addMethod(@ptrCast(&f1C), .gen("f"), &.{ .float });
		class.addMethod(@ptrCast(&intC), .gen("u"), &.{ .float });
		class.addMethod(@ptrCast(&setC), .gen("set"), &.{ .gimme });
	}
};

export fn flenc_setup() void {
	_ = pd.wrap(void, FlEnc.setup(), @src().fn_name);
}
