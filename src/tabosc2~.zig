const pd = @import("tab2.zig");

const unitbit32 = 1572864.0; // 3*2^19; bit 32 has place value 1
const hioffset: u1 = blk: {
	const builtin = @import("builtin");
	break :blk if (builtin.target.cpu.arch.endian() == .little) 1 else 0;
};

const TabFudge = union {
	d: f64,
	i: [2]i32,
};

// -------------------------- tabosc2~ --------------------------
const TabOsc2 = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	base: pd.Tab2,
	phase: f64,
	conv: pd.Float,
	len: pd.Float,
	invlen: pd.Float,

	fn perform(w: [*]isize) *isize {
		const self: *Self = @ptrFromInt(@as(usize, @intCast(w[1])));
		const n: usize = @intCast(w[2]);
		const out: [*]pd.Sample = @ptrFromInt(@as(usize, @intCast(w[3])));
		if (self.base.vec) |vec| {
			const len = self.len;
			const mask = @as(i32, @intFromFloat(len)) - 1;
			const conv = len * self.conv;
			var dphase = len * self.phase + unitbit32;

			var tf = TabFudge{ .d = unitbit32 };
			var normhipart = tf.i[hioffset];

			const inlet1: [*]pd.Sample = @ptrFromInt(@as(usize, @intCast(w[4])));
			const inlet2: [*]pd.Sample = @ptrFromInt(@as(usize, @intCast(w[5])));
			for (out[0..n], inlet1, inlet2) |*o, in1, in2| {
				tf.d = dphase;
				dphase += in1 * conv;
				const i: usize = @as(usize, @intCast(tf.i[hioffset] & mask)) + 1;
				tf.i[hioffset] = normhipart;
				o.* = pd.Tab2.sample(vec + i, @floatCast(tf.d - unitbit32), in2);
			}

			tf.d = unitbit32 * len;
			normhipart = tf.i[hioffset];
			tf.d = dphase + unitbit32 * (len - 1);
			tf.i[hioffset] = normhipart;
			self.phase = (tf.d - unitbit32 * len) * self.invlen;
		} else {
			for (0..n) |i| {
				out[i] = 0;
			}
		}

		return &w[6];
	}

	fn set(self: *Self, s: *pd.Symbol) void {
		const npoints = self.base.set_array(s) catch return;
		self.len = @floatFromInt(npoints);
		self.invlen = 1.0 / self.len;
	}

	fn dsp(self: *Self, sp: [*]*pd.Signal) void {
		self.conv = 1.0 / sp[0].srate;
		self.set(self.base.arrayname);
		pd.Dsp.add(@ptrCast(&perform),
			5, self, sp[0].len, sp[2].vec, sp[0].vec, sp[1].vec);
	}

	fn ft1(self: *Self, f: pd.Float) void {
		self.phase = f;
	}

	fn new(arrayname: *pd.Symbol, hold: pd.Float) *Self {
		const self: *Self = @ptrCast(class.new());
		self.base.init(arrayname, hold);

		const obj: *pd.Object = @ptrCast(self);
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("ft1"));

		self.len = 512.0;
		self.invlen = 1.0 / self.len;
		return self;
	}

	fn setup() void {
		const A = pd.AtomType;
		class = pd.class(pd.symbol("tabosc2~"), @ptrCast(&new), null,
			@sizeOf(Self), pd.Class.DEFAULT, A.DEFSYM, A.DEFFLOAT, A.NULL);

		pd.Tab2.extend(class);
		class.addMethod(@ptrCast(&dsp), pd.symbol("dsp"), A.CANT, A.NULL);
		class.addMethod(@ptrCast(&set), pd.symbol("set"), A.SYMBOL, A.NULL);
		class.addMethod(@ptrCast(&ft1), pd.symbol("ft1"), A.FLOAT, A.NULL);
	}
};

export fn tabosc2_tilde_setup() void {
	TabOsc2.setup();
}
