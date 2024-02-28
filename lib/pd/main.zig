const std = @import("std");
const c = @import("m_pd.zig");
const cnv = @import("canvas.zig");
pub const iem = @import("iem.zig");
pub const canvas = cnv;

pub extern const pd_compatibilitylevel: c_int;

pub const Int = c.t_int;
pub const Float = c.t_float;
pub const Sample = Float;

pub const Method = c.t_method;
pub const NewMethod = c.t_newmethod;

pub const Word = extern union {
	// we're going to trust pd to give us valid pointers of the respective types
	float: Float,
	symbol: *Symbol,
	gpointer: *GPointer,
	array: *cnv.Array,
	binbuf: *BinBuf,
	index: c_int,
};

// ----------------------------------- Atom ------------------------------------
// -----------------------------------------------------------------------------
pub const Atom = extern struct {
	type: Type,
	w: Word,

	pub const Type = enum(c_uint) {
		none,
		float,
		symbol,
		pointer,
		semi,
		comma,
		deffloat,
		defsymbol,
		dollar,
		dollsym,
		gimme,
		cant,

		const Tuple = std.meta.Tuple;
		fn tuple(comptime args: []const Type)
		Tuple(&[_]type {c_uint} ** (args.len + 1)) {
			var arr: Tuple(&[_]type {c_uint} ** (args.len + 1)) = undefined;
			inline for (0..args.len) |i| {
				arr[i] = @intFromEnum(args[i]);
			}
			arr[args.len] = @intFromEnum(Type.none);
			return arr;
		}
	};

	pub const int = c.atom_getint;
	pub const float = c.atom_getfloat;
	pub const symbol = c.atom_getsymbol;
	pub const toSymbol = c.atom_gensym;

	pub fn bufPrint(self: *const Atom, buf: []u8) void {
		c.atom_string(self, buf.ptr, @intCast(buf.len));
	}
};

pub fn intArg(av: []const Atom, which: usize) Int {
	return c.atom_getintarg(@intCast(which), @intCast(av.len), av.ptr);
}
pub fn floatArg(av: []const Atom, which: usize) Float {
	return c.atom_getfloatarg(@intCast(which), @intCast(av.len), av.ptr);
}
pub fn symbolArg(av: []const Atom, which: usize) *Symbol {
	return c.atom_getsymbolarg(@intCast(which), @intCast(av.len), av.ptr);
}


// ---------------------------------- BinBuf -----------------------------------
// -----------------------------------------------------------------------------
pub const BinBuf = opaque {
	pub const free = c.binbuf_free;
	pub const duplicate = c.binbuf_duplicate;
	pub const fromText = c.binbuf_text;
	pub const text = c.binbuf_gettext;
	pub const clear = c.binbuf_clear;
	pub const add = c.binbuf_add;
	pub const addV = c.binbuf_addv;
	pub const addBinBuf = c.binbuf_addbinbuf;
	pub const addSemi = c.binbuf_addsemi;
	pub const restore = c.binbuf_restore;
	pub const print = c.binbuf_print;
	pub const nAtoms = c.binbuf_getnatom;
	pub const vec = c.binbuf_getvec;
	pub const eval = c.binbuf_eval;
	pub const read = c.binbuf_read;
	pub const readViaCanvas = c.binbuf_read_via_canvas;
	pub const readViaPath = c.binbuf_read_via_path;
	pub const write = c.binbuf_write;

	pub fn resize(self: *BinBuf, newsize: usize) !void {
		if (self.binbuf_resize(@intCast(newsize)) == 0)
			return error.OutOfMemory;
	}
};
pub const binbuf = c.binbuf_new;
pub const evalFile = c.binbuf_evalfile;
pub const realizeDollSym = c.binbuf_realizedollsym;


// ----------------------------------- Class -----------------------------------
// -----------------------------------------------------------------------------
pub const MethodEntry = extern struct {
	name: *Symbol,
	fun: GotFn,
	arg: [max_arg:0]u8,
};

pub const BangMethod = c.t_bangmethod;
pub const PointerMethod = c.t_pointermethod;
pub const FloatMethod = c.t_floatmethod;
pub const SymbolMethod = c.t_symbolmethod;
pub const ListMethod = c.t_listmethod;
pub const AnyMethod = c.t_anymethod;
pub const SaveFn = c.t_savefn;
pub const PropertiesFn = c.t_propertiesfn;
pub const ClassFreeFn = c.t_classfreefn;

