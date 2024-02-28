pub extern const pd_compatibilitylevel: i32;

pub const Int = isize;
pub const Float = f32;
pub const Sample = f32;
pub const FloatUInt = if (Float == f64) u64 else u32;

pub const Method = ?*const fn () callconv(.C) void;
pub const NewMethod = ?*const fn () callconv(.C) *anyopaque;


// ----------------------------------- Atom ------------------------------------
// -----------------------------------------------------------------------------
extern fn atom_getfloat(*const Atom) Float;
extern fn atom_getint(*const Atom) Int;
extern fn atom_getsymbol(*const Atom) *Symbol;
extern fn atom_gensym(*const Atom) *Symbol;
extern fn atom_string(*const Atom, [*]u8, u32) void;
extern fn atom_getfloatarg(u32, u32, *const Atom) Float;
extern fn atom_getintarg(u32, u32, *const Atom) Int;
extern fn atom_getsymbolarg(u32, u32, *const Atom) *Symbol;
pub const Atom = extern struct {
	type: u32,
	w: Word,

	pub const getFloat = atom_getfloat;
	pub const getInt = atom_getint;
	pub const getSymbol = atom_getsymbol;
	pub const genSymbol = atom_gensym;
	pub const string = atom_string;

	pub inline fn getFloatArg(self: *const Atom, which: u32, ac: u32) Float {
		return atom_getfloatarg(which, ac, self);
	}
	pub inline fn getIntArg(self: *const Atom, which: u32, ac: u32) Int {
		return atom_getintarg(which, ac, self);
	}
	pub inline fn getSymbolArg(self: *const Atom, which: u32, ac: u32) *Symbol {
		return atom_getsymbolarg(which, ac, self);
	}
};

pub const AtomType = struct {
	pub const NULL: u32 = 0;
	pub const FLOAT: u32 = 1;
	pub const SYMBOL: u32 = 2;
	pub const POINTER: u32 = 3;
	pub const SEMI: u32 = 4;
	pub const COMMA: u32 = 5;
	pub const DEFFLOAT: u32 = 6;
	pub const DEFSYM: u32 = 7;
	pub const DEFSYMBOL: u32 = 7;
	pub const DOLLAR: u32 = 8;
	pub const DOLLSYM: u32 = 9;
	pub const GIMME: u32 = 10;
	pub const CANT: u32 = 11;
};


// ---------------------------------- BinBuf -----------------------------------
// -----------------------------------------------------------------------------
extern fn binbuf_free(*BinBuf) void;
extern fn binbuf_duplicate(*const BinBuf) *BinBuf;
extern fn binbuf_text(*BinBuf, [*]const u8, usize) void;
extern fn binbuf_gettext(*const BinBuf, *[*]u8, *u32) void;
extern fn binbuf_clear(*BinBuf) void;
extern fn binbuf_add(*BinBuf, u32, [*]const Atom) void;
extern fn binbuf_addv(*BinBuf, [*]const u8, ...) void;
extern fn binbuf_addbinbuf(*BinBuf, *const BinBuf) void;
extern fn binbuf_addsemi(*BinBuf) void;
extern fn binbuf_restore(*BinBuf, u32, [*]const Atom) void;
extern fn binbuf_print(*const BinBuf) void;
extern fn binbuf_getnatom(*const BinBuf) u32;
extern fn binbuf_getvec(*const BinBuf) [*]Atom;
extern fn binbuf_resize(*BinBuf, u32) u32;
extern fn binbuf_eval(*const BinBuf, *Pd, u32, [*]const Atom) void;
extern fn binbuf_read(*BinBuf, [*]const u8, [*]const u8, u32) u32;
extern fn binbuf_read_via_canvas(*BinBuf, [*]const u8, *const GList, u32) u32;
extern fn binbuf_read_via_path(*BinBuf, [*]const u8, [*]const u8, u32) u32;
extern fn binbuf_write(*const BinBuf, [*]const u8, [*]const u8, u32) u32;
pub const BinBuf = opaque {
	pub const free = binbuf_free;
	pub const duplicate = binbuf_duplicate;
	pub const text = binbuf_text;
	pub const getText = binbuf_gettext;
	pub const clear = binbuf_clear;
	pub const add = binbuf_add;
	pub const addV = binbuf_addv;
	pub const addBinBuf = binbuf_addbinbuf;
	pub const addSemi = binbuf_addsemi;
	pub const restore = binbuf_restore;
	pub const print = binbuf_print;
	pub const getNAtom = binbuf_getnatom;
	pub const getVec = binbuf_getvec;
	pub const resize = binbuf_resize;
	pub const eval = binbuf_eval;
	pub const read = binbuf_read;
	pub const readViaCanvas = binbuf_read_via_canvas;
	pub const readViaPath = binbuf_read_via_path;
	pub const write = binbuf_write;
};
extern fn binbuf_new() *BinBuf;
pub const binbuf = binbuf_new;


