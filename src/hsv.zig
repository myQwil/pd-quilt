//! Translate hue-saturation-value to a 24-bit rgb integer.

const pd = @import("pd");

const Pd = pd.Pd;
const Float = pd.Float;

const Rgb = struct {
	r: Float,
	g: Float,
	b: Float,
};

const Hsv = extern struct {
	obj: pd.Object,
	out: *pd.Outlet,
	h: Float,
	s: Float,
	v: Float,

	const name = "hsv";
	var class: *pd.Class = undefined;
	const parentPtr = pd.parentPtr(Hsv);
	const parentConstPtr = pd.parentConstPtr(Hsv);

	fn bangC(pp: *const Pd) callconv(.c) void {
		const self = parentConstPtr(pp);
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
		parentPtr(p).h = f;
		bangC(p);
	}

	fn initC(h: Float, s: Float, v: Float) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(h, s, v), name);
	}
	inline fn init(h: Float, s: Float, v: Float) !*Pd {
		const self: *Hsv = try pd.gpa.create(Hsv);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inletFloat(&self.s);
		_ = try obj.inletFloat(&self.v);
		self.* = .{
			.obj = self.obj,
			.out = try .init(obj, pd.s.float()),
			.h = h,
			.s = s,
			.v = v,
		};
		return &obj.g.pd;
	}

	inline fn setup() !void {
		const args: [3]pd.Atom.Type = @splat(.deffloat);
		class = try .init(Hsv, name, &args, &initC, null, .{});
		class.addBang(&bangC);
		class.addFloat(&floatC);
	}
};

export fn hsv_setup() void {
	_ = pd.wrap(void, Hsv.setup(), @src().fn_name);
}
