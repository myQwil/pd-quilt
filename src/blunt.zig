const std = @import("std");
const pd = @import("pd");
const LB = pd.canvas.LoadBang;
var blunt_class: *pd.Class = undefined;

const pi = std.math.pi;
const atan = std.math.atan;
const atan2 = std.math.atan2;
const strlen = std.mem.len;

// ----------------------------------- Blunt -----------------------------------
// -----------------------------------------------------------------------------
const Blunt = extern struct {
	const Self = @This();

	// "loadbang" actions - 0 for original meaning
	const c_load: u8 = '!';
	// loaded but not yet connected to parent patch
	const c_init: u8 = '$';
	// about to close
	const c_close: u8 = '&';

	obj: pd.Object,
	out: *pd.Outlet,
	mask: u8,

	fn loadbang(self: *Self, f: pd.Float) void {
		const action = @as(u8, 1) << @intFromFloat(f);
		if (self.mask & action != 0) {
			self.obj.g.pd.bang();
		}
	}

	fn init(self: *Self, ac: c_uint, av: [*]const pd.Atom) u32 {
		self.mask = 0;
		if (ac >= 1 and av[ac - 1].type == .symbol) {
			const str = av[ac - 1].w.symbol.name;
			var i: usize = 0;
			while (str[i] != '\x00') : (i += 1) {
				switch (str[i]) {
					c_load => self.mask |= 1 << @intFromEnum(LB.load),
					c_init => self.mask |= 1 << @intFromEnum(LB.init),
					c_close => self.mask |= 1 << @intFromEnum(LB.close),
					else => break,
				}
			}
		}
		return ac - @intFromBool(self.mask != 0);
	}

	fn extend(class: *pd.Class) void {
		class.addMethod(@ptrCast(&loadbang), pd.symbol("loadbang"), &.{ .deffloat });
	}
};


