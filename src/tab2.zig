pub usingnamespace @import("pd.zig");
const pd = @This();

pub const Tab2 = extern struct {
	const Self = @This();

	obj: pd.Object,
	hold: *pd.Float,
	vec: ?[*]pd.Word,
	arrayname: *pd.Symbol,
	f: pd.Float,

	fn set_hold(self: *Self, f: pd.Float) void {
		self.hold.* = f;
	}

	pub inline fn sample(w: [*]pd.Word, x: pd.Sample, hold: pd.Sample) pd.Sample {
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

	pub fn set_array(self: *Self, s: *pd.Symbol) !u32 {
		errdefer self.vec = null;
		self.arrayname = s;

		const array: *pd.GArray = blk: {
			if (pd.garray_class.find(self.arrayname)) |arr| {
				break :blk @ptrCast(arr);
			} else {
				if (s.name[0] != '\x00') {
					pd.err(self, "%s: no such array", self.arrayname.name);
				}
				return error.NotFound;
			}
		};

		const array_len = blk: {
			var len: u32 = undefined;
			if (array.getFloatWords(&len, &self.vec) != 0) {
				break :blk len;
			} else {
				pd.err(self, "%s: bad template for tab2~", self.arrayname.name);
				return error.BadTemplate;
			}
		};

		const npoints = array_len - 3;
		if (npoints != @as(u32, 1) << @intCast(pd.ilog2(npoints))) {
			pd.err(self, "%s: number of points (%d) not a power of 2 plus three",
				self.arrayname.name, array_len);
			return error.InvalidSize;
		}

		array.useInDsp();
		return npoints;
	}

	pub inline fn init(self: *Self, arrayname: *pd.Symbol, hold: pd.Float) void {
		self.arrayname = arrayname;
		self.vec = null;

		const obj = &self.obj;
		const in2 = obj.inletSignal(hold);
		self.hold = &in2.un.floatsignalvalue;

		_ = obj.outlet(pd.s.signal);
		self.f = 0;
	}

	pub inline fn extend(class: *pd.Class) void {
		const A = pd.AtomType;
		class.doMainSignalIn(@offsetOf(Self, "f"));
		class.addMethod(@ptrCast(&set_hold), pd.symbol("hold"), A.FLOAT, A.NULL);
	}
};
