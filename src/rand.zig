//! Similar to `[random]` but the seed is initialized with Zig's `io.random()`.

const pd = @import("pd");
const std = @import("std");
const Rng = @import("misc/Rng.zig");
const wr = @import("misc/write.zig");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;
const Writer = std.Io.Writer;
const ClassError = pd.Class.Error;

const gpa = pd.gpa;
const io = std.Io.Threaded.global_single_threaded.io();

fn setWords(vec: []pd.Word, av: []const Atom) error{NotEnoughArgs}!void {
	if (av.len < 2) {
		return error.NotEnoughArgs;
	}
	// first arg specifies the onset
	const i = blk: {
		const i: i32 = if (av[0].getFloat()) |f| @trunc(f) else 0;
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

const Rand = struct {
	out: *pd.Outlet,
	/// repeat interrupt (0: disabled, >=1: allowed repeat values in a row)
	rep: u32 = 0,
	/// repeat count
	reps: u32 = 0,
	/// previous index
	prev: u32 = 0,

	const name = "rand";
	var s_rep: *Symbol = undefined;

	fn init(obj: *pd.Object) pd.Oom!Rand {
		return .{ .out = try .create(obj, pd.s.float()) };
	}

	fn createC(_: *Symbol, ac: c_uint, av: [*]Atom) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, choose(av[0..ac]), name);
	}
	inline fn choose(av: []Atom) pd.Oom!*Pd {
		if (av.len == 1 and av[0].type == .symbol) {
			return try ExArray.create(av[0].w.symbol);
		} else if (av.len > 2) {
			return try InArray.create(av);
		} else {
			return try Range.create(av);
		}
	}

	inline fn setup() ClassError!void {
		s_rep = .gen("rep");
		pd.addCreator(name, &.{ .gimme }, createC);
		try Range.setup();
		try InArray.setup();
		try ExArray.setup();
	}

	fn Impl(Self: type) type { return struct {
		fn next(self: *Self, range: Float) Float {
			const rand: *Rand = &self.rand;
			const rng: *Rng = &self.rng;
			const f: Float = blk: {
				const nxt = rng.next();
				if (rand.rep != 0 and rand.reps >= rand.rep) {
					const offset: Float = @floatFromInt(rand.prev + 1);
					const n = nxt * (range - 1) + offset;
					break :blk if (n >= range) n - range else n;
				}
				break :blk nxt * range;
			};
			const i: u32 = @trunc(f);
			rand.reps = if (rand.prev == i) rand.reps + 1 else 1;
			rand.prev = i;
			return f;
		}

		fn repC(p: *Pd, f: Float) callconv(.c) void {
			const self = Self.Box.state(p);
			const rand: *Rand = &self.rand;
			rand.rep = @trunc(f);
		}

		fn extend() void {
			const class: *pd.Class = Self.class;
			class.addMethod(&.{ .float }, repC, s_rep);
			class.setHelpSymbol(.gen("rand"));
		}
	};}
};

const Range = struct {
	rand: Rand,
	min: Float,
	max: Float,
	rng: Rng,

	const name = "_rand_range";
	const Impl = Rand.Impl(Range);
	pub var class: *pd.Class = undefined;
	pub const Box = pd.Box(pd.Object, Range);

	fn printC(p: *const Pd) callconv(.c) void {
		const self = Box.stateConst(p);
		pd.post.log(p, .normal, "%g..%g", .{ self.min, self.max });
	}

	fn listC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = Box.state(p);
		sw: switch (@min(ac, 2)) {
			2 => { if (av[1].getFloat()) |f| self.max = f; continue :sw 1; },
			1 => { if (av[0].getFloat()) |f| self.min = f; },
			else => {},
		}
	}

	fn anythingC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = Box.state(p);
		self.min = pd.floatArg(0, av[0..ac]) catch self.min;
	}

	fn bangC(p: *Pd) callconv(.c) void {
		const self = Box.state(p);
		const range = self.max - self.min;
		const f = Impl.next(self, @abs(range));
		self.rand.out.float(@floor((if (range < 0) -f else f) + self.min));
	}

	inline fn create(av: []const Atom) pd.Oom!*Pd {
		const obj: *pd.Object = @ptrCast(try class.pd());
		const self = Box.state(&obj.g.pd);
		errdefer obj.g.pd.destroy();

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
			.rand = try .init(obj),
			.rng = .init(),
			.min = min,
			.max = max,
		};
		return &obj.g.pd;
	}

	inline fn setup() ClassError!void {
		class = try .create(name, &.{}, null, null, @sizeOf(Box), .{});
		Rng.Impl(Range).extend(io);
		Impl.extend();
		class.addBang(bangC);
		class.addList(listC);
		class.addAnything(anythingC);
		class.addMethod(&.{}, printC, .gen("print"));
	}
};