// ------------------------------ Binary operator ------------------------------
// -----------------------------------------------------------------------------
const BinOp = extern struct {
	const Self = @This();
	const Op = *const fn(pd.Float, pd.Float) pd.Float;

	base: Blunt,
	f1: pd.Float,
	f2: pd.Float,

	fn print(self: *const Self) void {
		pd.post.log(self, .normal, "%g %g", self.f1, self.f2);
	}

	fn setF1(self: *Self, f: pd.Float) void {
		self.f1 = f;
	}

	fn setF2(self: *Self, f: pd.Float) void {
		self.f2 = f;
	}

	fn set(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		if (ac >= 2 and av[1].type == .float) {
			self.f2 = av[1].w.float;
		}
		if (ac >= 1 and av[0].type == .float) {
			self.f1 = av[0].w.float;
		}
	}

	fn op(self: *const Self) Op {
		const class: *const *pd.Class = @ptrCast(self);
		return @as(Op, @ptrCast(class.*.methods[0].fun));
	}

	fn send(self: *Self, s: pd.Symbol) void {
		const thing = s.thing
			orelse return pd.post.err(self, "%s: no such object", s.name);
		thing.float(self.op()(self.f1, self.f2));
	}

	fn revSend(self: *Self, s: pd.Symbol) void {
		const thing = s.thing
			orelse return pd.post.err(self, "%s: no such object", s.name);
		thing.float(self.op()(self.f2, self.f1));
	}

	fn bang(self: *const Self) void {
		self.base.out.float(self.op()(self.f1, self.f2));
	}

	fn revBang(self: *const Self) void {
		self.base.out.float(self.op()(self.f2, self.f1));
	}

	fn float(self: *Self, f: pd.Float) void {
		self.f1 = f;
		@as(*pd.Pd, @ptrCast(self)).bang();
	}

	fn list(self: *Self, s: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		self.set(s, ac, av);
		@as(*pd.Pd, @ptrCast(self)).bang();
	}

	fn anything(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		if (ac >= 1 and av[0].type == .float) {
			self.f2 = av[0].w.float;
		}
		@as(*pd.Pd, @ptrCast(self)).bang();
	}

	fn init(self: *Self, ac: c_uint, av: [*]const pd.Atom) void {
		const n = self.base.init(ac, av);
		self.base.out = self.base.obj.outlet(pd.s.float).?;

		// set the 1st float, but only if there are 2 args
		switch (n) {
			2 => {
				self.f1 = av[0].float();
				self.f2 = av[1].float();
			},
			1 => self.f2 = av[0].float(),
			else => {},
		}
	}

	fn new(cl: *pd.Class, ac: c_uint, av: [*]const pd.Atom) ?*Self {
		const self: *Self = @ptrCast(cl.new() orelse return null);
		_ = self.base.obj.inletFloat(&self.f2);
		self.init(ac, av);
		return self;
	}

	fn hotNew(cl: *pd.Class, ac: c_uint, av: [*]const pd.Atom) ?*Self {
		const self: *Self = @ptrCast(cl.new() orelse return null);
		const obj = &self.base.obj;
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.s.anything);
		self.init(ac, av);
		return self;
	}

	const Pkg = struct {
		class: [2]*pd.Class = undefined,
		name: []const u8,
		new: *const fn(*pd.Symbol, u32, [*]const pd.Atom) ?*Self,
		op: Op,
		rev: bool = false,

		fn gen(pack: *Pkg, s: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) ?*Self {
			return switch (s.name[0]) {
				'#' => Self.hotNew(pack.class[0], ac, av),
				'@' => Self.new(pack.class[1], ac, av),
				else => Self.new(pack.class[0], ac, av),
			};
		}

		fn setup(self: *Pkg, s: *pd.Symbol) *pd.Class {
			const cl = pd.class(s, @ptrCast(self.new), null,
				@sizeOf(Self), .{}, &.{ .gimme }).?;
			cl.addFloat(@ptrCast(&float));
			cl.addList(@ptrCast(&list));
			cl.addAnything(@ptrCast(&anything));

			cl.addMethod(@ptrCast(self.op), pd.s._, &.{});
			cl.addMethod(@ptrCast(&print), pd.symbol("print"), &.{});
			cl.addMethod(@ptrCast(&setF1), pd.symbol("f1"), &.{ .float });
			cl.addMethod(@ptrCast(&setF2), pd.symbol("f2"), &.{ .float });
			cl.addMethod(@ptrCast(&set), pd.symbol("set"), &.{ .gimme });
			cl.setHelpSymbol(pd.symbol("blunt"));
			Blunt.extend(cl);
			return cl;
		}
	};
};


