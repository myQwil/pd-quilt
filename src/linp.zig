const pd = @import("toggle.zig");
const default_grain = 20;

// -------------------------- linp ------------------------------
const LinP = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	obj: pd.Object,
	o_pause: *pd.Outlet,
	clock: *pd.Clock,
	targettime: f64,
	prevtime: f64,
	invtime: f64,
	in1val: f64,
	grain: pd.Float,
	setval: pd.Float,
	targetval: pd.Float,
	pause: pd.Tgl,
	gotinlet: bool,

	inline fn set_pause(self: *Self, state: bool) void {
		if (self.pause.set(state)) {
			self.o_pause.float(@floatFromInt(@intFromBool(self.pause.state)));
		}
	}

	inline fn tgl_pause(self: *Self, av: []pd.Atom) bool {
		const changed = self.pause.toggle(av);
		if (changed) {
			self.o_pause.float(@floatFromInt(@intFromBool(self.pause.state)));
		}
		return changed;
	}

	fn ft1(self: *Self, f: pd.Float) void {
		self.in1val = f;
		self.gotinlet = true;
	}

	fn set(self: *Self, f: pd.Float) void {
		self.clock.unset();
		self.targetval = f;
		self.setval = f;
	}

	inline fn freeze(self: *Self) void {
		if (pd.getSysTime() >= self.targettime) {
			self.setval = self.targetval;
		} else {
			self.setval += @floatCast(self.invtime * (pd.getSysTime() - self.prevtime)
				* (self.targetval - self.setval));
		}
		self.clock.unset();
	}

	fn stop(self: *Self) void {
		if (pd.pd_compatibilitylevel >= 48) {
			self.freeze();
		}
		self.targetval = self.setval;
		self.set_pause(true);
	}

	fn pause(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		if (!self.tgl_pause(av[0..ac]) or self.setval == self.targetval) {
			return;
		}

		if (self.pause.state) {
			self.freeze();
			self.targettime = -pd.getTimeSince(self.targettime);
		} else {
			const timenow = pd.getSysTime();
			const msectogo = self.targettime;
			self.targettime = pd.getSysTimeAfter(msectogo);
			self.invtime = 1 / (self.targettime - timenow);
			self.prevtime = timenow;
			if (self.grain <= 0) {
				self.grain = default_grain;
			}
			self.clock.delay(if (self.grain > msectogo) msectogo else self.grain);
		}
	}

	fn tick(self: *Self) void {
		const timenow = pd.getSysTime();
		const msectogo = -pd.getTimeSince(self.targettime);
		if (msectogo < 1e-9) {
			self.obj.out.float(self.targetval);
		} else {
			self.obj.out.float(@floatCast(self.setval + self.invtime
				* (timenow - self.prevtime) * (self.targetval - self.setval)));
			if (self.grain <= 0) {
				self.grain = default_grain;
			}
			self.clock.delay(if (self.grain > msectogo) msectogo else self.grain);
		}
	}

	fn float(self: *Self, f: pd.Float) void {
		const timenow = pd.getSysTime();
		if (self.gotinlet and self.in1val > 0) {
			if (timenow > self.targettime) {
				self.setval = self.targetval;
			} else {
				self.setval += @floatCast(self.invtime * (timenow - self.prevtime)
					* (self.targetval - self.setval));
			}
			self.prevtime = timenow;
			self.targettime = pd.getSysTimeAfter(self.in1val);
			self.targetval = f;
			self.tick();
			self.gotinlet = false;
			self.set_pause(false);
			self.invtime = 1 / (self.targettime - timenow);
			if (self.grain <= 0) {
				self.grain = default_grain;
			}
			self.clock.delay(if (self.grain > self.in1val) self.in1val else self.grain);
		} else {
			self.clock.unset();
			self.targetval = f;
			self.setval = f;
			self.obj.out.float(f);
		}
		self.gotinlet = false;
	}

	fn new(f: pd.Float, grain: pd.Float) *Self {
		const self: *Self = @ptrCast(class.new());
		self.targetval = f;
		self.setval = f;
		self.gotinlet = false;
		self.pause.state = false;
		self.invtime = 1;
		self.grain = grain;
		self.clock = pd.clock(self, @ptrCast(&tick));
		self.targettime = pd.getSysTime();
		self.prevtime = self.targettime;
		const obj = &self.obj;
		_ = obj.outlet(pd.s.float);
		self.o_pause = obj.outlet(pd.s.float);
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("ft1"));
		_ = obj.inletFloat(&self.grain);
		return self;
	}

	fn free(self: *Self) void {
		self.clock.free();
	}

	fn setup() void {
		const A = pd.AtomType;
		class = pd.class(pd.symbol("linp"), @ptrCast(&new), @ptrCast(&free),
			@sizeOf(Self), pd.Class.DEFAULT, A.DEFFLOAT, A.DEFFLOAT, A.NULL);
		class.addFloat(@ptrCast(&float));
		class.addMethod(@ptrCast(&stop), pd.symbol("stop"), 0);
		class.addMethod(@ptrCast(&ft1), pd.symbol("ft1"), A.FLOAT, A.NULL);
		class.addMethod(@ptrCast(&set), pd.symbol("set"), A.FLOAT, A.NULL);
		class.addMethod(@ptrCast(&pause), pd.symbol("pause"), A.GIMME, A.NULL);
	}
};

export fn linp_setup() void {
	LinP.setup();
}