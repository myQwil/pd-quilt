//! `[line]` with pause/resume functionality.

const pd = @import("pd");
const tg = @import("toggle.zig");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;

const default_grain = 20;

const LinP = extern struct {
	obj: pd.Object,
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
	const parentPtr = pd.parentPtr(LinP);

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

	fn ft1C(p: *Pd, f: Float) callconv(.c) void {
		const self = parentPtr(p);
		self.in1val = f;
		self.gotinlet = true;
	}

	fn setC(p: *Pd, f: Float) callconv(.c) void {
		const self = parentPtr(p);
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

	fn stopC(p: *Pd) callconv(.c) void {
		const self = parentPtr(p);
		if (pd.pd_compatibilitylevel >= 48) {
			self.freeze();
		}
		self.targetval = self.setval;
		self.setPause(true);
	}

	fn pauseC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = parentPtr(p);
		if (!self.tglPause(av[0..ac]) or self.setval == self.targetval) {
			return;
		}

		if (self.paused) {
			self.freeze();
			self.targettime = -pd.timeSince(self.targettime);
		} else {
			const timenow = pd.time();
			const msectogo = self.targettime;
			self.targettime = pd.timeAfter(msectogo);
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

	fn floatC(p: *Pd, f: Float) callconv(.c) void {
		const self = parentPtr(p);
		const timenow = pd.time();
		if (self.gotinlet and self.in1val > 0) {
			if (timenow > self.targettime) {
				self.setval = self.targetval;
			} else {
				self.setval += @floatCast(self.invtime * (timenow - self.prevtime)
					* (self.targetval - self.setval));
			}
			self.prevtime = timenow;
			self.targettime = pd.timeAfter(self.in1val);
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

	fn initC(f: Float, grain: Float) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(f, grain), name);
	}
	inline fn init(f: Float, grain: Float) !*Pd {
		const self: *LinP = try pd.gpa.create(LinP);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		var clock: *pd.Clock = try .init(LinP, self, tickC);
		errdefer clock.deinit();

		_ = try obj.inlet(&obj.g.pd, pd.s.float(), .gen("ft1"));
		_ = try obj.inletFloat(&self.grain);

		const targettime = pd.time();
		self.* = .{
			.obj = self.obj,
			.clock = clock,
			.out_f = try .init(obj, pd.s.float()),
			.out_p = try .init(obj, pd.s.float()),
			.targettime = targettime,
			.prevtime = targettime,
			.grain = grain,
			.targetval = f,
			.setval = f,
		};
		return &obj.g.pd;
	}

	fn deinitC(p: *Pd) callconv(.c) void {
		parentPtr(p).clock.deinit();
	}

	inline fn setup() !void {
		class = try .init(LinP, name, &.{ .deffloat, .deffloat }, initC, deinitC, .{});
		class.addFloat(floatC);
		class.addMethod(&.{}, stopC, .gen("stop"));
		class.addMethod(&.{ .float }, ft1C, .gen("ft1"));
		class.addMethod(&.{ .float }, setC, .gen("set"));
		class.addMethod(&.{ .gimme }, pauseC, .gen("pause"));
	}
};

export fn linp_setup() void {
	_ = pd.wrap(void, LinP.setup(), @src().fn_name);
}
