const pd = @import("pd");
const std = @import("std");
const rn = @import("rng.zig");
const wr = @import("write.zig");

const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;
const Writer = std.Io.Writer;

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
		return .{ .out = try .init(obj, &pd.s_float) };
	}

	fn initC(_: *Symbol, ac: c_uint, av: [*]Atom) callconv(.c) ?*anyopaque {
		return pd.wrap(*anyopaque, choose(av[0..ac]), name);
	}
	inline fn choose(av: []Atom) !*anyopaque {
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
		pd.addCreator(anyopaque, name, &.{ .gimme }, &initC);
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

		fn repC(self: *Self, f: Float) callconv(.c) void {
			const rand: *Rand = &self.rand;
			rand.rep = @intFromFloat(f);
		}

		fn extend() void {
			const class: *pd.Class = Self.class;
			class.addMethod(@ptrCast(&repC), s_rep, &.{ .float });
			class.setHelpSymbol(.gen("rand"));
		}
	};}
};

const Range = extern struct {
	obj: pd.Object = undefined,
	rand: Rand,
	min: Float,
	max: Float,
	rng: rn.Rng,

	const name = "_rand_range";
	const Rnd = Rand.Impl(Range);
	pub var class: *pd.Class = undefined;

	fn printC(self: *const Range) callconv(.c) void {
		pd.post.log(self, .normal, "%g..%g", .{ self.min, self.max });
	}

	fn listC(
		self: *Range,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		sw: switch (@min(ac, 2)) {
			2 => {
				self.max = av[1].getFloat() orelse self.max;
				continue :sw 1;
			},
			1 => self.min = av[0].getFloat() orelse self.min,
			else => {},
		}
	}

	fn anythingC(
		self: *Range,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		self.min = pd.floatArg(0, av[0..ac]) catch self.min;
	}

	fn bangC(self: *Range) callconv(.c) void {
		const range = self.max - self.min;
		const f = Rnd.next(self, @abs(range));
		self.rand.out.float(@floor((if (range < 0) -f else f) + self.min));
	}

	inline fn init(av: []const Atom) !*Range {
		const self: *Range = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		// defaults
		var min: Float = 0;
		var max: Float = 0;

		// av.len must be <= 2 at this point
		sw: switch (av.len) {
			2 => {
				min = av[0].getFloat() orelse min;
				max = av[1].getFloat() orelse max;
				continue :sw 0;
			},
			1 => {
				max = av[0].getFloat() orelse max;
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
		return self;
	}

	inline fn setup() !void {
		class = try .init(Range, name, &.{}, null, null, .{});
		try rn.Impl(Range).extend();
		Rnd.extend();
		class.addBang(@ptrCast(&bangC));
		class.addList(@ptrCast(&listC));
		class.addAnything(@ptrCast(&anythingC));
		class.addMethod(@ptrCast(&printC), .gen("print"), &.{});
	}
};

/// manages its own array
const InArray = extern struct {
	obj: pd.Object = undefined,
	rand: Rand,
	win: wi.WordInlets,
	rng: rn.Rng,

	const wi = @import("winlet.zig");
	const name = "_rand_array";
	const Rnd = Rand.Impl(InArray);
	pub var class: *pd.Class = undefined;

	inline fn err(self: *const InArray, e: anyerror) void {
		pd.post.err(self, name ++ ": %s", .{ @errorName(e).ptr });
	}

	fn printC(self: *const InArray) callconv(.c) void {
		var buffer: [pd.max_string:0]u8 = undefined;
		var writer: Writer = .fixed(&buffer);
		self.win.print(&writer) catch unreachable;
		wr.writeVec(&writer, self.win.items()) catch wr.ellipsis(&writer);
		buffer[writer.end] = 0;
		pd.post.log(self, .normal, "%s", .{ &buffer });
	}

	fn resizeC(self: *InArray, f: Float) callconv(.c) void {
		self.win.resize(@intFromFloat(@max(1, f))) catch |e| self.err(e);
	}

	fn listC(
		self: *InArray,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		setWords(self.win.items(), av[0..ac]) catch |e| self.err(e);
	}

	fn bangC(self: *InArray) callconv(.c) void {
		const f = Rnd.next(self, @floatFromInt(self.win.len));
		self.rand.out.float(self.win.ptr[@intFromFloat(f)].float);
	}

	inline fn init(av: []Atom) !*InArray {
		const self: *InArray = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		// 3 args with a symbol in the middle creates a 2-item array (ex: 7 or 9)
		const n: usize = if (av.len == 3 and av[1].type != .float) blk: {
			av[1] = av[2];
			break :blk 2;
		} else av.len;

		self.* = .{
			.win = try .init(obj, av[0..n]),
			.rand = try .init(obj),
			.rng = .init(),
		};
		return self;
	}

	fn deinitC(self: *InArray) callconv(.c) void {
		self.win.deinit();
	}

	inline fn setup() !void {
		class = try .init(InArray, name, &.{}, null, &deinitC, .{});
		try rn.Impl(InArray).extend();
		Rnd.extend();
		class.addBang(@ptrCast(&bangC));
		class.addList(@ptrCast(&listC));
		class.addMethod(@ptrCast(&printC), .gen("print"), &.{});
		class.addMethod(@ptrCast(&resizeC), .gen("n"), &.{ .float });
	}
};

/// uses an array that exists separately
const ExArray = extern struct {
	obj: pd.Object = undefined,
	rand: Rand,
	sym: *Symbol,
	rng: rn.Rng,

	const name = "_rand_garray";
	const Rnd = Rand.Impl(ExArray);
	pub var class: *pd.Class = undefined;

	inline fn err(self: *const ExArray, e: anyerror) void {
		pd.post.err(self, name ++ ": %s", .{ @errorName(e).ptr });
	}

	inline fn garray(self: *const ExArray) error{GArrayNotFound}!*pd.GArray {
		return @ptrCast(pd.garray_class.find(self.sym) orelse return error.GArrayNotFound);
	}

	fn printC(self: *const ExArray) callconv(.c) void {
		self.print() catch |e| self.err(e);
	}
	inline fn print(self: *const ExArray) !void {
		const vec = try (try self.garray()).floatWords();
		var buffer: [pd.max_string:0]u8 = undefined;
		var writer: Writer = .fixed(&buffer);
		writer.print("{s} ({*}) ", .{ self.sym.name, self.sym.thing }) catch unreachable;
		wr.writeVec(&writer, vec) catch wr.ellipsis(&writer);
		buffer[writer.end] = 0;
		pd.post.log(self, .normal, "%s", .{ &buffer });
	}

	fn resizeC(self: *ExArray, f: Float) callconv(.c) void {
		self.resize(f) catch |e| self.err(e);
	}
	inline fn resize(self: *ExArray, f: Float) !void {
		(try self.garray()).resize(@intFromFloat(f));
	}

	fn listC(
		self: *ExArray,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		self.list(av[0..ac]) catch |e| self.err(e);
	}
	inline fn list(self: *ExArray, av: []const Atom) !void {
		const garr = try self.garray();
		defer garr.redraw();
		try setWords(try garr.floatWords(), av);
	}

	fn bangC(self: *ExArray) callconv(.c) void {
		self.bang() catch |e| self.err(e);
	}
	inline fn bang(self: *ExArray) !void {
		const vec = try (try self.garray()).floatWords();
		const f = Rnd.next(self, @floatFromInt(vec.len));
		self.rand.out.float(vec[@intFromFloat(f)].float);
	}

	inline fn init(s: *Symbol) !*ExArray {
		const self: *ExArray = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inletSymbol(&self.sym);
		self.* = .{
			.rand = try .init(obj),
			.rng = .init(),
			.sym = s,
		};
		return self;
	}

	inline fn setup() !void {
		class = try .init(ExArray, name, &.{}, null, null, .{});
		try rn.Impl(ExArray).extend();
		Rnd.extend();
		class.addBang(@ptrCast(&bangC));
		class.addList(@ptrCast(&listC));
		class.addMethod(@ptrCast(&printC), .gen("print"), &.{});
		class.addMethod(@ptrCast(&resizeC), .gen("n"), &.{ .float });
	}
};

export fn rand_setup() void {
	_ = pd.wrap(void, Rand.setup(), @src().fn_name);
}
