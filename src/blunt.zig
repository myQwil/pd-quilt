//! Objects that can be triggered by load/init/close bang events.
//! Objects based on pre-existing ones start with '`'

const std = @import("std");
const pd = @import("pd");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Class = pd.Class;
const Float = pd.Float;
const Object = pd.Object;
const Outlet = pd.Outlet;
const Symbol = pd.Symbol;

var s_blunt: *Symbol = undefined;

// ----------------------------------- Blunt -----------------------------------
// -----------------------------------------------------------------------------
const Blunt = extern struct {
	mask: u8 = 0,

	const name = "blunt";
	var class: *Class = undefined;
	const LB = pd.cnv.LoadBang;

	const LBChar = enum(u8) {
		load = '!',
		init = '$',
		close = '&',
		_,
	};

	fn init(av: []const Atom) Blunt {
		if (av.len == 0 or av[av.len - 1].type != .symbol) {
			return .{};
		}
		var mask: u8 = 0;
		const str = av[av.len - 1].w.symbol;
		for (std.mem.sliceTo(str.name, 0)) |c| {
			switch (@as(LBChar, @enumFromInt(c))) {
				.load => mask |= 1 << @intFromEnum(LB.load),
				.init => mask |= 1 << @intFromEnum(LB.init),
				.close => mask |= 1 << @intFromEnum(LB.close),
				_ => continue,
			}
		}
		return .{ .mask = mask };
	}

	fn initC() callconv(.c) ?*Pd {
		return pd.wrap(*Pd, boxInit(), name);
	}
	inline fn boxInit() !*Pd {
		const obj = try pd.gpa.create(Object);
		obj.* = .{ .g = .{ .pd = .{ .class = class } } };
		return &obj.g.pd;
	}

	inline fn setup() !void {
		pd.post.do("Blunt! v0.9", .{});
		class = try .init(Object, name, &.{}, initC, null, .{ .no_inlet = true });
	}

	pub fn Impl(Self: type) type { return struct {
		fn loadbangC(p: *Pd, f: Float) callconv(.c) void {
			const blunt: *Blunt = &Self.parentPtr(p).blunt;
			const action = @as(u8, 1) << @intFromFloat(f);
			if (blunt.mask & action != 0) {
				p.bang();
			}
		}

		inline fn extend(cls: *Class) void {
			cls.addMethod(&.{ .deffloat }, loadbangC, .gen("loadbang"));
			cls.setHelpSymbol(s_blunt);
		}
	};}
};


