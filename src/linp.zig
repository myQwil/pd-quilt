const pd = @import("pd");
const tg = @import("toggle.zig");

const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;

const default_grain = 20;

const LinP = extern struct {
	obj: pd.Object = undefined,
	/// sends ramp value
	out_f: *pd.Outlet,
	/// sends pause state
	out_p: *pd.Outlet,
	clock: *pd.Clock,
	targettime: f64,
	prevtime: f64,
	invtime: f64 = 1,
	in1val: f64 = 0,
	grain: Float,
	setval: Float,
	targetval: Float,
	paused: bool = false,
	gotinlet: bool = false,

	const name = "linp";
	var class: *pd.Class = undefined;

	fn setPause(self: *LinP, state: bool) void {
		if (tg.set(&self.paused, state)) {
			self.out_p.float(@floatFromInt(@intFromBool(self.paused)));
		}
	}

	fn tglPause(self: *LinP, av: []const Atom) bool {
		const changed = tg.toggle(&self.paused, av);
		if (changed) {
			self.out_p.float(@floatFromInt(@intFromBool(self.paused)));
		}
		return changed;
	}

	fn ft1C(self: *LinP, f: Float) callconv(.c) void {
		self.in1val = f;
		self.gotinlet = true;
	}

	fn setC(self: *LinP, f: Float) callconv(.c) void {
		self.clock.unset();
		self.targetval = f;
		self.setval = f;
	}

	fn freeze(self: *LinP) void {
		if (pd.time() >= self.targettime) {
			self.setval = self.targetval;
		} else {
			self.setval += @floatCast(self.invtime * (pd.time() - self.prevtime)
				* (self.targetval - self.setval));
		}
		self.clock.unset();
	}

	fn stopC(self: *LinP) callconv(.c) void {
		if (pd.pd_compatibilitylevel >= 48) {
			self.freeze();
		}
		self.targetval = self.setval;
		self.setPause(true);
	}

	fn pauseC(
		self: *LinP,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
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

	fn tickC(self: *LinP) callconv(.c) void {
		const timenow = pd.time();
		const msectogo = -pd.timeSince(self.targettime);
		if (msectogo < 1e-9) {
			self.out_f.float(self.targetval);
		} else {
			self.out_f.float(@floatCast(self.setval + self.invtime
				* (timenow - self.prevtime) * (self.targetval - self.setval)));
			if (self.grain <= 0) {
				self.grain = default_grain;
			}
			self.clock.delay(if (self.grain > msectogo) msectogo else self.grain);
		}
	}

	fn floatC(self: *LinP, f: Float) callconv(.c) void {
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
			self.tickC();
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
			self.out_f.float(f);
		}
		self.gotinlet = false;
	}

	fn initC(f: Float, grain: Float) callconv(.c) ?*LinP {
		return pd.wrap(*LinP, init(f, grain), name);
	}
	inline fn init(f: Float, grain: Float) !*LinP {
		const self: *LinP = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		var clock: *pd.Clock = try .init(self, @ptrCast(&tickC));
		errdefer clock.deinit();

		_ = try obj.inlet(&obj.g.pd, &pd.s_float, .gen("ft1"));
		_ = try obj.inletFloat(&self.grain);

		const targettime = pd.time();
		self.* = .{
			.clock = clock,
			.out_f = try .init(obj, &pd.s_float),
			.out_p = try .init(obj, &pd.s_float),
			.targettime = targettime,
			.prevtime = targettime,
			.grain = grain,
			.targetval = f,
			.setval = f,
		};
		return self;
	}

	fn deinitC(self: *LinP) callconv(.c) void {
		self.clock.deinit();
	}

	inline fn setup() !void {
		class = try .init(LinP, name, &.{ .deffloat, .deffloat }, &initC, &deinitC, .{});
		class.addFloat(@ptrCast(&floatC));
		class.addMethod(@ptrCast(&stopC), .gen("stop"), &.{});
		class.addMethod(@ptrCast(&ft1C), .gen("ft1"), &.{ .float });
		class.addMethod(@ptrCast(&setC), .gen("set"), &.{ .float });
		class.addMethod(@ptrCast(&pauseC), .gen("pause"), &.{ .gimme });
	}
};

export fn linp_setup() void {
	_ = pd.wrap(void, LinP.setup(), @src().fn_name);
}