// ----------------------------------- Class -----------------------------------
// -----------------------------------------------------------------------------
pub const MethodEntry = extern struct {
	name: *Symbol,
	fun: GotFn,
	arg: [6]u8,
};

pub const BangMethod = ?*const fn (*Pd) callconv(.C) void;
pub const PointerMethod = ?*const fn (*Pd, *GPointer) callconv(.C) void;
pub const FloatMethod = ?*const fn (*Pd, Float) callconv(.C) void;
pub const SymbolMethod = ?*const fn (*Pd, *Symbol) callconv(.C) void;
pub const ListMethod = ?*const fn (*Pd, *Symbol, u32, [*]Atom) callconv(.C) void;
pub const AnyMethod = ?*const fn (*Pd, *Symbol, u32, [*]Atom) callconv(.C) void;

extern fn class_free(*Class) void;
extern fn class_addmethod(*Class, Method, *Symbol, u32, ...) void;
extern fn class_addbang(*Class, Method) void;
extern fn class_addpointer(*Class, Method) void;
extern fn class_doaddfloat(*Class, Method) void;
extern fn class_addsymbol(*Class, Method) void;
extern fn class_addlist(*Class, Method) void;
extern fn class_addanything(*Class, Method) void;
extern fn class_sethelpsymbol(*Class, *Symbol) void;
extern fn class_setwidget(*Class, ?*const WidgetBehavior) void;
extern fn class_setparentwidget(*Class, ?*const ParentWidgetBehavior) void;
extern fn class_getname(*const Class) [*]const u8;
extern fn class_gethelpname(*const Class) [*]const u8;
extern fn class_gethelpdir(*const Class) [*]const u8;
extern fn class_setdrawcommand(*Class) void;
extern fn class_isdrawcommand(*const Class) i32;
extern fn class_domainsignalin(*Class, c_int) void;
pub const SaveFn = ?*const fn (*GObj, ?*BinBuf) callconv(.C) void;
extern fn class_setsavefn(*Class, SaveFn) void;
extern fn class_getsavefn(*const Class) SaveFn;
pub const PropertiesFn = *const fn (*GObj, *GList) callconv(.C) void;
extern fn class_setpropertiesfn(*Class, PropertiesFn) void;
extern fn class_getpropertiesfn(*const Class) PropertiesFn;
pub const ClassFreeFn = ?*const fn (*Class) callconv(.C) void;
extern fn class_setfreefn(*Class, ClassFreeFn) void;
extern fn pd_new(*Class) *Pd;
extern fn pd_findbyclass(*Symbol, *const Class) ?*Pd;
pub const Class = extern struct {
	name: *Symbol,
	helpname: *Symbol,
	externdir: *Symbol,
	size: usize,
	methods: [*]MethodEntry,
	nmethod: u32,
	freemethod: Method,
	bangmethod: BangMethod,
	pointermethod: PointerMethod,
	floatmethod: FloatMethod,
	symbolmethod: SymbolMethod,
	listmethod: ListMethod,
	anymethod: AnyMethod,
	wb: ?*const WidgetBehavior,
	pwb: ?*const ParentWidgetBehavior,
	savefn: SaveFn,
	propertiesfn: PropertiesFn,
	next: *Class,
	floatsignalin: i32,
	flags: u8,
	classfreefn: ClassFreeFn,

	pub const free = class_free;
	pub const addMethod = class_addmethod;
	pub const addBang = class_addbang;
	pub const addPointer = class_addpointer;
	pub const addFloat = class_doaddfloat;
	pub const addSymbol = class_addsymbol;
	pub const addList = class_addlist;
	pub const addAnything = class_addanything;
	pub const setHelpSymbol = class_sethelpsymbol;
	pub const setWidget = class_setwidget;
	pub const setParentWidget = class_setparentwidget;
	pub const getName = class_getname;
	pub const getHelpName = class_gethelpname;
	pub const getHelpDir = class_gethelpdir;
	pub const setDrawCommand = class_setdrawcommand;
	pub const isDrawCommand = class_isdrawcommand;
	pub const doMainSignalIn = class_domainsignalin;
	pub const setSaveFn = class_setsavefn;
	pub const getSaveFn = class_getsavefn;
	pub const setPropertiesFn = class_setpropertiesfn;
	pub const getPropertiesFn = class_getpropertiesfn;
	pub const setFreeFn = class_setfreefn;
	pub const new = pd_new;

	pub inline fn find(self: *const Class, sym: *Symbol) ?*Pd {
		return pd_findbyclass(sym, self);
	}

	pub const DEFAULT: u32 = 0;     // flags for new classes below
	pub const PD: u32 = 1;          // non-canvasable (bare) pd such as an inlet
	pub const GOBJ: u32 = 2;        // pd that can belong to a canvas
	pub const PATCHABLE: u32 = 3;   // pd that also can have inlets and outlets
	pub const TYPEMASK: u32 = 3;
	pub const NOINLET: u32 = 8;          // suppress left inlet
	pub const MULTICHANNEL: u32 = 0x10;  // can deal with multichannel signals
	pub const NOPROMOTESIG: u32 = 0x20;  // don't promote scalars to signals
	pub const NOPROMOTELEFT: u32 = 0x40; // not even the main (left) inlet
};
extern fn class_new(*Symbol, NewMethod, Method, usize, u32, u32, ...) *Class;
extern fn class_new64(*Symbol, NewMethod, Method, usize, u32, u32, ...) *Class;
pub const class = class_new;
pub const class64 = class_new64;