// ------------------------------ Binary operator ------------------------------
// -----------------------------------------------------------------------------
const BinOp = extern struct {
	obj: Object,
	out: *Outlet,
	f1: Float,
	f2: Float,
	blunt: Blunt,

	const Init = fn (*Class, []const Atom) anyerror!*Pd;
	const BluntImpl = Blunt.Impl(BinOp);
	const parentPtr = pd.parentPtr(BinOp);
	const parentConstPtr = pd.parentConstPtr(BinOp);

	fn printC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		pd.post.log(self, .normal, "%g %g", .{ self.f1, self.f2 });
	}

	fn f1C(p: *Pd, f: Float) callconv(.c) void {
		parentPtr(p).f1 = f;
	}

	fn f2C(p: *Pd, f: Float) callconv(.c) void {
		parentPtr(p).f2 = f;
	}

	fn setC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = parentPtr(p);
		sw: switch (@min(ac, 2)) {
			2 => { if (av[1].getFloat()) |f| self.f2 = f; continue :sw 1; },
			1 => { if (av[0].getFloat()) |f| self.f1 = f; },
			else => {},
		}
	}

	fn floatC(p: *Pd, f: Float) callconv(.c) void {
		parentPtr(p).f1 = f;
		p.bang();
	}

	fn listC(p: *Pd, s: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		setC(p, s, ac, av);
		p.bang();
	}

	fn anythingC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = parentPtr(p);
		self.f2 = pd.floatArg(0, av[0..ac]) catch self.f2;
		p.bang();
	}

	fn initBase(self: *BinOp, av: []const Atom) !void {
		const blunt: Blunt = .init(av);
		// last arg shouldn't be part of arg count if it was blunt's bit mask
		const n: usize = av.len - @intFromBool(blunt.mask != 0);

		// set f1 only if there are 2 args. otherwise, f2 gets priority.
		var f1: Float = 0;
		var f2: Float = 0;
		switch (n) {
			2 => {
				if (av[0].getFloat()) |f| f1 = f;
				if (av[1].getFloat()) |f| f2 = f;
			},
			1 => { if (av[0].getFloat()) |f| f2 = f; },
			else => {},
		}
		self.* = .{
			.obj = self.obj,
			.out = try .init(&self.obj, pd.s.float()),
			.blunt = blunt,
			.f1 = f1,
			.f2 = f2,
		};
	}

	fn initCold(class: *Class, av: []const Atom) !*Pd {
		const self: *BinOp = try pd.gpa.create(BinOp);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inletFloat(&self.f2);
		try self.initBase(av);
		return &obj.g.pd;
	}

	fn initHot(class: *Class, av: []const Atom) !*Pd {
		const self: *BinOp = try pd.gpa.create(BinOp);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inlet(&obj.g.pd, pd.s.float(), pd.s.anything());
		try self.initBase(av);
		return &obj.g.pd;
	}

	fn extend(class: *Class) void {
		class.addFloat(floatC);
		class.addList(listC);
		class.addAnything(anythingC);

		class.addMethod(&.{}, printC, .gen("print"));
		class.addMethod(&.{ .gimme }, setC, .gen("set"));
		class.addMethod(&.{ .float }, f1C, .gen("f1"));
		class.addMethod(&.{ .float }, f2C, .gen("f2"));
		BluntImpl.extend(class);
	}

	const Type = enum {
		/// will override any pre-existing object with the same name
		none,
		/// prevents overriding pre-existing object
		alias,
		/// reverse operands
		reverse_op,
		/// both inlets will trigger an output
		hot_inlets,
	};

	const Obj = struct {
		name: [:0]const u8,
		op: fn(Float, Float) callconv(.@"inline") Float,
	};

	fn Impl(comptime ob: Obj, comptime t: Type) type { return struct {
		var class: *Class = undefined;

		fn sendC(p: *Pd, s: *Symbol) callconv(.c) void {
			const self = parentPtr(p);
			const thing = s.thing
				orelse return pd.post.err(self, "%s: no such object", .{ s.name });
			thing.float(if (t == .reverse_op)
				ob.op(self.f2, self.f1)
			else
				ob.op(self.f1, self.f2));
		}

		fn bangC(p: *const Pd) callconv(.c) void {
			const self = parentConstPtr(p);
			self.out.float(if (t == .reverse_op)
				ob.op(self.f2, self.f1)
			else
				ob.op(self.f1, self.f2));
		}

		fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
			const init: Init = if (t == .hot_inlets) initHot else initCold;
			return pd.wrap(*Pd, init(class, av[0..ac]), ob.name);
		}

		fn setup() !void {
			const pre = switch (t) {
				.reverse_op => "@",
				.hot_inlets => "#",
				.alias      => "`",
				.none       => "",
			};
			class = try .init(BinOp, pre ++ ob.name, &.{ .gimme }, initC, null, .{});
			class.addBang(bangC);
			class.addMethod(&.{ .symbol }, sendC, .gen("send"));
			extend(class);
		}
	};}
};


