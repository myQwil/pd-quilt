//! A number box with options for specifying base, precision, and dragging sensitivity.

const pd = @import("pd");
const std = @import("std");
const Rad = @import("misc/Rad.zig");
const bf = @import("misc/bitfloat.zig");
const cnv = pd.cnv;

const Pd = pd.Pd;
const uint = pd.uint;
const Atom = pd.Atom;
const GObj = pd.GObj;
const Float = pd.Float;
const GList = pd.GList;
const Object = pd.Object;
const Symbol = pd.Symbol;
const Writer = std.Io.Writer;
const BufPrintError = std.fmt.BufPrintError;

const IVec2 = @Vector(2, c_int);
const SVec2 = @Vector(2, c_short);
const FVec2 = @Vector(2, Float);

const margin = struct {
	const left = 2;
	const right = 2;
	const top = 3;
	const bottom = 2;
};
const atom_rmargin = margin.left + margin.right - 2;
const atom_bmargin = margin.top + margin.bottom - 1;

fn escape(s: *Symbol) BufPrintError!*Symbol {
	return if (s == pd.s.empty()) .gen("_") else if (s.name[0] != '_') s else blk: {
		var shmo: [100]u8 = undefined;
		const str = try std.fmt.bufPrintSentinel(&shmo, "_{s}", .{ s.name }, 0);
		break :blk .gen(str.ptr);
	};
}

fn unescape(s: *Symbol) *Symbol {
	return if (s.name[0] == '_') .gen(s.name + 1) else s;
}

pub inline fn getDlrSym(self: Atom) ?*Symbol {
	return if (self.type == .dollsym) self.w.symbol else null;
}
pub inline fn dlrSymArg(idx: usize, av: []const Atom) pd.ArgError!*Symbol {
	return if (idx < av.len)
		getDlrSym(av[idx]) orelse error.WrongAtomType
	else error.IndexOutOfBounds;
}

fn deleteLine(gl: *GList, oc: *pd.OutConnect) void {
	if (!gl.isVisible()) {
		return;
	}
	var tag: [@sizeOf(usize) * 2 + 3 :0]u8 = undefined;
	var w: Writer = .fixed(&tag);
	w.print("l0x{x}", .{ @intFromPtr(oc) }) catch unreachable;
	tag[w.end] = 0;
	pd.vMess(null, "crs", .{ gl.getCanvas(), "delete", &tag });
}

/// Kill all lines for one inlet or outlet
fn deleteLinesForIo(x: *GList, text: *Object, inp: ?*pd.Inlet, outp: ?*pd.Outlet) void {
	var t: cnv.LineTraverser = .init(x);
	var oconn: ?*pd.OutConnect = t.next();
	while (oconn) |oc| : (oconn = t.next()) {
		if ((t.ob == text and t.outlet == outp) or (t.ob2 == text and t.inlet == inp)) {
			deleteLine(x, oc);
			if (t.ob) |ob| {
				ob.disconnect(t.outno, t.ob2, t.inno);
			}
		}
	}
}

const WhereLabel = enum(u2) {
	left = 0,
	right = 1,
	up = 2,
	down = 3,
};

const TagType = enum(u8) {
	border = 'b',
	label = 'l',
	text = 't',
};

inline fn maybeAtom(self: ?Float) Atom {
	return if (self) |f| .float(f) else .symbol(.gen("_"));
}

fn maybePrint(self: ?Float) void {
	if (self) |f| {
		pd.post.start("%g", .{ f });
	} else {
		pd.post.start("null", .{});
	}
}

const Range = struct {
	lo: ?Float = null,
	hi: ?Float = null,

	inline fn sanitized(self: Range, val: Float) Float {
		if (self.lo) |lo| {
			if (lo > val) {
				return lo;
			}
		} else if (self.hi) |hi| {
			if (hi < val) {
				return hi;
			}
		}
		return val;
	}

	inline fn sort(self: *Range) void {
		const lo = self.lo orelse return;
		const hi = self.hi orelse return;
		if (lo > hi) {
			const temp: Float = lo;
			self.lo = hi;
			self.hi = temp;
		}
	}
};