// ------------------------------ Unary operator -------------------------------
// -----------------------------------------------------------------------------
const UnOp = extern struct {
	const Self = @This();
	const Op = *const fn(pd.Float) pd.Float;
	const parse = std.fmt.parseFloat;

	base: Blunt,
	f: pd.Float,

	fn print(self: *const Self) void {
		pd.post.log(self, .normal, "%g", self.f);
	}

	fn set(self: *Self, f: pd.Float) void {
		self.f = f;
	}

	fn op(self: *const Self) Op {
		const class: *const *pd.Class = @ptrCast(self);
		return @as(Op, @ptrCast(class.*.methods[0].fun));
	}

	fn send(self: *const Self, s: pd.Symbol) void {
		const thing = s.thing
			orelse return pd.post.err(self, "%s: no such object", s.name);
		thing.float(self.op()(self.f));
	}

	fn bang(self: *const Self) void {
		self.base.out.float(self.op()(self.f));
	}

	fn float(self: *Self, f: pd.Float) void {
		self.f = f;
		@as(*pd.Pd, @ptrCast(self)).bang();
	}

	fn symbol(self: *Self, s: pd.Symbol) void {
		const f = parse(pd.Float, s.name[0..strlen(s.name)]) catch {
			pd.post.err(self, "Couldn't convert %s to float.", s.name);
			return;
		};
		self.float(f);
	}

	const Pkg = struct {
		class: *pd.Class = undefined,
		name: []const u8,
		new: *const fn(*pd.Symbol, u32, [*]const pd.Atom) ?*Self,
		op: Op,
		inlet: bool = false,
		alias: bool = true,

		fn gen(pack: *Pkg, ac: c_uint, av: [*]const pd.Atom) ?*Self {
			const self: *Self = @ptrCast(pack.class.new() orelse return null);
			const obj: *pd.Object = @ptrCast(self);
			if (pack.inlet) {
				_ = obj.inletFloat(&self.f);
			}
			self.base.out = obj.outlet(pd.s.float).?;
			self.f = pd.floatArg(av[0..self.base.init(ac, av)], 0);
			return self;
		}

		fn setup(self: *Pkg) *pd.Class {
			const cl = pd.class(pd.symbol(@ptrCast(self.name)), @ptrCast(self.new), null,
				@sizeOf(Self), .{}, &.{ .gimme }).?;
			cl.addBang(@ptrCast(&bang));
			cl.addFloat(@ptrCast(&float));
			cl.addSymbol(@ptrCast(&symbol));

			cl.addMethod(@ptrCast(self.op), pd.s._, &.{});
			cl.addMethod(@ptrCast(&print), pd.symbol("print"), &.{});
			cl.addMethod(@ptrCast(&set), pd.symbol("set"), &.{ .float });
			cl.addMethod(@ptrCast(&send), pd.symbol("send"), &.{ .symbol });
			cl.setHelpSymbol(pd.symbol("blunt"));
			Blunt.extend(cl);
			return cl;
		}
	};
};


// ----------------------------------- Bang ------------------------------------
// -----------------------------------------------------------------------------
const Bang = extern struct {
	const Self = Blunt;
	var class: *pd.Class = undefined;

	fn bang(self: *const Self) void {
		self.out.bang();
	}

	fn new(_: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) ?*Self {
		const self: *Self = @ptrCast(class.new() orelse return null);
		_ = self.init(ac, av);
		self.out = self.obj.outlet(pd.s.bang).?;
		return self;
	}

	fn setup() void {
		const bnew: pd.NewMethod = @ptrCast(&new);
		class = pd.class(pd.symbol("b"), bnew, null,
			@sizeOf(Self), .{}, &.{ .gimme }).?;
		pd.addCreator(bnew, pd.symbol("`b"), &.{ .gimme });
		class.addBang(@ptrCast(&bang));
		class.addFloat(@ptrCast(&bang));
		class.addSymbol(@ptrCast(&bang));
		class.addList(@ptrCast(&bang));
		class.addAnything(@ptrCast(&bang));

		Blunt.extend(class);
		class.setHelpSymbol(pd.symbol("blunt"));
	}
};


// ---------------------------------- Symbol -----------------------------------
// -----------------------------------------------------------------------------
const Symbol = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	base: Blunt,
	sym: *pd.Symbol,

	fn print(self: *const Self) void {
		pd.post.log(self, .normal, "%s", self.sym.name);
	}

	fn bang(self: *const Self) void {
		self.base.out.symbol(self.sym);
	}

	fn symbol(self: *Self, s: *pd.Symbol) void {
		self.sym = s;
		self.bang();
	}

	fn list(self: *Self, s: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		if (ac == 0) {
			self.bang();
		} else if (av[0].type == .symbol) {
			self.symbol(av[0].w.symbol);
		} else {
			self.symbol(s);
		}
	}

	fn new(_: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) ?*Self {
		const self: *Self = @ptrCast(class.new() orelse return null);
		self.sym = pd.symbolArg(av[0..self.base.init(ac, av)], 0);
		self.base.out = self.base.obj.outlet(pd.s.symbol).?;
		_ = self.base.obj.inletSymbol(&self.sym);
		return self;
	}

	fn setup() void {
		const bnew: pd.NewMethod = @ptrCast(&new);
		class = pd.class(pd.symbol("sym"), bnew, null,
			@sizeOf(Self), .{}, &.{ .gimme }).?;
		class.addBang(@ptrCast(&bang));
		class.addSymbol(@ptrCast(&symbol));
		class.addList(@ptrCast(&list));
		class.addAnything(@ptrCast(&symbol));
		class.addMethod(@ptrCast(&print), pd.symbol("print"), &.{});

		Blunt.extend(class);
		class.setHelpSymbol(pd.symbol("blunt"));
	}
};