pub extern const garray_class: *Class;
pub extern const scalar_class: *Class;
pub extern const glob_pdobject: *Class;


// ----------------------------------- Clock -----------------------------------
// -----------------------------------------------------------------------------
extern fn clock_set(*Clock, f64) void;
extern fn clock_delay(*Clock, f64) void;
extern fn clock_unset(*Clock) void;
extern fn clock_setunit(*Clock, f64, u32) void;
extern fn clock_free(*Clock) void;
pub const Clock = opaque {
	pub const set = clock_set;
	pub const delay = clock_delay;
	pub const unset = clock_unset;
	pub const setUnit = clock_setunit;
	pub const free = clock_free;
};
extern fn clock_new(*anyopaque, Method) *Clock;
pub const clock = clock_new;


// ------------------------------------ Dsp ------------------------------------
// -----------------------------------------------------------------------------
extern fn dsp_add(PerfRoutine, u32, ...) void;
extern fn dsp_addv(PerfRoutine, u32, [*]Int) void;
extern fn dsp_add_plus([*]Sample, [*]Sample, [*]Sample, u32) void;
extern fn dsp_add_copy([*]Sample, [*]Sample, u32) void;
extern fn dsp_add_scalarcopy([*]Float, [*]Sample, u32) void;
extern fn dsp_add_zero([*]Sample, u32) void;
pub const Dsp = struct {
	pub const add = dsp_add;
	pub const addV = dsp_addv;
	pub const addPlus = dsp_add_plus;
	pub const addCopy = dsp_add_copy;
	pub const addScalarCopy = dsp_add_scalarcopy;
	pub const addZero = dsp_add_zero;
};


// ---------------------------------- GArray -----------------------------------
// -----------------------------------------------------------------------------
extern fn garray_getfloatarray(*GArray, *u32, *?[*]Float) i32;
extern fn garray_getfloatwords(*GArray, *u32, *?[*]Word) i32;
extern fn garray_redraw(*GArray) void;
extern fn garray_npoints(*GArray) i32;
extern fn garray_vec(*GArray) [*]u8;
extern fn garray_resize(*GArray, Float) void;
extern fn garray_resize_long(*GArray, i64) void;
extern fn garray_usedindsp(*GArray) void;
extern fn garray_setsaveit(*GArray, i32) void;
extern fn garray_getglist(*GArray) *GList;
extern fn garray_getarray(*GArray) *Array;
pub const GArray = opaque {
	pub const getFloatArray = garray_getfloatarray;
	pub const getFloatWords = garray_getfloatwords;
	pub const redraw = garray_redraw;
	pub const nPoints = garray_npoints;
	pub const vec = garray_vec;
	pub const resize = garray_resize;
	pub const resizeLong = garray_resize_long;
	pub const useInDsp = garray_usedindsp;
	pub const setSaveIt = garray_setsaveit;
	pub const getGList = garray_getglist;
	pub const getArray = garray_getarray;
};