pub const Class = extern struct {
	name: *Symbol,
	helpname: *Symbol,
	externdir: *Symbol,
	size: usize,
	methods: [*]MethodEntry,
	nmethod: c_uint,
	freemethod: Method,
	bangmethod: BangMethod,
	pointermethod: PointerMethod,
	floatmethod: FloatMethod,
	symbolmethod: SymbolMethod,
	listmethod: ListMethod,
	anymethod: AnyMethod,
	wb: ?*const cnv.WidgetBehavior,
	pwb: ?*const cnv.ParentWidgetBehavior,
	savefn: SaveFn,
	propertiesfn: PropertiesFn,
	next: ?*Class,
	floatsignalin: c_uint,
	flags: packed struct(u8) {
		gobj: bool,              // true if is a gobj
		patchable: bool,         // true if we have a t_object header
		firstin: bool,           // if so, true if drawing first inlet
		drawcommand: bool,       // drawing command for a template
		multichannel: bool,      // can deal with multichannel sigs
		nopromotesig: bool,      // don't promote scalars to signals
		nopromoteleft: bool,     // not even the main (left) inlet
		_padding: u1,
	},
	classfreefn: ClassFreeFn,

	pub const free = c.class_free;
	pub const addBang = c.class_addbang;
	pub const addPointer = c.class_addpointer;
	pub const addFloat = c.class_doaddfloat;
	pub const addSymbol = c.class_addsymbol;
	pub const addList = c.class_addlist;
	pub const addAnything = c.class_addanything;
	pub const setHelpSymbol = c.class_sethelpsymbol;
	pub const setWidget = c.class_setwidget;
	pub const setParentWidget = c.class_setparentwidget;
	pub const name = c.class_getname;
	pub const helpName = c.class_gethelpname;
	pub const helpDir = c.class_gethelpdir;
	pub const setDrawCommand = c.class_setdrawcommand;
	pub const doMainSignalIn = c.class_domainsignalin;
	pub const setSaveFn = c.class_setsavefn;
	pub const saveFn = c.class_getsavefn;
	pub const setPropertiesFn = c.class_setpropertiesfn;
	pub const propertiesFn = c.class_getpropertiesfn;
	pub const setFreeFn = c.class_setfreefn;
	pub const new = c.pd_new;

	pub fn isDrawCommand(self: *const Class) bool {
		return (self.class_isdrawcommand() != 0);
	}

	pub fn find(self: *const Class, sym: *Symbol) ?*Pd {
		return c.pd_findbyclass(sym, self);
	}

	pub const Options = struct {
		bare: bool = false,      // non-canvasable pd such as an inlet
		gobj: bool = false,      // pd that can belong to a canvas
		patchable: bool = false, // pd that also can have inlets and outlets

		no_inlet: bool = false,        // suppress left inlet
		multichannel: bool = false,    // can deal with multichannel signals
		no_promote_sig: bool = false,  // don't promote scalars to signals
		no_promote_left: bool = false, // not even the main (left) inlet

		fn mask(self: Options) c_int {
			return @intFromBool(self.bare)
				| (@as(u2, @intFromBool(self.gobj)) << 1)
				| (@as(u2, @intFromBool(self.patchable)) * 3)
				| (@as(u4, @intFromBool(self.no_inlet)) << 3)
				| (@as(u5, @intFromBool(self.multichannel)) << 4)
				| (@as(u6, @intFromBool(self.no_promote_sig)) << 5)
				| (@as(u7, @intFromBool(self.no_promote_left)) << 6);
		}
	};

	pub fn addMethod(
		cls: *Class, func: Method, sel: *Symbol, comptime args: []const Atom.Type,
	) void {
		@call(.auto, c.class_addmethod, .{ cls, func, sel } ++ Atom.Type.tuple(args));
	}
};

pub fn class(
	name: *Symbol, newmethod: NewMethod, freemethod: Method, size: usize,
	flags: Class.Options, comptime args: []const Atom.Type,
) ?*Class {
	return @call(.auto, c.class_new,
		.{ name, newmethod, freemethod, size, flags.mask() } ++ Atom.Type.tuple(args));
}

