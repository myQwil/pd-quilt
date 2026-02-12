const pd = @import("pd");
const std = @import("std");
const wr = @import("write.zig");

const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;
const Word = pd.Word;
const Writer = std.Io.Writer;

var buffer: [pd.max_string:0]u8 = undefined;
const epsilon = std.math.floatEps(Float);
const gpa = pd.gpa;

inline fn getDigit(c: u8) ?u8 {
	return if ('0' <= c and c <= '9') c - '0' else null;
}

/// Simple string-to-float converter
pub fn fParse(s: [*:0]const u8, end_index: ?*usize) ?Float {
	var i: usize = 0;
	var no_digits: bool = true;
	if (s[0] == '-' or s[0] == '+') {
		i += 1;
	}

	// integer digits
	var acc: u64 = 0;
	while (getDigit(s[i])) |d| : (i += 1) {
		acc = acc *| 10 +| d;
		no_digits = false;
	}

	// fractional digits
	const exp_offset: usize = if (s[i] == '.') blk: {
		i += 1;
		const start: usize = i;
		while (getDigit(s[i])) |d| : (i += 1) {
			acc = acc *| 10 +| d;
			no_digits = false;
		}
		break :blk i - start;
	} else 0;

	if (no_digits) {
		return null;
	}

	const f: f64 = blk: {
		const a: f64 = @floatFromInt(acc);
		const scale: f64 = @floatFromInt(
			std.math.powi(usize, 10, exp_offset) catch return null);
		break :blk a / scale;
	};
	if (end_index) |end| {
		end.* = i;
	}
	return @floatCast(if (s[0] == '-') -f else f);
}

/// Simple string-to-int converter
pub fn iParse(s: [*:0]const u8, end_index: ?*usize) ?i32 {
	var i: usize = 0;
	var no_digits: bool = true;
	if (s[0] == '-' or s[0] == '+') {
		i += 1;
	}

	var acc: i32 = 0;
	while (getDigit(s[i])) |d| : (i += 1) {
		acc = acc *| 10 +| d;
		no_digits = false;
	}

	if (no_digits) {
		return null;
	}
	if (end_index) |end| {
		end.* = i;
	}
	return if (s[0] == '-') -acc else acc;
}

fn onset(i: i32, len: usize) usize {
	const j: u32 = @min(@max(0, @abs(i)), len);
	return if (i < 0) len - j else j;
}

var ops: std.AutoHashMapUnmanaged(u8, *const fn(Float, Float) Float) = .{};

fn opPlus(f1: Float, f2: Float) Float {
	return f1 + f2;
}
fn opMinus(f1: Float, f2: Float) Float {
	return f1 - f2;
}
fn opTimes(f1: Float, f2: Float) Float {
	return f1 * f2;
}
fn opOver(f1: Float, f2: Float) Float {
	return if (f2 == 0) 0 else f1 / f2;
}

