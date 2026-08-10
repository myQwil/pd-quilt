//! Signal-based metronome.
//! Works by generating a sawtooth wave and sending a bang on each new ramp.

const pd = @import("pd");

const tb = @import("tabfudge.zig");
const unitbit32 = tb.unitbit32;
const hioffset = tb.hioffset;

const Pd = pd.Pd;
const Float = pd.Float;
const Sample = pd.Sample;

const MetroSignal = extern struct {
	obj: pd.Object,
	out: *pd.Outlet,
	phase: f64 = 0,
	prev: Sample = 0,
	conv: Float = 0,
	f: Float, // scalar frequency

	const name = "metro~";
	var class: *pd.Class = undefined;
	const parentPtr = pd.parentPtr(MetroSignal);

	fn performC(w: [*]usize) callconv(.c) [*]usize {
		const self: *MetroSignal = @ptrFromInt(w[1]);
		const inlet = @as([*]Sample, @ptrFromInt(w[3]))[0..w[2]];
		const conv = self.conv;
		var dphase = self.phase + unitbit32;

		var tf: tb.TabFudge = .{ .d = unitbit32 };
		const normhipart = tf.i[hioffset];
		tf.d = dphase;

		for (inlet) |in| {
			tf.i[hioffset] = normhipart;
			dphase += in * conv;
			const f: Sample = @floatCast(tf.d - unitbit32);
			if (in < 0) {
				if (f < self.prev) {
					self.out.bang();
				}
			} else {
				if (f > self.prev) {
					self.out.bang();
				}
			}
			self.prev = f;
			tf.d = dphase;
		}
		tf.i[hioffset] = normhipart;
		self.phase = tf.d - unitbit32;
		return w + 4;
	}

	fn dspC(p: *Pd, sp: [*]*pd.Signal) callconv(.c) void {
		const self = parentPtr(p);
		self.conv = -1.0 / sp[0].srate;
		pd.dsp.add(performC, .{ self, sp[0].len, sp[0].vec });
	}

	fn ft1C(p: *Pd, f: Float) callconv(.c) void {
		parentPtr(p).phase = f;
	}

	fn initC(f: Float) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(f), name);
	}
	inline fn init(f: Float) pd.Oom!*Pd {
		const self: *MetroSignal = try pd.gpa.create(MetroSignal);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inlet(&obj.g.pd, pd.s.float(), .gen("ft1"));
		self.* = .{
			.obj = self.obj,
			.out = try .init(obj, pd.s.bang()),
			.f = f,
		};
		return &obj.g.pd;
	}

	inline fn setup() pd.Class.Error!void {
		class = try .init(MetroSignal, name, &.{ .deffloat }, initC, null, .{});
		class.doMainSignalIn(@offsetOf(MetroSignal, "f"));
		class.addMethod(&.{ .cant }, dspC, .gen("dsp"));
		class.addMethod(&.{ .float }, ft1C, .gen("ft1"));
	}
};

export fn metro_tilde_setup() void {
	_ = pd.wrap(void, MetroSignal.setup(), @src().fn_name);
}
