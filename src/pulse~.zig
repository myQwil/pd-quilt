const pd = @import("pd");
const Inlet = @import("inlet.zig").Inlet;

const Float = pd.Float;
const Sample = pd.Sample;

const tb = @import("tabfudge.zig");
const unitbit32 = tb.unitbit32;
const hioffset = tb.hioffset;

const Pulse = extern struct {
	obj: pd.Object = undefined,
	phase: f64 = 0,
	edge: *Float,
	conv: Float = 0,
	f: Float, // scalar frequency

	const name = "pulse~";
	var class: *pd.Class = undefined;

	fn edgeC(self: *Pulse, f: Float) callconv(.c) void {
		self.edge.* = f;
	}

	fn performC(w: [*]usize) callconv(.c) [*]usize {
		const self: *Pulse = @ptrFromInt(w[1]);
		const out = @as([*]Sample, @ptrFromInt(w[3]))[0..w[2]];
		const conv = self.conv;
		var dphase = self.phase + unitbit32;

		var tf: tb.TabFudge = .{ .d = unitbit32 };
		const normhipart = tf.i[hioffset];
		tf.d = dphase;

		const inlet2: [*]Sample = @ptrFromInt(w[4]);
		const inlet1: [*]Sample = @ptrFromInt(w[5]);
		for (out, inlet1, inlet2) |*o, in1, in2| {
			tf.i[hioffset] = normhipart;
			dphase += in1 * conv;
			const f: Sample = @floatCast(tf.d - unitbit32);
			o.* = if (f < in2) 0 else 1;
			tf.d = dphase;
		}
		tf.i[hioffset] = normhipart;
		self.phase = tf.d - unitbit32;
		return w + 6;
	}

	fn dspC(self: *Pulse, sp: [*]*pd.Signal) callconv(.c) void {
		self.conv = 1.0 / sp[0].srate;
		pd.dsp.add(&performC, .{ self, sp[2].len, sp[2].vec, sp[1].vec, sp[0].vec });
	}

	fn ft1C(self: *Pulse, f: Float) callconv(.c) void {
		self.phase = f;
	}

	fn initC(_: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) callconv(.c) ?*Pulse {
		return pd.wrap(*Pulse, init(av[0..ac]), name);
	}
	inline fn init(av: []const pd.Atom) !*Pulse {
		const self: *Pulse = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.outlet(&pd.s_signal);
		const inlet: *Inlet = @ptrCast(@alignCast(
			try obj.inletSignal(pd.floatArg(0, av) catch 0.5)));
		_ = try obj.inlet(&obj.g.pd, &pd.s_float, .gen("ft1"));

		self.* = .{
			.edge = &inlet.un.floatsignalvalue,
			.f = pd.floatArg(1, av) catch 0,
		};
		return self;
	}

	inline fn setup() !void {
		class = try .init(Pulse, name, &.{ .gimme }, &initC, null, .{});
		class.doMainSignalIn(@offsetOf(Pulse, "f"));
		class.addMethod(@ptrCast(&dspC), .gen("dsp"), &.{ .cant });
		class.addMethod(@ptrCast(&ft1C), .gen("ft1"), &.{ .float });
		class.addMethod(@ptrCast(&edgeC), .gen("edge"), &.{ .float });
	}
};

export fn pulse_tilde_setup() void {
	_ = pd.wrap(void, Pulse.setup(), @src().fn_name);
}