gl: *GList,
/// label text
lbl: *Symbol,
/// receive (inlet) binding
rcv: *Symbol,
/// send (outlet) binding
snd: *Symbol,
/// expanded form of `snd`
sndx: *Symbol,
/// last character in the tag (indicates type)
tag_type: *TagType,
/// min-max range of possible values
range: Range,
/// number of pixels per motion step
step: [2]Float,
/// position at the start of a grab
grab: [2]Float = .{ 0, 0 },
/// value at the start of a grab, or the toggle value
alt: Float = 0,
/// radix context
rad: Rad,
/// font size (pt)
font_size: u16,
/// tcl tag
tag: [@sizeOf(usize) * 2 + 2 :0]u8,
/// bit field
b: packed struct(u8) {
	where: WhereLabel,
	/// true if we've grabbed the keyboard and want a thicker border
	grabbed: bool = false,
	/// whether shift key was down when drag started
	shift: bool = false,
	_unused: u4 = 0,
},

const name = "radix";
var class: *pd.Class = undefined;
const Box = pd.Box(Object, @This());

inline fn err(p: *const Pd, e: anyerror) void {
	pd.post.err(p, name ++ ": %s", .{ @errorName(e).ptr });
}

fn getRect(obj: *Object, glist: *GList) pd.Rect(c_int) {
	const self = Box.state(&obj.g.pd);
	const fontsize: uint = if (self.font_size != 0) self.font_size else glist.getFont();
	const len: uint = if (self.rad.width == 0)
		@max(3, self.rad.end) else self.rad.width;
	const size: IVec2 = blk: {
		const uz = glist.getZoom();
		const iz: c_int = uz;
		const amargin = IVec2{ atom_rmargin, atom_bmargin } * IVec2{ iz, iz };
		break :blk amargin + @as(IVec2, @Vector(2, uint){
			len * pd.zoomFontWidth(fontsize, uz, false),
			pd.zoomFontHeight(fontsize, uz, false),
		});
	};
	const p1 = obj.pos(glist);
	return .{ .p1 = p1, .p2 = p1 + size };
}

fn getRectC(
	g: *GObj, glist: *GList,
	xp1: *c_int, yp1: *c_int,
	xp2: *c_int, yp2: *c_int,
) callconv(.c) void {
	const rect = getRect(@ptrCast(g), glist);
	xp1.* = rect.p1[0];
	yp1.* = rect.p1[1];
	xp2.* = rect.p2[0];
	yp2.* = rect.p2[1];
}

fn selectC(g: *GObj, glist: *GList, selected: c_int) callconv(.c) void {
	if (!glist.isVisible() or !g.shouldVis(glist)) {
		return;
	}
	const color = if (selected != 0)
		pd.this().gui.selectcolor
	else pd.this().gui.foregroundcolor;

	const self = Box.state(&g.pd);
	self.tag_type.* = .text;
	pd.vMess(null, "crs rk", .{ glist, "itemconfigure", &self.tag, "-fill", color });
	self.tag_type.* = .border;
	pd.vMess(null, "crs rk", .{ glist, "itemconfigure", &self.tag, "-fill", color });
}

fn deleteC(g: *GObj, glist: *GList) callconv(.c) void {
	glist.deleteLinesFor(@ptrCast(g));
}

fn drawBorder(
	obj: *Object, glist: *GList,
	rect: pd.Rect(c_int),
	firsttime: bool,
) void {
	const self = Box.state(&obj.g.pd);
	self.tag_type.* = .border;
	const zoom = glist.zoom;
	const grabbed: c_int = zoom * @intFromBool(self.b.grabbed);
	const p1 = rect.p1 + IVec2{ grabbed, grabbed };
	const p2 = rect.p2;
	const corner = @divTrunc(rect.size()[1], 4);
	const shape: @Tuple(&@as([12]type, @splat(c_int))) = .{
		p1[0], p1[1],
		p2[0], p1[1],
		p2[0], p2[1] - corner,
		p2[0] - corner, p2[1],
		p1[0], p2[1],
		p1[0], p1[1],
	};

	const canvas = glist.getCanvas();
	const tags = [_][*:0]const u8{ &self.tag, "obj" };
	if (firsttime) {
		pd.vMess(null, "crr" ++ @as([shape.len]u8, @splat('i')) ++ "ri rk rr rS", .{
			canvas, "create", "line",
		} ++ shape ++ .{
			"-width", zoom + grabbed,
			"-fill", pd.this().gui.foregroundcolor,
			"-capstyle", "projecting",
			"-tags", tags.len, &tags,
		});
		pd.vMess(null, "crr", .{ canvas, "raise", "cord" });
	} else {
		pd.vMess(null, "crs" ++ @as([shape.len]u8, @splat('i')), .{
			canvas, "coords", &self.tag,
		} ++ shape);
		pd.vMess(null, "crs ri", .{
			canvas, "itemconfigure", &self.tag,
			"-width", zoom + grabbed,
		});
	}
	glist.drawIoFor(obj, firsttime, &self.tag, p1[0], p1[1], p2[0], p2[1]);
}