// ------------------------------ Unary operator -------------------------------
// -----------------------------------------------------------------------------
const UnOp = extern struct {
	obj: Object,
	out: *Outlet,
	f: Float,
	blunt: Blunt,

	const BluntImpl = Blunt.Impl(UnOp);
	const parentPtr = pd.parentPtr(UnOp);
	const parentConstPtr = pd.parentConstPtr(UnOp);

	fn printC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		pd.post.log(self, .normal, "%g", .{ self.f });
	}

	fn setC(p: *Pd, f: Float) callconv(.c) void {
		parentPtr(p).f = f;
	}

	fn floatC(p: *Pd, f: Float) callconv(.c) void {
		parentPtr(p).f = f;
		p.bang();
	}

	fn symbolC(p: *Pd, s: *Symbol) callconv(.c) void {
		const f = std.fmt.parseFloat(Float, std.mem.sliceTo(s.name, 0)) catch {
			pd.post.err(p, "Couldn't convert %s to float.", .{ s.name });
			return;
		};
		floatC(p, f);
	}

	fn init(class: *Class, av: []const Atom) !*UnOp {
		const self: *UnOp = try pd.gpa.create(UnOp);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *Object = &self.obj;
		errdefer obj.g.pd.deinit();

		const blunt: Blunt = .init(av);
		const n: usize = av.len - @intFromBool(blunt.mask != 0);
		self.* = .{
			.obj = self.obj,
			.out = try .init(obj, pd.s.float()),
			.f = pd.floatArg(0, av[0..n]) catch 0,
			.blunt = blunt,
		};
		return self;
	}

	fn extend(class: *Class) void {
		class.addFloat(floatC);
		class.addSymbol(symbolC);

		class.addMethod(&.{}, printC, .gen("print"));
		class.addMethod(&.{ .float }, setC, .gen("set"));
		BluntImpl.extend(class);
	}

	const Type = struct {
		name: [:0]const u8,
		op: fn(Float) callconv(.@"inline") Float,
		inlet: bool = false,
		new: bool = false,
	};

	fn Impl(comptime t: Type) type { return struct {
		var class: *Class = undefined;

		fn sendC(p: *const Pd, s: *Symbol) callconv(.c) void {
			const self = parentConstPtr(p);
			const thing = s.thing
				orelse return pd.post.err(self, "%s: no such object", .{ s.name });
			thing.float(t.op(self.f));
		}

		fn bangC(p: *const Pd) callconv(.c) void {
			const self = parentConstPtr(p);
			self.out.float(t.op(self.f));
		}

		fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
			return pd.wrap(*Pd, implNew(av[0..ac]), t.name);
		}
		inline fn implNew(av: []const Atom) !*Pd {
			const self = try init(class, av);
			if (t.inlet) {
				_ = try self.obj.inletFloat(&self.f);
			}
			return &self.obj.g.pd;
		}

		fn setup() !void {
			const pre = if (t.new) "" else "`";
			class = try .init(UnOp, pre ++ t.name, &.{ .gimme }, initC, null, .{});
			class.addBang(bangC);
			class.addMethod(&.{ .symbol }, sendC, .gen("send"));
			extend(class);
		}
	};}
};


// ----------------------------------- Bang ------------------------------------
// -----------------------------------------------------------------------------
const Bang = extern struct {
	obj: Object,
	out: *Outlet,
	blunt: Blunt,

	const name = "`b";
	var class: *Class = undefined;
	const BluntImpl = Blunt.Impl(Bang);
	const parentPtr = pd.parentPtr(Bang);
	const parentConstPtr = pd.parentConstPtr(Bang);

	fn bangC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		self.out.bang();
	}

	fn floatC(p: *const Pd, _: Float) callconv(.c) void {
		bangC(p);
	}
	fn symbolC(p: *const Pd, _: *Symbol) callconv(.c) void {
		bangC(p);
	}
	fn listC(p: *Pd, _: *Symbol, _: c_uint, _: [*]const Atom) callconv(.c) void {
		bangC(p);
	}

	fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(av[0..ac]), name);
	}
	inline fn init(av: []const Atom) !*Pd {
		const self: *Bang = try pd.gpa.create(Bang);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *Object = &self.obj;
		errdefer obj.g.pd.deinit();

		self.* = .{
			.obj = self.obj,
			.out = try .init(obj, pd.s.bang()),
			.blunt = .init(av),
		};
		return &obj.g.pd;
	}

	inline fn setup() !void {
		class = try .init(Bang, name, &.{ .gimme }, initC, null, .{});
		class.addBang(bangC);
		class.addFloat(floatC);
		class.addSymbol(symbolC);
		class.addList(listC);
		class.addAnything(listC);
		BluntImpl.extend(class);
	}
};


