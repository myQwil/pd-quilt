//! Timer with pause and lap features.

const pd = @import("pd");
const tm = @import("timer.zig");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Symbol = pd.Symbol;

const Chrono = extern struct {
	obj: pd.Object,
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
	const parentPtr = pd.parentPtr(Chrono);
	const parentConstPtr = pd.parentConstPtr(Chrono);

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

	fn delayC(p: *Pd, f: pd.Float) callconv(.c) void {
		parentPtr(p).setmore -= f;
	}

	fn bangC(p: *Pd) callconv(.c) void {
		parentPtr(p).reset(false);
	}

	fn floatC(p: *Pd, f: pd.Float) callconv(.c) void {
		parentPtr(p).reset(false);
		delayC(p, f);
	}

	fn listC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const a = av[0..ac];
		parentPtr(p).reset((pd.floatArg(1, a) catch 0) != 0);
		if (pd.floatArg(0, a)) |f| {
			delayC(p, f);
		} else |_| {}
	}

	fn bang2C(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		const result = self.setmore + if (self.timer.paused)
			0 else self.timer.timeSince(self.settime);
		self.out_total.float(@floatCast(result));
	}

	fn lapC(p: *Pd) callconv(.c) void {
		const self = parentPtr(p);
		const result = self.lapmore + if (self.timer.paused)
			0 else self.timer.timeSince(self.laptime);
		self.out_lap.float(@floatCast(result));
		self.laptime = pd.time();
		self.lapmore = 0;
	}

	fn pauseC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = parentPtr(p);
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

	fn tempoC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = parentPtr(p);
		if (!self.timer.paused) {
			self.setmore += self.timer.timeSince(self.settime);
			self.lapmore += self.timer.timeSince(self.laptime);
			self.setTime();
		}
		self.timer.parseUnits(av[0..ac])
			catch |e| pd.post.err(self, name ++ ": %s", .{ @errorName(e).ptr });
	}

	fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(av[0..ac]), name);
	}
	inline fn init(av: []const Atom) !*Pd {
		const self: *Chrono = try pd.gpa.create(Chrono);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		const settime = pd.time();
		_ = try obj.inlet(&obj.g.pd, pd.s.bang(), .gen("bang2"));
		self.* = .{
			.obj = self.obj,
			.out_total = try .init(obj, pd.s.float()),
			.out_lap = try .init(obj, pd.s.float()),
			.timer = try .init(obj, av),
			.settime = settime,
			.laptime = settime,
		};
		return &obj.g.pd;
	}

	inline fn setup() !void {
		class = try .init(Chrono, name, &.{ .gimme }, initC, null, .{});
		class.addBang(bangC);
		class.addFloat(floatC);
		class.addList(listC);
		class.addMethod(&.{}, lapC, .gen("lap"));
		class.addMethod(&.{}, bang2C, .gen("bang2"));
		class.addMethod(&.{ .float }, delayC, .gen("del"));
		class.addMethod(&.{ .float }, delayC, .gen("delay"));
		class.addMethod(&.{ .gimme }, pauseC, .gen("pause"));
		class.addMethod(&.{ .gimme }, tempoC, .gen("tempo"));
	}
};

export fn chrono_setup() void {
	_ = pd.wrap(void, Chrono.setup(), @src().fn_name);
}
