//! `[delay]` with pause/resume functionality.

const DelP = @This();
const pd = @import("pd");
const Timer = @import("timer.zig");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Outlet = pd.Outlet;
const Symbol = pd.Symbol;

tmr: Timer,
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
const Box = pd.Box(pd.Object, DelP);

fn timeoutC(self: *const DelP) callconv(.c) void {
	self.out_b.bang();
}

fn delayC(p: *Pd, f: pd.Float) callconv(.c) void {
	const self = Box.state(p);
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

fn timeC(p: *const Pd) callconv(.c) void {
	const self = Box.stateConst(p);
	const result = self.setmore + if (self.tmr.paused)
		0 else self.tmr.timeSince(self.settime);
	self.out_f.float(@floatCast(result));
}

fn pauseC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	const self = Box.state(p);
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

fn stopC(p: *Pd) callconv(.c) void {
	pauseC(p, pd.s.empty(), 1, &.{ .float(1) });
}

fn tempoC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	const self = Box.state(p);
	if (!self.tmr.paused) {
		self.setmore += self.tmr.timeSince(self.settime);
		self.settime = pd.time();
	}
	self.tmr.parseUnits(av[0..ac])
		catch |e| pd.post.err(p, name ++ ": %s", .{ @errorName(e).ptr });
	self.clock.setUnit(self.tmr.unit);
}

fn ft1C(p: *Pd, f: pd.Float) callconv(.c) void {
	Box.state(p).deltime = @max(0, f);
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

fn bangC(p: *Pd) callconv(.c) void {
	Box.state(p).reset(false);
}

fn floatC(p: *Pd, f: pd.Float) callconv(.c) void {
	const self = Box.state(p);
	self.deltime = @max(0, f);
	self.reset(false);
}

fn listC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	const self = Box.state(p);
	const a = av[0..ac];
	if (pd.floatArg(0, a)) |f| {
		ft1C(p, f);
	} else |_| {}
	self.reset((pd.floatArg(1, a) catch 0) != 0);
}

fn anythingC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	Box.state(p).reset((pd.floatArg(0, av[0..ac]) catch 0) != 0);
}

fn createC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
	return pd.wrap(*Pd, create(av[0..ac]), name);
}
inline fn create(av: []const Atom) (pd.Oom || pd.TimeUnit.Error)!*Pd {
	const obj: *pd.Object = @ptrCast(try class.pd());
	const self = Box.state(&obj.g.pd);
	errdefer obj.g.pd.destroy();

	_ = try obj.inlet(&obj.g.pd, pd.s.float(), .gen("ft1"));
	const out_b: *Outlet = try .create(obj, pd.s.bang());
	const out_f: *Outlet = try .create(obj, pd.s.float());

	var clock: *pd.Clock = try .create(DelP, self, timeoutC);
	errdefer clock.destroy();

	var a = av;
	const settime = pd.time();
	const deltime = if (a.len >= 1 and a[0].type == .float) blk: {
		a = a[1..];
		break :blk @max(0, av[0].w.float);
	} else 0;

	const tmr: Timer = try .init(obj, a);
	clock.setUnit(tmr.unit);

	self.* = .{
		.out_b = out_b,
		.out_f = out_f,
		.clock = clock,
		.deltime = deltime,
		.settime = settime,
		.tmr = tmr,
	};
	return &obj.g.pd;
}

fn destroyC(p: *const Pd) callconv(.c) void {
	 Box.stateConst(p).clock.destroy();
}

inline fn setup() pd.Class.Error!void {
	class = try .create(name, &.{ .gimme }, createC, destroyC, @sizeOf(Box), .{});
	class.addBang(bangC);
	class.addFloat(floatC);
	class.addList(listC);
	class.addAnything(anythingC);
	class.addMethod(&.{}, stopC, .gen("stop"));
	class.addMethod(&.{}, timeC, .gen("time"));
	class.addMethod(&.{ .float }, ft1C, .gen("ft1"));
	class.addMethod(&.{ .float }, delayC, .gen("del"));
	class.addMethod(&.{ .float }, delayC, .gen("delay"));
	class.addMethod(&.{ .gimme }, pauseC, .gen("pause"));
	class.addMethod(&.{ .gimme }, tempoC, .gen("tempo"));
}

export fn delp_setup() void {
	_ = pd.wrap(void, setup(), @src().fn_name);
}
