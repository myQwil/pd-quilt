const pd = @import("pd");
const tg = @import("toggle.zig");
const default_grain = 20;

const LinP = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	obj: pd.Object,
	out: [2]*pd.Outlet,
	clock: *pd.Clock,
	targettime: f64,
	prevtime: f64,
	invtime: f64,
	in1val: f64,
	grain: pd.Float,
	setval: pd.Float,
	targetval: pd.Float,
	paused: bool,
	gotinlet: bool,

	fn setPause(self: *Self, state: bool) void {
		if (tg.set(&self.paused, state)) {
			self.out[1].float(@floatFromInt(@intFromBool(self.paused)));
		}
	}

	fn tglPause(self: *Self, av: []const pd.Atom) bool {
		const changed = tg.toggle(&self.paused, av);
		if (changed) {
			self.out[1].float(@floatFromInt(@intFromBool(self.paused)));
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

	fn freeze(self: *Self) void {
		if (pd.time() >= self.targettime) {
			self.setval = self.targetval;
		} else {
			self.setval += @floatCast(self.invtime * (pd.time() - self.prevtime)
				* (self.targetval - self.setval));
		}
		self.clock.unset();
	}

	fn stop(self: *Self) void {
		if (pd.pd_compatibilitylevel >= 48) {
			self.freeze();
		}
		self.targetval = self.setval;
		self.setPause(true);
	}

	fn pause(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		if (!self.tglPause(av[0..ac]) or self.setval == self.targetval) {
			return;
		}

		if (self.paused) {
			self.freeze();
			self.targettime = -pd.timeSince(self.targettime);
		} else {
			const timenow = pd.time();
			const msectogo = self.targettime;
			self.targettime = pd.sysTimeAfter(msectogo);
			self.invtime = 1 / (self.targettime - timenow);
			self.prevtime = timenow;
			if (self.grain <= 0) {
				self.grain = default_grain;
			}
			self.clock.delay(if (self.grain > msectogo) msectogo else self.grain);
		}
	}

	fn tick(self: *Self) void {
		const timenow = pd.time();
		const msectogo = -pd.timeSince(self.targettime);
		if (msectogo < 1e-9) {
			self.out[0].float(self.targetval);
		} else {
			self.out[0].float(@floatCast(self.setval + self.invtime
				* (timenow - self.prevtime) * (self.targetval - self.setval)));
			if (self.grain <= 0) {
				self.grain = default_grain;
			}
			self.clock.delay(if (self.grain > msectogo) msectogo else self.grain);
		}
	}

	fn float(self: *Self, f: pd.Float) void {
		const timenow = pd.time();
		if (self.gotinlet and self.in1val > 0) {
			if (timenow > self.targettime) {
				self.setval = self.targetval;
			} else {
				self.setval += @floatCast(self.invtime * (timenow - self.prevtime)
					* (self.targetval - self.setval));
			}
			self.prevtime = timenow;
			self.targettime = pd.sysTimeAfter(self.in1val);
			self.targetval = f;
			self.tick();
			self.gotinlet = false;
			self.setPause(false);
			self.invtime = 1 / (self.targettime - timenow);
			if (self.grain <= 0) {
				self.grain = default_grain;
			}
			self.clock.delay(if (self.grain > self.in1val) self.in1val else self.grain);
		} else {
			self.clock.unset();
			self.targetval = f;
			self.setval = f;
			self.out[0].float(f);
		}
		self.gotinlet = false;
	}

	fn new(f: pd.Float, grain: pd.Float) ?*Self {
		const self: *Self = @ptrCast(class.new() orelse return null);
		self.targetval = f;
		self.setval = f;
		self.gotinlet = false;
		self.paused = false;
		self.invtime = 1;
		self.grain = grain;
		self.clock = pd.clock(self, @ptrCast(&tick)).?;
		self.targettime = pd.time();
		self.prevtime = self.targettime;
		const obj = &self.obj;
		self.out[0] = obj.outlet(pd.s.float).?;
		self.out[1] = obj.outlet(pd.s.float).?;
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("ft1"));
		_ = obj.inletFloat(&self.grain);
		return self;
	}

	fn free(self: *Self) void {
		self.clock.free();
	}

	fn setup() void {
		class = pd.class(pd.symbol("linp"), @ptrCast(&new), @ptrCast(&free),
			@sizeOf(Self), .{}, &.{ .deffloat, .deffloat }).?;
		class.addFloat(@ptrCast(&float));
		class.addMethod(@ptrCast(&stop), pd.symbol("stop"), &.{});
		class.addMethod(@ptrCast(&ft1), pd.symbol("ft1"), &.{ .float });
		class.addMethod(@ptrCast(&set), pd.symbol("set"), &.{ .float });
		class.addMethod(@ptrCast(&pause), pd.symbol("pause"), &.{ .gimme });
	}
};

export fn linp_setup() void {
	LinP.setup();
}