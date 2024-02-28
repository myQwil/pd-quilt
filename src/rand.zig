const pd = @import("pd");
const hr = @import("rng.zig");
const hw = @import("winlet.zig");
var s_rep: *pd.Symbol = undefined;

fn onset(f: pd.Float, len: usize) usize {
	const i: i32 = @intFromFloat(f);
	const j: usize = @min(@max(0, @abs(i)), len);
	return if (i < 0) len - j else j;
}

fn _list(vec: []pd.Word, av: []const pd.Atom) void {
	const i = onset(av[0].float(), vec.len);
	const n = @min(vec.len - i, av.len - 1);
	for (vec[i..i+n], av[1..1+n]) |*w, *a| {
		if (a.type == .float) {
			w.float = a.w.float;
		}
	}
}

fn floatPassive(fp: *pd.Float, av: []const pd.Atom, i: usize) void {
	if (i < av.len and av[i].type == .float) {
		fp.* = av[i].w.float;
	}
}

const Rand = extern struct {
	base: hr.Rng,
	out: *pd.Outlet,
	rep: u32, // repeat interrupt (0: disabled, >=1: allowed values in a row)
	reps: u32, // repeat count
	prev: u32, // previous index

	fn setRep(self: *Rand, f: pd.Float) void {
		self.rep = @intFromFloat(f);
	}

	fn printVec(self: *const Rand, vec: []pd.Word) void {
		if (vec.len == 0) {
			return pd.post.log(self, .normal, "[]");
		}
		pd.post.start("[%g", vec[0].float);
		for (vec[1..]) |w| {
			pd.post.start(", %g", w.float);
		}
		pd.post.log(self, .normal, "]");
	}

	fn extend(class: *pd.Class) void {
		hr.Rng.extend(class);
		class.addMethod(@ptrCast(&setRep), s_rep, &.{ .float });
	}

	fn next(self: *Rand, range: pd.Float) pd.Float {
		const f: pd.Float = blk: {
			const rand = self.base.next();
			if (self.rep != 0 and self.reps >= self.rep) {
				const offset: pd.Float = @floatFromInt(self.prev + 1);
				const n = rand * (range - 1) + offset;
				break :blk if (n >= range) n - range else n;
			}
			break :blk rand * range;
		};
		const i: u32 = @intFromFloat(f);
		self.reps = if (self.prev == i) self.reps + 1 else 1;
		self.prev = i;
		return f;
	}

	fn init(self: *Rand) void {
		self.base.init();
		self.out = self.base.obj.outlet(pd.s.float).?;
	}

	fn new(_: *pd.Symbol, ac: c_uint, av: [*]pd.Atom) ?*anyopaque {
		if (ac == 1 and av[0].type == .symbol) {
			return GArray.new(av[0].w.symbol);
		}
		return if (ac <= 2) Range.new(av[0..ac]) else Array.new(av[0..ac]) catch null;
	}

	fn setup() void {
		s_rep = pd.symbol("rep");
		pd.addCreator(@ptrCast(&new), pd.symbol("rand"), &.{ .gimme });
		Range.setup();
		Array.setup();
		GArray.setup();
	}
};

const Range = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	base: Rand,
	max: pd.Float,
	min: pd.Float,

	fn print(self: *const Self) void {
		pd.post.log(self, .normal, "%g..%g", self.min, self.max);
	}

	fn list(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		const vec = av[0..ac];
		floatPassive(&self.max, vec, 0);
		floatPassive(&self.min, vec, 1);
	}

	fn anything(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		floatPassive(&self.min, av[0..ac], 0);
	}

	fn bang(self: *Self) void {
		const range = self.max - self.min;
		const f = self.base.next(@abs(range));
		self.base.out.float(@floor((if (range < 0) -f else f) + self.min));
	}

	fn new(av: []const pd.Atom) ?*Self {
		const self: *Self = @ptrCast(class.new() orelse return null);
		self.base.init();

		const obj = &self.base.base.obj;
		if (av.len == 1) {
			_ = obj.inletFloatArg(&self.max, av, 0);
		} else {
			_ = obj.inletFloatArg(&self.min, av, 0);
			_ = obj.inletFloatArg(&self.max, av, 1);
		}
		return self;
	}

	fn setup() void {
		class = pd.class(pd.symbol("_rand_range"), null, null,
			@sizeOf(Self), .{}, &.{}).?;
		Rand.extend(class);
		class.addBang(@ptrCast(&bang));
		class.addList(@ptrCast(&list));
		class.addAnything(@ptrCast(&anything));
		class.addMethod(@ptrCast(&print), pd.symbol("print"), &.{});
	}
};