// --------------------------------- Packages ----------------------------------
// -----------------------------------------------------------------------------
var pkg_plus  = BinOp.Pkg { .name="+",     .new=plusNew,  .op=plusOp };
var pkg_minus = BinOp.Pkg { .name="-",     .new=minusNew, .op=minusOp, .rev=true };
var pkg_times = BinOp.Pkg { .name="*",     .new=timesNew, .op=timesOp };
var pkg_over  = BinOp.Pkg { .name="/",     .new=overNew,  .op=overOp,  .rev=true };
var pkg_min   = BinOp.Pkg { .name="min",   .new=minNew,   .op=minOp };
var pkg_max   = BinOp.Pkg { .name="max",   .new=maxNew,   .op=maxOp };
var pkg_log   = BinOp.Pkg { .name="log",   .new=logNew,   .op=logOp,   .rev=true };
var pkg_pow   = BinOp.Pkg { .name="pow",   .new=powNew,   .op=powOp,   .rev=true };
var pkg_lt    = BinOp.Pkg { .name="<",     .new=ltNew,    .op=ltOp };
var pkg_gt    = BinOp.Pkg { .name=">",     .new=gtNew,    .op=gtOp };
var pkg_le    = BinOp.Pkg { .name="<=",    .new=leNew,    .op=leOp };
var pkg_ge    = BinOp.Pkg { .name=">=",    .new=geNew,    .op=geOp };
var pkg_ee    = BinOp.Pkg { .name="==",    .new=eeNew,    .op=eeOp };
var pkg_ne    = BinOp.Pkg { .name="!=",    .new=neNew,    .op=neOp };
var pkg_la    = BinOp.Pkg { .name="&&",    .new=laNew,    .op=laOp };
var pkg_lo    = BinOp.Pkg { .name="||",    .new=loNew,    .op=loOp };
var pkg_ba    = BinOp.Pkg { .name="&",     .new=baNew,    .op=baOp };
var pkg_bo    = BinOp.Pkg { .name="|",     .new=boNew,    .op=boOp };
var pkg_bx    = BinOp.Pkg { .name="^",     .new=bxNew,    .op=bxOp };
var pkg_ls    = BinOp.Pkg { .name="<<",    .new=lsNew,    .op=lsOp,    .rev=true };
var pkg_rs    = BinOp.Pkg { .name=">>",    .new=rsNew,    .op=rsOp,    .rev=true };
var pkg_rem   = BinOp.Pkg { .name="%",     .new=remNew,   .op=remOp,   .rev=true };
var pkg_mod   = BinOp.Pkg { .name="mod",   .new=modNew,   .op=modOp,   .rev=true };
var pkg_div   = BinOp.Pkg { .name="div",   .new=divNew,   .op=divOp,   .rev=true };
var pkg_frem  = BinOp.Pkg { .name="f%",    .new=fremNew,  .op=fremOp,  .rev=true };
var pkg_fmod  = BinOp.Pkg { .name="fmod",  .new=fmodNew,  .op=fmodOp,  .rev=true };
var pkg_atan2 = BinOp.Pkg { .name="atan2", .new=atan2New, .op=atan2Op, .rev=true };