fn displaceC(g: *GObj, glist: *GList, dx: c_int, dy: c_int) callconv(.c) void {
	const self = Box.state(&g.pd);
	const obj: *Object = @ptrCast(g);
	const canvas = glist.getCanvas();
	const dvec: IVec2 = .{ dx, dy };
	obj.pix = obj.pix + @as(SVec2, @truncate(dvec));
	if (!glist.isVisible()) {
		return;
	}

	const zoom = glist.zoom;
	const d = dvec * IVec2{ zoom, zoom };

	self.tag_type.* = .text;
	pd.vMess(null, "crs ii", .{ canvas, "move", &self.tag, d[0], d[1] });
	self.tag_type.* = .label;
	pd.vMess(null, "crs ii", .{ canvas, "move", &self.tag, d[0], d[1] });
	drawBorder(obj, glist, getRect(obj, glist), false);
	glist.fixLinesFor(obj);
}

fn write(p: *Pd) void {
	const self = Box.state(p);
	self.rad.write() catch |e| {
		err(p, e);
		@memcpy(self.rad.buf[0..4], "err\x00");
	};
}

fn visC(g: *GObj, glist: *GList, visible: c_int) callconv(.c) void {
	if (!g.shouldVis(glist)) {
		return;
	}
	const self = Box.state(&g.pd);
	const canvas = glist.getCanvas();
	if (visible == 0) {
		if (self.lbl != pd.s.empty()) {
			self.tag_type.* = .label;
			pd.vMess(null, "crs", .{ canvas, "delete", &self.tag });
		}

		self.tag_type.* = .text;
		pd.vMess(null, "crs", .{ canvas, "delete", &self.tag });

		self.tag_type.* = .border;
		glist.eraseIoFor(@ptrCast(g), &self.tag);
		pd.vMess(null, "crs", .{ canvas, "delete", &self.tag });
		return;
	}

	// update the buffer
	write(&g.pd);

	// draw the border
	const obj: *Object = @ptrCast(g);
	const rect = getRect(obj, glist);
	drawBorder(obj, glist, rect, true);

	// draw the text
	const fontsize: uint = if (self.font_size != 0) self.font_size else glist.getFont();
	const uz = glist.getZoom();
	const iz: c_int = uz;
	{
		self.tag_type.* = .text;
		const tags = [_][*]const u8{ &self.tag, "text" };
		const pos = rect.p1 + IVec2{ margin.left, margin.top } * IVec2{ iz, iz };
		pd.vMess("pdtk_text_new", "c S ii s i k", .{
			canvas,
			tags.len, &tags,
			pos[0], pos[1],
			&self.rad.buf,
			@as(c_uint, pd.hostFontSize(fontsize, uz)),
			if (glist.isSelected(g))
				pd.this().gui.selectcolor
			else pd.this().gui.foregroundcolor,
		});
	}
	if (self.lbl == pd.s.empty()) {
		return;
	}

	// draw the label
	const label = glist.realizeDollar(self.lbl).name;
	const p1 = switch (self.b.where) {
		.left => blk: {
			const len = std.mem.len(label);
			const wid: c_int = pd.iFromU(len * pd.zoomFontWidth(fontsize, uz, false));
			break :blk rect.p1 + IVec2{ -3 * iz - wid, 2 * iz };
		},
		.right => blk: {
			const dz = iz * 2;
			break :blk IVec2{ rect.p2[0], rect.p1[1] } + IVec2{ dz, dz };
		},
		.up => blk: {
			const h: c_int = pd.zoomFontHeight(fontsize, uz, false);
			break :blk rect.p1 - IVec2{ iz, iz + h };
		},
		.down => IVec2{ rect.p1[0], rect.p2[1] } + IVec2{ -iz, 3 * iz },
	};

	self.tag_type.* = .label;
	const tags = [_][*]const u8{ &self.tag, "label", "text" };
	pd.vMess("pdtk_text_new", "cS ii s ik", .{
		canvas, tags.len, &tags,
		p1[0], p1[1],
		label,
		@as(c_uint, fontsize * uz), pd.this().gui.foregroundcolor,
	});
}