const Array = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	base: Rand,
	win: hw.WInlet,
	size: usize,

	fn print(self: *const Self) void {
		self.base.printVec(self.win.ptr[0..self.size]);
	}

	fn resize(self: *Self, f: pd.Float) void {
		const n: usize = @intFromFloat(@max(1, f));
		self.win.resize(n) catch return;
		self.size = n;
	}

	fn list(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		if (ac < 2) {
			return;
		}
		_list(self.win.ptr[0..self.size], av[0..ac]);
	}

	fn bang(self: *Self) void {
		const f = self.base.next(@floatFromInt(self.size));
		self.base.out.float(self.win.ptr[@intFromFloat(f)].float);
	}

	fn new(av: []pd.Atom) !*Self {
		const self: *Self = @ptrCast(class.new() orelse return error.NoSetup);
		errdefer @as(*pd.Pd, @ptrCast(self)).free();
		self.base.init();

		// 3 args with a symbol in the middle creates a 2-item array (ex: 7 or 9)
		const n: usize = blk: {
			if (av.len == 3 and av[1].type != .float) {
				av[1] = av[2];
				break :blk 2;
			}
			break :blk av.len;
		};

		const obj = &self.base.base.obj;
		try self.win.init(obj, n);
		self.size = n;
		for (0..n, self.win.ptr) |i, *w| {
			_ = obj.inletFloatArg(&w.float, av, @intCast(i));
		}
		return self;
	}

	fn free(self: *Self) void {
		self.win.free();
	}

	fn setup() void {
		class = pd.class(pd.symbol("_rand_array"), null, @ptrCast(&free),
			@sizeOf(Self), .{}, &.{}).?;
		Rand.extend(class);
		class.addBang(@ptrCast(&bang));
		class.addList(@ptrCast(&list));
		class.addMethod(@ptrCast(&print), pd.symbol("print"), &.{});
		class.addMethod(@ptrCast(&resize), pd.symbol("n"), &.{ .float });
	}
};

const GArray = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	base: Rand,
	sym: *pd.Symbol,

	fn garray(self: *const Self) ?*pd.GArray {
		return @as(*pd.GArray, @ptrCast(pd.garray_class.find(self.sym) orelse {
			pd.post.err(self, "%s: no such array", self.sym.name);
			return null;
		}));
	}

	fn print(self: *const Self) void {
		pd.post.start("%s (0x%x) ", self.sym.name, self.sym.thing);
		self.base.printVec((self.garray() orelse return).floatWords() orelse return);
	}

	fn resize(self: *Self, f: pd.Float) void {
		(self.garray() orelse return).resize(@as(c_long, @intFromFloat(f)));
	}

	fn list(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		if (ac < 2) {
			return;
		}
		const garr = self.garray() orelse return;
		defer garr.redraw();
		_list(garr.floatWords() orelse return, av[0..ac]);
	}

	fn bang(self: *Self) void {
		const vec = (self.garray() orelse return).floatWords() orelse return;
		const f = self.base.next(@floatFromInt(vec.len));
		self.base.out.float(vec[@intFromFloat(f)].float);
	}

	fn new(s: *pd.Symbol) ?*Self {
		const self: *Self = @ptrCast(class.new() orelse return null);
		self.base.init();
		self.sym = s;
		_ = self.base.base.obj.inletSymbol(&self.sym);
		return self;
	}

	fn setup() void {
		class = pd.class(pd.symbol("_rand_garray"), null, null,
			@sizeOf(Self), .{}, &.{}).?;
		Rand.extend(class);
		class.addBang(@ptrCast(&bang));
		class.addList(@ptrCast(&list));
		class.addMethod(@ptrCast(&print), pd.symbol("print"), &.{});
		class.addMethod(@ptrCast(&resize), pd.symbol("n"), &.{ .float });
	}
};

export fn rand_setup() void {
	Rand.setup();
}