var pkg_f     = UnOp.Pkg { .name="f",     .new=fNew,     .op=fOp,     .inlet=true };
var pkg_i     = UnOp.Pkg { .name="i",     .new=iNew,     .op=iOp,     .inlet=true };
var pkg_floor = UnOp.Pkg { .name="floor", .new=floorNew, .op=floorOp, .alias=false };
var pkg_ceil  = UnOp.Pkg { .name="ceil",  .new=ceilNew,  .op=ceilOp,  .alias=false };
var pkg_bnot  = UnOp.Pkg { .name="~",     .new=bnotNew,  .op=bnotOp,  .alias=false };
var pkg_lnot  = UnOp.Pkg { .name="!",     .new=lnotNew,  .op=lnotOp,  .alias=false };
var pkg_fact  = UnOp.Pkg { .name="n!",    .new=factNew,  .op=factOp,  .alias=false };
var pkg_sin   = UnOp.Pkg { .name="sin",   .new=sinNew,   .op=sinOp };
var pkg_cos   = UnOp.Pkg { .name="cos",   .new=cosNew,   .op=cosOp };
var pkg_tan   = UnOp.Pkg { .name="tan",   .new=tanNew,   .op=tanOp };
var pkg_atan  = UnOp.Pkg { .name="atan",  .new=atanNew,  .op=atanOp };
var pkg_sqrt  = UnOp.Pkg { .name="sqrt",  .new=sqrtNew,  .op=sqrtOp };
var pkg_exp   = UnOp.Pkg { .name="exp",   .new=expNew,   .op=expOp };
var pkg_abs   = UnOp.Pkg { .name="abs",   .new=absNew,   .op=absOp };


// -------------------------------- New methods --------------------------------
// -----------------------------------------------------------------------------
const S = *pd.Symbol;
const Ac = u32;
const Av = [*]const pd.Atom;
fn plusNew(s: S, ac: Ac, av: Av)  ?*BinOp { return pkg_plus.gen(s, ac, av); }
fn minusNew(s: S, ac: Ac, av: Av) ?*BinOp { return pkg_minus.gen(s, ac, av); }
fn timesNew(s: S, ac: Ac, av: Av) ?*BinOp { return pkg_times.gen(s, ac, av); }
fn overNew(s: S, ac: Ac, av: Av)  ?*BinOp { return pkg_over.gen(s, ac, av); }
fn minNew(s: S, ac: Ac, av: Av)   ?*BinOp { return pkg_min.gen(s, ac, av); }
fn maxNew(s: S, ac: Ac, av: Av)   ?*BinOp { return pkg_max.gen(s, ac, av); }
fn logNew(s: S, ac: Ac, av: Av)   ?*BinOp { return pkg_log.gen(s, ac, av); }
fn powNew(s: S, ac: Ac, av: Av)   ?*BinOp { return pkg_pow.gen(s, ac, av); }
fn ltNew(s: S, ac: Ac, av: Av)    ?*BinOp { return pkg_lt.gen(s, ac, av); }
fn gtNew(s: S, ac: Ac, av: Av)    ?*BinOp { return pkg_gt.gen(s, ac, av); }
fn leNew(s: S, ac: Ac, av: Av)    ?*BinOp { return pkg_le.gen(s, ac, av); }
fn geNew(s: S, ac: Ac, av: Av)    ?*BinOp { return pkg_ge.gen(s, ac, av); }
fn eeNew(s: S, ac: Ac, av: Av)    ?*BinOp { return pkg_ee.gen(s, ac, av); }
fn neNew(s: S, ac: Ac, av: Av)    ?*BinOp { return pkg_ne.gen(s, ac, av); }
fn laNew(s: S, ac: Ac, av: Av)    ?*BinOp { return pkg_la.gen(s, ac, av); }
fn loNew(s: S, ac: Ac, av: Av)    ?*BinOp { return pkg_lo.gen(s, ac, av); }
fn baNew(s: S, ac: Ac, av: Av)    ?*BinOp { return pkg_ba.gen(s, ac, av); }
fn boNew(s: S, ac: Ac, av: Av)    ?*BinOp { return pkg_bo.gen(s, ac, av); }
fn bxNew(s: S, ac: Ac, av: Av)    ?*BinOp { return pkg_bx.gen(s, ac, av); }
fn lsNew(s: S, ac: Ac, av: Av)    ?*BinOp { return pkg_ls.gen(s, ac, av); }
fn rsNew(s: S, ac: Ac, av: Av)    ?*BinOp { return pkg_rs.gen(s, ac, av); }
fn remNew(s: S, ac: Ac, av: Av)   ?*BinOp { return pkg_rem.gen(s, ac, av); }
fn modNew(s: S, ac: Ac, av: Av)   ?*BinOp { return pkg_mod.gen(s, ac, av); }
fn divNew(s: S, ac: Ac, av: Av)   ?*BinOp { return pkg_div.gen(s, ac, av); }
fn fremNew(s: S, ac: Ac, av: Av)  ?*BinOp { return pkg_frem.gen(s, ac, av); }
fn fmodNew(s: S, ac: Ac, av: Av)  ?*BinOp { return pkg_fmod.gen(s, ac, av); }
fn atan2New(s: S, ac: Ac, av: Av) ?*BinOp { return pkg_atan2.gen(s, ac, av); }

