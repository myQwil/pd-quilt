const c = @import("m_pd.zig");
const pd = @import("main.zig");

pub const io_width = c.IOWIDTH;
pub const i_height = c.IHEIGHT;
pub const o_height = c.OHEIGHT;


// ----------------------------------- Array -----------------------------------
// -----------------------------------------------------------------------------
pub const Array = extern struct {
	n: c_int,
	elemsize: c_int,
	vec: [*]u8,
	templatesym: *pd.Symbol,
	valid: c_int,
	gp: pd.GPointer,
	stub: *pd.GStub,
};


// ---------------------------------- Editor -----------------------------------
// -----------------------------------------------------------------------------
const RText = c.struct__rtext;
pub const GListKeyFn = c.t_glistkeyfn;
pub const GListMotionFn = c.t_glistmotionfn;
const GuiConnect = c.struct__guiconnect;
const OutConnect = c.struct__outconnect;

pub const UpdateHeader = extern struct {
	next: ?*UpdateHeader,
	flags: packed struct(u32) {
		array: bool,       // true if array, false if glist
		queued: bool,      // true if we're queued
		_padding: u30,
	},
};

const Selection = extern struct {
	what: *pd.GObj,
	next: ?*Selection,
};

pub const Editor = extern struct {
	upd: UpdateHeader,           // update header structure
	updlist: *Selection,         // list of objects to update
	rtext: *RText,               // text responder linked list
	selection: *Selection,       // head of the selection list
	textedfor: *RText,           // the rtext if any that we are editing
	grab: *pd.GObj,              // object being "dragged"
	motionfn: GListMotionFn,     // ... motion callback
	keyfn: GListKeyFn,           // ... keypress callback
	connectbuf: *pd.BinBuf,      // connections to deleted objects
	deleted: *pd.BinBuf,         // last stuff we deleted
	guiconnect: *GuiConnect,     // GUI connection for filtering messages
	glist: *GList,               // glist which owns this
	xwas: c_int,                 // xpos on last mousedown or motion event
	ywas: c_int,                 // ypos, similarly
	selectline_index1: c_int,    // indices for the selected line if any
	selectline_outno: c_int,     // (only valid if e_selectedline is set)
	selectline_index2: c_int,
	selectline_inno: c_int,
	selectline_tag: *OutConnect,
	flags: packed struct(u32) {
		onmotion: OnMotion, // action to take on motion
		lastmoved: bool,    // true if mouse has moved since click
		textdirty: bool,    // one if e_textedfor has changed
		selectedline: bool, // one if a line is selected
		_padding: u26,
	},
	clock: *pd.Clock,               // clock to filter GUI move messages
	xnew: c_int,                     // xpos for next move event
	ynew: c_int,                     // ypos, similarly

	const OnMotion = enum(u3) {
		none,     // do nothing
		move,     // drag the selection around
		connect,  // make a connection
		region,   // selection region
		passout,  // send on to e_grab
		dragtext, // drag in text editor to alter selection
		resize,   // drag to resize
	};
};


// ----------------------------------- GList -----------------------------------
// -----------------------------------------------------------------------------
pub const CanvasEnvironment = c.struct__canvasenvironment;
const Tick = extern struct {    // where to put ticks on x or y axes
	point: pd.Float, // one point to draw a big tick at
	inc: pd.Float,   // x or y increment per little tick
	lperb: c_int,    // little ticks per big; 0 if no ticks to draw
};