pub fn class64(
	name: *Symbol, newmethod: NewMethod, freemethod: Method, size: usize,
	flags: Class.Options, comptime args: []const Atom.Type,
) ?*Class {
	return @call(.auto, c.class_new64,
		.{ name, newmethod, freemethod, size, flags.mask() } ++ Atom.Type.tuple(args));
}

pub fn addCreator(
	newmethod: NewMethod, sym: *Symbol, comptime args: []const Atom.Type,
) void {
	@call(.auto, c.class_addcreator, .{ newmethod, sym } ++ Atom.Type.tuple(args));
}

pub extern const garray_class: *Class;
pub extern const scalar_class: *Class;
pub extern const glob_pdobject: *Class;


// ----------------------------------- Clock -----------------------------------
// -----------------------------------------------------------------------------
pub const Clock = opaque {
	pub const set = c.clock_set;
	pub const delay = c.clock_delay;
	pub const unset = c.clock_unset;
	pub const free = c.clock_free;

	pub fn setUnit(self: *Clock, timeunit: f64, in_samples: bool) void {
		c.clock_setunit(self, timeunit, @intFromBool(in_samples));
	}
};
pub const clock = c.clock_new;
pub const time = c.clock_getlogicaltime;
pub const timeSince = c.clock_gettimesince;
pub const sysTimeAfter = c.clock_getsystimeafter;

pub fn timeSinceWithUnits(prevsystime: f64, units: f64, in_samples: bool) f64 {
	return c.clock_gettimesincewithunits(prevsystime, units, @intFromBool(in_samples));
}


// ------------------------------------ Dsp ------------------------------------
// -----------------------------------------------------------------------------
pub const PerfRoutine = c.t_perfroutine;
pub const dsp = struct {
	pub const add = c.dsp_add;
	pub const addV = c.dsp_addv;
	pub const addPlus = c.dsp_add_plus;
	pub const addCopy = c.dsp_add_copy;
	pub const addScalarCopy = c.dsp_add_scalarcopy;
	pub const addZero = c.dsp_add_zero;
};


// ---------------------------------- GArray -----------------------------------
// -----------------------------------------------------------------------------
pub const GArray = opaque {
	pub const redraw = c.garray_redraw;
	pub const nPoints = c.garray_npoints;
	pub const vec = c.garray_vec;
	pub const resize = c.garray_resize_long;
	pub const useInDsp = c.garray_usedindsp;
	pub const setSaveIt = c.garray_setsaveit;
	pub const glist = c.garray_getglist;
	pub const array = c.garray_getarray;

	pub fn floatWords(self: *GArray) ?[]Word {
		var len: c_int = undefined;
		var ptr: [*]Word = undefined;
		return if (c.garray_getfloatwords(self, &len, &ptr) != 0)
			ptr[0..@intCast(len)] else null;
	}
};


// --------------------------------- GPointer ----------------------------------
// -----------------------------------------------------------------------------
pub const Scalar = c.struct__scalar;
pub const GStub = extern struct {
	un: extern union {
		glist: *cnv.GList,
		array: *cnv.Array,
	},
	which: Type,
	refcount: c_int,

	const Type = enum(c_uint) {
		none,
		glist,
		array,
	};
};

pub const GPointer = extern struct {
	un: extern union {
		scalar: *Scalar,
		w: *Word,
	},
	valid: c_int,
	stub: *GStub,

	pub const init = c.gpointer_init;
	pub const copy = c.gpointer_copy;
	pub const unset = c.gpointer_unset;
	pub const check = c.gpointer_check;
};


// ----------------------------------- Inlet -----------------------------------
// -----------------------------------------------------------------------------
pub const Inlet = extern struct {
	pd: Pd,
	next: ?*Inlet,
	owner: *Object,
	dest: ?*Pd,
	symfrom: *Symbol,
	un: extern union {
		symto: *Symbol,
		pointerslot: *GPointer,
		floatslot: *Float,
		symslot: **Symbol,
		floatsignalvalue: Float,
	},

	pub const free = c.inlet_free;
};


// ---------------------------------- Memory -----------------------------------
// -----------------------------------------------------------------------------
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

fn alloc(_: *anyopaque, len: usize, _: u8, _: usize) ?[*]u8 {
	assert(len > 0);
	return @ptrCast(c.getbytes(len));
}