/// manages its own array
const InArray = struct {
	rand: Rand,
	win: WordInlets,
	rng: Rng,

	const WordInlets = @import("misc/WordInlets.zig");
	const name = "_rand_array";
	const Impl = Rand.Impl(InArray);
	pub var class: *pd.Class = undefined;
	pub const Box = pd.Box(pd.Object, InArray);

	inline fn err(p: *const Pd, e: anyerror) void {
		pd.post.err(p, name ++ ": %s", .{ @errorName(e).ptr });
	}

	fn printC(p: *const Pd) callconv(.c) void {
		const self = Box.stateConst(p);
		var buffer: [pd.max_string:0]u8 = undefined;
		var w: Writer = .fixed(&buffer);
		self.win.print(&w) catch unreachable;
		wr.writeVec(&w, self.win.vec) catch wr.ellipsis(&w);
		buffer[w.end] = 0;
		pd.post.log(p, .normal, &buffer, .{});
	}

	fn resizeC(p: *Pd, f: Float) callconv(.c) void {
		const self = Box.state(p);
		self.win.resize(gpa, @trunc(@max(1, f))) catch |e| err(p, e);
	}

	fn listC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = Box.state(p);
		setWords(self.win.vec, av[0..ac]) catch |e| err(p, e);
	}

	fn bangC(p: *Pd) callconv(.c) void {
		const self = Box.state(p);
		const f = Impl.next(self, @floatFromInt(self.win.vec.len));
		self.rand.out.float(self.win.vec[@trunc(f)].float);
	}

	inline fn create(av: []Atom) pd.Oom!*Pd {
		const obj: *pd.Object = @ptrCast(try class.pd());
		const self = Box.state(&obj.g.pd);
		errdefer obj.g.pd.destroy();

		// 3 args with a symbol in the middle creates a 2-item array (ex: 7 or 9)
		const n: usize = if (av.len == 3 and av[1].type != .float) blk: {
			av[1] = av[2];
			break :blk 2;
		} else av.len;

		self.* = .{
			.win = try .init(gpa, obj, av[0..n]),
			.rand = try .init(obj),
			.rng = .init(),
		};
		return &obj.g.pd;
	}

	fn destroyC(p: *Pd) callconv(.c) void {
		Box.state(p).win.deinit(gpa);
	}

	inline fn setup() ClassError!void {
		class = try .create(name, &.{}, null, destroyC, @sizeOf(Box), .{});
		Rng.Impl(InArray).extend(io);
		Impl.extend();
		class.addBang(bangC);
		class.addList(listC);
		class.addMethod(&.{}, printC, .gen("print"));
		class.addMethod(&.{ .float }, resizeC, .gen("n"));
	}
};

/// uses an array that exists separately
const ExArray = struct {
	rand: Rand,
	sym: *Symbol,
	rng: Rng,

	const name = "_rand_garray";
	const Impl = Rand.Impl(ExArray);
	pub var class: *pd.Class = undefined;
	pub const Box = pd.Box(pd.Object, ExArray);

	const Error = pd.GArray.GetError;

	inline fn err(p: *const Pd, e: anyerror) void {
		pd.post.err(p, name ++ ": %s", .{ @errorName(e).ptr });
	}

	inline fn garray(self: *const ExArray) error{GArrayNotFound}!*pd.GArray {
		const result = pd.garray_class.find(self.sym);
		return if (result) |ga| @ptrCast(ga) else error.GArrayNotFound;
	}

	fn printC(p: *const Pd) callconv(.c) void {
		print(p) catch |e| err(p, e);
	}
	inline fn print(p: *const Pd) Error!void {
		const self = Box.stateConst(p);
		const vec = try (try self.garray()).floatWords();
		var buffer: [pd.max_string:0]u8 = undefined;
		var w: Writer = .fixed(&buffer);
		w.print("{s} ({*}) ", .{ self.sym.name, self.sym.thing }) catch unreachable;
		wr.writeVec(&w, vec) catch wr.ellipsis(&w);
		buffer[w.end] = 0;
		pd.post.log(p, .normal, &buffer, .{});
	}

	fn resizeC(p: *Pd, f: Float) callconv(.c) void {
		const self = Box.state(p);
		self.resize(f) catch |e| err(p, e);
	}
	const ResizeError = pd.GArray.ResizeError || error{GArrayNotFound};
	inline fn resize(self: *ExArray, f: Float) ResizeError!void {
		const arr = try self.garray();
		try arr.resize(@trunc(f));
	}

	fn listC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = Box.state(p);
		self.list(av[0..ac]) catch |e| err(p, e);
	}
	inline fn list(self: *ExArray, av: []const Atom) (Error || error{NotEnoughArgs})!void {
		const garr = try self.garray();
		defer garr.redraw();
		try setWords(try garr.floatWords(), av);
	}

	fn bangC(p: *Pd) callconv(.c) void {
		const self = Box.state(p);
		self.bang() catch |e| err(p, e);
	}
	inline fn bang(self: *ExArray) Error!void {
		const vec = try (try self.garray()).floatWords();
		const f = Impl.next(self, @floatFromInt(vec.len));
		self.rand.out.float(vec[@trunc(f)].float);
	}

	inline fn create(s: *Symbol) pd.Oom!*Pd {
		const obj: *pd.Object = @ptrCast(try class.pd());
		const self = Box.state(&obj.g.pd);
		errdefer obj.g.pd.destroy();

		_ = try obj.inletSymbol(&self.sym);
		self.* = .{
			.rand = try .init(obj),
			.rng = .init(),
			.sym = s,
		};
		return &obj.g.pd;
	}

	inline fn setup() ClassError!void {
		class = try .create(name, &.{}, null, null, @sizeOf(Box), .{});
		Rng.Impl(ExArray).extend(io);
		Impl.extend();
		class.addBang(bangC);
		class.addList(listC);
		class.addMethod(&.{}, printC, .gen("print"));
		class.addMethod(&.{ .float }, resizeC, .gen("n"));
	}
};

export fn rand_setup() void {
	_ = pd.wrap(void, Rand.setup(), @src().fn_name);
}