pub const GList = extern struct {
	obj: pd.Object,        // header in case we're a glist
	list: *pd.GObj,        // the actual data
	stub: *pd.GStub,       // safe pointer handler
	valid: c_int,          // incremented when pointers might be stale
	owner: *GList,         // parent glist, supercanvas, or 0 if none
	pixwidth: c_uint,      // width in pixels (on parent, if a graph)
	pixheight: c_uint,
	x1: pd.Float,          // bounding rectangle in our own coordinates
	y1: pd.Float,
	x2: pd.Float,
	y2: pd.Float,
	screenx1: c_int,       // screen coordinates when toplevel
	screeny1: c_int,
	screenx2: c_int,
	screeny2: c_int,
	xmargin: c_int,        // origin for GOP rectangle
	ymargin: c_int,
	xtick: Tick,           // ticks marking X values
	nxlabels: c_int,       // number of X coordinate labels
	xlabel: **pd.Symbol,   // ... an array to hold them
	xlabely: pd.Float,     // ... and their Y coordinates
	ytick: Tick,           // same as above for Y ticks and labels
	nylabels: c_int,
	ylabel: **pd.Symbol,
	ylabelx: pd.Float,
	editor: *Editor,       // editor structure when visible
	name: *pd.Symbol,      // symbol bound here
	font: c_int,           // nominal font size in points, e.g., 10
	next: ?*GList,          // link in list of toplevels
	env: *CanvasEnvironment, // root canvases and abstractions only
	flags: packed struct(u32) {
		havewindow: bool,   // true if we own a window
		mapped: bool,       // true if, moreover, it's "mapped"
		dirty: bool,        // (root canvas only:) patch has changed
		loading: bool,      // am now loading from file
		willvis: bool,      // make me visible after loading
		edit: bool,         // edit mode
		isdeleting: bool,   // we're inside glist_delete -- hack!
		goprect: bool,      // draw rectangle for graph-on-parent
		isgraph: bool,      // show as graph on parent
		hidetext: bool,     // hide object-name + args when doing graph on parent
		private: bool,      // private flag used in x_scalar.c
		isclone: bool,      // exists as part of a clone object
		_padding: u20,
	},
	zoom: c_uint,          // zoom factor (integer zoom-in only)
	privatedata: *anyopaque, // private data

	pub const init = c.glist_init;
	pub const add = c.glist_add;
	pub const clear = c.glist_clear;
	pub const canvas = c.glist_getcanvas;
	pub const isSelected = c.glist_isselected;
	pub const select = c.glist_select;
	pub const deselect = c.glist_deselect;
	pub const noSelect = c.glist_noselect;
	pub const selectAll = c.glist_selectall;
	pub const delete = c.glist_delete;
	pub const retext = c.glist_retext;
	pub const grab = c.glist_grab;
	pub const isTopLevel = c.glist_istoplevel;
	pub const findGraph = c.glist_findgraph;
	pub const font = c.glist_getfont;
	pub const fontWidth = c.glist_fontwidth;
	pub const fontHeight = c.glist_fontheight;
	pub const zoom = c.glist_getzoom;
	pub const sort = c.glist_sort;
	pub const read = c.glist_read;
	pub const mergeFile = c.glist_mergefile;
	pub const pixelsToX = c.glist_pixelstox;
	pub const pixelsToY = c.glist_pixelstoy;
	pub const xToPixels = c.glist_xtopixels;
	pub const yToPixels = c.glist_ytopixels;
	pub const dpixToDx = c.glist_dpixtodx;
	pub const dpixToDy = c.glist_dpixtody;
	pub const nextXY = c.glist_getnextxy;
	pub const gList = c.glist_glist;
	pub const addGList = c.glist_addglist;
	pub const arrayDialog = c.glist_arraydialog;
	pub const writeToBinbuf = c.glist_writetobinbuf;
	pub const isGraph = c.glist_isgraph;
	pub const redraw = c.glist_redraw;
	pub const drawIoFor = c.glist_drawiofor;
	pub const eraseIoFor = c.glist_eraseiofor;
	pub const createEditor = c.canvas_create_editor;
	pub const destroyEditor = c.canvas_destroy_editor;
	pub const deleteLinesForIo = c.canvas_deletelinesforio;
	pub const makeFilename = c.canvas_makefilename;
	pub const dir = c.canvas_getdir;
	pub const dataProperties = c.canvas_dataproperties;
	pub const open = c.canvas_open;
	pub const sampleRate = c.canvas_getsr;
	pub const signalLength = c.canvas_getsignallength;
	// static methods
	pub const setArgs = c.canvas_setargs;
	pub const args = c.canvas_getargs;

	pub fn isVisible(self: *GList) bool {
		return (c.glist_isvisible(self) != 0);
	}

	pub fn undoSetState(
		self: *GList, x: *pd.Pd, s: *pd.Symbol, undo: []pd.Atom, redo: []pd.Atom,
	) void {
		c.pd_undo_set_objectstate(self, x, s,
			@intCast(undo.len), undo.ptr, @intCast(redo.len), redo.ptr);
	}
};
pub const currentCanvas = c.canvas_getcurrent;


// --------------------------------- LoadBang ----------------------------------
// -----------------------------------------------------------------------------
pub const LoadBang = enum(u2) {
	load,
	init,
	close,
};


// --------------------------------- Template ----------------------------------
// -----------------------------------------------------------------------------
pub const GTemplate = c.struct__gtemplate;
pub const DataSlot = extern struct {
	type: c_int,
	name: *pd.Symbol,
	arraytemplate: *pd.Symbol,
};

pub const Template = extern struct {
	pdobj: pd.Pd,
	list: *GTemplate,
	sym: *pd.Symbol,
	n: c_int,
	vec: *DataSlot,
	next: ?*Template,
};


// ---------------------------------- Widgets ----------------------------------
// -----------------------------------------------------------------------------
pub const GetRectFn = c.t_getrectfn;
pub const DisplaceFn = c.t_displacefn;
pub const SelectFn = c.t_selectfn;
pub const ActivateFn = c.t_activatefn;
pub const DeleteFn = c.t_deletefn;
pub const VisFn = c.t_visfn;
pub const ClickFn = c.t_clickfn;
pub const WidgetBehavior = extern struct {
	getrect: GetRectFn = null,
	displace: DisplaceFn = null,
	select: SelectFn = null,
	activate: ActivateFn = null,
	delete: DeleteFn = null,
	vis: VisFn = null,
	click: ClickFn = null,
};

pub const ParentGetRectFn = c.t_parentgetrectfn;
pub const ParentDisplaceFn = c.t_parentdisplacefn;
pub const ParentSelectFn = c.t_parentselectfn;
pub const ParentActivateFn = c.t_parentactivatefn;
pub const ParentVisFn = c.t_parentvisfn;
pub const ParentClickFn = c.t_parentclickfn;
pub const ParentWidgetBehavior = extern struct {
	getrect: ParentGetRectFn = null,
	displace: ParentDisplaceFn = null,
	select: ParentSelectFn = null,
	activate: ParentActivateFn = null,
	vis: ParentVisFn = null,
	click: ParentClickFn = null,
};
