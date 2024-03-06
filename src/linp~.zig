const pd = @import("toggle.zig");

// -------------------------- linp~ ------------------------------
const LinPTilde = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	obj: pd.Object,
	o_pause: *pd.Outlet,
	target: pd.Sample,
	value: pd.Sample,
	biginc: pd.Sample,
	inc: pd.Sample,
	invn: pd.Float,
	dspticktomsec: pd.Float,
	inletvalue: pd.Float,
	inletwas: pd.Float,
	ticksleft: u32,
	retarget: bool,
	pause: pd.Tgl,

	inline fn tgl_pause(self: *Self, av: []pd.Atom) bool {
		const changed = self.pause.toggle(av);
		if (changed) {
			self.o_pause.float(@floatFromInt(@intFromBool(self.pause.state)));
		}
		return changed;
	}

	fn perform(w: [*]pd.Int) *pd.Int {
		const self: *Self = @ptrFromInt(@as(usize, @intCast(w[1])));
		const n: usize = @intCast(w[2]);
		const out: [*]pd.Sample = @ptrFromInt(@as(usize, @intCast(w[3])));

		if (pd.bigOrSmall(self.value)) {
			self.value = 0;
		}
		if (self.retarget) {
			const nticks = @max(1,
				@as(u32, @intFromFloat(self.inletwas * self.dspticktomsec)));
			self.ticksleft = nticks;
			self.biginc = (self.target - self.value)
				/ @as(pd.Sample, @floatFromInt(nticks));
			self.inc = self.invn * self.biginc;
			self.retarget = false;
		}

		if (!self.pause.state) {
			if (self.ticksleft > 0) {
				var f = self.value;
				for (out[0..n]) |*o| {
					o.* = f;
					f += self.inc;
				}
				self.value += self.biginc;
				self.ticksleft -= 1;
				return &w[4];
			} else {
				self.value = self.target;
			}
		}

		const f = self.value;
		for (out[0..n]) |*o| {
			o.* = f;
		}
		return &w[4];
	}

	fn dsp(self: *Self, sp: [*]*pd.Signal) void {
		// if (sp[0].s_un.s_n & 7) {
			pd.Dsp.add(@ptrCast(&perform), 3, self, sp[0].len, sp[0].vec);
		// } else {
			// dsp_add(@ptrCast(&perf8), 3, self, sp[0].s_un.s_n, sp[0].s_vec);
		// }
		self.invn = 1 / @as(pd.Float, @floatFromInt(sp[0].len));
		self.dspticktomsec = sp[0].srate
			/ @as(pd.Float, @floatFromInt(1000 * sp[0].len));
	}

	fn stop(self: *Self) void {
		self.target = self.value;
		self.ticksleft = 0;
		self.retarget = false;
	}

	fn pause(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		if (!self.tgl_pause(av[0..ac]) or self.value == self.target) {
			return;
		}
	}

	fn float(self: *Self, f: pd.Float) void {
		if (self.inletvalue <= 0) {
			self.target = f;
			self.value = f;
			self.ticksleft = 0;
			self.retarget = false;
		} else {
			self.target = f;
			self.inletwas = self.inletvalue;
			self.inletvalue = 0;
			self.retarget = true;
			if (self.pause.set(false)) {
				self.o_pause.float(@floatFromInt(@intFromBool(self.pause.state)));
			}
		}
	}

	fn new() *Self {
		const self: *Self = @ptrCast(class.new());
		const obj = &self.obj;
		_ = obj.inletFloat(&self.inletvalue);
		_ = obj.outlet(pd.s.signal);
		self.o_pause = obj.outlet(pd.s.float);
		self.pause.state = false;
		self.retarget = false;
		self.ticksleft = 0;
		self.value = 0;
		self.target = 0;
		self.inletvalue = 0;
		self.inletwas = 0;
		return self;
	}

	fn setup() void {
		class = pd.class(pd.symbol("linp~"), @ptrCast(&new), null,
			@sizeOf(Self), pd.Class.DEFAULT, 0);

		const A = pd.AtomType;
		class.addFloat(@ptrCast(&float));
		class.addMethod(@ptrCast(&stop), pd.symbol("stop"), 0);
		class.addMethod(@ptrCast(&dsp), pd.symbol("dsp"), A.CANT, A.NULL);
		class.addMethod(@ptrCast(&pause), pd.symbol("pause"), A.GIMME, A.NULL);
	}
};

export fn linp_tilde_setup() void {
	LinPTilde.setup();
}
