const c = @import("m_pd.zig");
const pd = @import("main.zig");
const cnv = @import("canvas.zig");

pub const io_height: u32 = c.IEM_GUI_IOHEIGHT;
pub const min_size: u32 = c.IEM_GUI_MINSIZE;
pub const max_size: u32 = c.IEM_GUI_MAXSIZE;
pub const max_num_len: u32 = c.IEMGUI_MAX_NUM_LEN;

pub fn isFloat(av: []pd.Atom) bool {
	for (av) |*a| {
		if (a.type != .float) {
			return false;
		}
	}
	return true;
}

pub fn isSymbolOrFloat(av: []pd.Atom) bool {
	for (av) |*a| {
		if (a.type != .float and a.type != .symbol) {
			return false;
		}
	}
	return true;
}


// ------------------------------------ Gui ------------------------------------
// -----------------------------------------------------------------------------
const DrawMode = enum(c_uint) {
	update,
	move,
	new,
	select,
	erase,
	config,
	io,
};

pub const FunPtr = ?*const fn (?*anyopaque, ?*cnv.GList, DrawMode) callconv(.C) void;
pub const DrawFunPtr = c.t_iemdrawfunptr;
const Private = c.struct__iemgui_private_8;

pub const DrawFunctions = extern struct {
	new: DrawFunPtr = null,
	config: DrawFunPtr = null,
	iolets: FunPtr = null,
	update: DrawFunPtr = null,
	select: DrawFunPtr = null,
	erase: DrawFunPtr = null,
	move: DrawFunPtr = null,
};

pub const FontStyleFlags = packed struct(u32) {
	font_style: u6,
	rcv_able: bool,
	snd_able: bool,
	lab_is_unique: bool,
	rcv_is_unique: bool,
	snd_is_unique: bool,
	lab_arg_tail_len: u6,
	lab_is_arg_num: u6,
	shiftdown: bool,
	selected: bool,
	finemoved: bool,
	put_in2out: bool,
	change: bool,
	thick: bool,
	lin0_log1: bool,
	steady: bool,
	_padding: u1,

	pub const set = c.iem_inttofstyle;
	pub const toInt = c.iem_fstyletoint;
};

pub const InitSymArgs = packed struct(u32) {
	loadinit: bool,
	rcv_arg_tail_len: u6,
	snd_arg_tail_len: u6,
	rcv_is_arg_num: u6,
	snd_is_arg_num: u6,
	scale: bool,
	flashed: bool,
	locked: bool,
	_padding: u4,

	pub const set = c.iem_inttosymargs;
	pub const toInt = c.iem_symargstoint;
};

pub const Gui = extern struct {
	obj: pd.Object,
	glist: *cnv.GList,
	draw: FunPtr,
	h: c_uint,
	w: c_uint,
	private: *Private,
	ldx: c_int,
	ldy: c_int,
	font: [pd.max_string-1:0]u8,
	fsf: FontStyleFlags,
	fontsize: c_uint,
	isa: InitSymArgs,
	fcol: c_uint,
	bcol: c_uint,
	lcol: c_uint,
	snd: ?*pd.Symbol,
	rcv: ?*pd.Symbol,
	lab: *pd.Symbol,
	snd_unexpanded: *pd.Symbol,
	rcv_unexpanded: *pd.Symbol,
	lab_unexpanded: *pd.Symbol,
	binbufindex: c_int,
	labelbindex: c_int,

	pub const free = c.iemgui_free;
	pub const verifySndNotRcv = c.iemgui_verify_snd_ne_rcv;
	pub const sym2DollarArg = c.iemgui_all_sym2dollararg;
	pub const dollarArg2Sym = c.iemgui_all_dollararg2sym;
	pub const newName = c.iemgui_new_dogetname;
	extern fn iemgui_new_getnames(iemgui: *Gui, indx: c_int, argv: ?[*]pd.Atom) void;
	pub const newNames = iemgui_new_getnames;
	pub const loadColors = c.iemgui_all_loadcolors;
	extern fn iemgui_setdrawfunctions(iemgui: *Gui, w: *const DrawFunctions) void;
	pub const setDrawFunctions = iemgui_setdrawfunctions;
	pub const save = c.iemgui_save;
	pub const zoom = c.iemgui_zoom;
	pub const newZoom = c.iemgui_newzoom;
	pub const properties = c.iemgui_properties;

	pub fn size(self: *Gui, x: *anyopaque) void {
		c.iemgui_size(x, self);
	}

	pub fn delta(self: *Gui, x: *anyopaque, s: *pd.Symbol, av: []pd.Atom)
	void {
		c.iemgui_delta(x, self, s, @intCast(av.len), av.ptr);
	}

	pub fn pos(self: *Gui, x: *anyopaque, s: *pd.Symbol, av: []pd.Atom)
	void {
		c.iemgui_pos(x, self, s, @intCast(av.len), av.ptr);
	}

	pub fn color(self: *Gui, x: *anyopaque, s: *pd.Symbol, av: []pd.Atom)
	void {
		c.iemgui_color(x, self, s, @intCast(av.len), av.ptr);
	}

	pub fn send(self: *Gui, x: *anyopaque, s: *pd.Symbol) void {
		c.iemgui_send(x, self, s);
	}

	pub fn receive(self: *Gui, x: *anyopaque, s: *pd.Symbol) void {
		c.iemgui_receive(x, self, s);
	}

	pub fn label(self: *Gui, x: *anyopaque, s: *pd.Symbol) void {
		c.iemgui_label(x, self, s);
	}

	pub fn labelPos(self: *Gui, x: *anyopaque, s: *pd.Symbol, av: []pd.Atom) void {
		c.iemgui_label_pos(x, self, s, @intCast(av.len), av.ptr);
	}

	pub fn labelFont(self: *Gui, x: *anyopaque, s: *pd.Symbol, av: []pd.Atom) void {
		c.iemgui_label_font(x, self, s, @intCast(av.len), av.ptr);
	}

	pub fn doLabel(self: *Gui, x: *anyopaque, s: *pd.Symbol, senditup: c_int) void {
		c.iemgui_dolabel(x, self, s, senditup);
	}

	pub fn newDialog(self: *Gui, x: *anyopaque, objname: [*:0]const u8,
		width: pd.Float, width_min: pd.Float, height: pd.Float, height_min: pd.Float,
		range_min: pd.Float, range_max: pd.Float, range_checkmode: c_int,
		mode: c_int, mode_label0: [*:0]const u8, mode_label1: [*:0]const u8,
		canloadbang: c_int, steady: c_int, number: c_int
	) void {
		c.iemgui_new_dialog(x, self, objname, width, width_min, height, height_min,
			range_min, range_max, range_checkmode, mode, mode_label0, mode_label1,
			canloadbang, steady, number);
	}

	pub fn setDialogAtoms(self: *Gui, argv: []pd.Atom) void {
		c.iemgui_setdialogatoms(self, @intCast(argv.len), argv.ptr);
	}

	pub fn dialog(self: *Gui, srl: []*pd.Symbol, av: []pd.Atom) c_int {
		return c.iemgui_dialog(self, &srl[0], @intCast(av.len), av.ptr);
	}
};
pub const gui = c.iemgui_new;

pub const displace = c.iemgui_displace;
pub const select = c.iemgui_select;
pub const delete = c.iemgui_delete;
pub const vis = c.iemgui_vis;