// ---------------------------------- Symbol -----------------------------------
// -----------------------------------------------------------------------------
const Sym = extern struct {
	obj: Object,
	out: *Outlet,
	sym: *Symbol,
	blunt: Blunt,

	const name = "`s";
	var class: *Class = undefined;
	const BluntImpl = Blunt.Impl(Sym);
	const parentPtr = pd.parentPtr(Sym);
	const parentConstPtr = pd.parentConstPtr(Sym);

	fn printC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		pd.post.log(self, .normal, self.sym.name, .{});
	}

	fn bangC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		self.out.symbol(self.sym);
	}

	fn symbolC(p: *Pd, s: *Symbol) callconv(.c) void {
		parentPtr(p).sym = s;
		bangC(p);
	}

	fn listC(p: *Pd, s: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		if (ac == 0) {
			bangC(p);
		} else {
			symbolC(p, av[0].getSymbol() orelse s);
		}
	}

	fn anythingC(p: *Pd, s: *Symbol, _: c_uint, _: [*]const Atom) callconv(.c) void {
		symbolC(p, s);
	}

	fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(av[0..ac]), name);
	}
	inline fn init(av: []const Atom) !*Pd {
		const self: *Sym = try pd.gpa.create(Sym);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *Object = &self.obj;
		errdefer obj.g.pd.deinit();

		const blunt: Blunt = .init(av);
		const n: usize = av.len - @intFromBool(blunt.mask != 0);

		_ = try obj.inletSymbol(&self.sym);
		self.* = .{
			.obj = self.obj,
			.out = try .init(obj, pd.s.symbol()),
			.sym = pd.symbolArg(0, av[0..n]) catch pd.s.empty(),
			.blunt = blunt,
		};
		return &obj.g.pd;
	}

	inline fn setup() !void {
		class = try .init(Sym, name, &.{ .gimme }, initC, null, .{});
		class.addBang(bangC);
		class.addSymbol(symbolC);
		class.addList(listC);
		class.addAnything(anythingC);
		class.addMethod(&.{}, printC, .gen("print"));
		BluntImpl.extend(class);
	}
};


// -------------------------------- Operations ---------------------------------
// -----------------------------------------------------------------------------
const Int = @Int(.signed, @bitSizeOf(Float));

// binop1:  +  -  *  /  min  max  log  pow
inline fn plus(f1: Float, f2: Float) Float {
	return f1 + f2;
}
inline fn minus(f1: Float, f2: Float) Float {
	return f1 - f2;
}
inline fn times(f1: Float, f2: Float) Float {
	return f1 * f2;
}
inline fn over(f1: Float, f2: Float) Float {
	return if (f2 == 0) 0 else f1 / f2;
}
inline fn min(f1: Float, f2: Float) Float {
	return @min(f1, f2);
}
inline fn max(f1: Float, f2: Float) Float {
	return @max(f1, f2);
}

inline fn log(f1: Float, f2: Float) Float {
	return if (f2 <= 0)
		@log(f1)
	else std.math.log(Float, f2, f1);
}

inline fn pow(f1: Float, f2: Float) Float {
	const d2: Float = @floatFromInt(@as(Int, @intFromFloat(f2)));
	return if (f1 == 0 or (f1 < 0 and f2 - d2 != 0))
		0
	else std.math.pow(Float, f1, f2);
}

