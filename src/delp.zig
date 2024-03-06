const pd = @import("timer.zig");
const A = pd.AtomType;

// -------------------------- delp ------------------------------
const DelP = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	base: pd.Timer,
	clock: *pd.Clock,
	o_time: *pd.Outlet,
	deltime: f64,
	settime: f64,
	setmore: f64,

	fn timeout(self: *const Self) void {
		self.base.obj.out.bang();
	}

	fn delay(self: *Self, f: pd.Float) void {
		self.setmore -= f;
		if (!self.base.pause.state) {
			self.clock.unset();
			self.setmore += self.base.time_since(self.settime);
			self.settime = pd.getLogicalTime();
			if (self.setmore < 0) {
				self.clock.delay(-self.setmore);
			}
		}
	}

	fn time(self: *Self) void {
		const result = self.setmore + if (self.base.pause.state) 0 else
			self.base.time_since(self.settime);
		self.o_time.float(@floatCast(result));
	}

	fn pause(self: *Self, _: ?*pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		if (!self.base.tgl_pause(av[0..ac])) {
			return;
		}

		if (self.base.pause.state) {
			self.clock.unset();
			self.setmore += self.base.time_since(self.settime);
		} else {
			self.settime = pd.getLogicalTime();
			if (self.setmore < 0) {
				self.clock.delay(-self.setmore);
			}
		}
	}

	fn stop(self: *Self) void {
		var a = pd.Atom{ .type = A.FLOAT, .w = .{ .float = 1 } };
		self.pause(null, 1, @ptrCast(&a));
	}

	fn tempo(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		if (!self.base.pause.state) {
			self.setmore += self.base.time_since(self.settime);
			self.settime = pd.getLogicalTime();
		}
		self.base.parse_units(av[0..ac]);
		self.clock.setUnit(self.base.unit, self.base.samps);
	}

	fn ft1(self: *Self, f: pd.Float) void {
		self.deltime = @max(0, f);
	}

	inline fn reset(self: *Self, paused: bool) void {
		self.base.set_pause(paused);
		if (paused) {
			self.clock.unset();
		} else {
			self.clock.delay(self.deltime);
		}
		self.settime = pd.getLogicalTime();
		self.setmore = -self.deltime;
	}

	fn bang(self: *Self) void {
		self.reset(false);
	}

	fn float(self: *Self, f: pd.Float) void {
		self.deltime = @max(0, f);
		self.reset(false);
	}

	fn list(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		if (ac >= 1 and av[0].type == A.FLOAT) {
			self.ft1(av[0].w.float);
		}
		self.reset(ac >= 2 and av[1].type == A.FLOAT and av[1].w.float == 1);
	}

	fn anything(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		self.reset(ac >= 1 and av[0].type == A.FLOAT and av[0].w.float == 1);
	}

	fn new(_: *pd.Symbol, argc: u32, argv: [*]pd.Atom) *Self {
		const self: *Self = @ptrCast(class.new());
		const obj = &self.base.obj;
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.symbol("ft1"));
		_ = obj.outlet(pd.s.bang);
		self.o_time = obj.outlet(pd.s.float);

		self.clock = pd.clock(self, @ptrCast(&timeout));
		self.settime = pd.getLogicalTime();

		var ac = argc;
		var av = argv;
		if (ac >= 1 and av[0].type == A.FLOAT) {
			self.ft1(av[0].w.float);
			ac -= 1;
			av += 1;
		}
		self.base.init(av[0..ac]);
		self.clock.setUnit(self.base.unit, self.base.samps);
		return self;
	}

	fn free(self: *const Self) void {
		self.clock.free();
	}

	fn setup() void {
		class = pd.class(pd.symbol("delp"), @ptrCast(&new), @ptrCast(&free),
			@sizeOf(Self), pd.Class.DEFAULT, A.GIMME, A.NULL);

		class.addBang(@ptrCast(&bang));
		class.addFloat(@ptrCast(&float));
		class.addList(@ptrCast(&list));
		class.addAnything(@ptrCast(&anything));
		class.addMethod(@ptrCast(&stop), pd.symbol("stop"), 0);
		class.addMethod(@ptrCast(&time), pd.symbol("time"), 0);
		class.addMethod(@ptrCast(&ft1), pd.symbol("ft1"), A.FLOAT, A.NULL);
		class.addMethod(@ptrCast(&delay), pd.symbol("del"), A.FLOAT, A.NULL);
		class.addMethod(@ptrCast(&delay), pd.symbol("delay"), A.FLOAT, A.NULL);
		class.addMethod(@ptrCast(&pause), pd.symbol("pause"), A.GIMME, A.NULL);
		class.addMethod(@ptrCast(&tempo), pd.symbol("tempo"), A.GIMME, A.NULL);
	}
};

export fn delp_setup() void {
	DelP.setup();
}
