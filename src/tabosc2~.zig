const pd = @import("pd");
const tb = @import("tab2.zig");
const tf = @import("tabfudge.zig");

const Atom = pd.Atom;
const Float = pd.Float;
const Sample = pd.Sample;
const Symbol = pd.Symbol;

const unitbit32 = tf.unitbit32;
const hioffset = tf.hioffset;

const TabOsc2 = extern struct {
	obj: pd.Object = undefined,
	tab2: tb.Tab2,
	phase: f64 = 0,
	conv: Float = 0,
	len: Float = default_len,
	invlen: Float = 1.0 / default_len,

	const name = "tabosc2~";
	const default_len = 512.0;
	pub var class: *pd.Class = undefined;

	fn performC(w: [*]usize) callconv(.c) [*]usize {
		const self: *TabOsc2 = @ptrFromInt(w[1]);
		const out = @as([*]Sample, @ptrFromInt(w[3]))[0..w[2]];
		const vec = self.tab2.vec orelse {
			@memset(out, 0);
			return w + 6;
		};
		const len = self.len;
		const mask = @as(i32, @intFromFloat(len)) - 1;
		const conv = len * self.conv;
		var dphase = len * self.phase + unitbit32;

		var t: tf.TabFudge = .{ .d = unitbit32 };
		var normhipart = t.i[hioffset];

		const inlet2: [*]Sample = @ptrFromInt(w[4]);
		const inlet1: [*]Sample = @ptrFromInt(w[5]);
		for (out, inlet1, inlet2) |*o, in1, in2| {
			t.d = dphase;
			dphase += in1 * conv;
			const i: usize = @intCast(t.i[hioffset] & mask);
			t.i[hioffset] = normhipart;
			o.* = tb.sample(vec + i, @floatCast(t.d - unitbit32), in2);
		}

		t.d = unitbit32 * len;
		normhipart = t.i[hioffset];
		t.d = dphase + unitbit32 * (len - 1);
		t.i[hioffset] = normhipart;
		self.phase = (t.d - unitbit32 * len) * self.invlen;
		return w + 6;
	}

	fn setC(self: *TabOsc2, s: *Symbol) callconv(.c) void {
		const len = self.set(s) catch |e| {
			pd.post.err(self, "%s: %s", .{ s.name, @errorName(e).ptr });
			return;
		};
		self.len = @floatFromInt(len);
		self.invlen = 1.0 / self.len;
	}
	inline fn set(self: *TabOsc2, s: *Symbol) !usize {
		errdefer self.tab2.vec = null;
		self.tab2.arrayname = s;

		const array: *pd.GArray = @ptrCast(pd.garray_class.find(s)
			orelse return error.GArrayNotFound);

		const vec = try array.floatWords();
		if (vec.len < 2) {
			return error.BadArraySize;
		}

		self.tab2.vec = vec.ptr;
		array.useInDsp();
		return @intCast(@as(usize, 1) << pd.ulog2(vec.len - 1).?);
	}

	fn dspC(self: *TabOsc2, sp: [*]*pd.Signal) callconv(.c) void {
		self.conv = 1.0 / sp[0].srate;
		self.setC(self.tab2.arrayname);
		pd.dsp.add(&performC, .{ self, sp[2].len, sp[2].vec, sp[1].vec, sp[0].vec });
	}

	fn ft1C(self: *TabOsc2, f: Float) callconv(.c) void {
		self.phase = f;
	}

	fn initC(_: *pd.Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*TabOsc2 {
		return pd.wrap(*TabOsc2, init(av[0..ac]), name);
	}
	inline fn init(av: []const Atom) !*TabOsc2 {
		const self: *TabOsc2 = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inlet(&obj.g.pd, &pd.s_float, .gen("ft1"));
		const arrayname = try pd.symbolArg(0, av);
		self.* = .{
			.tab2 = try .init(obj, arrayname, pd.floatArg(1, av) catch 0),
		};
		return self;
	}

	inline fn setup() !void {
		class = try .init(TabOsc2, name, &.{ .gimme }, &initC, null, .{});
		tb.Impl(TabOsc2).extend();
		class.addMethod(@ptrCast(&dspC), .gen("dsp"), &.{ .cant });
		class.addMethod(@ptrCast(&setC), .gen("set"), &.{ .symbol });
		class.addMethod(@ptrCast(&ft1C), .gen("ft1"), &.{ .float });
	}
};

export fn tabosc2_tilde_setup() void {
	_ = pd.wrap(void, TabOsc2.setup(), @src().fn_name);
}