// ----------------------------------- GList -----------------------------------
// -----------------------------------------------------------------------------
extern fn canvas_makefilename(*const GList, [*]const u8, [*]u8, u32) void;
extern fn canvas_getdir(*const GList) *Symbol;
extern fn canvas_dataproperties(*GList, *Scalar, *BinBuf) void;
extern fn canvas_open(*const GList, [*]const u8, [*]const u8, [*]u8, *[*]u8, u32, u32) i32;
extern fn canvas_getsr(*GList) Float;
extern fn canvas_getsignallength(*GList) u32;
extern fn pd_undo_set_objectstate(*GList, *Pd, *Symbol, u32, [*]Atom, u32, [*]Atom) void;
extern fn canvas_setargs(u32, [*]const Atom) void;
extern fn canvas_getargs(*u32, *[*]Atom) void;
extern fn canvas_getcurrent() ?*GList;
pub const GList = opaque {
	pub const makeFilename = canvas_makefilename;
	pub const getDir = canvas_getdir;
	pub const dataProperties = canvas_dataproperties;
	pub const open = canvas_open;
	pub const getSampleRate = canvas_getsr;
	pub const getSignalLength = canvas_getsignallength;
	pub const undoSetState = pd_undo_set_objectstate;
	// static methods
	pub const setArgs = canvas_setargs;
	pub const getArgs = canvas_getargs;
	pub const getCurrent = canvas_getcurrent;
};


// --------------------------------- GPointer ----------------------------------
// -----------------------------------------------------------------------------
extern fn gpointer_init(*GPointer) void;
extern fn gpointer_copy(*const GPointer, *GPointer) void;
extern fn gpointer_unset(*GPointer) void;
extern fn gpointer_check(*const GPointer, u32) u32;
pub const GPointer = extern struct {
	un: extern union {
		scalar: *Scalar,
		w: *Word,
	},
	valid: c_int,
	stub: *GStub,

	pub const init = gpointer_init;
	pub const copy = gpointer_copy;
	pub const unset = gpointer_unset;
	pub const check = gpointer_check;
};


// ----------------------------------- Inlet -----------------------------------
// -----------------------------------------------------------------------------
extern fn inlet_free(*Inlet) void;
pub const Inlet = extern struct {
	pd: Pd,
	next: *Inlet,
	owner: *Object,
	dest: *Pd,
	symfrom: *Symbol,
	un: extern union {
		symto: *Symbol,
		pointerslot: *GPointer,
		floatslot: *Float,
		symslot: **Symbol,
		floatsignalvalue: Float,
	},

	pub const free = inlet_free;
};


// ---------------------------------- Object -----------------------------------
// -----------------------------------------------------------------------------
extern fn obj_list(*Object, *Symbol, u32, [*]Atom) void;
extern fn obj_saveformat(*const Object, ?*BinBuf) void;
extern fn outlet_new(*Object, *Symbol) *Outlet;
extern fn inlet_new(*Object, *Pd, ?*Symbol, ?*Symbol) *Inlet;
extern fn pointerinlet_new(*Object, *GPointer) *Inlet;
extern fn floatinlet_new(*Object, *Float) *Inlet;
extern fn symbolinlet_new(*Object, **Symbol) *Inlet;
extern fn signalinlet_new(*Object, Float) *Inlet;
pub const Object = extern struct {
	g: GObj,
	binbuf: *BinBuf,
	out: *Outlet,
	in: *Inlet,
	xpix: i16,
	ypix: i16,
	width: i16,
	type: ObjectType,

	pub const list = obj_list;
	pub const saveFormat = obj_saveformat;
	pub const outlet = outlet_new;
	pub const inlet = inlet_new;
	pub const inletPointer = pointerinlet_new;
	pub const inletFloat = floatinlet_new;
	pub const inletSymbol = symbolinlet_new;
	pub const inletSignal = signalinlet_new;
};

pub const ObjectType = enum(u8) {
	text = 0,
	object = 1,
	message = 2,
	atom = 3,
};


// ---------------------------------- Outlet -----------------------------------
// -----------------------------------------------------------------------------
extern fn outlet_bang(*Outlet) void;
extern fn outlet_pointer(*Outlet, *GPointer) void;
extern fn outlet_float(*Outlet, Float) void;
extern fn outlet_symbol(*Outlet, *Symbol) void;
extern fn outlet_list(*Outlet, *Symbol, u32, [*]Atom) void;
extern fn outlet_anything(*Outlet, *Symbol, u32, [*]Atom) void;
extern fn outlet_getsymbol(*Outlet) *Symbol;
extern fn outlet_free(*Outlet) void;
pub const Outlet = opaque {
	pub const bang = outlet_bang;
	pub const pointer = outlet_pointer;
	pub const float = outlet_float;
	pub const symbol = outlet_symbol;
	pub const list = outlet_list;
	pub const anything = outlet_anything;
	pub const getSymbol = outlet_getsymbol;
	pub const free = outlet_free;
};