const Arp = extern struct {
	/// sends the midi note equivalent of a given scale index
	out_f: *pd.Outlet,
	/// sends transformed copies of the current list
	out_l: *pd.Outlet,
	/// number of semitones jumped per octave
	oct: Float = 12,

	const name = "arp";

	fn init(obj: *pd.Object) !Arp {
		return .{
			.out_f = try .init(obj, &pd.s_float),
			.out_l = try .init(obj, &pd.s_list),
		};
	}

	fn interval(self: *const Arp, vec: []const Word, f: Float) Float {
		const g = @floor(f);
		const num: i32 = @intFromFloat(g);
		const den: i32 = @intCast(vec.len);
		const quo: i32 = @divFloor(num, den);
		var i: u32 = @intCast(num - den * quo);

		const oct = self.oct * @as(Float, @floatFromInt(quo));
		const note = oct + if (i == 0) 0 else vec[i].float;
		const frac = f - g;
		if (frac < epsilon) {
			return note;
		}
		i += 1;
		const next = oct + if (i < vec.len) vec[i].float else self.oct;
		return (next - note) * frac + note;
	}

	inline fn refParse(self: *const Arp, vec: []const Word, s: [*:0]const u8) ?Float {
		return if (s[0] == '&')
			(if (fParse(s + 1, null)) |f| self.interval(vec, f) else null)
		else fParse(s, null);
	}

	fn list(self: *const Arp, vec: []Word, av: []const Atom, on: i32) !void {
		const temp = try gpa.dupe(Word, vec); // vec in its initial state
		defer gpa.free(temp);

		var i = onset(on, vec.len);
		for (av[0..@min(vec.len - i, av.len)]) |*atom| {
			const w = &vec[i];
			if (atom.type == .float) {
				w.float = atom.w.float;
			} else {
				var s = atom.w.symbol.name;
				const n = blk: { // inner arg count
					var rem = vec.len - i;
					var end: usize = undefined;
					if (iParse(s, &end)) |j| {
						s += end;
						rem = onset(j, rem);
					}
					break :blk rem;
				};
				const c = s[0];
				if (ops.get(c)) |op| {
					if (c == s[1]) { // ++, --, etc.
						// do the same shift for all intervals that follow
						const f = self.refParse(temp, s+2) orelse 1;
						for (vec[i..][0..n]) |*x| {
							x.float = op(x.float, f);
						}
						i += n;
						continue;
					} else {
						w.float = op(w.float, self.refParse(temp, s+1) orelse 1);
					}
				} else if (c == '<' or c == '>') { // scale inversion
					const mvrt: bool = (c == s[1]); // << or >> moves the root
					const f = blk: {
						const dir: Float = @floatFromInt(@as(i8, @intCast(c)) - '=');
						const j = @as(u8, @intFromBool(mvrt)) + 1;
						break :blk dir * (fParse(s + j, null) orelse 1);
					};
					const g = @floor(f);
					const num: i32 = @intFromFloat(g);
					const den: i32 = @intCast(n);
					const quo: i32 = @divFloor(num, den);
					var d: u32 = @intCast(num - den * quo); // rotation amount
					var p = n - d; // pivot index

					const vp = vec[i..][0..n];
					const tp = temp[i..][0..n];

					// temporarily set old root to 0, reset to original value when done
					const root = tp[0].float;
					tp[0].float = 0;
					defer tp[0].float = root;

					// rotate vec to the left by `d` positions while simultaneously:
					// - adding (octave - vec[d]) to values where index >= pivot
					// - subtracting vec[d] from values where index < pivot
					const a = tp[d].float;
					const oa = self.oct - a;
					const frac = f - g;
					if (frac < epsilon) {
						for (vp[p..n], tp[0..d]) |*v, *t| {
							v.float = t.float + oa;
						}
						for (vp[1..p], tp[d+1..n]) |*v, *t| {
							v.float = t.float - a;
						}
						if (mvrt) {
							const octs = self.oct * @as(Float, @floatFromInt(quo));
							vp[0].float = root + octs + a;
						}
					} else {
						// interpolate between inversions `a` and `b`
						d += 1;
						const b = if (d >= n) self.oct else tp[d].float;
						const ob = self.oct - b;
						var min: Float = undefined;
						for (vp[p..n], tp[0..d-1], tp[1..d]) |*v, *ta, *tb| {
							min = ta.float + oa;
							v.float = (tb.float + ob - min) * frac + min;
						}
						p -= 1;
						if (p > 0) {
							for (vp[1..p], tp[d..n-1], tp[d+1..n]) |*v, *ta, *tb| {
								min = ta.float - a;
								v.float = (tb.float - b - min) * frac + min;
							}
							// interpolate between a's last item and b's first item
							min = tp[n-1].float - a;
							vp[p].float = (ob - min) * frac + min;
						}
						if (mvrt) {
							const octs = self.oct * @as(Float, @floatFromInt(quo));
							vp[0].float = root + octs + (b - a) * frac + a;
						}
					}
					i += n;
					continue;
				} else if (self.refParse(temp, s)) |f| {
					w.float = f;
				}
			}
			i += 1;
		}
	}

	fn anything(
		self: *const Arp,
		vec: []Word,
		sym: *Symbol, av: []const Atom,
	) !void {
		const s = sym.name;
		if (av.len == 0) {
			// check if it's `interval+semitone` syntax
			var end: usize = undefined;
			if (fParse(s, &end)) |f| {
				if (ops.get(s[end])) |op| {
					const g = fParse(s + end + 1, null) orelse 1;
					return self.out_f.float(op(vec[0].float + self.interval(vec, f), g));
				}
			}
			return self.list(vec, &.{ .symbol(sym) }, 0);
		}
		if (s[0] == '#') {
			return self.list(vec, av, iParse(s+1, null) orelse 0);
		}
		const argv = try gpa.alloc(Atom, av.len + 1);
		defer gpa.free(argv);
		argv[0] = .symbol(sym);
		@memcpy(argv[1..], av);
		try self.list(vec, argv, 0);
	}

	fn send(self: *const Arp, vec: []const Word, av: []const Atom) !void {
		const temp = try gpa.alloc(Word, vec.len);
		defer gpa.free(temp);
		@memcpy(temp, vec);

		if (av.len >= 2 and av[0].type == .symbol and av[0].w.symbol.name[0] == '#') {
			try self.list(temp, av[1..], iParse(av[0].w.symbol.name+1, null) orelse 0);
		} else if (av.len >= 1) {
			try self.list(temp, av, 0);
		}

		const atoms = try gpa.alloc(Atom, vec.len);
		defer gpa.free(atoms);
		for (atoms, temp) |*a, t| {
			a.* = .float(t.float);
		}
		self.out_l.list(null, atoms);
	}

	fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*anyopaque {
		return pd.wrap(*anyopaque, choose(av[0..ac]), name);
	}
	inline fn choose(av: []const Atom) !*anyopaque {
		if (av.len == 1 and av[0].type == .symbol) {
			return try ExArray.init(av[0].w.symbol);
		} else {
			return try InArray.init(av);
		}
	}

	inline fn setup() !void {
		errdefer ops.deinit(gpa);
		try ops.put(gpa, '+', opPlus);
		try ops.put(gpa, '^', opPlus);
		try ops.put(gpa, '-', opMinus);
		try ops.put(gpa, 'v', opMinus);
		try ops.put(gpa, '*', opTimes);
		try ops.put(gpa, '/', opOver);

		pd.addCreator(anyopaque, name, &.{ .gimme }, &initC);
		try InArray.setup();
		try ExArray.setup();
	}

	fn Impl(Self: type) type { return struct {
		fn octC(self: *Self, f: Float) callconv(.c) void {
			const arp: *Arp = &self.arp;
			arp.oct = f;
		}

		inline fn extend() void {
			const class: *pd.Class = Self.class;
			class.addMethod(@ptrCast(&octC), .gen("oct"), &.{ .float });
			class.setHelpSymbol(.gen("arp"));
		}
	};}
};

