const pd = @import("pd");
const h = @import("timer.zig");

const Chrono = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	base: h.Timer,
	out: [2]*pd.Outlet,
	settime: f64,
	setmore: f64,
	laptime: f64,
	lapmore: f64,

	fn setTime(self: *Self) void {
		self.settime = pd.time();
		self.laptime = self.settime;
	}

	fn reset(self: *Self, paused: bool) void {
		self.base.setPause(paused);
		self.setTime();
		self.setmore = 0;
		self.lapmore = 0;
	}

	fn delay(self: *Self, f: pd.Float) void {
		self.setmore -= f;
	}

	fn bang(self: *Self) void {
		self.reset(false);
	}

	fn float(self: *Self, f: pd.Float) void {
		self.reset(false);
		self.delay(f);
	}

	fn list(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		self.reset(ac >= 2 and av[1].type == .float and av[1].w.float == 1);
		if (ac >= 1 and av[0].type == .float) {
			self.delay(av[0].w.float);
		}
	}

	fn bang2(self: *const Self) void {
		const result = self.setmore + if (self.base.paused) 0 else
			self.base.timeSince(self.settime);
		self.out[0].float(@floatCast(result));
	}

	fn lap(self: *Self) void {
		const result = self.lapmore + if (self.base.paused) 0 else
			self.base.timeSince(self.laptime);
		self.out[1].float(@floatCast(result));
		self.laptime = pd.time();
		self.lapmore = 0;
	}

	fn pause(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		if (!self.base.tglPause(av[0..ac])) {
			return;
		}

		if (self.base.paused) {
			self.setmore += self.base.timeSince(self.settime);
			self.lapmore += self.base.timeSince(self.laptime);
		} else {
			self.setTime();
		}
	}

	fn tempo(self: *Self, _: ?*pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		if (!self.base.paused) {
			self.setmore += self.base.timeSince(self.settime);
			self.lapmore += self.base.timeSince(self.laptime);
			self.setTime();
		}
		self.base.parseUnits(av[0..ac]);
	}

	fn new(_: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) ?*Self {
		const self: *Self = @ptrCast(class.new() orelse return null);
		const obj = &self.base.obj;
		_ = obj.inlet(&obj.g.pd, pd.s.bang, pd.symbol("bang2"));
		self.out[0] = obj.outlet(pd.s.float).?;
		self.out[1] = obj.outlet(pd.s.float).?;

		self.base.init(av[0..ac]);
		self.bang();
		return self;
	}

	fn setup() void {
		class = pd.class(pd.symbol("chrono"), @ptrCast(&new), null,
			@sizeOf(Self), .{}, &.{ .gimme }).?;

		class.addBang(@ptrCast(&bang));
		class.addFloat(@ptrCast(&float));
		class.addList(@ptrCast(&list));
		class.addMethod(@ptrCast(&lap), pd.symbol("lap"), &.{});
		class.addMethod(@ptrCast(&bang2), pd.symbol("bang2"), &.{});
		class.addMethod(@ptrCast(&delay), pd.symbol("del"), &.{ .float });
		class.addMethod(@ptrCast(&delay), pd.symbol("delay"), &.{ .float });
		class.addMethod(@ptrCast(&pause), pd.symbol("pause"), &.{ .gimme });
		class.addMethod(@ptrCast(&tempo), pd.symbol("tempo"), &.{ .gimme });
	}
};

export fn chrono_setup() void {
	Chrono.setup();
}
