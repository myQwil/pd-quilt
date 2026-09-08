//! Pulse wave generator.
const Pulse = @This();

const pd = @import("pd");
const tb = @import("misc/tabfudge.zig");
const Inlet = @import("misc/inlet.zig").Inlet;

const Pd = pd.Pd;
const Float = pd.Float;
const Sample = pd.Sample;

const unitbit32 = tb.unitbit32;
const hioffset = tb.hioffset;

phase: f64 = 0,
edge: *Float,
conv: Float = 0,
f: Float, // scalar frequency

const name = "pulse~";
var class: *pd.Class = undefined;
const Box = pd.Box(pd.Object, Pulse);

fn edgeC(p: *Pd, f: Float) callconv(.c) void {
	Box.state(p).edge.* = f;
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

fn dspC(p: *Pd, sp: [*]*pd.Signal) callconv(.c) void {
	const self = Box.state(p);
	self.conv = 1.0 / sp[0].srate;
	pd.dsp.add(performC, .{ self, sp[2].len, sp[2].vec, sp[1].vec, sp[0].vec });
}

fn ft1C(p: *Pd, f: Float) callconv(.c) void {
	Box.state(p).phase = f;
}

fn createC(_: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) callconv(.c) ?*Pd {
	return pd.wrap(*Pd, create(av[0..ac]), name);
}
inline fn create(av: []const pd.Atom) pd.Oom!*Pd {
	const obj: *pd.Object = @ptrCast(try class.pd());
	const self = Box.state(&obj.g.pd);
	errdefer obj.g.pd.destroy();

	_ = try obj.outlet(pd.s.signal());
	const inlet: *Inlet = @ptrCast(@alignCast(
		try obj.inletSignal(pd.floatArg(0, av) catch 0.5)));
	_ = try obj.inlet(&obj.g.pd, pd.s.float(), .gen("ft1"));

	self.* = .{
		.edge = &inlet.un.floatsignalvalue,
		.f = pd.floatArg(1, av) catch 0,
	};
	return &obj.g.pd;
}

inline fn setup() pd.Class.Error!void {
	class = try .create(name, &.{ .gimme }, createC, null, @sizeOf(Box), .{});
	class.doMainSignalIn(@offsetOf(Box, "body") + @offsetOf(Pulse, "f"));
	class.addMethod(&.{ .cant }, dspC, .gen("dsp"));
	class.addMethod(&.{ .float }, ft1C, .gen("ft1"));
	class.addMethod(&.{ .float }, edgeC, .gen("edge"));
}

export fn pulse_tilde_setup() void {
	_ = pd.wrap(void, setup(), @src().fn_name);
}
