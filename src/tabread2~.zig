//! Linear interpolating table lookup.
//! Uses the largest power of 2 + 1 points in an array and ignores leftovers.

const TabRead2 = @This();
const pd = @import("pd");
const Tab2 = @import("tab2.zig");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Float = pd.Float;
const Sample = pd.Sample;
const Symbol = pd.Symbol;

tab2: Tab2,
onset: Float = 0,
len: u32 = 0,

const name = "tabread2~";
pub var class: *pd.Class = undefined;
pub const Box = pd.Box(pd.Object, TabRead2);

fn performC(w: [*]usize) callconv(.c) [*]usize {
	const self: *TabRead2 = @ptrFromInt(w[1]);
	const out = @as([*]Sample, @ptrFromInt(w[3]))[0..w[2]];
	if (self.tab2.vec == null or self.len < 2) {
		@memset(out, 0);
		return w + 6;
	}
	const maxindex = self.len - 2;
	const vec = self.tab2.vec.?;
	const onset = self.onset;

	const inlet2: [*]Sample = @ptrFromInt(w[4]);
	const inlet1: [*]Sample = @ptrFromInt(w[5]);
	for (out, inlet1, inlet2) |*o, in1, in2| {
		const findex: f64 = in1 + onset;
		const ftrunc: f64 = @trunc(findex);
		const index: u32, const frac: Sample = if (ftrunc < 0)
			.{ 0, 0 }
		else if (ftrunc > maxindex)
			.{ maxindex, 1 }
		else
			.{ @intFromFloat(ftrunc), @floatCast(findex - ftrunc) };
		o.* = Tab2.sample(vec + index, frac, in2);
	}
	return w + 6;
}

fn setC(p: *Pd, s: *Symbol) callconv(.c) void {
	const self = Box.state(p);
	self.len = self.set(s) catch |e| {
		pd.post.err(p, "%s: %s", .{ s.name, @errorName(e).ptr });
		return;
	};
}
inline fn set(self: *TabRead2, s: *Symbol) pd.GArray.GetError!u32 {
	errdefer self.tab2.vec = null;
	self.tab2.arrayname = s;

	const array: *pd.GArray = if (pd.garray_class.find(s)) |ga| @ptrCast(ga)
		else return error.GArrayNotFound;

	const vec = try array.floatWords();
	self.tab2.vec = vec.ptr;
	array.useInDsp();
	return @truncate(vec.len);
}

fn dspC(p: *Pd, sp: [*]*pd.Signal) callconv(.c) void {
	const self = Box.state(p);
	setC(p, self.tab2.arrayname);
	pd.dsp.add(performC, .{ self, sp[2].len, sp[2].vec, sp[1].vec, sp[0].vec });
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

	_ = try obj.inletFloat(&self.onset);
	self.* = .{ .tab2 = tab2 };
	return &obj.g.pd;
}

inline fn setup() pd.Class.Error!void {
	class = try .create(name, &.{ .gimme }, createC, null, @sizeOf(Box), .{});
	Tab2.Impl(TabRead2).extend();
	class.addMethod(&.{ .cant }, dspC, .gen("dsp"));
	class.addMethod(&.{ .symbol }, setC, .gen("set"));
}

export fn tabread2_tilde_setup() void {
	_ = pd.wrap(void, setup(), @src().fn_name);
}
