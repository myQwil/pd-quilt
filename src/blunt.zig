const pd = @import("pd.zig");
const A = pd.AtomType;
var blunt_class: *pd.Class = undefined;

const pi = @import("std").math.pi;
const atan = @import("std").math.atan;
const atan2 = @import("std").math.atan2;
const strlen = @import("std").mem.len;

// ----------------------------------- Blunt -----------------------------------
// -----------------------------------------------------------------------------
const Blunt = extern struct {
	const Self = @This();

	// "loadbang" actions - 0 for original meaning
	const lb_load: u3 = 0;
	const c_load: u8 = '!';
	// loaded but not yet connected to parent patch
	const lb_init: u3 = 1;
	const c_init: u8 = '$';
	// about to close
	const lb_close: u3 = 2;
	const c_close: u8 = '&';

	obj: pd.Object,
	mask: u8,

	fn loadbang(self: *Self, f: pd.Float) void {
		const action = @as(u8, 1) << @as(u3, @intFromFloat(f));
		if (self.mask & action != 0) {
			self.obj.g.pd.bang();
		}
	}

	inline fn init(self: *Self, ac: u32, av: [*]pd.Atom) u32 {
		self.mask = 0;
		if (ac >= 1 and av[ac - 1].type == A.SYMBOL) {
			const str = av[ac - 1].w.symbol.name;
			var i: usize = 0;
			while (str[i] != '\x00') : (i += 1) {
				switch (str[i]) {
					c_load => self.mask |= 1 << lb_load,
					c_init => self.mask |= 1 << lb_init,
					c_close => self.mask |= 1 << lb_close,
					else => break,
				}
			}
		}
		return ac - @intFromBool(self.mask != 0);
	}

	inline fn extend(class: *pd.Class) void {
		class.addMethod(@ptrCast(&loadbang), pd.symbol("loadbang"), A.DEFFLOAT, A.NULL);
	}
};


