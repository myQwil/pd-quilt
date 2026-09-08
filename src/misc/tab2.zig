const Tab2 = @This();

const pd = @import("pd");
const Inlet = @import("inlet.zig").Inlet;

const Pd = pd.Pd;
const Float = pd.Float;
const Sample = pd.Sample;
const Symbol = pd.Symbol;

hold: *Float,
vec: ?[*]pd.Word = null,
arrayname: *Symbol,
f: Float = 0,

pub inline fn init(obj: *pd.Object, arrayname: *Symbol, hold: Float) pd.Oom!Tab2 {
	_ = try obj.outlet(pd.s.signal());
	const inlet: *Inlet = @ptrCast(@alignCast(try obj.inletSignal(hold)));
	return .{
		.hold = &inlet.un.floatsignalvalue,
		.arrayname = arrayname,
	};
}

pub inline fn sample(w: [*]pd.Word, x: Sample, hold: Sample) Sample {
	const h = 0.5 * @min(hold, 1);
	if (x < h) {
		return w[0].float;
	}
	if (x > 1 - h) {
		return w[1].float;
	}

	const y1 = w[0].float;
	const y2 = w[1].float;
	return (y2 - y1) / (1 - hold) * (x - h) + y1;
}

pub fn Impl(Self: type) type { return struct {
	fn holdC(p: *Pd, f: Float) callconv(.c) void {
		Self.Box.state(p).tab2.hold.* = f;
	}

	pub inline fn extend() void {
		const class: *pd.Class = Self.class;
		class.doMainSignalIn(
			@offsetOf(Self.Box, "body") + @offsetOf(Self, "tab2") + @offsetOf(Tab2, "f"));
		class.addMethod(&.{ .float }, holdC, .gen("hold"));
	}
};}