fn resize(_: *anyopaque, buf: []u8, _: u8, new_len: usize, _: usize) bool {
	return (new_len <= buf.len);
}

fn free(_: *anyopaque, buf: []u8, _: u8, _: usize) void {
	c.freebytes(buf.ptr, buf.len);
}

const mem_vtable = Allocator.VTable{
	.alloc = alloc,
	.resize = resize,
	.free = free,
};
pub const mem = Allocator{
	.ptr = undefined,
	.vtable = &mem_vtable,
};


// ---------------------------------- Object -----------------------------------
// -----------------------------------------------------------------------------
pub const GObj = extern struct {
	pd: Pd,
	next: ?*GObj,
};

pub const Object = extern struct {
	g: GObj,            // header for graphical object
	binbuf: *BinBuf,    // holder for the text
	outlets: ?*Outlet,  // linked list of outlets
	inlets: ?*Inlet,    // linked list of inlets
	xpix: i16,          // x&y location (within the toplevel)
	ypix: i16,
	width: i16,         // requested width in chars, 0 if auto
	type: Type,

	const Type = enum(u8) {
		text,    // just a textual comment
		object,  // a MAX style patchable object
		message, // a MAX type message
		atom,    // a cell to display a number or symbol
	};

	pub const list = c.obj_list;
	pub const saveFormat = c.obj_saveformat;
	extern fn outlet_new(*Object, ?*Symbol) ?*Outlet;
	pub const outlet = outlet_new;
	extern fn inlet_new(*Object, *Pd, ?*Symbol, ?*Symbol) ?*Inlet;
	pub const inlet = inlet_new;
	pub const inletPointer = c.pointerinlet_new;
	pub const inletFloat = c.floatinlet_new;
	pub const inletSymbol = c.symbolinlet_new;
	pub const inletSignal = c.signalinlet_new;
	pub const xPix = c.text_xpix;
	pub const yPix = c.text_ypix;

	pub fn inletFloatArg(obj: *Object, fp: *Float, av: []const Atom, i: usize)
	*Inlet {
		fp.* = floatArg(av, i);
		return obj.inletFloat(fp).?;
	}

	pub fn inletSymbolArg(obj: *Object, sp: **Symbol, av: []const Atom, i: usize)
	*Inlet {
		sp.* = symbolArg(av, i);
		return obj.inletSymbol(sp).?;
	}

};


// ---------------------------------- Outlet -----------------------------------
// -----------------------------------------------------------------------------
pub const Outlet = opaque {
	pub const bang = c.outlet_bang;
	pub const pointer = c.outlet_pointer;
	pub const float = c.outlet_float;
	pub const symbol = c.outlet_symbol;
	extern fn outlet_list(*Outlet, ?*Symbol, c_int, [*]Atom) void;
	pub const list = outlet_list;
	pub const anything = c.outlet_anything;
	pub const toSymbol = c.outlet_getsymbol;
	pub const free = c.outlet_free;
};


// ------------------------------------ Pd -------------------------------------
// -----------------------------------------------------------------------------
pub const Pd = extern struct {
	_: *const Class,

	pub const free = c.pd_free;
	pub const bind = c.pd_bind;
	pub const unbind = c.pd_unbind;
	pub const pushSymbol = c.pd_pushsym;
	pub const popSymbol = c.pd_popsym;
	pub const bang = c.pd_bang;
	pub const pointer = c.pd_pointer;
	pub const float = c.pd_float;
	pub const symbol = c.pd_symbol;
	pub const list = c.pd_list;
	pub const anything = c.pd_anything;
	pub const vMess = c.pd_vmess;
	pub const typedMess = c.pd_typedmess;
	pub const forwardMess = c.pd_forwardmess;
	pub const checkObject = c.pd_checkobject;
	pub const parentWidget = c.pd_getparentwidget;
	pub const vStub = c.pdgui_stub_vnew;
	pub const func = c.getfn;
	pub const zFunc = c.zgetfn;
	pub const newest = c.pd_newest; // static
};