fn fNew(_: S, ac: Ac, av: Av)     ?*UnOp { return pkg_f.gen(ac, av); }
fn iNew(_: S, ac: Ac, av: Av)     ?*UnOp { return pkg_i.gen(ac, av); }
fn floorNew(_: S, ac: Ac, av: Av) ?*UnOp { return pkg_floor.gen(ac, av); }
fn ceilNew(_: S, ac: Ac, av: Av)  ?*UnOp { return pkg_ceil.gen(ac, av); }
fn bnotNew(_: S, ac: Ac, av: Av)  ?*UnOp { return pkg_bnot.gen(ac, av); }
fn lnotNew(_: S, ac: Ac, av: Av)  ?*UnOp { return pkg_lnot.gen(ac, av); }
fn factNew(_: S, ac: Ac, av: Av)  ?*UnOp { return pkg_fact.gen(ac, av); }
fn sinNew(_: S, ac: Ac, av: Av)   ?*UnOp { return pkg_sin.gen(ac, av); }
fn cosNew(_: S, ac: Ac, av: Av)   ?*UnOp { return pkg_cos.gen(ac, av); }
fn tanNew(_: S, ac: Ac, av: Av)   ?*UnOp { return pkg_tan.gen(ac, av); }
fn atanNew(_: S, ac: Ac, av: Av)  ?*UnOp { return pkg_atan.gen(ac, av); }
fn sqrtNew(_: S, ac: Ac, av: Av)  ?*UnOp { return pkg_sqrt.gen(ac, av); }
fn expNew(_: S, ac: Ac, av: Av)   ?*UnOp { return pkg_exp.gen(ac, av); }
fn absNew(_: S, ac: Ac, av: Av)   ?*UnOp { return pkg_abs.gen(ac, av); }


// -------------------------------- Operations ---------------------------------
// -----------------------------------------------------------------------------
const F = pd.Float;
// binop1:  +  -  *  /  min  max  log  pow
fn plusOp(f1: F, f2: F) F { return f1 + f2; }
fn minusOp(f1: F, f2: F) F { return f1 - f2; }
fn timesOp(f1: F, f2: F) F { return f1 * f2; }
fn overOp(f1: F, f2: F) F { return if (f2 == 0) 0 else f1 / f2; }
fn minOp(f1: F, f2: F) F { return @min(f1, f2); }
fn maxOp(f1: F, f2: F) F { return @max(f1, f2); }
fn logOp(f1: F, f2: F) F {
	return if (f1 <= 0) -1000
		else if (f2 <= 0) @log(f1)
		else @log2(f1) / @log2(f2);
}
fn powOp(f1: F, f2: F) F {
	const d2: F = @floatFromInt(@as(i32, @intFromFloat(f2)));
	return if (f1 == 0 or (f1 < 0 and f2 - d2 != 0))
		0 else @exp2(@log2(f1) * f2);
}