// ------------------------------ Binary operator ------------------------------
// -----------------------------------------------------------------------------
const BinOp = extern struct {
	const Self = @This();
	const Op = *const fn(pd.Float, pd.Float) callconv(.C) pd.Float;

	const Pkg = struct {
		class: [2]*pd.Class = undefined,
		name: [*:0]const u8,
		new: *const fn(*pd.Symbol, u32, [*]pd.Atom) *Self,
		op: Op,
		rev: bool = false,

		fn gen(pack: *Pkg, s: *pd.Symbol, ac: u32, av: [*]pd.Atom) *Self {
			return switch (s.name[0]) {
				'#' => Self.hot_new(pack.class[0], ac, av),
				'@' => Self.new(pack.class[1], ac, av),
				else => Self.new(pack.class[0], ac, av),
			};
		}

		inline fn setup(self: *Pkg, s: *pd.Symbol) *pd.Class {
			const cl = pd.class(s, @ptrCast(self.new), null,
				@sizeOf(BinOp), pd.Class.DEFAULT, A.GIMME, A.NULL);
			cl.addFloat(@ptrCast(&float));
			cl.addList(@ptrCast(&list));
			cl.addAnything(@ptrCast(&anything));

			cl.addMethod(@ptrCast(self.op), pd.s._, 0);
			cl.addMethod(@ptrCast(&print), pd.symbol("print"), A.DEFSYM, A.NULL);
			cl.addMethod(@ptrCast(&set_f1), pd.symbol("f1"), A.FLOAT, A.NULL);
			cl.addMethod(@ptrCast(&set_f2), pd.symbol("f2"), A.FLOAT, A.NULL);
			cl.addMethod(@ptrCast(&set), pd.symbol("set"), A.GIMME, A.NULL);
			cl.setHelpSymbol(pd.symbol("blunt"));
			Blunt.extend(cl);
			return cl;
		}
	};

	base: Blunt,
	f1: pd.Float,
	f2: pd.Float,

	fn print(self: *Self, s: *pd.Symbol) void {
		if (s.name[0] != '\x00') {
			pd.startpost("%s: ", s.name);
		}
		pd.post("%g %g", self.f1, self.f2);
	}

	fn set_f1(self: *Self, f: pd.Float) void {
		self.f1 = f;
	}

	fn set_f2(self: *Self, f: pd.Float) void {
		self.f2 = f;
	}

	fn set(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		if (ac >= 2 and av[1].type == A.FLOAT) {
			self.f2 = av[1].w.float;
		}
		if (ac >= 1 and av[0].type == A.FLOAT) {
			self.f1 = av[0].w.float;
		}
	}

	fn send(self: *Self, s: pd.Symbol) void {
		if (s.thing) |thing| {
			const op: Op = @ptrCast(@as(**pd.Class, @ptrCast(self)).*.methods[0].fun);
			thing.float(op(self.f1, self.f2));
		} else {
			pd.err(self, "%s: no such object", s.name);
		}
	}

	fn rev_send(self: *Self, s: pd.Symbol) void {
		if (s.thing) |thing| {
			const op: Op = @ptrCast(@as(**pd.Class, @ptrCast(self)).*.methods[0].fun);
			thing.float(op(self.f2, self.f1));
		} else {
			pd.err(self, "%s: no such object", s.name);
		}
	}

	fn bang(self: *Self) void {
		const op: Op = @ptrCast(@as(**pd.Class, @ptrCast(self)).*.methods[0].fun);
		self.base.obj.out.float(op(self.f1, self.f2));
	}

	fn rev_bang(self: *Self) void {
		const op: Op = @ptrCast(@as(**pd.Class, @ptrCast(self)).*.methods[0].fun);
		self.base.obj.out.float(op(self.f2, self.f1));
	}

	fn float(self: *Self, f: pd.Float) void {
		self.f1 = f;
		@as(*pd.Pd, @ptrCast(self)).bang();
	}

	fn list(self: *Self, s: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		self.set(s, ac, av);
		@as(*pd.Pd, @ptrCast(self)).bang();
	}

	fn anything(self: *Self, _: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		if (ac >= 1 and av[0].type == A.FLOAT) {
			self.f2 = av[0].w.float;
		}
		@as(*pd.Pd, @ptrCast(self)).bang();
	}

	inline fn init(self: *Self, ac: u32, av: [*]pd.Atom) void {
		const n = self.base.init(ac, av);
		_ = self.base.obj.outlet(pd.s.float);

		// set the 1st float, but only if there are 2 args
		switch (n) {
			2 => {
				self.f1 = av[0].getFloat();
				self.f2 = av[1].getFloat();
			},
			1 => self.f2 = av[0].getFloat(),
			else => {},
		}
	}

	inline fn new(cl: *pd.Class, ac: u32, av: [*]pd.Atom) *Self {
		const self: *Self = @ptrCast(cl.new());
		_ = self.base.obj.inletFloat(&self.f2);
		self.init(ac, av);
		return self;
	}

	inline fn hot_new(cl: *pd.Class, ac: u32, av: [*]pd.Atom) *Self {
		const self: *Self = @ptrCast(cl.new());
		const obj = &self.base.obj;
		_ = obj.inlet(&obj.g.pd, pd.s.float, pd.s.anything);
		self.init(ac, av);
		return self;
	}
};