/// uses an internal array
const InArray = extern struct {
	obj: pd.Object = undefined,
	arp: Arp,
	win: WordInlets,

	const WordInlets = @import("winlet.zig").WordInlets;
	const name = "_arp_inarray";
	var class: *pd.Class = undefined;

	inline fn err(self: *const InArray, e: anyerror) void {
		pd.post.err(self, name ++ ": %s", .{ @errorName(e).ptr });
	}

	fn printC(self: *const InArray) callconv(.c) void {
		var writer: Writer = .fixed(&buffer);
		self.win.print(&writer) catch unreachable;
		wr.writeVec(&writer, self.win.items()) catch wr.ellipsis(&writer);
		buffer[writer.end] = 0;
		pd.post.log(self, .normal, "%s", .{ &buffer });
	}

	fn resizeC(self: *InArray, f: Float) callconv(.c) void {
		self.win.resize(@intFromFloat(@max(1, f))) catch |e| self.err(e);
	}

	fn floatC(self: *InArray, f: Float) callconv(.c) void {
		const vec = self.win.items();
		self.arp.out_f.float(vec[0].float + self.arp.interval(vec, f));
	}

	fn sendC(
		self: *const InArray,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		self.arp.send(self.win.items(), av[0..ac]) catch |e| self.err(e);
	}

	fn listC(
		self: *InArray,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		self.arp.list(self.win.items(), av[0..ac], 0) catch |e| self.err(e);
	}

	fn anythingC(
		self: *InArray,
		s: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		self.arp.anything(self.win.items(), s, av[0..ac]) catch |e| self.err(e);
	}

	fn symbolC(self: *InArray, s: *Symbol) callconv(.c) void {
		self.anythingC(s, 0, &.{});
	}

	inline fn init(av: []const Atom) !*InArray {
		const self: *InArray = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		self.* = .{
			.win = try .init(obj, if (av.len > 0) av else &.{ .float(69), .float(7) }),
			.arp = try .init(obj),
		};
		return self;
	}

	fn deinitC(self: *InArray) callconv(.c) void {
		self.win.deinit();
	}

	inline fn setup() !void {
		class = try .init(InArray, name, &.{}, null, &deinitC, .{});
		Arp.Impl(InArray).extend();
		class.addList(@ptrCast(&listC));
		class.addFloat(@ptrCast(&floatC));
		class.addSymbol(@ptrCast(&symbolC));
		class.addAnything(@ptrCast(&anythingC));
		class.addMethod(@ptrCast(&printC), .gen("print"), &.{});
		class.addMethod(@ptrCast(&resizeC), .gen("n"), &.{ .float });
		class.addMethod(@ptrCast(&resizeC), .gen("size"), &.{ .float });
		class.addMethod(@ptrCast(&sendC), .gen("send"), &.{ .gimme });
	}
};

