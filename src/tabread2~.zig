const pd = @import("pd");
const h = @import("tab2.zig");

const TabRead2 = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	base: h.Tab2,
	onset: pd.Float,
	len: usize,

	fn perform(w: [*]usize) *usize {
		const self: *Self = @ptrFromInt(w[1]);
		const out = @as([*]pd.Sample, @ptrFromInt(w[3]))[0..w[2]];
		const vec = self.base.vec orelse {
			for (out) |*o| {
				o.* = 0;
			}
			return &w[6];
		};
		const onset = self.onset;
		const len = self.len;

		const inlet2: [*]pd.Sample = @ptrFromInt(w[4]);
		const inlet1: [*]pd.Sample = @ptrFromInt(w[5]);
		for (out, inlet1, inlet2) |*o, in1, in2| {
			const findex: f64 = in1 + onset;
			var i: usize = @intFromFloat(findex);
			const frac: pd.Sample = blk: {
				if (i < 0) {
					i = 0;
					break :blk 0;
				} else if (i >= len) {
					i = len - 1;
					break :blk 1;
				}
				break :blk @floatCast(findex - @as(f64, @floatFromInt(i)));
			};
			o.* = h.Tab2.sample(vec + i, frac, in2);
		}
		return &w[6];
	}

	fn set(self: *Self, s: *pd.Symbol) void {
		self.len = self.base.setArray(s) catch return;
	}

	fn dsp(self: *Self, sp: [*]*pd.Signal) void {
		self.set(self.base.arrayname);
		pd.dsp.add(@ptrCast(&perform),
			5, self, sp[2].len, sp[2].vec, sp[1].vec, sp[0].vec);
	}

	fn new(arrayname: *pd.Symbol, hold: pd.Float) ?*Self {
		const self: *Self = @ptrCast(class.new() orelse return null);
		self.base.init(arrayname, hold);

		const obj = &self.base.obj;
		_ = obj.inletFloat(&self.onset);
		self.onset = 0;
		return self;
	}

	fn setup() void {
		class = pd.class(pd.symbol("tabread2~"), @ptrCast(&new), null,
			@sizeOf(Self), .{}, &.{ .defsymbol, .deffloat }).?;

		h.Tab2.extend(class);
		class.addMethod(@ptrCast(&dsp), pd.symbol("dsp"), &.{ .cant });
		class.addMethod(@ptrCast(&set), pd.symbol("set"), &.{ .symbol });
	}
};

export fn tabread2_tilde_setup() void {
	TabRead2.setup();
}