fn redrawC(g: *GObj, glist: *GList) callconv(.c) void {
	const self = Box.state(&g.pd);
	write(&g.pd);
	self.tag_type.* = .text;
	pd.vMess("pdtk_text_set", "cs s", .{
		glist, &self.tag,
		&self.rad.buf,
	});
	if (self.rad.width == 0 and self.rad.resize) {
		drawBorder(@ptrCast(g), self.gl, getRect(@ptrCast(g), self.gl), false);
	}
}

fn sendItUp(p: *Pd) void {
	const self = Box.state(p);
	const g: *GObj = @ptrCast(p);
	const canvas = self.gl.getCanvas();
	if (canvas.editor != null and g.shouldVis(self.gl)) {
		pd.queueGui(p, canvas, redrawC);
	}
}

fn setC(p: *Pd, f: Float) callconv(.c) void {
	const self = Box.state(p);
	if (@as(bf.Uf, @bitCast(self.rad.value)) != @as(bf.Uf, @bitCast(f))) {
		self.rad.value = f;
		sendItUp(p);
	}
}

fn bangC(p: *Pd) callconv(.c) void {
	const self = Box.state(p);
	const obj: *Object = @ptrCast(p);
	if (obj.outlets) |outlet| {
		outlet.float(self.rad.value);
	} else if (self.sndx.thing) |thing| {
		if (self.snd == self.rcv) {
			pd.post.err(p, "%s: infinite loop", .{ self.snd.name });
		} else {
			thing.float(self.rad.value);
		}
	}
}

fn floatC(p: *Pd, f: Float) callconv(.c) void {
	setC(p, f);
	bangC(p);
}

fn checkRange(p: *Pd) void {
	const self = Box.state(p);
	self.range.sort();
	const f = self.range.sanitized(self.rad.value);
	if (f != self.rad.value) {
		setC(p, f);
	}
}

fn keyC(g: *GObj, _: *Symbol, f: Float) callconv(.c) void {
	const char: u8 = @trunc(f);
	if (char == 0) {
		const self = Box.state(&g.pd);
		self.b.grabbed = false;
		const obj: *Object = @ptrCast(g);
		drawBorder(obj, self.gl, getRect(obj, self.gl), false);
	}
}

fn motionC(p: *Pd, dx: Float, dy: Float, released: Float) callconv(.c) void {
	if (released != 0 or (dx == 0 and dy == 0)) {
		return;
	}
	const self = Box.state(p);
	const e = self.gl.getCanvas().editor orelse return;
	const bn2: Float = 1.0 / @as(Float, @floatFromInt(self.rad.base * self.rad.base));
	const bn4: Float = bn2 * bn2;

	const pos = FVec2{ dx, dy } + @as(FVec2, @floatFromInt(@as(IVec2, e.was)));
	const dif = pos - self.grab;
	const sum =
		(if (self.step[0] == 0) 0.25 else dif[0] / self.step[0]) +
		(if (self.step[1] == 0) 0.25 else dif[1] / self.step[1]);

	var nval = self.alt + @floor(sum) * if (self.b.shift) bn2 else 1;
	const trunc = @floor(nval / bn2 + 0.5) * bn2;
	if (trunc < nval + bn4 and trunc > nval - bn4) {
		nval = trunc;
	}
	if (self.range.lo) |lo| {
		if (lo > nval) {
			nval = lo;
			// prevent having to drag all the way back to where limit was reached
			self.grab = pos - self.step * FVec2{ 0.25, 0.25 };
			self.alt = nval;
		}
	}
	if (self.range.hi) |hi| {
		if (hi < nval) {
			nval = hi;
			self.grab = pos - self.step * FVec2{ 0.25, 0.25 };
			self.alt = nval;
		}
	}
	if (@as(bf.Uf, @bitCast(self.rad.value)) != @as(bf.Uf, @bitCast(nval))) {
		self.rad.value = nval;
		sendItUp(p);
		bangC(p);
	}
}