/// uses an external array
const ExArray = extern struct {
	obj: pd.Object = undefined,
	arp: Arp,
	sym: *Symbol,

	const name = "_arp_exarray";
	var class: *pd.Class = undefined;

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

	fn floatC(self: *ExArray, f: Float) callconv(.c) void {
		self.float(f) catch |e| self.err(e);
	}
	inline fn float(self: ExArray, f: Float) !void {
		const vec = try (try self.garray()).floatWords();
		self.arp.out_f.float(vec[0].float + self.arp.interval(vec, f));
	}

	fn sendC(
		self: *const ExArray,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		self.send(av[0..ac]) catch |e| self.err(e);
	}
	inline fn send(self: *const ExArray, av: []const Atom) !void {
		const garr = try self.garray();
		defer garr.redraw();
		try self.arp.send(try garr.floatWords(), av);
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
		try self.arp.list(try garr.floatWords(), av, 0);
	}

	fn anythingC(
		self: *ExArray,
		s: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		self.anything(s, av[0..ac]) catch |e| self.err(e);
	}
	inline fn anything(self: *ExArray, s: *Symbol, av: []const Atom) !void {
		const garr = try self.garray();
		defer garr.redraw();
		try self.arp.anything(try garr.floatWords(), s, av);
	}

	fn symbolC(self: *ExArray, s: *Symbol) callconv(.c) void {
		self.anythingC(s, 0, &.{});
	}

	inline fn init(s: *Symbol) !*ExArray {
		const self: *ExArray = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inletSymbol(&self.sym);
		self.* = .{
			.arp = try .init(obj),
			.sym = s,
		};
		return self;
	}

	fn classFreeC(_: *pd.Class) callconv(.c) void {
		ops.deinit(gpa);
	}

	inline fn setup() !void {
		class = try .init(ExArray, name, &.{}, null, null, .{});
		Arp.Impl(ExArray).extend();
		class.addList(@ptrCast(&listC));
		class.addFloat(@ptrCast(&floatC));
		class.addSymbol(@ptrCast(&symbolC));
		class.addAnything(@ptrCast(&anythingC));
		class.addMethod(@ptrCast(&printC), .gen("print"), &.{});
		class.addMethod(@ptrCast(&resizeC), .gen("n"), &.{ .float });
		class.addMethod(@ptrCast(&resizeC), .gen("size"), &.{ .float });
		class.addMethod(@ptrCast(&sendC), .gen("send"), &.{ .gimme });
		class.setFreeFn(&classFreeC);
	}
};

export fn arp_setup() void {
	_ = pd.wrap(void, Arp.setup(), @src().fn_name);
}
