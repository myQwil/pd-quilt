//! Translate hue-saturation-value to a 24-bit rgb integer.

const pd = @import("pd");

const Pd = pd.Pd;
const Float = pd.Float;

const Rgb = struct {
	r: Float,
	g: Float,
	b: Float,
};

out: *pd.Outlet,
h: Float,
s: Float,
v: Float,

const name = "hsv";
var class: *pd.Class = undefined;
const Box = pd.Box(pd.Object, @This());

fn bangC(pp: *const Pd) callconv(.c) void {
	const self = Box.stateConst(pp);
	const s = self.s;
	const v = self.v;
	const color: Rgb = if (s <= 0)
		.{ .r = v, .g = v, .b = v }
	else blk: {
		const h = @mod(self.h, 360) / 60;
		const i: u3 = @intFromFloat(h);

		const f = h - @as(Float, @floatFromInt(i));
		const p = v * (1 - s);
		const q = v * (1 - (s * if (i & 1 == 0) (1 - f) else f));

		break :blk switch (i) {
			0 => .{ .r = v, .g = q, .b = p },
			1 => .{ .r = q, .g = v, .b = p },
			2 => .{ .r = p, .g = v, .b = q },
			3 => .{ .r = p, .g = q, .b = v },
			4 => .{ .r = q, .g = p, .b = v },
			5 => .{ .r = v, .g = p, .b = q },
			else => unreachable,
		};
	};
	const R = @as(u24, @intFromFloat(color.r * 0xff)) << 16;
	const G = @as(u24, @intFromFloat(color.g * 0xff)) << 8;
	const B = @as(u24, @intFromFloat(color.b * 0xff));
	self.out.float(@floatFromInt(R + G + B));
}

fn floatC(p: *Pd, f: Float) callconv(.c) void {
	Box.state(p).h = f;
	bangC(p);
}

fn createC(h: Float, s: Float, v: Float) callconv(.c) ?*Pd {
	return pd.wrap(*Pd, create(h, s, v), name);
}
inline fn create(h: Float, s: Float, v: Float) pd.Oom!*Pd {
	const obj: *pd.Object = @ptrCast(try class.pd());
	const self = Box.state(&obj.g.pd);
	errdefer obj.g.pd.destroy();

	_ = try obj.inletFloat(&self.s);
	_ = try obj.inletFloat(&self.v);
	self.* = .{
		.out = try .create(obj, pd.s.float()),
		.h = h,
		.s = s,
		.v = v,
	};
	return &obj.g.pd;
}

inline fn setup() pd.Class.Error!void {
	const args: [3]pd.Atom.Type = @splat(.deffloat);
	class = try .create(name, &args, &createC, null, @sizeOf(Box), .{});
	class.addBang(&bangC);
	class.addFloat(&floatC);
}

export fn hsv_setup() void {
	_ = pd.wrap(void, setup(), @src().fn_name);
}
