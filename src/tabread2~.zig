const pd = @import("pd");
const tb = @import("tab2.zig");

const Atom = pd.Atom;
const Float = pd.Float;
const Sample = pd.Sample;
const Symbol = pd.Symbol;

const TabRead2 = extern struct {
	obj: pd.Object = undefined,
	tab2: tb.Tab2,
	onset: Float = 0,
	len: usize = 0,

	const name = "tabread2~";
	pub var class: *pd.Class = undefined;

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
			const fint: i64 = @intFromFloat(findex);
			var index: usize = undefined;
			var frac: Sample = undefined;
			if (fint < 0) {
				index = 0;
				frac = 0;
			} else if (fint > maxindex) {
				index = maxindex;
				frac = 1;
			} else {
				index = @intCast(fint);
				frac = @floatCast(findex - @as(f64, @floatFromInt(fint)));
			}
			o.* = tb.sample(vec + index, frac, in2);
		}
		return w + 6;
	}

	fn setC(self: *TabRead2, s: *Symbol) callconv(.c) void {
		self.len = self.set(s) catch |e| {
			pd.post.err(self, "%s: %s", .{ s.name, @errorName(e).ptr });
			return;
		};
	}
	inline fn set(self: *TabRead2, s: *Symbol) !usize {
		errdefer self.tab2.vec = null;
		self.tab2.arrayname = s;

		const array: *pd.GArray = @ptrCast(pd.garray_class.find(s)
			orelse return error.GArrayNotFound);

		const vec = try array.floatWords();
		self.tab2.vec = vec.ptr;
		array.useInDsp();
		return @intCast(vec.len);
	}

	fn dspC(self: *TabRead2, sp: [*]*pd.Signal) callconv(.c) void {
		self.setC(self.tab2.arrayname);
		pd.dsp.add(&performC, .{ self, sp[2].len, sp[2].vec, sp[1].vec, sp[0].vec });
	}

	fn initC(_: *pd.Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*TabRead2 {
		return pd.wrap(*TabRead2, init(av[0..ac]), name);
	}
	inline fn init(av: []const Atom) !*TabRead2 {
		const self: *TabRead2 = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer self.obj.g.pd.deinit();

		const arrayname = try pd.symbolArg(0, av);
		const tab2: tb.Tab2 = try .init(obj, arrayname, pd.floatArg(1, av) catch 0);

		_ = try obj.inletFloat(&self.onset);
		self.* = .{ .tab2 = tab2 };
		return self;
	}

	inline fn setup() !void {
		class = try .init(TabRead2, name, &.{ .gimme }, &initC, null, .{});
		tb.Impl(TabRead2).extend();
		class.addMethod(@ptrCast(&dspC), .gen("dsp"), &.{ .cant });
		class.addMethod(@ptrCast(&setC), .gen("set"), &.{ .symbol });
	}
};

export fn tabread2_tilde_setup() void {
	_ = pd.wrap(void, TabRead2.setup(), @src().fn_name);
}