// ------------------------------------ Pd -------------------------------------
// -----------------------------------------------------------------------------
extern fn pd_free(*Pd) void;
extern fn pd_bind(*Pd, *Symbol) void;
extern fn pd_unbind(*Pd, *Symbol) void;
extern fn pd_pushsym(*Pd) void;
extern fn pd_popsym(*Pd) void;
extern fn pd_bang(*Pd) void;
extern fn pd_pointer(*Pd, *GPointer) void;
extern fn pd_float(*Pd, Float) void;
extern fn pd_symbol(*Pd, *Symbol) void;
extern fn pd_list(*Pd, *Symbol, u32, [*]Atom) void;
extern fn pd_anything(*Pd, *Symbol, u32, [*]Atom) void;
extern fn pd_vmess(*Pd, *Symbol, [*]const u8, ...) void;
extern fn pd_typedmess(*Pd, *Symbol, u32, [*]Atom) void;
extern fn pd_forwardmess(*Pd, u32, [*]Atom) void;
extern fn pd_checkobject(*Pd) ?*Object;
extern fn pd_getparentwidget(*Pd) ?*const ParentWidgetBehavior;
extern fn gfxstub_new(*Pd, ?*anyopaque, [*]const u8) void;
extern fn pdgui_stub_vnew(*Pd, [*]const u8, ?*anyopaque, [*]const u8, ...) void;
extern fn getfn(*const Pd, *Symbol) GotFn;
extern fn zgetfn(*const Pd, *Symbol) GotFn;
extern fn pd_newest() *Pd;
pub const Pd = extern struct {
	_: *Class,

	pub const free = pd_free;
	pub const bind = pd_bind;
	pub const unbind = pd_unbind;
	pub const pushSymbol = pd_pushsym;
	pub const popSymbol = pd_popsym;
	pub const bang = pd_bang;
	pub const pointer = pd_pointer;
	pub const float = pd_float;
	pub const symbol = pd_symbol;
	pub const list = pd_list;
	pub const anything = pd_anything;
	pub const vMess = pd_vmess;
	pub const typedMess = pd_typedmess;
	pub const forwardMess = pd_forwardmess;
	pub const checkObject = pd_checkobject;
	pub const getParentWidget = pd_getparentwidget;
	pub const gfxStub = gfxstub_new;
	pub const guiStub = pdgui_stub_vnew;
	pub const getFn = getfn;
	pub const zGetFn = zgetfn;
	pub const newest = pd_newest; // static
};


// --------------------------------- Resample ----------------------------------
// -----------------------------------------------------------------------------
extern fn resample_init(*Resample) void;
extern fn resample_free(*Resample) void;
extern fn resample_dsp(*Resample, [*]Sample, u32, [*]Sample, u32, u32) void;
extern fn resamplefrom_dsp(*Resample, [*]Sample, u32, u32, u32) void;
extern fn resampleto_dsp(*Resample, [*]Sample, u32, u32, u32) void;
pub const Resample = extern struct {
	method: c_int,
	downsample: c_int,
	upsample: c_int,
	vec: [*]Sample,
	n: u32,
	coeffs: [*]Sample,
	coefsize: u32,
	buffer: [*]Sample,
	bufsize: u32,

	pub const init = resample_init;
	pub const free = resample_free;
	pub const dsp = resample_dsp;
	pub const fromDsp = resamplefrom_dsp;
	pub const toDsp = resampleto_dsp;
};


// ---------------------------------- Signal -----------------------------------
// -----------------------------------------------------------------------------
pub const Signal = extern struct {
	len: u32,
	vec: [*]Sample,
	srate: Float,
	nchans: u32,
	overlap: i32,
	refcount: i32,
	isborrowed: i32,
	isscalar: i32,
	borrowedfrom: *Signal,
	nextfree: *Signal,
	nextused: *Signal,
	nalloc: i32,
};
extern fn signal_new(u32, u32, Float, [*]Sample) *Signal;
pub const signal = signal_new;


