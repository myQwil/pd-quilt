const pd = @import("pd");

const unitbit32 = 1572864.0; // 3*2^19; bit 32 has place value 1
const hioffset: u1 = blk: {
	const builtin = @import("builtin");
	break :blk if (builtin.target.cpu.arch.endian() == .little) 1 else 0;
};

const TabFudge = union {
	d: f64,
	i: [2]i32,
};

const MetroTilde = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	obj: pd.Object,
	out: *pd.Outlet,
	phase: f64,
	prev: pd.Sample,
	conv: pd.Float,
	f: pd.Float, // scalar frequency

	fn perform(w: [*]usize) *usize {
		const self: *Self = @ptrFromInt(w[1]);
		const inlet: [*]pd.Sample = @ptrFromInt(w[2]);
		const conv = self.conv;
		var dphase = self.phase + unitbit32;
		var tf = TabFudge{ .d = unitbit32 };
		const normhipart = tf.i[hioffset];
		tf.d = dphase;

		for (inlet[0..w[3]]) |in| {
			tf.i[hioffset] = normhipart;
			dphase += in * conv;
			const f: pd.Sample = @floatCast(tf.d - unitbit32);
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
		return &w[4];
	}

	fn dsp(self: *Self, sp: [*]*pd.Signal) void {
		self.conv = -1.0 / sp[0].srate;
		pd.dsp.add(@ptrCast(&perform), 3, self, sp[0].vec, sp[0].len);
	}

	fn ft1(self: *Self, f: pd.Float) void {
		self.phase = f;
	}

	fn new(f: pd.Float) ?*Self {
		const self: *Self = @ptrCast(class.new() orelse return null);
		const obj: *pd.Object = @ptrCast(self);
		self.out = obj.outlet(pd.s.bang).?;
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("ft1"));
		self.phase = 0;
		self.prev = 0;
		self.conv = 0;
		self.f = f;
		return self;
	}

	fn setup() void {
		class = pd.class(pd.symbol("metro~"), @ptrCast(&new), null,
			@sizeOf(Self), .{}, &.{ .deffloat }).?;

		class.doMainSignalIn(@offsetOf(Self, "f"));
		class.addMethod(@ptrCast(&dsp), pd.symbol("dsp"), &.{ .cant });
		class.addMethod(@ptrCast(&ft1), pd.symbol("ft1"), &.{ .float });
	}
};

export fn metro_tilde_setup() void {
	MetroTilde.setup();
}