// binop2:  <  >  <=  >=  ==  !=
inline fn lt(f1: Float, f2: Float) Float {
	return @floatFromInt(@intFromBool(f1 < f2));
}
inline fn gt(f1: Float, f2: Float) Float {
	return @floatFromInt(@intFromBool(f1 > f2));
}
inline fn le(f1: Float, f2: Float) Float {
	return @floatFromInt(@intFromBool(f1 <= f2));
}
inline fn ge(f1: Float, f2: Float) Float {
	return @floatFromInt(@intFromBool(f1 >= f2));
}
inline fn ee(f1: Float, f2: Float) Float {
	return @floatFromInt(@intFromBool(f1 == f2));
}
inline fn ne(f1: Float, f2: Float) Float {
	return @floatFromInt(@intFromBool(f1 != f2));
}

// binop3:  &&  ||  &  |  ^  <<  >>  %  mod  div  f%  fmod
inline fn la(f1: Float, f2: Float) Float {
	return @floatFromInt(@intFromBool(f1 != 0 and f2 != 0));
}
inline fn lo(f1: Float, f2: Float) Float {
	return @floatFromInt(@intFromBool(f1 != 0 or f2 != 0));
}
inline fn ba(f1: Float, f2: Float) Float {
	return @floatFromInt(@as(Int, @intFromFloat(f1)) & @as(Int, @intFromFloat(f2)));
}
inline fn bo(f1: Float, f2: Float) Float {
	 return @floatFromInt(@as(Int, @intFromFloat(f1)) | @as(Int, @intFromFloat(f2)));
}
inline fn bx(f1: Float, f2: Float) Float {
	 return @floatFromInt(@as(Int, @intFromFloat(f1)) ^ @as(Int, @intFromFloat(f2)));
}
inline fn ls(f1: Float, f2: Float) Float {
	 return @floatFromInt(@as(Int, @intFromFloat(f1)) << @intFromFloat(f2));
}
inline fn rs(f1: Float, f2: Float) Float {
	 return @floatFromInt(@as(Int, @intFromFloat(f1)) >> @intFromFloat(f2));
}

inline fn rem(f1: Float, f2: Float) Float {
	const n2: Int = @intFromFloat(@max(1, @abs(f2)));
	return @floatFromInt(@rem(@as(Int, @intFromFloat(f1)), n2));
}
inline fn mod(f1: Float, f2: Float) Float {
	const n2: Int = @intFromFloat(@max(1, @abs(f2)));
	return @floatFromInt(@mod(@as(Int, @intFromFloat(f1)), n2));
}
inline fn div(f1: Float, f2: Float) Float {
	const n2: Int = @intFromFloat(@max(1, @abs(f2)));
	return @floatFromInt(@divFloor(@as(Int, @intFromFloat(f1)), n2));
}

inline fn frem(f1: Float, f2: Float) Float {
	return @rem(f1, if (f2 == 0) 1 else @abs(f2));
}
inline fn fmod(f1: Float, f2: Float) Float {
	return @mod(f1, if (f2 == 0) 1 else @abs(f2));
}
inline fn atan2(f1: Float, f2: Float) Float {
	return std.math.atan2(f1, f2);
}

// // unop:  f  i  !  ~  floor  ceil  factorial
inline fn float(f: Float) Float {
	return f;
}
inline fn int(f: Float) Float {
	return @floatFromInt(@as(Int, @intFromFloat(f)));
}
inline fn floor(f: Float) Float {
	return @floor(f);
}
inline fn ceil(f: Float) Float {
	return @ceil(f);
}
inline fn bnot(f: Float) Float {
	return @floatFromInt(~@as(Int, @intFromFloat(f)));
}
inline fn lnot(f: Float) Float {
	return @floatFromInt(@intFromBool(f == 0));
}
inline fn fact(f: Float) Float {
	return std.math.gamma(Float, f + 1);
}

inline fn sin(f: Float) Float {
	return @sin(f);
}
inline fn cos(f: Float) Float {
	return @cos(f);
}
inline fn tan(f: Float) Float {
	return @tan(f);
}
inline fn atan(f: Float) Float {
	return std.math.atan(f);
}
inline fn sqrt(f: Float) Float {
	return if (f > 0) @sqrt(f) else 0;
}
inline fn exp(f: Float) Float {
	return @exp(f);
}
inline fn abs(f: Float) Float {
	return @abs(f);
}
inline fn exp2(f: Float) Float {
	return @exp2(f);
}
inline fn log2(f: Float) Float {
	return @log2(f);
}