// ---------------------------------- Symbol -----------------------------------
// -----------------------------------------------------------------------------
extern fn class_set_extern_dir(*Symbol) void;
extern fn text_getbufbyname(*Symbol) ?*BinBuf;
extern fn text_notifybyname(*Symbol) void;
extern fn value_get(*Symbol) *Float;
extern fn value_release(*Symbol) void;
extern fn value_getfloat(*Symbol, *Float) u32;
extern fn value_setfloat(*Symbol, Float) u32;
pub const Symbol = extern struct {
	name: [*:0]const u8,
	thing: ?*Pd,
	next: ?*Symbol,

	pub const setExternDir = class_set_extern_dir;
	pub const getBuf = text_getbufbyname;
	pub const notify = text_notifybyname;
	pub const getVal = value_get;
	pub const releaseVal = value_release;
	pub const getFloat = value_getfloat;
	pub const setFloat = value_setfloat;
};
extern fn gensym([*]const u8) *Symbol;
pub const symbol = gensym;

extern var s_pointer: Symbol;
extern var s_float: Symbol;
extern var s_symbol: Symbol;
extern var s_bang: Symbol;
extern var s_list: Symbol;
extern var s_anything: Symbol;
extern var s_signal: Symbol;
extern var s__N: Symbol;
extern var s__X: Symbol;
extern var s_x: Symbol;
extern var s_y: Symbol;
extern var s_: Symbol;
pub const s = struct {
	pub const pointer = &s_pointer;
	pub const float = &s_float;
	pub const symbol = &s_symbol;
	pub const bang = &s_bang;
	pub const list = &s_list;
	pub const anything = &s_anything;
	pub const signal = &s_signal;
	pub const _N = &s__N;
	pub const _X = &s__X;
	pub const x = &s_x;
	pub const y = &s_y;
	pub const _ = &s_;
};


// ------------------------------ Static methods -------------------------------
// -----------------------------------------------------------------------------
extern fn sys_getblksize() u32;
extern fn sys_getsr() Float;
extern fn sys_get_inchannels() u32;
extern fn sys_get_outchannels() u32;
extern fn sys_vgui([*]const u8, ...) void;
extern fn sys_gui([*]const u8) void;
extern fn sys_pretendguibytes(i32) void;
extern fn sys_queuegui(?*anyopaque, ?*GList, GuiCallbackFn) void;
extern fn sys_unqueuegui(?*anyopaque) void;
extern fn sys_getversion(*i32, *i32, *i32) void;
extern fn sys_getfloatsize() c_uint;
extern fn sys_getrealtime() f64;
extern fn sys_open([*]const u8, c_int, ...) c_int;
extern fn sys_close(c_int) c_int;
// extern fn sys_fopen([*]const u8, [*]const u8) *FILE;
// extern fn sys_fclose(*FILE) c_int;
extern fn sys_lock() void;
extern fn sys_unlock() void;
extern fn sys_trylock() c_int;
extern fn sys_isabsolutepath([*]const u8) c_int;
extern fn sys_bashfilename([*]const u8, [*]u8) void;
extern fn sys_unbashfilename([*]const u8, [*]u8) void;
extern fn sys_hostfontsize(c_int, c_int) c_int;
extern fn sys_zoomfontwidth(c_int, c_int, c_int) c_int;
extern fn sys_zoomfontheight(c_int, c_int, c_int) c_int;
extern fn sys_fontwidth(c_int) c_int;
extern fn sys_fontheight(c_int) c_int;
pub const getBlockSize = sys_getblksize;
pub const getSampleRate = sys_getsr;
pub const getInChannels = sys_get_inchannels;
pub const getOutChannels = sys_get_outchannels;
pub const vgui = sys_vgui;
pub const gui = sys_gui;
pub const pretendGuiBytes = sys_pretendguibytes;
pub const queueGui = sys_queuegui;
pub const unqueueGui = sys_unqueuegui;
pub const getVersion = sys_getversion;
pub const getFloatSize = sys_getfloatsize;
pub const getRealTime = sys_getrealtime;
pub const open = sys_open;
pub const close = sys_close;
// pub const fopen = sys_fopen;
// pub const fclose = sys_fclose;
pub const lock = sys_lock;
pub const unlock = sys_unlock;
pub const tryLock = sys_trylock;
pub const isAbsolutePath = sys_isabsolutepath;
pub const bashFilename = sys_bashfilename;
pub const unbashFilename = sys_unbashfilename;
pub const hostFontSize = sys_hostfontsize;
pub const zoomFontWidth = sys_zoomfontwidth;
pub const zoomFontHeight = sys_zoomfontheight;
pub const fontWidth = sys_fontwidth;
pub const fontHeight = sys_fontheight;

extern fn class_addcreator(NewMethod, *Symbol, u32, ...) void;
pub const addCreator = class_addcreator;

