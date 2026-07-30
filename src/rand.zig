//! Similar to `[random]` but the seed is initialized with Zig's `io.random()`.

const pd = @import("pd");
const std = @import("std");
const rn = @import("rng.zig");
const wr = @import("write.zig");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;
const Writer = std.Io.Writer;

const gpa = pd.gpa;
const io = std.Io.Threaded.global_single_threaded.io();

fn setWords(vec: []pd.Word, av: []const Atom) !void {
	if (av.len < 2) {
		return error.NotEnoughArgs;
	}
	// first arg specifies the onset
	const i = blk: {
		const i: i32 = @intFromFloat(av[0].getFloat() orelse 0);
		const j: usize = @min(@max(0, @abs(i)), vec.len);
		break :blk if (i < 0) vec.len - j else j;
	};
	const n = @min(vec.len - i, av.len - 1);
	for (vec[i..][0..n], av[1..][0..n]) |*w, *a| {
		if (a.type == .float) {
			w.float = a.w.float;
		}
	}
}

const Rand = extern struct {
	out: *pd.Outlet,
	/// repeat interrupt (0: disabled, >=1: allowed repeat values in a row)
	rep: u32 = 0,
	/// repeat count
	reps: u32 = 0,
	/// previous index
	prev: u32 = 0,

	const name = "rand";
	var s_rep: *Symbol = undefined;

	fn init(obj: *pd.Object) !Rand {
		return .{ .out = try .init(obj, pd.s.float()) };
	}

	fn initC(_: *Symbol, ac: c_uint, av: [*]Atom) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, choose(av[0..ac]), name);
	}
	inline fn choose(av: []Atom) !*Pd {
		if (av.len == 1 and av[0].type == .symbol) {
			return try ExArray.init(av[0].w.symbol);
		} else if (av.len > 2) {
			return try InArray.init(av);
		} else {
			return try Range.init(av);
		}
	}

	inline fn setup() !void {
		s_rep = .gen("rep");
		pd.addCreator(name, &.{ .gimme }, initC);
		try Range.setup();
		try InArray.setup();
		try ExArray.setup();
	}

	fn Impl(Self: type) type { return struct {
		fn next(self: *Self, range: Float) Float {
			const rand: *Rand = &self.rand;
			const rng: *rn.Rng = &self.rng;
			const f: Float = blk: {
				const nxt = rng.next();
				if (rand.rep != 0 and rand.reps >= rand.rep) {
					const offset: Float = @floatFromInt(rand.prev + 1);
					const n = nxt * (range - 1) + offset;
					break :blk if (n >= range) n - range else n;
				}
				break :blk nxt * range;
			};
			const i: u32 = @intFromFloat(f);
			rand.reps = if (rand.prev == i) rand.reps + 1 else 1;
			rand.prev = i;
			return f;
		}

		fn repC(p: *Pd, f: Float) callconv(.c) void {
			const self = Self.parentPtr(p);
			const rand: *Rand = &self.rand;
			rand.rep = @intFromFloat(f);
		}

		fn extend() void {
			const class: *pd.Class = Self.class;
			class.addMethod(&.{ .float }, repC, s_rep);
			class.setHelpSymbol(.gen("rand"));
		}
	};}
};

const Range = extern struct {
	obj: pd.Object,
	rand: Rand,
	min: Float,
	max: Float,
	rng: rn.Rng,

	const name = "_rand_range";
	const Rnd = Rand.Impl(Range);
	pub var class: *pd.Class = undefined;
	pub const parentPtr = pd.parentPtr(Range);
	pub const parentConstPtr = pd.parentConstPtr(Range);

	fn printC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		pd.post.log(self, .normal, "%g..%g", .{ self.min, self.max });
	}

	fn listC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = parentPtr(p);
		sw: switch (@min(ac, 2)) {
			2 => { if (av[1].getFloat()) |f| self.max = f; continue :sw 1; },
			1 => { if (av[0].getFloat()) |f| self.min = f; },
			else => {},
		}
	}

	fn anythingC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = parentPtr(p);
		self.min = pd.floatArg(0, av[0..ac]) catch self.min;
	}

	fn bangC(p: *Pd) callconv(.c) void {
		const self = parentPtr(p);
		const range = self.max - self.min;
		const f = Rnd.next(self, @abs(range));
		self.rand.out.float(@floor((if (range < 0) -f else f) + self.min));
	}

	inline fn init(av: []const Atom) !*Pd {
		const self: *Range = try pd.gpa.create(Range);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		// defaults
		var min: Float = 0;
		var max: Float = 0;

		// av.len must be <= 2 at this point
		sw: switch (av.len) {
			2 => {
				if (av[0].getFloat()) |f| min = f;
				if (av[1].getFloat()) |f| max = f;
				continue :sw 0;
			},
			1 => {
				if (av[0].getFloat()) |f| max = f;
				_ = try obj.inletFloat(&self.max);
			},
			0 => {
				_ = try obj.inletFloat(&self.min);
				_ = try obj.inletFloat(&self.max);
			},
			else => unreachable,
		}
		self.* = .{
			.obj = self.obj,
			.rand = try .init(obj),
			.rng = .init(),
			.min = min,
			.max = max,
		};
		return &obj.g.pd;
	}

	inline fn setup() !void {
		class = try .init(Range, name, &.{}, null, null, .{});
		try rn.Impl(Range).extend(io);
		Rnd.extend();
		class.addBang(bangC);
		class.addList(listC);
		class.addAnything(anythingC);
		class.addMethod(&.{}, printC, .gen("print"));
	}
};

