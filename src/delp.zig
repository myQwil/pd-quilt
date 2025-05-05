const pd = @import("pd");
const tm = @import("timer.zig");

const Atom = pd.Atom;
const Outlet = pd.Outlet;
const Symbol = pd.Symbol;

const DelP = extern struct {
	obj: pd.Object = undefined,
	tmr: tm.Timer,
	/// sends bang when delay time has passed
	out_b: *Outlet,
	/// sends time relative to when bang occurs
	out_f: *Outlet,
	clock: *pd.Clock,
	deltime: f64,
	settime: f64,
	setmore: f64 = 0,

	const name = "delp";
	var class: *pd.Class = undefined;

	fn timeoutC(self: *const DelP) callconv(.c) void {
		self.out_b.bang();
	}

	fn delayC(self: *DelP, f: pd.Float) callconv(.c) void {
		self.setmore -= f;
		if (!self.tmr.paused) {
			self.clock.unset();
			self.setmore += self.tmr.timeSince(self.settime);
			self.settime = pd.time();
			if (self.setmore < 0) {
				self.clock.delay(-self.setmore);
			}
		}
	}

	fn timeC(self: *const DelP) callconv(.c) void {
		const result = self.setmore + if (self.tmr.paused)
			0 else self.tmr.timeSince(self.settime);
		self.out_f.float(@floatCast(result));
	}

	fn pauseC(
		self: *DelP,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		if (!self.tmr.tglPause(av[0..ac])) {
			return;
		}

		if (self.tmr.paused) {
			self.clock.unset();
			self.setmore += self.tmr.timeSince(self.settime);
		} else {
			self.settime = pd.time();
			if (self.setmore < 0) {
				self.clock.delay(-self.setmore);
			}
		}
	}

	fn stopC(self: *DelP) callconv(.c) void {
		self.pauseC(&pd.s_, 1, &.{ .float(1) });
	}

	fn tempoC(
		self: *DelP,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		if (!self.tmr.paused) {
			self.setmore += self.tmr.timeSince(self.settime);
			self.settime = pd.time();
		}
		self.tmr.parseUnits(av[0..ac]);
		self.clock.setUnit(self.tmr.unit, self.tmr.in_samples);
	}

	fn ft1C(self: *DelP, f: pd.Float) callconv(.c) void {
		self.deltime = @max(0, f);
	}

	fn reset(self: *DelP, paused: bool) void {
		self.tmr.setPause(paused);
		if (paused) {
			self.clock.unset();
		} else {
			self.clock.delay(self.deltime);
		}
		self.settime = pd.time();
		self.setmore = -self.deltime;
	}

	fn bangC(self: *DelP) callconv(.c) void {
		self.reset(false);
	}

	fn floatC(self: *DelP, f: pd.Float) callconv(.c) void {
		self.deltime = @max(0, f);
		self.reset(false);
	}

	fn listC(
		self: *DelP,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		const a = av[0..ac];
		if (pd.floatArg(0, a)) |f| {
			self.ft1C(f);
		} else |_| {}
		self.reset((pd.floatArg(1, a) catch 0) != 0);
	}

	fn anythingC(
		self: *DelP,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		self.reset((pd.floatArg(0, av[0..ac]) catch 0) != 0);
	}

	fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*DelP {
		return pd.wrap(*DelP, init(av[0..ac]), name);
	}
	inline fn init(av: []const Atom) !*DelP {
		const self: *DelP = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inlet(&obj.g.pd, &pd.s_float, .gen("ft1"));
		const out_b: *Outlet = try .init(obj, &pd.s_bang);
		const out_f: *Outlet = try .init(obj, &pd.s_float);

		var clock: *pd.Clock = try .init(self, @ptrCast(&timeoutC));
		errdefer clock.deinit();

		var a = av;
		const settime = pd.time();
		const deltime = if (a.len >= 1 and a[0].type == .float) blk: {
			a = a[1..];
			break :blk @max(0, av[0].w.float);
		} else 0;

		const tmr: tm.Timer = try .init(obj, a);
		clock.setUnit(tmr.unit, tmr.in_samples);

		self.* = .{
			.out_b = out_b,
			.out_f = out_f,
			.clock = clock,
			.deltime = deltime,
			.settime = settime,
			.tmr = tmr,
		};
		return self;
	}

	fn deinitC(self: *const DelP) callconv(.c) void {
		self.clock.deinit();
	}

	inline fn setup() !void {
		class = try .init(DelP, name, &.{ .gimme }, &initC, &deinitC, .{});
		class.addBang(@ptrCast(&bangC));
		class.addFloat(@ptrCast(&floatC));
		class.addList(@ptrCast(&listC));
		class.addAnything(@ptrCast(&anythingC));
		class.addMethod(@ptrCast(&stopC), .gen("stop"), &.{});
		class.addMethod(@ptrCast(&timeC), .gen("time"), &.{});
		class.addMethod(@ptrCast(&ft1C), .gen("ft1"), &.{ .float });
		class.addMethod(@ptrCast(&delayC), .gen("del"), &.{ .float });
		class.addMethod(@ptrCast(&delayC), .gen("delay"), &.{ .float });
		class.addMethod(@ptrCast(&pauseC), .gen("pause"), &.{ .gimme });
		class.addMethod(@ptrCast(&tempoC), .gen("tempo"), &.{ .gimme });
	}
};

export fn delp_setup() void {
	_ = pd.wrap(void, DelP.setup(), @src().fn_name);
}