/// called when clicked on in run mode
fn clickC(
	g: *GObj, gl: *GList,
	xpos: c_int, ypos: c_int,
	shift: c_int, alt: c_int, _: c_int, doit: c_int,
) callconv(.c) c_int {
	if (doit == 0) {
		return 1;
	}
	const p: *Pd = &g.pd;
	const self = Box.state(p);
	if (alt != 0) {
		const zero: Float = self.range.sanitized(0);
		if (self.rad.value != zero) {
			self.alt = self.rad.value;
			floatC(p, zero);
		} else {
			floatC(p, self.alt);
		}
		gl.grab(g, null, keyC, 0, 0);
	} else {
		const pos: FVec2 = @floatFromInt(IVec2{ xpos, ypos });
		// start in the middle of a step rather than at the beginning of one
		self.grab = pos - self.step * FVec2{ 0.25, 0.25 };
		self.b.shift = (shift != 0);
		self.alt = self.rad.value;
		gl.grab(g, motionC, keyC, xpos, ypos);
	}
	self.b.grabbed = true;
	const obj: *Object = @ptrCast(g);
	drawBorder(obj, gl, getRect(obj, gl), false);
	return 1;
}

/// Get unresolved `rcv`, `snd`, and `lbl` symbols.
///
/// Symbols are already resolved if radix is loaded from a patch,
/// so we have to find the unresolved versions in the object's binbuf.
fn getRSL(obj: *Object) BufPrintError![3]*Symbol {
	const self = Box.state(&obj.g.pd);
	return if (obj.binbuf) |binbuf| blk: {
		const a = binbuf.getSlice();
		break :blk .{
			dlrSymArg(9, a) catch try escape(self.rcv),
			dlrSymArg(10, a) catch try escape(self.snd),
			dlrSymArg(11, a) catch try escape(self.lbl),
		};
	} else .{
		try escape(self.rcv),
		try escape(self.snd),
		try escape(self.lbl),
	};
}

fn saveC(g: *GObj, b: *pd.BinBuf) callconv(.c) void {
	save(g, b) catch |e| err(&g.pd, e);
}
inline fn save(g: *GObj, b: *pd.BinBuf) (pd.Oom || BufPrintError)!void {
	const self = Box.state(&g.pd);
	const obj: *Object = @ptrCast(g);
	const rsl = try getRSL(obj);
	try b.add(&.{
		.symbol(.gen("#X")), .symbol(.gen("obj")),
		.float(obj.pix[0]), .float(obj.pix[1]),
		.symbol(.gen("radix")),

		.float(self.rad.base), .float(self.rad.prec),
		.float(self.step[0]), .float(-self.step[1]),
		maybeAtom(self.range.lo), maybeAtom(self.range.hi),

		.float(self.rad.width), .float(self.font_size),
		.symbol(rsl[0]), .symbol(rsl[1]), .symbol(rsl[2]),
		.float(@floatFromInt(@intFromEnum(self.b.where))),
		.semi,
	});
}

fn propertiesC(g: *GObj, _: *GList) callconv(.c) void {
	properties(g) catch |e| err(&g.pd, e);
}
inline fn properties(g: *GObj) BufPrintError!void {
	const self = Box.state(&g.pd);
	var buf_min: [16:0]u8 = undefined;
	var buf_max: [16:0]u8 = undefined;
	maybeAtom(self.range.lo).bufPrint(&buf_min);
	maybeAtom(self.range.hi).bufPrint(&buf_max);

	const rsl = try getRSL(@ptrCast(g));
	g.pd.stub("dialog_radix::setup", g, "ii ff ss ii ss si", .{
		self.rad.base, self.rad.prec,
		self.step[0], -self.step[1],
		&buf_min, &buf_max,
		self.rad.width, self.font_size,
		rsl[0].name, rsl[1].name,
		rsl[2].name, @as(u8, @intFromEnum(self.b.where)),
	});
}