export fn blunt_setup() void {
	_ = pd.wrap(void, setup(), @src().fn_name);
}
inline fn setup() !void {
	s_blunt = .gen(Blunt.name);

	// Describes the object and which variants to make
	const BinOpPlan = struct {
		ob: BinOp.Obj,
		rev: bool = false,
		/// true if there is no pre-existing object with the same name
		uniq: bool = false,
	};

	inline for ([_]BinOpPlan{
		.{ .ob = .{ .name = "+",     .op = plus } },
		.{ .ob = .{ .name = "*",     .op = times } },
		.{ .ob = .{ .name = "min",   .op = min } },
		.{ .ob = .{ .name = "max",   .op = max } },
		.{ .ob = .{ .name = "<",     .op = lt } },
		.{ .ob = .{ .name = ">",     .op = gt } },
		.{ .ob = .{ .name = "<=",    .op = le } },
		.{ .ob = .{ .name = ">=",    .op = ge } },
		.{ .ob = .{ .name = "==",    .op = ee } },
		.{ .ob = .{ .name = "!=",    .op = ne } },
		.{ .ob = .{ .name = "&&",    .op = la } },
		.{ .ob = .{ .name = "||",    .op = lo } },
		.{ .ob = .{ .name = "&",     .op = ba } },
		.{ .ob = .{ .name = "|",     .op = bo } },
		.{ .ob = .{ .name = "^",     .op = bx }, .uniq = true },
		.{ .ob = .{ .name = "-",     .op = minus }, .rev = true },
		.{ .ob = .{ .name = "/",     .op = over },  .rev = true },
		.{ .ob = .{ .name = "log",   .op = log },   .rev = true },
		.{ .ob = .{ .name = "pow",   .op = pow },   .rev = true },
		.{ .ob = .{ .name = "<<",    .op = ls },    .rev = true },
		.{ .ob = .{ .name = ">>",    .op = rs },    .rev = true },
		.{ .ob = .{ .name = "%",     .op = rem },   .rev = true },
		.{ .ob = .{ .name = "mod",   .op = mod },   .rev = true },
		.{ .ob = .{ .name = "div",   .op = div },   .rev = true },
		.{ .ob = .{ .name = "atan2", .op = atan2 }, .rev = true },
		.{ .ob = .{ .name = "f%",    .op = frem },  .rev = true, .uniq = true },
		.{ .ob = .{ .name = "fmod",  .op = fmod },  .rev = true, .uniq = true },
	}) |p| {
		try BinOp.Impl(p.ob, if (p.uniq) .none else .alias).setup();
		try BinOp.Impl(p.ob, .hot_inlets).setup();
		if (p.rev) {
			try BinOp.Impl(p.ob, .reverse_op).setup();
		}
	}

	inline for ([_]UnOp.Type{
		.{ .name = "f",     .op = float, .inlet = true },
		.{ .name = "i",     .op = int,   .inlet = true },
		.{ .name = "sin",   .op = sin },
		.{ .name = "cos",   .op = cos },
		.{ .name = "tan",   .op = tan },
		.{ .name = "atan",  .op = atan },
		.{ .name = "sqrt",  .op = sqrt },
		.{ .name = "exp",   .op = exp },
		.{ .name = "abs",   .op = abs },
		.{ .name = "floor", .op = floor, .new = true },
		.{ .name = "ceil",  .op = ceil,  .new = true },
		.{ .name = "~",     .op = bnot,  .new = true },
		.{ .name = "!",     .op = lnot,  .new = true },
		.{ .name = "n!",    .op = fact,  .new = true },
		.{ .name = "exp2",  .op = exp2,  .new = true },
		.{ .name = "log2",  .op = log2,  .new = true },
	}) |t| {
		try UnOp.Impl(t).setup();
	}

	try Bang.setup();
	try Sym.setup();
	try Blunt.setup();
}