// ------------------------------ Unary operator -------------------------------
// -----------------------------------------------------------------------------
const UnOp = extern struct {
	const Self = @This();
	const Op = *const fn(pd.Float) callconv(.C) pd.Float;
	const parse = @import("std").fmt.parseFloat;

	const Pkg = struct {
		class: *pd.Class = undefined,
		name: [*:0]const u8,
		new: *const fn(*pd.Symbol, u32, [*]pd.Atom) *Self,
		op: Op,
		inlet: bool = false,
		alias: bool = true,

		fn gen(pack: *Pkg, ac: u32, av: [*]pd.Atom) *Self {
			const self: *Self = @ptrCast(pack.class.new());
			const obj: *pd.Object = @ptrCast(self);
			if (pack.inlet) {
				_ = obj.inletFloat(&self.f);
			}
			_ = obj.outlet(pd.s.float);
			self.f = (&av[0]).getFloatArg(0, self.base.init(ac, av));
			return self;
		}

		inline fn setup(pack: *Pkg) void {
			const cl = pd.class(pd.symbol(pack.name), @ptrCast(pack.new), null,
				@sizeOf(Self), pd.Class.DEFAULT, A.GIMME, A.NULL);
			cl.addBang(@ptrCast(&bang));
			cl.addFloat(@ptrCast(&float));
			cl.addSymbol(@ptrCast(&symbol));

			cl.addMethod(@ptrCast(pack.op), pd.s._, 0);
			cl.addMethod(@ptrCast(&print), pd.symbol("print"), A.DEFSYM, A.NULL);
			cl.addMethod(@ptrCast(&set), pd.symbol("set"), A.FLOAT, A.NULL);
			cl.addMethod(@ptrCast(&send), pd.symbol("send"), A.SYMBOL, A.NULL);
			cl.setHelpSymbol(pd.symbol("blunt"));
			Blunt.extend(cl);
			pack.class = cl;
		}
	};

	base: Blunt,
	f: pd.Float,

	fn print(self: *Self, s: *pd.Symbol) void {
		if (s.name[0] != '\x00') {
			pd.startpost("%s: ", s.name);
		}
		pd.post("%g", self.f);
	}

	fn set(self: *Self, f: pd.Float) void {
		self.f = f;
	}

	fn send(self: *Self, s: pd.Symbol) void {
		if (s.thing) |thing| {
			const op: Op = @ptrCast(@as(**pd.Class, @ptrCast(self)).*.methods[0].fun);
			thing.float(op(self.f));
		} else {
			pd.err(self, "%s: no such object", s.name);
		}
	}

	fn bang(self: *Self) void {
		const op: Op = @ptrCast(@as(**pd.Class, @ptrCast(self)).*.methods[0].fun);
		self.base.obj.out.float(op(self.f));
	}

	fn float(self: *Self, f: pd.Float) void {
		self.f = f;
		@as(*pd.Pd, @ptrCast(self)).bang();
	}

	fn symbol(self: *Self, s: pd.Symbol) void {
		const n = strlen(s.name);
		const f = parse(pd.Float, s.name[0..n]) catch {
			pd.err(self, "Couldn't convert %s to float.", s.name);
			return;
		};
		self.float(f);
	}
};