// binop2:  <  >  <=  >=  ==  !=
fn ltOp(f1: F, f2: F) F { return @floatFromInt(@intFromBool(f1 < f2)); }
fn gtOp(f1: F, f2: F) F { return @floatFromInt(@intFromBool(f1 > f2)); }
fn leOp(f1: F, f2: F) F { return @floatFromInt(@intFromBool(f1 <= f2)); }
fn geOp(f1: F, f2: F) F { return @floatFromInt(@intFromBool(f1 >= f2)); }
fn eeOp(f1: F, f2: F) F { return @floatFromInt(@intFromBool(f1 == f2)); }
fn neOp(f1: F, f2: F) F { return @floatFromInt(@intFromBool(f1 != f2)); }

// binop3:  &&  ||  &  |  ^  <<  >>  %  mod  div  f%  fmod
fn laOp(f1: F, f2: F) F { return @floatFromInt(@intFromBool(f1 != 0 and f2 != 0)); }
fn loOp(f1: F, f2: F) F { return @floatFromInt(@intFromBool(f1 != 0 or f2 != 0)); }
fn baOp(f1: F, f2: F) F
{ return @floatFromInt(@as(i32, @intFromFloat(f1)) & @as(i32, @intFromFloat(f2))); }
fn boOp(f1: F, f2: F) F
{ return @floatFromInt(@as(i32, @intFromFloat(f1)) | @as(i32, @intFromFloat(f2))); }
fn bxOp(f1: F, f2: F) F
{ return @floatFromInt(@as(i32, @intFromFloat(f1)) ^ @as(i32, @intFromFloat(f2))); }
fn lsOp(f1: F, f2: F) F
{ return @floatFromInt(@as(i32, @intFromFloat(f1)) << @intFromFloat(f2)); }
fn rsOp(f1: F, f2: F) F
{ return @floatFromInt(@as(i32, @intFromFloat(f1)) >> @intFromFloat(f2)); }

fn remOp(f1: F, f2: F) F {
	const n2: i32 = @intFromFloat(@max(1, @abs(f2)));
	return @floatFromInt(@rem(@as(i32, @intFromFloat(f1)), n2));
}
fn modOp(f1: F, f2: F) F {
	const n2: i32 = @intFromFloat(@max(1, @abs(f2)));
	return @floatFromInt(@mod(@as(i32, @intFromFloat(f1)), n2));
}
fn divOp(f1: F, f2: F) F {
	const n2: i32 = @intFromFloat(@max(1, @abs(f2)));
	return @floatFromInt(@divFloor(@as(i32, @intFromFloat(f1)), n2));
}
fn fremOp(f1: F, f: F) F {
	const f2 = if (f == 0) 1 else @abs(f);
	return @rem(f1, f2);
}
fn fmodOp(f1: F, f: F) F {
	const f2 = if (f == 0) 1 else @abs(f);
	return @mod(f1, f2);
}
fn atan2Op(f1: F, f2: F) F {
	return if (f1 == 0 and f2 == 0) 0 else atan2(f1, f2);
}

// // unop:  f  i  !  ~  floor  ceil  factorial
fn fOp(f: F) F { return f; }
fn iOp(f: F) F { return @floatFromInt(@as(i32, @intFromFloat(f))); }
fn floorOp(f: F) F { return @floor(f); }
fn ceilOp(f: F) F { return @ceil(f); }
fn bnotOp(f: F) F { return @floatFromInt(~@as(i32, @intFromFloat(f))); }
fn lnotOp(f: F) F { return @floatFromInt(@intFromBool(f == 0)); }