// --------------------------------- Resample ----------------------------------
// -----------------------------------------------------------------------------
pub const Resample = extern struct {
	method: i32,
	downsample: i32,
	upsample: i32,
	vec: [*]Sample,
	n: u32,
	coeffs: [*]Sample,
	coefsize: u32,
	buffer: [*]Sample,
	bufsize: u32,

	pub const init = c.resample_init;
	pub const free = c.resample_free;
	pub const dsp = c.resample_dsp;
	pub const fromDsp = c.resamplefrom_dsp;
	pub const toDsp = c.resampleto_dsp;
};


// ---------------------------------- Signal -----------------------------------
// -----------------------------------------------------------------------------
pub const Signal = extern struct {
	len: u32,
	vec: [*]Sample,
	srate: Float,
	nchans: c_int,
	overlap: c_int,
	refcount: c_int,
	isborrowed: c_int,
	isscalar: c_int,
	borrowedfrom: ?*Signal,
	nextfree: ?*Signal,
	nextused: ?*Signal,
	nalloc: c_int,
};
pub const signal = c.signal_new;
pub const setMultiOut = c.signal_setmultiout;


// ---------------------------------- Symbol -----------------------------------
// -----------------------------------------------------------------------------
pub const Symbol = extern struct {
	name: [*:0]const u8,
	thing: ?*Pd,
	next: ?*Symbol,

	pub const setExternDir = c.class_set_extern_dir;
	pub const buf = c.text_getbufbyname;
	pub const notify = c.text_notifybyname;
	pub const val = c.value_get;
	pub const releaseVal = c.value_release;
	pub const float = c.value_getfloat;
	pub const setFloat = c.value_setfloat;
};
pub const symbol = c.gensym;

pub const s = struct {
	pub const pointer = &c.s_pointer;
	pub const float = &c.s_float;
	pub const symbol = &c.s_symbol;
	pub const bang = &c.s_bang;
	pub const list = &c.s_list;
	pub const anything = &c.s_anything;
	pub const signal = &c.s_signal;
	pub const _N = &c.s__N;
	pub const _X = &c.s__X;
	pub const x = &c.s_x;
	pub const y = &c.s_y;
	pub const _ = &c.s_;
};


// ---------------------------------- System -----------------------------------
// -----------------------------------------------------------------------------
pub const blockSize = c.sys_getblksize;
pub const sampleRate = c.sys_getsr;
pub const inChannels = c.sys_get_inchannels;
pub const outChannels = c.sys_get_outchannels;
pub const pretendGuiBytes = c.sys_pretendguibytes;
pub const queueGui = c.sys_queuegui;
pub const unqueueGui = c.sys_unqueuegui;
pub const version = c.sys_getversion;
pub const floatSize = c.sys_getfloatsize;
pub const realTime = c.sys_getrealtime;
pub const open = c.sys_open;
pub const close = c.sys_close;
pub const fopen = c.sys_fopen;
pub const fclose = c.sys_fclose;
pub const lock = c.sys_lock;
pub const unlock = c.sys_unlock;
pub const tryLock = c.sys_trylock;
pub const bashFilename = c.sys_bashfilename;
pub const unbashFilename = c.sys_unbashfilename;
pub const hostFontSize = c.sys_hostfontsize;
pub const zoomFontWidth = c.sys_zoomfontwidth;
pub const zoomFontHeight = c.sys_zoomfontheight;
pub const fontWidth = c.sys_fontwidth;
pub const fontHeight = c.sys_fontheight;

pub fn isAbsolutePath(dir: [*:0]const u8) bool {
	return (c.sys_isabsolutepath(dir) != 0);
}

pub const currentDir = c.canvas_getcurrentdir;
pub const suspendDsp = c.canvas_suspend_dsp;
pub const resumeDsp = c.canvas_resume_dsp;
pub const updateDsp = c.canvas_update_dsp;

pub const setFileName = c.glob_setfilename;

pub const canvasList = c.pd_getcanvaslist;
pub const dspState = c.pd_getdspstate;


// ----------------------------------- Misc. -----------------------------------
// -----------------------------------------------------------------------------
pub extern const pd_objectmaker: Pd;
pub extern const pd_canvasmaker: Pd;

pub const GotFn = c.t_gotfn;
pub const GotFn1 = c.t_gotfn1;
pub const GotFn2 = c.t_gotfn2;
pub const GotFn3 = c.t_gotfn3;
pub const GotFn4 = c.t_gotfn4;
pub const GotFn5 = c.t_gotfn5;

pub const nullFn = c.nullfn;