fn paramC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	param(p, av[0..ac]) catch |e| err(p, e);
}
const ParamError = BufPrintError || error{WrongArgCount} || pd.Oom;
inline fn param(p: *Pd, av: []const Atom) ParamError!void {
	const obj: *Object = @ptrCast(p);
	const self = Box.state(p);
	if (av.len != 12) {
		return error.WrongArgCount;
	}
	const visible = self.gl.isVisible();
	const rsl = try getRSL(obj);

	self.gl.setUndoState(p, .gen("param"), &.{
		.float(@floatFromInt(self.rad.base)),
		.float(@floatFromInt(self.rad.prec)),
		.float(self.step[0]),
		.float(-self.step[1]),
		maybeAtom(self.range.lo),
		maybeAtom(self.range.hi),
		.float(@floatFromInt(self.rad.width)),
		.float(@floatFromInt(self.font_size)),
		.symbol(rsl[0]),
		.symbol(rsl[1]),
		.symbol(rsl[2]),
		.float(@floatFromInt(@intFromEnum(self.b.where))),
	}, av);
	if (visible) {
		obj.g.vis(self.gl, false);
	}

	self.rad.base = if (av[0].getFloat()) |f| @trunc(f) else self.rad.base;
	self.rad.prec = if (av[1].getFloat()) |f| @trunc(f) else self.rad.prec;
	self.rad.reset();
	const width: u16 = if (av[6].getFloat()) |f| @trunc(f) else 0;
	self.rad.width = @min(width, 1000);

	self.step = .{
		av[2].getFloat() orelse self.step[0],
		if (av[3].getFloat()) |f| -f else self.step[1],
	};

	self.range = .{ .lo = av[4].getFloat(), .hi = av[5].getFloat() };
	checkRange(p);

	const fs: u16 = if (av[7].getFloat()) |f| @trunc(f) else 0;
	self.font_size = @min(fs, 36);

	const rcv_old = self.rcv;
	const rcv_raw = av[8].getSymbol() orelse pd.s.empty();
	const rcv_new = unescape(rcv_raw);
	if (rcv_old != pd.s.empty()) {
		if (rcv_new != pd.s.empty()) {
			if (rcv_old != rcv_new) { // symbol to symbol
				p.unbind(self.gl.realizeDollar(rcv_old));
				p.bind(self.gl.realizeDollar(rcv_new));
			}
		} else { // symbol to inlet
			p.unbind(self.gl.realizeDollar(rcv_old));
			_ = try obj.inlet(p, null, null);
		}
	} else if (rcv_new != pd.s.empty()) { // inlet to symbol
		if (obj.inlets) |inlet| {
			deleteLinesForIo(self.gl, obj, inlet, null);
			inlet.destroy();
		}
		p.bind(self.gl.realizeDollar(rcv_new));
	}
	self.rcv = rcv_new;

	const snd_old = self.snd;
	const snd_raw = av[9].getSymbol() orelse pd.s.empty();
	const snd_new = unescape(snd_raw);
	if (snd_old != pd.s.empty()) {
		if (snd_new == pd.s.empty()) { // symbol to outlet
			_ = try obj.outlet(null);
		}
	} else if (snd_new != pd.s.empty()) { // outlet to symbol
		if (obj.outlets) |outlet| {
			deleteLinesForIo(self.gl, obj, null, outlet);
			outlet.destroy();
		}
	}
	self.snd = snd_new;
	self.sndx = self.gl.realizeDollar(snd_new);

	const lbl_raw = av[10].getSymbol() orelse pd.s.empty();
	self.lbl = unescape(lbl_raw);
	const where: u2 = if (av[11].getFloat()) |f| @trunc(f) else 0;
	self.b.where = @enumFromInt(where);

	if (obj.binbuf) |binbuf| {
		const slc = binbuf.getSlice();
		sw: switch (@min(slc.len, 12)) {
			12 => { slc[11] = .dollsym(lbl_raw); continue :sw 11; },
			11 => { slc[10] = .dollsym(snd_raw); continue :sw 10; },
			10 => { slc[9] = .dollsym(rcv_raw); },
			else => {},
		}
	}

	if (visible) {
		if (obj.g.shouldVis(self.gl)) {
			visC(&obj.g, self.gl, 1);
		}
		self.gl.fixLinesFor(obj);
	}
	self.gl.setDirty(true);
}

