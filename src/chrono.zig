//! Timer with pause and lap features.

const Chrono = @This();
const pd = @import("pd");
const Timer = @import("timer.zig");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Symbol = pd.Symbol;

timer: Timer,
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
const Box = pd.Box(pd.Object, Chrono);

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
	Box.state(p).setmore -= f;
}

fn bangC(p: *Pd) callconv(.c) void {
	Box.state(p).reset(false);
}

fn floatC(p: *Pd, f: pd.Float) callconv(.c) void {
	Box.state(p).reset(false);
	delayC(p, f);
}

fn listC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	const a = av[0..ac];
	Box.state(p).reset((pd.floatArg(1, a) catch 0) != 0);
	if (pd.floatArg(0, a)) |f| {
		delayC(p, f);
	} else |_| {}
}

fn bang2C(p: *const Pd) callconv(.c) void {
	const self = Box.stateConst(p);
	const result = self.setmore + if (self.timer.paused)
		0 else self.timer.timeSince(self.settime);
	self.out_total.float(@floatCast(result));
}

fn lapC(p: *Pd) callconv(.c) void {
	const self = Box.state(p);
	const result = self.lapmore + if (self.timer.paused)
		0 else self.timer.timeSince(self.laptime);
	self.out_lap.float(@floatCast(result));
	self.laptime = pd.time();
	self.lapmore = 0;
}

fn pauseC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	const self = Box.state(p);
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
	const self = Box.state(p);
	if (!self.timer.paused) {
		self.setmore += self.timer.timeSince(self.settime);
		self.lapmore += self.timer.timeSince(self.laptime);
		self.setTime();
	}
	self.timer.parseUnits(av[0..ac])
		catch |e| pd.post.err(p, name ++ ": %s", .{ @errorName(e).ptr });
}

fn createC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
	return pd.wrap(*Pd, create(av[0..ac]), name);
}
inline fn create(av: []const Atom) (pd.Oom || pd.TimeUnit.Error)!*Pd {
	const obj: *pd.Object = @ptrCast(try class.pd());
	const self = Box.state(&obj.g.pd);
	errdefer obj.g.pd.destroy();

	const settime = pd.time();
	_ = try obj.inlet(&obj.g.pd, pd.s.bang(), .gen("bang2"));
	self.* = .{
		.out_total = try .create(obj, pd.s.float()),
		.out_lap = try .create(obj, pd.s.float()),
		.timer = try .init(obj, av),
		.settime = settime,
		.laptime = settime,
	};
	return &obj.g.pd;
}

inline fn setup() pd.Class.Error!void {
	class = try .create(name, &.{ .gimme }, createC, null, @sizeOf(Box), .{});
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

export fn chrono_setup() void {
	_ = pd.wrap(void, setup(), @src().fn_name);
}
