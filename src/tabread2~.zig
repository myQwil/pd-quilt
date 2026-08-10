//! Linear interpolating table lookup.
//! Uses the largest power of 2 + 1 points in an array and ignores leftovers.

const pd = @import("pd");
const tb = @import("tab2.zig");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Float = pd.Float;
const Sample = pd.Sample;
const Symbol = pd.Symbol;

const TabRead2 = extern struct {
	obj: pd.Object,
	tab2: tb.Tab2,
	onset: Float = 0,
	len: u32 = 0,

	const name = "tabread2~";
	pub var class: *pd.Class = undefined;
	pub const parentPtr = pd.parentPtr(TabRead2);

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
			const ffloor: f64 = @trunc(findex);
			var index: u32 = undefined;
			var frac: Sample = undefined;
			if (ffloor < 0) {
				index = 0;
				frac = 0;
			} else if (ffloor > maxindex) {
				index = maxindex;
				frac = 1;
			} else {
				index = @intFromFloat(ffloor);
				frac = @floatCast(findex - ffloor);
			}
			o.* = tb.sample(vec + index, frac, in2);
		}
		return w + 6;
	}

	fn setC(p: *Pd, s: *Symbol) callconv(.c) void {
		const self = parentPtr(p);
		self.len = self.set(s) catch |e| {
			pd.post.err(self, "%s: %s", .{ s.name, @errorName(e).ptr });
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
		const self = parentPtr(p);
		setC(p, self.tab2.arrayname);
		pd.dsp.add(performC, .{ self, sp[2].len, sp[2].vec, sp[1].vec, sp[0].vec });
	}

	fn initC(_: *pd.Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(av[0..ac]), name);
	}
	inline fn init(av: []const Atom) (pd.Oom || pd.ArgError)!*Pd {
		const self: *TabRead2 = try pd.gpa.create(TabRead2);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer self.obj.g.pd.deinit();

		const arrayname = try pd.symbolArg(0, av);
		const tab2: tb.Tab2 = try .init(obj, arrayname, pd.floatArg(1, av) catch 0);

		_ = try obj.inletFloat(&self.onset);
		self.* = .{
			.obj = self.obj,
			.tab2 = tab2,
		};
		return &obj.g.pd;
	}

	inline fn setup() pd.Class.Error!void {
		class = try .init(TabRead2, name, &.{ .gimme }, initC, null, .{});
		tb.Impl(TabRead2).extend();
		class.addMethod(&.{ .cant }, dspC, .gen("dsp"));
		class.addMethod(&.{ .symbol }, setC, .gen("set"));
	}
};

export fn tabread2_tilde_setup() void {
	_ = pd.wrap(void, TabRead2.setup(), @src().fn_name);
}
