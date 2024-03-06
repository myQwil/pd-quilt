const pd = @import("pd");
const h = @import("timer.zig");

const DelP = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	base: h.Timer,
	out: [2]*pd.Outlet,
	clock: *pd.Clock,
	deltime: f64,
	settime: f64,
	setmore: f64,

	fn timeout(self: *const Self) void {
		self.out[0].bang();
	}

	fn delay(self: *Self, f: pd.Float) void {
		self.setmore -= f;
		if (!self.base.paused) {
			self.clock.unset();
			self.setmore += self.base.timeSince(self.settime);
			self.settime = pd.time();
			if (self.setmore < 0) {
				self.clock.delay(-self.setmore);
			}
		}
	}

	fn time(self: *const Self) void {
		const result = self.setmore + if (self.base.paused) 0 else
			self.base.timeSince(self.settime);
		self.out[1].float(@floatCast(result));
	}

	fn pause(self: *Self, _: ?*pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		if (!self.base.tglPause(av[0..ac])) {
			return;
		}

		if (self.base.paused) {
			self.clock.unset();
			self.setmore += self.base.timeSince(self.settime);
		} else {
			self.settime = pd.time();
			if (self.setmore < 0) {
				self.clock.delay(-self.setmore);
			}
		}
	}

	fn stop(self: *Self) void {
		var a = pd.Atom{ .type = .float, .w = .{ .float = 1 } };
		self.pause(null, 1, @ptrCast(&a));
	}

	fn tempo(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		if (!self.base.paused) {
			self.setmore += self.base.timeSince(self.settime);
			self.settime = pd.time();
		}
		self.base.parseUnits(av[0..ac]);
		self.clock.setUnit(self.base.unit, self.base.in_samples);
	}

	fn ft1(self: *Self, f: pd.Float) void {
		self.deltime = @max(0, f);
	}

	fn reset(self: *Self, paused: bool) void {
		self.base.setPause(paused);
		if (paused) {
			self.clock.unset();
		} else {
			self.clock.delay(self.deltime);
		}
		self.settime = pd.time();
		self.setmore = -self.deltime;
	}

	fn bang(self: *Self) void {
		self.reset(false);
	}

	fn float(self: *Self, f: pd.Float) void {
		self.deltime = @max(0, f);
		self.reset(false);
	}

	fn list(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		if (ac >= 1 and av[0].type == .float) {
			self.ft1(av[0].w.float);
		}
		self.reset(ac >= 2 and av[1].type == .float and av[1].w.float == 1);
	}

	fn anything(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		self.reset(ac >= 1 and av[0].type == .float and av[0].w.float == 1);
	}

	fn new(_: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) ?*Self {
		const self: *Self = @ptrCast(class.new() orelse return null);
		const obj = &self.base.obj;
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("ft1"));
		self.out[0] = obj.outlet(pd.s.bang).?;
		self.out[1] = obj.outlet(pd.s.float).?;

		self.clock = pd.clock(self, @ptrCast(&timeout)).?;
		self.settime = pd.time();

		var vec = av[0..ac];
		if (vec.len >= 1 and vec[0].type == .float) {
			self.ft1(vec[0].w.float);
			vec = vec[1..];
		}
		self.base.init(vec);
		self.clock.setUnit(self.base.unit, self.base.in_samples);
		return self;
	}

	fn free(self: *const Self) void {
		self.clock.free();
	}

	fn setup() void {
		class = pd.class(pd.symbol("delp"), @ptrCast(&new), @ptrCast(&free),
			@sizeOf(Self), .{}, &.{ .gimme }).?;

		class.addBang(@ptrCast(&bang));
		class.addFloat(@ptrCast(&float));
		class.addList(@ptrCast(&list));
		class.addAnything(@ptrCast(&anything));
		class.addMethod(@ptrCast(&stop), pd.symbol("stop"), &.{});
		class.addMethod(@ptrCast(&time), pd.symbol("time"), &.{});
		class.addMethod(@ptrCast(&ft1), pd.symbol("ft1"), &.{ .float });
		class.addMethod(@ptrCast(&delay), pd.symbol("del"), &.{ .float });
		class.addMethod(@ptrCast(&delay), pd.symbol("delay"), &.{ .float });
		class.addMethod(@ptrCast(&pause), pd.symbol("pause"), &.{ .gimme });
		class.addMethod(@ptrCast(&tempo), pd.symbol("tempo"), &.{ .gimme });
	}
};

export fn delp_setup() void {
	DelP.setup();
}