fn stepC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	const self = Box.state(p);
	const a = av[0..ac];
	if (a.len > 1) {
		self.step = .{
			a[0].getFloat() orelse self.step[0],
			if (a[1].getFloat()) |f| -f else self.step[1],
		};
	} else if (pd.floatArg(0, a)) |f| {
		self.step = .{ f, -f };
	} else |_| {}
}

fn readC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	const self = Box.state(p);
	read(p, self.rad.base, av[0..ac]) catch |e| err(p, e);
}
const ReadError = error{NotEnoughArgs} || BufPrintError || Rad.ParseError;
fn read(p: *Pd, base: u16, av: []const Atom) ReadError!void {
	if (av.len < 1) {
		return error.NotEnoughArgs;
	}
	var res: [32]u8 = undefined;
	const cp: [*:0]const u8 = if (av[0].type == .float)
		try std.fmt.bufPrintSentinel(&res, "{}", .{ av[0].w.float }, 0)
	else av[0].w.symbol.name;
	floatC(p, try Rad.parseFloat(cp, base));
}

fn anythingC(p: *Pd, s: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	if (s.name[0] == 'b') {
		read(p, Rad.getBase(std.mem.sliceTo(s.name, 0)[1..]), av[0..ac])
			catch |e| err(p, e);
	} else {
		pd.post.err(p, name ++ ": no method for '%s'", .{ s.name });
	}
}

fn baseC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	const self = Box.state(p);
	const a = av[0..ac];
	if (pd.floatArg(0, a)) |f| { // set
		self.rad.base = @trunc(@max(0, f));
		if (pd.floatArg(1, a)) |g| {
			self.rad.prec = @trunc(@max(0, g));
		} else |_| {}
		self.rad.reset();
		sendItUp(p);
	} else |_| { // get
		pd.post.log(p, .normal, "base: %u", .{ self.rad.base });
	}
}

fn precC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	const self = Box.state(p);
	if (pd.floatArg(0, av[0..ac])) |f| { // set
		self.rad.setPrecision(f);
		sendItUp(p);
	} else |_| { // print
		pd.post.log(p, .normal, "precision: %u", .{ self.rad.prec });
	}
}

fn minC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	const self = Box.state(p);
	if (ac > 0) {
		self.range.lo = av[0].getFloat();
		checkRange(p);
	} else { // print
		pd.post.start("min: ", .{});
		maybePrint(self.range.lo);
		pd.post.log(p, .normal, "", .{});
	}
}

fn maxC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	const self = Box.state(p);
	if (ac > 0) {
		self.range.hi = av[0].getFloat();
		checkRange(p);
	} else { // print
		pd.post.start("max: ", .{});
		maybePrint(self.range.hi);
		pd.post.log(p, .normal, "", .{});
	}
}

fn rangeC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
	const self = Box.state(p);
	const a = av[0..ac];
	if (a.len > 0) {
		self.range.lo = a[0].getFloat();
		self.range.hi = pd.floatArg(1, a) catch null;
		checkRange(p);
	} else { // print
		pd.post.start("range: ", .{});
		maybePrint(self.range.lo);
		pd.post.start("..", .{});
		maybePrint(self.range.hi);
		pd.post.log(p, .normal, "", .{});
	}
}

