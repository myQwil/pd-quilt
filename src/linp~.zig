//! `[line~]` with pause/resume functionality.

const LinPSignal = @This();
const pd = @import("pd");
const tg = @import("toggle.zig");

const Pd = pd.Pd;
const Sample = pd.Sample;
const Float = pd.Float;

o_pause: *pd.Outlet,
target: Sample = 0,
value: Sample = 0,
biginc: Sample = 0,
inc: Sample = 0,
invn: Float = 0,
dspticktomsec: Float = 0,
inletvalue: Float = 0,
inletwas: Float = 0,
ticksleft: u32 = 0,
retarget: bool = false,
paused: bool = false,

const name = "linp~";
var class: *pd.Class = undefined;
const Box = pd.Box(pd.Object, LinPSignal);

fn tglPause(self: *LinPSignal, av: []const pd.Atom) bool {
	const changed = tg.toggle(&self.paused, av);
	if (changed) {
		self.o_pause.float(@floatFromInt(@intFromBool(self.paused)));
	}
	return changed;
}

fn performC(w: [*]usize) callconv(.c) [*]usize {
	const self: *LinPSignal = @ptrFromInt(w[1]);
	const out = @as([*]Sample, @ptrFromInt(w[3]))[0..w[2]];

	if (pd.bigOrSmall(self.value)) {
		self.value = 0;
	}
	if (self.retarget) {
		const nticks = @max(1,
			@as(u32, @intFromFloat(self.inletwas * self.dspticktomsec)));
		self.ticksleft = nticks;
		self.biginc = (self.target - self.value)
			/ @as(Sample, @floatFromInt(nticks));
		self.inc = self.invn * self.biginc;
		self.retarget = false;
	}

	if (!self.paused) {
		if (self.ticksleft > 0) {
			var f = self.value;
			for (out) |*o| {
				o.* = f;
				f += self.inc;
			}
			self.value += self.biginc;
			self.ticksleft -= 1;
			return w + 4;
		} else {
			self.value = self.target;
		}
	}
	@memset(out, self.value);
	return w + 4;
}

fn dspC(p: *Pd, sp: [*]*pd.Signal) callconv(.c) void {
	const self = Box.state(p);
	pd.dsp.add(performC, .{ self, sp[0].len, sp[0].vec });
	self.invn = 1 / @as(Float, @floatFromInt(sp[0].len));
	self.dspticktomsec = sp[0].srate
		/ @as(Float, @floatFromInt(1000 * sp[0].len));
}

fn stopC(p: *Pd) callconv(.c) void {
	const self = Box.state(p);
	self.target = self.value;
	self.ticksleft = 0;
	self.retarget = false;
}

fn pauseC(p: *Pd, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) callconv(.c) void {
	_ = Box.state(p).tglPause(av[0..ac]);
}

fn floatC(p: *Pd, f: Float) callconv(.c) void {
	const self = Box.state(p);
	if (self.inletvalue <= 0) {
		self.target = f;
		self.value = f;
		self.ticksleft = 0;
		self.retarget = false;
	} else {
		self.target = f;
		self.inletwas = self.inletvalue;
		self.inletvalue = 0;
		self.retarget = true;
		if (tg.set(&self.paused, false)) {
			self.o_pause.float(@floatFromInt(@intFromBool(self.paused)));
		}
	}
}

fn createC() callconv(.c) ?*Pd {
	return pd.wrap(*Pd, create(), name);
}
inline fn create() pd.Oom!*Pd {
	const obj: *pd.Object = @ptrCast(try class.pd());
	const self = Box.state(&obj.g.pd);
	errdefer obj.g.pd.destroy();

	_ = try obj.inletFloat(&self.inletvalue);
	_ = try obj.outlet(pd.s.signal());

	self.* = .{ .o_pause = try .create(obj, pd.s.float()) };
	return &obj.g.pd;
}

inline fn setup() pd.Class.Error!void {
	class = try .create(name, &.{}, createC, null, @sizeOf(Box), .{});
	class.addFloat(floatC);
	class.addMethod(&.{}, stopC, .gen("stop"));
	class.addMethod(&.{ .cant }, dspC, .gen("dsp"));
	class.addMethod(&.{ .gimme }, pauseC, .gen("pause"));
}

export fn linp_tilde_setup() void {
	_ = pd.wrap(void, setup(), @src().fn_name);
}