/// manages its own array
const InArray = extern struct {
	obj: pd.Object,
	rand: Rand,
	win: wi.WordInlets,
	rng: rn.Rng,

	const wi = @import("winlet.zig");
	const name = "_rand_array";
	const Rnd = Rand.Impl(InArray);
	pub var class: *pd.Class = undefined;
	pub const parentPtr = pd.parentPtr(InArray);
	pub const parentConstPtr = pd.parentConstPtr(InArray);

	inline fn err(self: *const InArray, e: anyerror) void {
		pd.post.err(self, name ++ ": %s", .{ @errorName(e).ptr });
	}

	fn printC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		var buffer: [pd.max_string:0]u8 = undefined;
		var w: Writer = .fixed(&buffer);
		self.win.print(&w) catch unreachable;
		wr.writeVec(&w, self.win.items()) catch wr.ellipsis(&w);
		buffer[w.end] = 0;
		pd.post.log(self, .normal, &buffer, .{});
	}

	fn resizeC(p: *Pd, f: Float) callconv(.c) void {
		const self = parentPtr(p);
		self.win.resize(gpa, @intFromFloat(@max(1, f))) catch |e| self.err(e);
	}

	fn listC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = parentPtr(p);
		setWords(self.win.items(), av[0..ac]) catch |e| self.err(e);
	}

	fn bangC(p: *Pd) callconv(.c) void {
		const self = parentPtr(p);
		const f = Rnd.next(self, @floatFromInt(self.win.len));
		self.rand.out.float(self.win.ptr[@intFromFloat(f)].float);
	}

	inline fn init(av: []Atom) !*Pd {
		const self: *InArray = try pd.gpa.create(InArray);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		// 3 args with a symbol in the middle creates a 2-item array (ex: 7 or 9)
		const n: usize = if (av.len == 3 and av[1].type != .float) blk: {
			av[1] = av[2];
			break :blk 2;
		} else av.len;

		self.* = .{
			.obj = self.obj,
			.win = try .init(gpa, obj, av[0..n]),
			.rand = try .init(obj),
			.rng = .init(),
		};
		return &obj.g.pd;
	}

	fn deinitC(p: *Pd) callconv(.c) void {
		const self = parentPtr(p);
		self.win.deinit(gpa);
	}

	inline fn setup() !void {
		class = try .init(InArray, name, &.{}, null, deinitC, .{});
		try rn.Impl(InArray).extend(io);
		Rnd.extend();
		class.addBang(bangC);
		class.addList(listC);
		class.addMethod(&.{}, printC, .gen("print"));
		class.addMethod(&.{ .float }, resizeC, .gen("n"));
	}
};

/// uses an array that exists separately
const ExArray = extern struct {
	obj: pd.Object,
	rand: Rand,
	sym: *Symbol,
	rng: rn.Rng,

	const name = "_rand_garray";
	const Rnd = Rand.Impl(ExArray);
	pub var class: *pd.Class = undefined;
	pub const parentPtr = pd.parentPtr(ExArray);
	pub const parentConstPtr = pd.parentConstPtr(ExArray);

	inline fn err(self: *const ExArray, e: anyerror) void {
		pd.post.err(self, name ++ ": %s", .{ @errorName(e).ptr });
	}

	inline fn garray(self: *const ExArray) error{GArrayNotFound}!*pd.GArray {
		const result = pd.garray_class.find(self.sym);
		return if (result) |ga| @ptrCast(ga) else error.GArrayNotFound;
	}

	fn printC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		self.print() catch |e| self.err(e);
	}
	inline fn print(self: *const ExArray) !void {
		const vec = try (try self.garray()).floatWords();
		var buffer: [pd.max_string:0]u8 = undefined;
		var w: Writer = .fixed(&buffer);
		w.print("{s} ({*}) ", .{ self.sym.name, self.sym.thing }) catch unreachable;
		wr.writeVec(&w, vec) catch wr.ellipsis(&w);
		buffer[w.end] = 0;
		pd.post.log(self, .normal, &buffer, .{});
	}

	fn resizeC(p: *Pd, f: Float) callconv(.c) void {
		const self = parentPtr(p);
		self.resize(f) catch |e| self.err(e);
	}
	inline fn resize(self: *ExArray, f: Float) !void {
		const arr = try self.garray();
		try arr.resize(@intFromFloat(f));
	}

	fn listC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = parentPtr(p);
		self.list(av[0..ac]) catch |e| self.err(e);
	}
	inline fn list(self: *ExArray, av: []const Atom) !void {
		const garr = try self.garray();
		defer garr.redraw();
		try setWords(try garr.floatWords(), av);
	}

	fn bangC(p: *Pd) callconv(.c) void {
		const self = parentPtr(p);
		self.bang() catch |e| self.err(e);
	}
	inline fn bang(self: *ExArray) !void {
		const vec = try (try self.garray()).floatWords();
		const f = Rnd.next(self, @floatFromInt(vec.len));
		self.rand.out.float(vec[@intFromFloat(f)].float);
	}

	inline fn init(s: *Symbol) !*Pd {
		const self: *ExArray = try pd.gpa.create(ExArray);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inletSymbol(&self.sym);
		self.* = .{
			.obj = self.obj,
			.rand = try .init(obj),
			.rng = .init(),
			.sym = s,
		};
		return &obj.g.pd;
	}

	inline fn setup() !void {
		class = try .init(ExArray, name, &.{}, null, null, .{});
		try rn.Impl(ExArray).extend(io);
		Rnd.extend();
		class.addBang(bangC);
		class.addList(listC);
		class.addMethod(&.{}, printC, .gen("print"));
		class.addMethod(&.{ .float }, resizeC, .gen("n"));
	}
};

export fn rand_setup() void {
	_ = pd.wrap(void, Rand.setup(), @src().fn_name);
}