pub const font = c.sys_font;
pub const font_weight = c.sys_fontweight;

pub const post = struct {
	pub const do = c.post;
	pub const start = c.startpost;
	pub const string = c.poststring;
	pub const float = c.postfloat;
	pub const atom = c.postatom;
	pub const end = c.endpost;
	pub const bug = c.bug;

	extern fn pd_error(?*const anyopaque, fmt: [*:0]const u8, ...) void;
	pub const err = pd_error;

	pub const LogLevel = enum(c_uint) {
		critical,
		err,
		normal,
		debug,
		verbose,
	};
	extern fn logpost(?*const anyopaque, LogLevel, [*:0]const u8, ...) void;
	pub const log = logpost;
};

pub const openViaPath = c.open_via_path;
pub const getEventNo = c.sched_geteventno;

pub extern var sys_idlehook: ?*const fn () callconv(.C) c_int;

pub const plusPerform = c.plus_perform;
pub const plusPerf8 = c.plus_perf8;
pub const zeroPerform = c.zero_perform;
pub const zeroPerf8 = c.zero_perf8;
pub const copyPerform = c.copy_perform;
pub const copyPerf8 = c.copy_perf8;
pub const scalarCopyPerform = c.scalarcopy_perform;
pub const scalarCopyPerf8 = c.scalarcopy_perf8;


pub const mayer = struct {
	pub const fht = c.mayer_fht;
	pub const fft = c.mayer_fft;
	pub const ifft = c.mayer_ifft;
	pub const realfft = c.mayer_realfft;
	pub const realifft = c.mayer_realifft;
};
pub const fft = c.pd_fft;

pub extern const cos_table: [*]f32;

const ushift = std.meta.Int(.unsigned, @log2(@as(f32, @bitSizeOf(usize))));
pub fn ulog2(n: usize) ushift {
	var i = n;
	var r: ushift = 0;
	while (i > 1) : (i >>= 1) {
		r += 1;
	}
	return r;
}

pub const mToF = c.mtof;
pub const fToM = c.ftom;
pub const rmsToDb = c.rmstodb;
pub const powToDb = c.powtodb;
pub const dbToRms = c.dbtorms;
pub const dbToPow = c.dbtopow;
pub const q8Sqrt = c.q8_sqrt;
pub const q8Rsqrt = c.q8_rsqrt;
pub const qSqrt = c.qsqrt;
pub const qRsqrt = c.qrsqrt;

pub const GuiCallbackFn = c.t_guicallbackfn;
extern fn pdgui_vmess(destination: ?[*]const u8, fmt: [*]const u8, ...) void;
pub const vMess = pdgui_vmess;
pub const deleteStubForKey = c.pdgui_stub_deleteforkey;
pub const cExtern = c.c_extern;
pub const cAddMess = c.c_addmess;

pub fn badFloat(f: Float) bool {
	return c.PD_BADFLOAT(f) != 0;
}
pub fn bigOrSmall(f: Float) bool {
	return c.PD_BIGORSMALL(f) != 0;
}

pub const InstanceMidi = c.struct__instancemidi;
pub const InstanceInterface = c.struct__instanceinterface;
pub const InstanceUgen = c.struct__instanceugen;
pub const InstanceCanvas = c.struct__instancecanvas;
pub const InstanceStuff = c.struct__instancestuff;
pub const Template = c.struct__template;
pub const PdInstance = extern struct {
	systime: f64,
	clock_setlist: *Clock,
	canvaslist: *cnv.GList,
	templatelist: *Template,
	instanceno: c_int,
	symhash: **Symbol,
	midi: ?*InstanceMidi,
	inter: ?*InstanceInterface,
	ugen: ?*InstanceUgen,
	gui: ?*InstanceCanvas,
	stuff: ?*InstanceStuff,
	newest: ?*Pd,
	islocked: c_int,
};

pub const this = &c.pd_maininstance;

pub const max_string = c.MAXPDSTRING;
pub const max_arg = c.MAXPDARG;
pub const max_logsig = c.MAXLOGSIG;
pub const max_sigsize = c.MAXSIGSIZE;

pub const PD_USE_TE_XPIX = c.PD_USE_TE_XPIX;
pub const PDTHREADS = c.PDTHREADS;
pub const PERTHREAD = c.PERTHREAD;