fn factOp(f: F) F {
	var d = @floor(f);
	if (d > 9) {
		// stirling's approximation
		return @exp2(@log2(f) * f) * @exp(-f) * @sqrt(f) * @sqrt(2 * pi);
	}
	var g: pd.Float = 1;
	while (d > 0) : (d -= 1) {
		g *= d;
	}
	return g;
}

fn sinOp(f: F) F { return @sin(f); }
fn cosOp(f: F) F { return @cos(f); }
fn tanOp(f: F) F { return @tan(f); }
fn atanOp(f: F) F { return atan(f); }
fn sqrtOp(f: F) F { return if (f > 0) @sqrt(f) else 0; }
fn expOp(f: F) F { return @exp(f); }
fn absOp(f: F) F { return @abs(f); }


fn bluntNew() ?*pd.Object {
	return @ptrCast(blunt_class.new() orelse return null);
}

export fn blunt_setup() void {
	pd.post.do("Blunt! v0.9");
	blunt_class = pd.class(pd.symbol("blunt"), @ptrCast(&bluntNew), null,
		@sizeOf(pd.Object), .{ .no_inlet=true }, &.{}).?;

	var buf: [6:0]u8 = undefined;
	const b = &buf;

	const binops = [_]*BinOp.Pkg {
		&pkg_plus, &pkg_minus, &pkg_times, &pkg_over,
		&pkg_min, &pkg_max, &pkg_log, &pkg_pow,
		&pkg_lt, &pkg_gt, &pkg_le, &pkg_ge, &pkg_ee, &pkg_ne,
		&pkg_la, &pkg_lo, &pkg_ba, &pkg_bo, &pkg_bx, &pkg_ls, &pkg_rs,
		&pkg_rem, &pkg_mod, &pkg_div, &pkg_frem, &pkg_fmod, &pkg_atan2,
	};
	for (binops) |p| {
		p.class[0] = p.setup(pd.symbol(@ptrCast(p.name.ptr)));
		p.class[0].addBang(@ptrCast(&BinOp.bang));
		p.class[0].addMethod(@ptrCast(&BinOp.send), pd.symbol("send"), &.{ .symbol });

		@memcpy(b[1..p.name.len+1], p.name);
		b[p.name.len+1] = '\x00';
		const new: pd.NewMethod = @ptrCast(p.new);
		b[0] = '`'; // alias for compatibility
		pd.addCreator(new, pd.symbol(b), &.{ .gimme });
		b[0] = '#'; // hot 2nd inlet variant
		pd.addCreator(new, pd.symbol(b), &.{ .gimme });

		if (p.rev) {
			b[0] = '@'; // reverse operand variant
			p.class[1] = p.setup(pd.symbol(b));
			p.class[1].addBang(@ptrCast(&BinOp.revBang));
			p.class[1].addMethod(@ptrCast(&BinOp.revSend), pd.symbol("send"), &.{ .symbol });
		}
	}
	pd.addCreator(@ptrCast(&fmodNew), pd.symbol("wrap"), &.{ .gimme });

	const unops = [_]*UnOp.Pkg {
		&pkg_f, &pkg_i, &pkg_floor, &pkg_ceil, &pkg_bnot, &pkg_lnot, &pkg_fact,
		&pkg_sin, &pkg_cos, &pkg_tan, &pkg_atan, &pkg_sqrt, &pkg_exp, &pkg_abs,
	};
	for (unops) |p| {
		p.class = p.setup();
		if (p.alias) {
			@memcpy(b[1..p.name.len+1], p.name);
			b[p.name.len+1] = '\x00';
			b[0] = '`';
			pd.addCreator(@ptrCast(p.new), pd.symbol(b), &.{ .gimme });
		}
	}

	Bang.setup();
	Symbol.setup();
}