fn createC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Pd {
	return pd.wrap(*Pd, create(av[0..ac]), name);
}
const CreateError = pd.Oom || error{NoCurrentGList} || Writer.Error;
inline fn create(av: []const Atom) CreateError!*Pd {
	const gl = GList.getCurrent() orelse return error.NoCurrentGList;
	const obj: *pd.Object = @ptrCast(try class.pd());
	const p: *Pd = &obj.g.pd;
	const self = Box.state(p);
	errdefer p.destroy();

	var tag: [@sizeOf(usize) * 2 + 2 :0]u8 = undefined;
	var w: Writer = .fixed(&tag);
	try w.print("{x}._", .{ @intFromPtr(obj) });
	tag[w.end] = 0;

	var base: u16 = 10;
	var prec: u16 = 0;
	var step: [2]Float = .{ 0, -3 };
	var range: Range = .{};
	var width: u16 = 0;
	var font_size: u16 = 0;
	var rsl: [3]*Symbol = @splat(pd.s.empty());
	var where: WhereLabel = .left;
	sw: switch (@min(av.len, 12)) {
		12 => {
			if (av[11].getFloat()) |f| where = @enumFromInt(@as(u2, @trunc(f)));
		continue :sw 11; }, 11 => {
			if (av[10].getSymbol()) |s| rsl[2] = unescape(s);
		continue :sw 10; }, 10 => {
			if (av[9].getSymbol()) |s| rsl[1] = unescape(s);
		continue :sw 9; }, 9 => {
			if (av[8].getSymbol()) |s| rsl[0] = unescape(s);
		continue :sw 8; }, 8 => {
			if (av[7].getFloat()) |f| font_size = @trunc(@min(f, 36));
		continue :sw 7; }, 7 => {
			if (av[6].getFloat()) |f| width = @trunc(@min(f, 500));
		continue :sw 6; }, 6 => {
			if (av[5].getFloat()) |f| range.hi = f;
		continue :sw 5; }, 5 => {
			if (av[4].getFloat()) |f| range.lo = f;
		continue :sw 4; }, 4 => {
			if (av[3].getFloat()) |f| step[1] = -f;
		continue :sw 3; }, 3 => {
			if (av[2].getFloat()) |f| step[0] = f;
		continue :sw 2; }, 2 => {
			if (av[1].getFloat()) |f| prec = @trunc(f);
		continue :sw 1; }, 1 => {
			if (av[0].getFloat()) |f| base = @trunc(f);
		}, else => {},
	}

	range.sort();
	var rad: Rad = .init(base, prec);
	rad.width = width;
	rad.value = range.sanitized(rad.value);

	if (rsl[0] == pd.s.empty()) {
		_ = try obj.inlet(p, null, null);
	} else {
		p.bind(gl.realizeDollar(rsl[0]));
	}
	if (rsl[1] == pd.s.empty()) {
		_ = try obj.outlet(pd.s.float());
	}

	self.* = .{
		.gl = gl,
		.rad = rad,
		.step = step,
		.range = range,
		.font_size = font_size,
		.rcv = rsl[0],
		.snd = rsl[1],
		.sndx = gl.realizeDollar(rsl[1]),
		.lbl = rsl[2],
		.b = .{ .where = where },
		.tag = tag,
		.tag_type = @ptrCast(&self.tag[w.end - 1]),
	};
	return p;
}

fn destroyC(p: *Pd) callconv(.c) void {
	const self = Box.state(p);
	if (self.rcv != pd.s.empty()) {
		p.unbind(self.gl.realizeDollar(self.rcv));
	}
	pd.deleteStubForKey(p);
	pd.unqueueGui(p);
}

inline fn setup() pd.Class.Error!void {
	const opts: pd.Class.Options = .{ .no_inlet = true, .patchable = true };
	class = try .create(name, &.{ .gimme }, createC, destroyC, @sizeOf(Box), opts);
	class.addBang(bangC);
	class.addFloat(floatC);
	class.addAnything(anythingC);
	class.addMethod(&.{ .float }, setC, .gen("set"));
	class.addMethod(&.{ .gimme }, minC, .gen("min"));
	class.addMethod(&.{ .gimme }, maxC, .gen("max"));
	class.addMethod(&.{ .gimme }, readC, .gen("read"));
	class.addMethod(&.{ .gimme }, baseC, .gen("base"));
	class.addMethod(&.{ .gimme }, precC, .gen("prec"));
	class.addMethod(&.{ .gimme }, stepC, .gen("step"));
	class.addMethod(&.{ .gimme }, rangeC, .gen("range"));
	class.addMethod(&.{ .gimme }, paramC, .gen("param"));

	class.setWidget(&.{
		.getrect = getRectC,
		.displace = displaceC,
		.select = selectC,
		.delete = deleteC,
		.vis = visC,
		.click = clickC,
	});
	class.setSaveFn(saveC);
	class.setPropertiesFn(propertiesC);
	pd.vMess(null, "r", .{ @embedFile("tcl/dialog_radix.tcl") });
}

export fn radix_setup() void {
	_ = pd.wrap(void, setup(), @src().fn_name);
}
