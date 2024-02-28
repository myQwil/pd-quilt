const pd = @import("tab2.zig");

// -------------------------- tabread2~ --------------------------
const TabRead2 = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	base: pd.Tab2,
	onset: pd.Float,
	npoints: usize,

	fn perform(w: [*]isize) *isize {
		const self: *Self = @ptrFromInt(@as(usize, @intCast(w[1])));
		const n: usize = @intCast(w[2]);
		const out: [*]pd.Sample = @ptrFromInt(@as(usize, @intCast(w[3])));
		if (self.base.vec) |vec| {
			const onset = self.onset;
			const npoints = self.npoints;

			const inlet1: [*]pd.Sample = @ptrFromInt(@as(usize, @intCast(w[4])));
			const inlet2: [*]pd.Sample = @ptrFromInt(@as(usize, @intCast(w[5])));
			for (out[0..n], inlet1, inlet2) |*o, in1, in2| {
				const findex: f64 = in1 + onset;
				var i: usize = @intFromFloat(findex);
				const frac: pd.Sample = blk: {
					if (i < 1) {
						i = 1;
						break :blk 0;
					} else if (i > npoints) {
						i = npoints;
						break :blk 1;
					}
					break :blk @floatCast(findex - @as(f64, @floatFromInt(i)));
				};
				o.* = pd.Tab2.sample(vec + i, frac, in2);
			}
		} else {
			for (0..n) |i| {
				out[i] = 0;
			}
		}

		return &w[6];
	}

	fn set(self: *Self, s: *pd.Symbol) void {
		self.npoints = self.base.set_array(s) catch return;
	}

	fn dsp(self: *Self, sp: [*]*pd.Signal) void {
		self.set(self.base.arrayname);
		pd.Dsp.add(@ptrCast(&perform),
			5, self, sp[0].len, sp[2].vec, sp[0].vec, sp[1].vec);
	}

	fn new(arrayname: *pd.Symbol, hold: pd.Float) *Self {
		const self: *Self = @ptrCast(class.new());
		self.base.init(arrayname, hold);

		const obj = &self.base.obj;
		_ = obj.inletFloat(&self.onset);
		self.onset = 0;
		return self;
	}

	fn setup() void {
		const A = pd.AtomType;
		class = pd.class(pd.symbol("tabread2~"), @ptrCast(&new), null,
			@sizeOf(Self), pd.Class.DEFAULT, A.DEFSYM, A.DEFFLOAT, A.NULL);

		pd.Tab2.extend(class);
		class.addMethod(@ptrCast(&dsp), pd.symbol("dsp"), A.CANT, A.NULL);
		class.addMethod(@ptrCast(&set), pd.symbol("set"), A.SYMBOL, A.NULL);
	}
};

export fn tabread2_tilde_setup() void {
	TabRead2.setup();
}
