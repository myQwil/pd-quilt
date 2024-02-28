const pd = @import("pd");

pub const Tab2 = extern struct {
	const Self = @This();

	obj: pd.Object,
	hold: *pd.Float,
	vec: ?[*]pd.Word,
	arrayname: *pd.Symbol,
	f: pd.Float,

	fn setHold(self: *Self, f: pd.Float) void {
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

	pub fn setArray(self: *Self, s: *pd.Symbol) !usize {
		errdefer self.vec = null;
		self.arrayname = s;

		const array: *pd.GArray = @ptrCast(pd.garray_class.find(s) orelse {
			if (s != pd.s._) {
				pd.post.err(self, "%s: no such array", s.name);
			}
			return error.NotFound;
		});

		const vec = array.floatWords() orelse {
			pd.post.err(self, "%s: bad template for tab2~", s.name);
			return error.BadTemplate;
		};

		const len = vec.len - 3;
		if (vec.len <= 3 or len & (len - 1) != 0) {
			pd.post.err(self, "%s: number of points (%u) not a power of 2 plus three",
				s.name, vec.len);
			return error.InvalidSize;
		}

		self.vec = vec.ptr;
		array.useInDsp();
		return len;
	}

	pub fn init(self: *Self, arrayname: *pd.Symbol, hold: pd.Float) void {
		self.arrayname = arrayname;
		self.vec = null;

		const obj = &self.obj;
		const in2 = obj.inletSignal(hold).?;
		self.hold = &in2.un.floatsignalvalue;

		_ = obj.outlet(pd.s.signal);
		self.f = 0;
	}

	pub fn extend(class: *pd.Class) void {
		class.doMainSignalIn(@offsetOf(Self, "f"));
		class.addMethod(@ptrCast(&setHold), pd.symbol("hold"), &.{ .float });
	}
};