extern fn binbuf_evalfile(*Symbol, *Symbol) void;
extern fn binbuf_realizedollsym(*Symbol, u32, [*]const Atom, u32) *Symbol;
pub const evalFile = binbuf_evalfile;
pub const realizeDollSym = binbuf_realizedollsym;

extern fn signal_setmultiout(*[*]Signal, u32) void;
pub const setMultiOut = signal_setmultiout;

extern fn clock_getlogicaltime() f64;
extern fn clock_getsystime() f64;
extern fn clock_gettimesince(f64) f64;
extern fn clock_gettimesincewithunits(f64, f64, u32) f64;
extern fn clock_getsystimeafter(f64) f64;
pub const getLogicalTime = clock_getlogicaltime;
pub const getSysTime = clock_getsystime;
pub const getTimeSince = clock_gettimesince;
pub const getTimeSinceWithUnits = clock_gettimesincewithunits;
pub const getSysTimeAfter = clock_getsystimeafter;

extern fn canvas_getcurrentdir() *Symbol;
extern fn canvas_suspend_dsp() c_int;
extern fn canvas_resume_dsp(c_int) void;
extern fn canvas_update_dsp() void;
pub const getCurrentDir = canvas_getcurrentdir;
pub const suspendDsp = canvas_suspend_dsp;
pub const resumeDsp = canvas_resume_dsp;
pub const updateDsp = canvas_update_dsp;

extern fn pd_getcanvaslist() ?*GList;
extern fn pd_getdspstate() c_int;
pub const getCanvasList = pd_getcanvaslist;
pub const getDspState = pd_getdspstate;

extern fn pd_error(?*const anyopaque, [*]const u8, ...) void;
pub const err = pd_error;

// ----------------------------------- Misc. -----------------------------------
// -----------------------------------------------------------------------------
pub const OutConnect = opaque {};
pub const Template = opaque {};
pub const Array = opaque {};

pub const GObj = extern struct {
	pd: Pd,
	next: *GObj,
};

pub const GStub = extern struct {
	un: extern union {
		glist: *GList,
		array: *Array,
	},
	which: i32,
	refcount: i32,
};

pub const Scalar = extern struct {
	gobj: GObj,
	template: *Symbol,
	vec: [1]Word,
};

pub const Word = extern union {
	float: Float,
	symbol: *Symbol,
	gpointer: *GPointer,
	array: *Array,
	binbuf: *BinBuf,
	index: c_int,
};

pub extern var pd_objectmaker: Pd;
pub extern var pd_canvasmaker: Pd;

pub const GotFn = ?*const fn (*anyopaque, ...) callconv(.C) void;
pub const GotFn1 = ?*const fn (*anyopaque, *anyopaque) callconv(.C) void;
pub const GotFn2 = ?*const fn (*anyopaque, *anyopaque, *anyopaque) callconv(.C) void;
pub const GotFn3 = ?*const fn (*anyopaque, *anyopaque, *anyopaque, *anyopaque) callconv(.C) void;
pub const GotFn4 = ?*const fn (*anyopaque, *anyopaque, *anyopaque, *anyopaque, *anyopaque) callconv(.C) void;
pub const GotFn5 = ?*const fn (*anyopaque, *anyopaque, *anyopaque, *anyopaque, *anyopaque, *anyopaque) callconv(.C) void;

pub extern fn nullfn() void;

pub extern fn getbytes(usize) ?*anyopaque;
pub extern fn getzbytes(usize) ?*anyopaque;
pub extern fn copybytes(?*const anyopaque, usize) ?*anyopaque;
pub extern fn freebytes(?*anyopaque, usize) void;
pub extern fn resizebytes(?*anyopaque, usize, usize) ?*anyopaque;

pub extern fn glob_setfilename(?*anyopaque, *Symbol, *Symbol) void;

pub const sys_font: [*]u8 = @extern([*]u8, .{
	.name = "sys_font",
});
pub const sys_fontweight: [*]u8 = @extern([*]u8, .{
	.name = "sys_fontweight",
});

pub const WidgetBehavior = opaque {};
pub const ParentWidgetBehavior = opaque {};

pub extern fn post([*]const u8, ...) void;
pub extern fn startpost([*]const u8, ...) void;
pub extern fn poststring([*]const u8) void;
pub extern fn postfloat(Float) void;
pub extern fn postatom(u32, [*]const Atom) void;
pub extern fn endpost() void;

pub extern fn bug([*]const u8, ...) void;
pub extern fn logpost(?*const anyopaque, c_int, [*]const u8, ...) void;
pub extern fn verbose(c_int, [*]const u8, ...) void;
pub const LogLevel = enum(u32) {
	critical,
	err,
	normal,
	debug,
	verbose
};

