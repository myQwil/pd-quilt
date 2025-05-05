const pd = @import("pd");
const tm = @import("timer.zig");

const Atom = pd.Atom;
const Symbol = pd.Symbol;

const Chrono = extern struct {
	obj: pd.Object = undefined,
	timer: tm.Timer,
	/// outputs total duration
	out_total: *pd.Outlet,
	/// outputs lap duration
	out_lap: *pd.Outlet,
	settime: f64,
	laptime: f64,
	setmore: f64 = 0,
	lapmore: f64 = 0,

	const name = "chrono";
	var class: *pd.Class = undefined;

	fn setTime(self: *Chrono) void {
		self.settime = pd.time();
		self.laptime = self.settime;
	}

	fn reset(self: *Chrono, paused: bool) void {
		self.timer.setPause(paused);
		self.setTime();
		self.setmore = 0;
		self.lapmore = 0;
	}

	fn delayC(self: *Chrono, f: pd.Float) callconv(.c) void {
		self.setmore -= f;
	}

	fn bangC(self: *Chrono) callconv(.c) void {
		self.reset(false);
	}

	fn floatC(self: *Chrono, f: pd.Float) callconv(.c) void {
		self.reset(false);
		self.delayC(f);
	}

	fn listC(
		self: *Chrono,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		const a = av[0..ac];
		self.reset((pd.floatArg(1, a) catch 0) == 1);
		if (pd.floatArg(0, a)) |f| {
			self.delayC(f);
		} else |_| {}
	}

	fn bang2C(self: *const Chrono) callconv(.c) void {
		const result = self.setmore + if (self.timer.paused)
			0 else self.timer.timeSince(self.settime);
		self.out_total.float(@floatCast(result));
	}

	fn lapC(self: *Chrono) callconv(.c) void {
		const result = self.lapmore + if (self.timer.paused)
			0 else self.timer.timeSince(self.laptime);
		self.out_lap.float(@floatCast(result));
		self.laptime = pd.time();
		self.lapmore = 0;
	}

	fn pauseC(
		self: *Chrono,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		if (!self.timer.tglPause(av[0..ac])) {
			return;
		}

		if (self.timer.paused) {
			self.setmore += self.timer.timeSince(self.settime);
			self.lapmore += self.timer.timeSince(self.laptime);
		} else {
			self.setTime();
		}
	}

	fn tempoC(
		self: *Chrono,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		if (!self.timer.paused) {
			self.setmore += self.timer.timeSince(self.settime);
			self.lapmore += self.timer.timeSince(self.laptime);
			self.setTime();
		}
		self.timer.parseUnits(av[0..ac]);
	}

	fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Chrono {
		return pd.wrap(*Chrono, init(av[0..ac]), name);
	}
	inline fn init(av: []const Atom) !*Chrono {
		const self: *Chrono = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		const settime = pd.time();
		_ = try obj.inlet(&obj.g.pd, &pd.s_bang, .gen("bang2"));
		self.* = .{
			.out_total = try .init(obj, &pd.s_float),
			.out_lap = try .init(obj, &pd.s_float),
			.timer = try .init(obj, av),
			.settime = settime,
			.laptime = settime,
		};
		return self;
	}

	inline fn setup() !void {
		class = try .init(Chrono, name, &.{ .gimme }, &initC, null, .{});
		class.addBang(@ptrCast(&bangC));
		class.addFloat(@ptrCast(&floatC));
		class.addList(@ptrCast(&listC));
		class.addMethod(@ptrCast(&lapC), .gen("lap"), &.{});
		class.addMethod(@ptrCast(&bang2C), .gen("bang2"), &.{});
		class.addMethod(@ptrCast(&delayC), .gen("del"), &.{ .float });
		class.addMethod(@ptrCast(&delayC), .gen("delay"), &.{ .float });
		class.addMethod(@ptrCast(&pauseC), .gen("pause"), &.{ .gimme });
		class.addMethod(@ptrCast(&tempoC), .gen("tempo"), &.{ .gimme });
	}
};

export fn chrono_setup() void {
	_ = pd.wrap(void, Chrono.setup(), @src().fn_name);
}