// ----------------------------------- Bang ------------------------------------
// -----------------------------------------------------------------------------
const Bang = extern struct {
	const Self = Blunt;
	var class: *pd.Class = undefined;

	fn bang(self: *Self) void {
		self.obj.out.bang();
	}

	fn new(_: *pd.Symbol, ac: u32, av: [*]pd.Atom) *Self {
		const self: *Self = @ptrCast(class.new());
		_ = self.init(ac, av);
		_ = self.obj.outlet(pd.s.bang);
		return self;
	}

	fn setup() void {
		const bnew: pd.NewMethod = @ptrCast(&new);
		class = pd.class(pd.symbol("b"), bnew, null,
			@sizeOf(Self), pd.Class.DEFAULT, A.GIMME, A.NULL);
		pd.addCreator(bnew, pd.symbol("`b"), A.GIMME, A.NULL);
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

	fn print(self: *Self, s: *pd.Symbol) void {
		if (s.name[0] != '\x00') {
			pd.startpost("%s: ", s.name);
		}
		pd.post("%s", self.sym.name);
	}

	fn bang(self: *Self) void {
		self.base.obj.out.symbol(self.sym);
	}

	fn symbol(self: *Self, s: *pd.Symbol) void {
		self.sym = s;
		self.bang();
	}

	fn list(self: *Self, s: *pd.Symbol, ac: u32, av: [*]pd.Atom) void {
		if (ac == 0) {
			self.bang();
		} else if (av[0].type == A.SYMBOL) {
			self.symbol(av[0].w.symbol);
		} else {
			self.symbol(s);
		}
	}

	fn new(_: *pd.Symbol, ac: u32, av: [*]pd.Atom) *Self {
		const self: *Self = @ptrCast(class.new());
		self.sym = (&av[0]).getSymbolArg(0, self.base.init(ac, av));
		_ = self.base.obj.outlet(pd.s.symbol);
		_ = self.base.obj.inletSymbol(&self.sym);
		return self;
	}

	fn setup() void {
		const bnew: pd.NewMethod = @ptrCast(&new);
		class = pd.class(pd.symbol("sym"), bnew, null,
			@sizeOf(Self), pd.Class.DEFAULT, A.GIMME, A.NULL);
		class.addBang(@ptrCast(&bang));
		class.addSymbol(@ptrCast(&symbol));
		class.addList(@ptrCast(&list));
		class.addAnything(@ptrCast(&symbol));

		Blunt.extend(class);
		class.setHelpSymbol(pd.symbol("blunt"));
	}
};


// --------------------------------- Packages ----------------------------------
// -----------------------------------------------------------------------------
var plus_pkg  = BinOp.Pkg { .name="+",     .new=plus_new,  .op=plus_op };
var minus_pkg = BinOp.Pkg { .name="-",     .new=minus_new, .op=minus_op, .rev=true };
var times_pkg = BinOp.Pkg { .name="*",     .new=times_new, .op=times_op };
var over_pkg  = BinOp.Pkg { .name="/",     .new=over_new,  .op=over_op,  .rev=true };
var min_pkg   = BinOp.Pkg { .name="min",   .new=min_new,   .op=min_op };
var max_pkg   = BinOp.Pkg { .name="max",   .new=max_new,   .op=max_op };
var log_pkg   = BinOp.Pkg { .name="log",   .new=log_new,   .op=log_op,   .rev=true };
var pow_pkg   = BinOp.Pkg { .name="pow",   .new=pow_new,   .op=pow_op,   .rev=true };
var ee_pkg    = BinOp.Pkg { .name="==",    .new=ee_new,    .op=ee_op };
var ne_pkg    = BinOp.Pkg { .name="!=",    .new=ne_new,    .op=ne_op };
var gt_pkg    = BinOp.Pkg { .name=">",     .new=gt_new,    .op=gt_op };
var lt_pkg    = BinOp.Pkg { .name="<",     .new=lt_new,    .op=lt_op };
var ge_pkg    = BinOp.Pkg { .name=">=",    .new=ge_new,    .op=ge_op };
var le_pkg    = BinOp.Pkg { .name="<=",    .new=le_new,    .op=le_op };
var la_pkg    = BinOp.Pkg { .name="&&",    .new=la_new,    .op=la_op };
var lo_pkg    = BinOp.Pkg { .name="||",    .new=lo_new,    .op=lo_op };
var ba_pkg    = BinOp.Pkg { .name="&",     .new=ba_new,    .op=ba_op };
var bo_pkg    = BinOp.Pkg { .name="|",     .new=bo_new,    .op=bo_op };
var bx_pkg    = BinOp.Pkg { .name="^",     .new=bx_new,    .op=bx_op };
var ls_pkg    = BinOp.Pkg { .name="<<",    .new=ls_new,    .op=ls_op,    .rev=true };
var rs_pkg    = BinOp.Pkg { .name=">>",    .new=rs_new,    .op=rs_op,    .rev=true };
var rem_pkg   = BinOp.Pkg { .name="%",     .new=rem_new,   .op=rem_op,   .rev=true };
var mod_pkg   = BinOp.Pkg { .name="mod",   .new=mod_new,   .op=mod_op,   .rev=true };
var div_pkg   = BinOp.Pkg { .name="div",   .new=div_new,   .op=div_op,   .rev=true };
var frem_pkg  = BinOp.Pkg { .name="f%",    .new=frem_new,  .op=frem_op,  .rev=true };
var fmod_pkg  = BinOp.Pkg { .name="fmod",  .new=fmod_new,  .op=fmod_op,  .rev=true };
var atan2_pkg = BinOp.Pkg { .name="atan2", .new=atan2_new, .op=atan2_op, .rev=true };

var f_pkg     = UnOp.Pkg { .name="f",     .new=f_new,     .op=f_op,     .inlet=true };
var i_pkg     = UnOp.Pkg { .name="i",     .new=i_new,     .op=i_op,     .inlet=true };
var floor_pkg = UnOp.Pkg { .name="floor", .new=floor_new, .op=floor_op, .alias=false };
var ceil_pkg  = UnOp.Pkg { .name="ceil",  .new=ceil_new,  .op=ceil_op,  .alias=false };
var bnot_pkg  = UnOp.Pkg { .name="~",     .new=bnot_new,  .op=bnot_op,  .alias=false };
var lnot_pkg  = UnOp.Pkg { .name="!",     .new=lnot_new,  .op=lnot_op,  .alias=false };
var fact_pkg  = UnOp.Pkg { .name="n!",    .new=fact_new,  .op=fact_op,  .alias=false };
var sin_pkg   = UnOp.Pkg { .name="sin",   .new=sin_new,   .op=sin_op };
var cos_pkg   = UnOp.Pkg { .name="cos",   .new=cos_new,   .op=cos_op };
var tan_pkg   = UnOp.Pkg { .name="tan",   .new=tan_new,   .op=tan_op };
var atan_pkg  = UnOp.Pkg { .name="atan",  .new=atan_new,  .op=atan_op };
var sqrt_pkg  = UnOp.Pkg { .name="sqrt",  .new=sqrt_new,  .op=sqrt_op };
var exp_pkg   = UnOp.Pkg { .name="exp",   .new=exp_new,   .op=exp_op };
var abs_pkg   = UnOp.Pkg { .name="abs",   .new=abs_new,   .op=abs_op };


// -------------------------------- New methods --------------------------------
// -----------------------------------------------------------------------------
const S = *pd.Symbol;
const Ac = u32;
const Av = [*]pd.Atom;
fn plus_new(s: S, ac: Ac, av: Av)  *BinOp { return plus_pkg.gen(s, ac, av); }
fn minus_new(s: S, ac: Ac, av: Av) *BinOp { return minus_pkg.gen(s, ac, av); }
fn times_new(s: S, ac: Ac, av: Av) *BinOp { return times_pkg.gen(s, ac, av); }
fn over_new(s: S, ac: Ac, av: Av)  *BinOp { return over_pkg.gen(s, ac, av); }
fn min_new(s: S, ac: Ac, av: Av)   *BinOp { return min_pkg.gen(s, ac, av); }
fn max_new(s: S, ac: Ac, av: Av)   *BinOp { return max_pkg.gen(s, ac, av); }
fn log_new(s: S, ac: Ac, av: Av)   *BinOp { return log_pkg.gen(s, ac, av); }
fn pow_new(s: S, ac: Ac, av: Av)   *BinOp { return pow_pkg.gen(s, ac, av); }
fn ee_new(s: S, ac: Ac, av: Av)    *BinOp { return ee_pkg.gen(s, ac, av); }
fn ne_new(s: S, ac: Ac, av: Av)    *BinOp { return ne_pkg.gen(s, ac, av); }
fn gt_new(s: S, ac: Ac, av: Av)    *BinOp { return gt_pkg.gen(s, ac, av); }
fn lt_new(s: S, ac: Ac, av: Av)    *BinOp { return lt_pkg.gen(s, ac, av); }
fn ge_new(s: S, ac: Ac, av: Av)    *BinOp { return ge_pkg.gen(s, ac, av); }
fn le_new(s: S, ac: Ac, av: Av)    *BinOp { return le_pkg.gen(s, ac, av); }
fn la_new(s: S, ac: Ac, av: Av)    *BinOp { return la_pkg.gen(s, ac, av); }
fn lo_new(s: S, ac: Ac, av: Av)    *BinOp { return lo_pkg.gen(s, ac, av); }
fn ba_new(s: S, ac: Ac, av: Av)    *BinOp { return ba_pkg.gen(s, ac, av); }
fn bo_new(s: S, ac: Ac, av: Av)    *BinOp { return bo_pkg.gen(s, ac, av); }
fn bx_new(s: S, ac: Ac, av: Av)    *BinOp { return bx_pkg.gen(s, ac, av); }
fn ls_new(s: S, ac: Ac, av: Av)    *BinOp { return ls_pkg.gen(s, ac, av); }
fn rs_new(s: S, ac: Ac, av: Av)    *BinOp { return rs_pkg.gen(s, ac, av); }
fn rem_new(s: S, ac: Ac, av: Av)   *BinOp { return rem_pkg.gen(s, ac, av); }
fn mod_new(s: S, ac: Ac, av: Av)   *BinOp { return mod_pkg.gen(s, ac, av); }
fn div_new(s: S, ac: Ac, av: Av)   *BinOp { return div_pkg.gen(s, ac, av); }
fn frem_new(s: S, ac: Ac, av: Av)  *BinOp { return frem_pkg.gen(s, ac, av); }
fn fmod_new(s: S, ac: Ac, av: Av)  *BinOp { return fmod_pkg.gen(s, ac, av); }
fn atan2_new(s: S, ac: Ac, av: Av) *BinOp { return atan2_pkg.gen(s, ac, av); }

fn f_new(_: S, ac: Ac, av: Av)     *UnOp { return f_pkg.gen(ac, av); }
fn i_new(_: S, ac: Ac, av: Av)     *UnOp { return i_pkg.gen(ac, av); }
fn floor_new(_: S, ac: Ac, av: Av) *UnOp { return floor_pkg.gen(ac, av); }
fn ceil_new(_: S, ac: Ac, av: Av)  *UnOp { return ceil_pkg.gen(ac, av); }
fn bnot_new(_: S, ac: Ac, av: Av)  *UnOp { return bnot_pkg.gen(ac, av); }
fn lnot_new(_: S, ac: Ac, av: Av)  *UnOp { return lnot_pkg.gen(ac, av); }
fn fact_new(_: S, ac: Ac, av: Av)  *UnOp { return fact_pkg.gen(ac, av); }
fn sin_new(_: S, ac: Ac, av: Av)   *UnOp { return sin_pkg.gen(ac, av); }
fn cos_new(_: S, ac: Ac, av: Av)   *UnOp { return cos_pkg.gen(ac, av); }
fn tan_new(_: S, ac: Ac, av: Av)   *UnOp { return tan_pkg.gen(ac, av); }
fn atan_new(_: S, ac: Ac, av: Av)  *UnOp { return atan_pkg.gen(ac, av); }
fn sqrt_new(_: S, ac: Ac, av: Av)  *UnOp { return sqrt_pkg.gen(ac, av); }
fn exp_new(_: S, ac: Ac, av: Av)   *UnOp { return exp_pkg.gen(ac, av); }
fn abs_new(_: S, ac: Ac, av: Av)   *UnOp { return abs_pkg.gen(ac, av); }


// -------------------------------- Operations ---------------------------------
// -----------------------------------------------------------------------------
const F = pd.Float;
// binop1:  +  -  *  /  min  max  log  pow
fn plus_op(f1: F, f2: F) callconv(.C) F { return f1 + f2; }
fn minus_op(f1: F, f2: F) callconv(.C) F { return f1 - f2; }
fn times_op(f1: F, f2: F) callconv(.C) F { return f1 * f2; }
fn over_op(f1: F, f2: F) callconv(.C) F {	return if (f2 == 0) 0 else f1 / f2; }
fn min_op(f1: F, f2: F) callconv(.C) F { return @min(f1, f2); }
fn max_op(f1: F, f2: F) callconv(.C) F { return @max(f1, f2); }
fn log_op(f1: F, f2: F) callconv(.C) F {
	return if (f1 <= 0) -1000
		else if (f2 <= 0) @log(f1)
		else @log(f1) / @log(f2);
}
fn pow_op(f1: F, f2: F) callconv(.C) F {
	const d2: F = @floatFromInt(@as(i32, @intFromFloat(f2)));
	return if (f1 == 0 or (f1 < 0 and f2 - d2 != 0))
		0 else @exp(@log(f1) * f2);
}

// binop2:  ==  !=  >  <  >=  <=
fn ee_op(f1: F, f2: F) callconv(.C) F { return @floatFromInt(@intFromBool(f1 == f2)); }
fn ne_op(f1: F, f2: F) callconv(.C) F { return @floatFromInt(@intFromBool(f1 != f2)); }
fn gt_op(f1: F, f2: F) callconv(.C) F { return @floatFromInt(@intFromBool(f1 > f2)); }
fn lt_op(f1: F, f2: F) callconv(.C) F { return @floatFromInt(@intFromBool(f1 < f2)); }
fn ge_op(f1: F, f2: F) callconv(.C) F { return @floatFromInt(@intFromBool(f1 >= f2)); }
fn le_op(f1: F, f2: F) callconv(.C) F { return @floatFromInt(@intFromBool(f1 <= f2)); }

// binop3:  &&  ||  &  |  ^  <<  >>  %  mod  div  f%  fmod
fn la_op(f1: F, f2: F) callconv(.C) F
{ return @floatFromInt(@intFromBool(f1 != 0 and f2 != 0)); }
fn lo_op(f1: F, f2: F) callconv(.C) F
{ return @floatFromInt(@intFromBool(f1 != 0 or f2 != 0)); }
fn ba_op(f1: F, f2: F) callconv(.C) F
{ return @floatFromInt(@as(i32, @intFromFloat(f1)) & @as(i32, @intFromFloat(f2))); }
fn bo_op(f1: F, f2: F) callconv(.C) F
{ return @floatFromInt(@as(i32, @intFromFloat(f1)) | @as(i32, @intFromFloat(f2))); }
fn bx_op(f1: F, f2: F) callconv(.C) F
{ return @floatFromInt(@as(i32, @intFromFloat(f1)) ^ @as(i32, @intFromFloat(f2))); }
fn ls_op(f1: F, f2: F) callconv(.C) F
{ return @floatFromInt(@as(i32, @intFromFloat(f1)) << @as(u5, @intFromFloat(f2))); }
fn rs_op(f1: F, f2: F) callconv(.C) F
{ return @floatFromInt(@as(i32, @intFromFloat(f1)) >> @as(u5, @intFromFloat(f2))); }

fn rem_op(f1: F, f2: F) callconv(.C) F {
	const n2: i32 = @intFromFloat(@max(1, @abs(f2)));
	return @floatFromInt(@rem(@as(i32, @intFromFloat(f1)), n2));
}
fn mod_op(f1: F, f2: F) callconv(.C) F {
	const n2: i32 = @intFromFloat(@max(1, @abs(f2)));
	return @floatFromInt(@mod(@as(i32, @intFromFloat(f1)), n2));
}
fn div_op(f1: F, f2: F) callconv(.C) F {
	const n2: i32 = @intFromFloat(@max(1, @abs(f2)));
	return @floatFromInt(@divFloor(@as(i32, @intFromFloat(f1)), n2));
}
fn frem_op(f1: F, f: F) callconv(.C) F {
	const f2 = if (f == 0) 1 else @abs(f);
	return @rem(f1, f2);
}
fn fmod_op(f1: F, f: F) callconv(.C) F {
	const f2 = if (f == 0) 1 else @abs(f);
	return @mod(f1, f2);
}
fn atan2_op(f1: F, f2: F) callconv(.C) F {
	return if (f1 == 0 and f2 == 0) 0 else atan2(f1, f2);
}

// // unop:  f  i  !  ~  floor  ceil  factorial
fn f_op(f: F) callconv(.C) F { return f; }
fn i_op(f: F) callconv(.C) F { return @floatFromInt(@as(i32, @intFromFloat(f))); }
fn floor_op(f: F) callconv(.C) F { return @floor(f); }
fn ceil_op(f: F) callconv(.C) F { return @ceil(f); }
fn bnot_op(f: F) callconv(.C) F { return @floatFromInt(~@as(i32, @intFromFloat(f))); }
fn lnot_op(f: F) callconv(.C) F { return @floatFromInt(@intFromBool(f == 0)); }

fn fact_op(f: F) callconv(.C) F {
	var d = @floor(f);
	if (d > 9) {
		// stirling's approximation
		return @exp((d + 0.5) * @log(d) - d + @log(2 * pi) * 0.5);
	}
	var g: pd.Float = 1;
	while (d > 0) : (d -= 1) {
		g *= d;
	}
	return g;
}

fn sin_op(f: F) callconv(.C) F { return @sin(f); }
fn cos_op(f: F) callconv(.C) F { return @cos(f); }
fn tan_op(f: F) callconv(.C) F { return @tan(f); }
fn atan_op(f: F) callconv(.C) F { return atan(f); }
fn sqrt_op(f: F) callconv(.C) F { return @sqrt(f); }
fn exp_op(f: F) callconv(.C) F { return @exp(f); }
fn abs_op(f: F) callconv(.C) F { return @abs(f); }


fn blunt_new() *pd.Object {
	return @ptrCast(blunt_class.new());
}

export fn blunt_setup() void {
	pd.post("Blunt! v0.9");
	blunt_class = pd.class(pd.symbol("blunt"), @ptrCast(&blunt_new), null,
		@sizeOf(pd.Object), pd.Class.NOINLET, 0);

	var buf: [8]u8 = undefined;
	var b: [*]u8 = @ptrCast(&buf);

	const binops = [_]*BinOp.Pkg {
		&plus_pkg, &minus_pkg, &times_pkg, &over_pkg,
		&min_pkg, &max_pkg, &log_pkg, &pow_pkg,
		&ee_pkg, &ne_pkg, &gt_pkg, &lt_pkg, &ge_pkg, &le_pkg,
		&la_pkg, &lo_pkg, &ba_pkg, &bo_pkg, &bx_pkg, &ls_pkg, &rs_pkg,
		&rem_pkg, &mod_pkg, &div_pkg, &frem_pkg, &fmod_pkg, &atan2_pkg,
	};
	for (binops) |p| {
		p.class[0] = p.setup(pd.symbol(p.name));
		p.class[0].addBang(@ptrCast(&BinOp.bang));
		p.class[0].addMethod(@ptrCast(&BinOp.send), pd.symbol("send"), A.SYMBOL, A.NULL);

		const n = strlen(p.name);
		@memcpy(b + 1, p.name[0..n]);
		b[n + 1] = '\x00';

		const new: pd.NewMethod = @ptrCast(p.new);
		b[0] = '`'; // alias for compatibility
		pd.addCreator(new, pd.symbol(b), A.GIMME, A.NULL);
		b[0] = '#'; // hot 2nd inlet variant
		pd.addCreator(new, pd.symbol(b), A.GIMME, A.NULL);

		if (p.rev) {
			b[0] = '@'; // reverse operand variant
			p.class[1] = p.setup(pd.symbol(b));
			p.class[1].addBang(@ptrCast(&BinOp.rev_bang));
			p.class[1].addMethod(@ptrCast(&BinOp.rev_send), pd.symbol("send"),
				A.SYMBOL, A.NULL);
		}
	}
	pd.addCreator(@ptrCast(&fmod_new), pd.symbol("wrap"), A.GIMME, A.NULL);

	const unops = [_]*UnOp.Pkg {
		&f_pkg, &i_pkg, &floor_pkg, &ceil_pkg, &bnot_pkg, &lnot_pkg, &fact_pkg,
		&sin_pkg, &cos_pkg, &tan_pkg, &atan_pkg, &sqrt_pkg, &exp_pkg, &abs_pkg,
	};
	for (unops) |p| {
		p.setup();
		if (p.alias) {
			const n = strlen(p.name);
			@memcpy(b + 1, p.name[0..n]);
			b[n + 1] = '\x00';
			b[0] = '`';
			pd.addCreator(@ptrCast(p.new), pd.symbol(b), A.GIMME, A.NULL);
		}
	}

	Bang.setup();
	Symbol.setup();
}
