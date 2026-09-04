//! Linear interpolating table oscillator.
//! Uses the largest power of 2 + 1 points in an array and ignores leftovers.

const TabOsc2 = @This();
const pd = @import("pd");
const Tab2 = @import("tab2.zig");
const tf = @import("tabfudge.zig");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Float = pd.Float;
const Sample = pd.Sample;
const Symbol = pd.Symbol;

const unitbit32 = tf.unitbit32;
const hioffset = tf.hioffset;

tab2: Tab2,
phase: f64 = 0,
conv: Float = 0,
len: Float = default_len,
invlen: Float = 1.0 / default_len,

const name = "tabosc2~";
const default_len = 512.0;
pub var class: *pd.Class = undefined;
pub const Box = pd.Box(pd.Object, TabOsc2);

fn performC(w: [*]usize) callconv(.c) [*]usize {
	const self: *TabOsc2 = @ptrFromInt(w[1]);
	const out = @as([*]Sample, @ptrFromInt(w[3]))[0..w[2]];
	const vec = self.tab2.vec orelse {
		@memset(out, 0);
		return w + 6;
	};
	const len = self.len;
	const mask = @as(u32, @intFromFloat(len)) - 1;
	const conv = len * self.conv;
	var dphase = len * self.phase + unitbit32;

	var t: tf.TabFudge = .{ .d = unitbit32 };
	var normhipart = t.i[hioffset];

	const inlet2: [*]Sample = @ptrFromInt(w[4]);
	const inlet1: [*]Sample = @ptrFromInt(w[5]);
	for (out, inlet1, inlet2) |*o, in1, in2| {
		t.d = dphase;
		dphase += in1 * conv;
		const i: u32 = t.i[hioffset] & mask;
		t.i[hioffset] = normhipart;
		o.* = Tab2.sample(vec + i, @floatCast(t.d - unitbit32), in2);
	}

	t.d = unitbit32 * len;
	normhipart = t.i[hioffset];
	t.d = dphase + unitbit32 * (len - 1);
	t.i[hioffset] = normhipart;
	self.phase = (t.d - unitbit32 * len) * self.invlen;
	return w + 6;
}

fn setC(p: *Pd, s: *Symbol) callconv(.c) void {
	const self = Box.state(p);
	const len = self.set(s) catch |e| {
		pd.post.err(p, "%s: %s", .{ s.name, @errorName(e).ptr });
		return;
	};
	self.len = @floatFromInt(len);
	self.invlen = 1.0 / self.len;
}
const SetError = pd.GArray.GetError || error{BadArraySize};
inline fn set(self: *TabOsc2, s: *Symbol) SetError!u32 {
	errdefer self.tab2.vec = null;
	self.tab2.arrayname = s;

	const array: *pd.GArray = if (pd.garray_class.find(s)) |ga| @ptrCast(ga)
		else return error.GArrayNotFound;

	const vec = try array.floatWords();
	if (vec.len < 2) {
		return error.BadArraySize;
	}

	self.tab2.vec = vec.ptr;
	array.useInDsp();
	return @truncate(@as(usize, 1) << pd.ulog2(vec.len - 1).?);
}

fn dspC(p: *Pd, sp: [*]*pd.Signal) callconv(.c) void {
	const self = Box.state(p);
	self.conv = 1.0 / sp[0].srate;
	setC(p, self.tab2.arrayname);
	pd.dsp.add(performC, .{ self, sp[2].len, sp[2].vec, sp[1].vec, sp[0].vec });
}

fn ft1C(p: *Pd, f: Float) callconv(.c) void {
	Box.state(p).phase = f;
}

fn createC(_: *pd.Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
	return pd.wrap(*Pd, create(av[0..ac]), name);
}
inline fn create(av: []const Atom) (pd.Oom || pd.ArgError)!*Pd {
	const obj: *pd.Object = @ptrCast(try class.pd());
	const self = Box.state(&obj.g.pd);
	errdefer obj.g.pd.destroy();

	const arrayname = try pd.symbolArg(0, av);
	const tab2: Tab2 = try .init(obj, arrayname, pd.floatArg(1, av) catch 0);

	_ = try obj.inlet(&obj.g.pd, pd.s.float(), .gen("ft1"));
	self.* = .{ .tab2 = tab2 };
	return &obj.g.pd;
}

inline fn setup() pd.Class.Error!void {
	class = try .create(name, &.{ .gimme }, createC, null, @sizeOf(Box), .{});
	Tab2.Impl(TabOsc2).extend();
	class.addMethod(&.{ .cant }, dspC, .gen("dsp"));
	class.addMethod(&.{ .symbol }, setC, .gen("set"));
	class.addMethod(&.{ .float }, ft1C, .gen("ft1"));
}

export fn tabosc2_tilde_setup() void {
	_ = pd.wrap(void, setup(), @src().fn_name);
}
