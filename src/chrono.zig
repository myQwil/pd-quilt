const pd = @import("timer.zig");
const A = pd.AtomType;

// -------------------------- chrono ------------------------------
const Chrono = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	base: pd.Timer,
	o_lap: *pd.Outlet,
	settime: f64,
	setmore: f64,
	laptime: f64,
	lapmore: f64,

	inline fn set_time(self: *Self) void {
		self.settime = pd.getLogicalTime();
		self.laptime = self.settime;
	}

	inline fn reset(self: *Self, paused: bool) void {
		self.base.set_pause(paused);
		self.set_time();
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

	fn list(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		self.reset(ac >= 2 and av[1].type == A.FLOAT and av[1].w.float == 1);
		if (ac >= 1 and av[0].type == A.FLOAT) {
			self.delay(av[0].w.float);
		}
	}

	fn bang2(self: *Self) void {
		const result = self.setmore + if (self.base.pause.state) 0 else
			self.base.time_since(self.settime);
		self.base.obj.out.float(@floatCast(result));
	}

	fn lap(self: *Self) void {
		const result = self.lapmore + if (self.base.pause.state) 0 else
			self.base.time_since(self.laptime);
		self.o_lap.float(@floatCast(result));
		self.laptime = pd.getLogicalTime();
		self.lapmore = 0;
	}

	fn pause(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		if (!self.base.tgl_pause(av[0..ac])) {
			return;
		}

		if (self.base.pause.state) {
			self.setmore += self.base.time_since(self.settime);
			self.lapmore += self.base.time_since(self.laptime);
		} else {
			self.set_time();
		}
	}

	fn tempo(self: *Self, _: ?*pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		if (!self.base.pause.state) {
			self.setmore += self.base.time_since(self.settime);
			self.lapmore += self.base.time_since(self.laptime);
			self.set_time();
		}
		self.base.parse_units(av[0..ac]);
	}

	fn new(_: *pd.Symbol, ac: u32, av: [*]pd.Atom) *Self {
		const self: *Self = @ptrCast(class.new());
		const obj = &self.base.obj;
		_ = obj.inlet(&obj.g.pd, pd.s.bang, pd.symbol("bang2"));
		_ = obj.outlet(pd.s.float);
		self.o_lap = obj.outlet(pd.s.float);

		self.base.init(av[0..ac]);
		self.bang();
		return self;
	}

	fn setup() void {
		class = pd.class(pd.symbol("chrono"), @ptrCast(&new), null,
			@sizeOf(Self), pd.Class.DEFAULT, A.GIMME, A.NULL);

		class.addBang(@ptrCast(&bang));
		class.addFloat(@ptrCast(&float));
		class.addList(@ptrCast(&list));
		class.addMethod(@ptrCast(&lap), pd.symbol("lap"), 0);
		class.addMethod(@ptrCast(&bang2), pd.symbol("bang2"), 0);
		class.addMethod(@ptrCast(&delay), pd.symbol("delay"), A.FLOAT, A.NULL);
		class.addMethod(@ptrCast(&delay), pd.symbol("del"), A.FLOAT, A.NULL);
		class.addMethod(@ptrCast(&pause), pd.symbol("pause"), A.GIMME, A.NULL);
		class.addMethod(@ptrCast(&tempo), pd.symbol("tempo"), A.GIMME, A.NULL);
	}
};

export fn chrono_setup() void {
	Chrono.setup();
}