pub extern fn open_via_path([*]const u8, [*]const u8, [*]const u8, [*]u8, *[*]u8, u32, u32) i32;
pub extern fn sched_geteventno() c_int;
pub extern var sys_idlehook: ?*const fn () callconv(.C) c_int;

pub const PerfRoutine = ?*const fn ([*]Int) *Int;
pub extern fn plus_perform([*]Int) *Int;
pub extern fn plus_perf8([*]Int) *Int;
pub extern fn zero_perform([*]Int) *Int;
pub extern fn zero_perf8([*]Int) *Int;
pub extern fn copy_perform([*]Int) *Int;
pub extern fn copy_perf8([*]Int) *Int;
pub extern fn scalarcopy_perform([*]Int) *Int;
pub extern fn scalarcopy_perf8([*]Int) *Int;

pub extern fn pd_fft([*]Float, u32, u32) void;
pub extern fn ilog2(u32) u32;
pub extern fn mayer_fht([*]Sample, u32) void;
pub extern fn mayer_fft(u32, [*]Sample, [*]Sample) void;
pub extern fn mayer_ifft(u32, [*]Sample, [*]Sample) void;
pub extern fn mayer_realfft(u32, [*]Sample) void;
pub extern fn mayer_realifft(u32, [*]Sample) void;
pub extern var cos_table: [*]f32;

pub extern fn mtof(Float) Float;
pub extern fn ftom(Float) Float;
pub extern fn rmstodb(Float) Float;
pub extern fn powtodb(Float) Float;
pub extern fn dbtorms(Float) Float;
pub extern fn dbtopow(Float) Float;
pub extern fn q8_sqrt(Float) Float;
pub extern fn q8_rsqrt(Float) Float;
pub extern fn qsqrt(Float) Float;
pub extern fn qrsqrt(Float) Float;

pub const GuiCallbackFn = ?*const fn (*GObj, ?*GList) callconv(.C) void;
pub extern fn gfxstub_deleteforkey(?*anyopaque) void;
pub extern fn pdgui_vmess([*]const u8, [*]const u8, ...) void;
pub extern fn pdgui_stub_deleteforkey(?*anyopaque) void;
pub extern fn c_extern(*Pd, NewMethod, Method, *Symbol, usize, c_int, u32, ...) void;
pub extern fn c_addmess(Method, *Symbol, u32, ...) void;


pub const BigOrSmall32 = extern union {
	f: Float,
	ui: u32,
};
pub inline fn badFloat(f: Float) bool {
	var pun = BigOrSmall32 { .f = f }; 
	pun.ui &= 0x7f800000;
	return pun.ui == 0 or pun.ui == 0x7f800000;
}
pub inline fn bigOrSmall(f: Float) bool {
	const pun = BigOrSmall32 { .f = f };
	return pun.ui & 0x20000000 == (pun.ui >> 1) & 0x20000000;
}

pub const MidiInstance = opaque {};
pub const InterfaceInstance = opaque {};
pub const CanvasInstance = opaque {};
pub const UgenInstance = opaque {};
pub const StuffInstance = opaque {};
pub const PdInstance = extern struct {
	systime: f64,
	clock_setlist: *Clock,
	canvaslist: *GList,
	templatelist: *Template,
	instanceno: u32,
	symhash: **Symbol,
	midi: *MidiInstance,
	inter: *InterfaceInstance,
	ugen: *UgenInstance,
	gui: *CanvasInstance,
	stuff: *StuffInstance,
	newest: *Pd,
	islocked: u32,
};
pub extern var pd_maininstance: PdInstance;
pub const this = &pd_maininstance;

pub const MAXPDSTRING: u32 = 1000;
pub const MAXPDARG: u32 = 5;
pub const MAXLOGSIG: u32 = 32;
pub const MAXSIGSIZE: u32 = 1 << MAXLOGSIG;

pub const GP_NONE = @as(c_int, 0);
pub const GP_GLIST = @as(c_int, 1);
pub const GP_ARRAY = @as(c_int, 2);

pub const LOGCOSTABSIZE: u32 = 9;
pub const COSTABSIZE: u32 = 1 << LOGCOSTABSIZE;

pub const typedmess = pd_typedmess;
pub const vmess = pd_vmess;
pub const PD_USE_TE_XPIX = "";
pub const PDTHREADS = @as(c_int, 1);
pub const PERTHREAD = "";
