const std = @import("std");
const pd = @import("pd");
const rx = @import("rad.zig");
const bf = @import("bitfloat.zig");
const cnv = pd.cnv;

const Atom = pd.Atom;
const Float = pd.Float;
const GList = pd.GList;
const Object = pd.Object;
const Symbol = pd.Symbol;
const Writer = std.Io.Writer;

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

fn escape(s: *Symbol) !*Symbol {
	return if (s == &pd.s_) .gen("_") else if (s.name[0] != '_') s else blk: {
		var shmo: [100]u8 = undefined;
		const str = try std.fmt.bufPrintZ(&shmo, "_{s}", .{ s.name });
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
			t.ob.disconnect(t.outno, t.ob2, t.inno);
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

const LimitState = packed struct(u2) {
	lo: bool,
	hi: bool,
};

const Radix = extern struct {
	obj: Object = undefined,
	/// owning glist
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
	/// number of pixels per motion step
	step: [2]Float,
	/// min-max range of possible values
	range: [2]Float,
	/// position at the start of a grab
	grab: [2]Float = .{ 0, 0 },
	/// value at the start of a grab, or the toggle value
	alt: Float = 0,
	/// radix context
	rad: rx.Rad,
	/// font size (pt)
	font_size: u16,
	/// tcl tag
	tag: [@sizeOf(usize) * 2 + 2 :0]u8,
	/// bit field
	b: packed struct(u8) {
		where: WhereLabel,
		/// null states for the min-max range
		range: LimitState,
		/// true if we've grabbed the keyboard and want a thicker border
		grabbed: bool = false,
		/// whether shift key was down when drag started
		shift: bool = false,
		_unused: u2 = 0,
	},

	const name = "radix";
	var class: *pd.Class = undefined;

	inline fn err(self: *Radix, e: anyerror) void {
		pd.post.err(self, "%s", .{ @errorName(e).ptr });
	}

	fn getRect(self: *Radix, glist: *GList) pd.Rect(c_int) {
		const obj: *Object = &self.obj;
		const fontsize: c_uint = if (self.font_size != 0)
			@intCast(self.font_size)
		else glist.getFont();
		const len: c_uint = if (self.rad.width == 0)
			@max(3, self.rad.end) else self.rad.width;
		const size: IVec2 = blk: {
			const uz = glist.getZoom();
			const iz: c_int = @intCast(uz);
			const amargin = IVec2{ atom_rmargin, atom_bmargin } * IVec2{ iz, iz };
			break :blk amargin + @as(IVec2, @intCast(@Vector(2, c_uint){
				len * pd.zoomFontWidth(fontsize, uz, false),
				pd.zoomFontHeight(fontsize, uz, false),
			}));
		};
		const p1 = obj.pos(glist);
		return .{ .p1 = p1, .p2 = p1 + size };
	}

	fn getRectC(
		self: *Radix, glist: *GList,
		xp1: *c_int, yp1: *c_int,
		xp2: *c_int, yp2: *c_int,
	) callconv(.c) void {
		const rect = self.getRect(glist);
		xp1.* = rect.p1[0];
		yp1.* = rect.p1[1];
		xp2.* = rect.p2[0];
		yp2.* = rect.p2[1];
	}

	fn selectC(self: *Radix, glist: *GList, selected: c_int) callconv(.c) void {
		const obj: *Object = &self.obj;
		if (!glist.isVisible() or !obj.g.shouldVis(glist)) {
			return;
		}
		const color = if (selected != 0)
			pd.this().gui.selectcolor
		else pd.this().gui.foregroundcolor;

		self.tag_type.* = .text;
		pd.vMess(null, "crs rk", .{ glist, "itemconfigure", &self.tag, "-fill", color });
		self.tag_type.* = .border;
		pd.vMess(null, "crs rk", .{ glist, "itemconfigure", &self.tag, "-fill", color });
	}

	fn deleteC(self: *Radix, glist: *GList) callconv(.c) void {
		glist.deleteLinesFor(&self.obj);
	}

	fn drawBorder(
		self: *Radix, glist: *GList,
		rect: pd.Rect(c_int),
		firsttime: bool,
	) void {
		self.tag_type.* = .border;
		const zoom: c_int = @intCast(glist.zoom);
		const grabbed: c_int = zoom * @intFromBool(self.b.grabbed);
		const p1 = rect.p1 + IVec2{ grabbed, grabbed };
		const p2 = rect.p2;
		const corner = @divTrunc(rect.size()[1], 4);
		const shape: std.meta.Tuple(&(.{c_int} ** 12)) = .{
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
			pd.vMess(null, "crr" ++ ("i" ** shape.len) ++ "ri rk rr rS", .{
				canvas, "create", "line",
			} ++ shape ++ .{
				"-width", zoom + grabbed,
				"-fill", pd.this().gui.foregroundcolor,
				"-capstyle", "projecting",
				"-tags", tags.len, &tags,
			});
			pd.vMess(null, "crr", .{ canvas, "raise", "cord" });
		} else {
			pd.vMess(null, "crs" ++ ("i" ** shape.len), .{
				canvas, "coords", &self.tag,
			} ++ shape);
			pd.vMess(null, "crs ri", .{
				canvas, "itemconfigure", &self.tag,
				"-width", zoom + grabbed,
			});
		}
		glist.drawIoFor(&self.obj, firsttime, &self.tag, p1[0], p1[1], p2[0], p2[1]);
	}

	fn displaceC(self: *Radix, glist: *GList, dx: c_int, dy: c_int) callconv(.c) void {
		const obj: *Object = &self.obj;
		const canvas = glist.getCanvas();
		const dvec: IVec2 = .{ dx, dy };
		obj.pix = obj.pix + @as(SVec2, @intCast(dvec));
		if (!glist.isVisible()) {
			return;
		}

		const zoom: c_int = @intCast(glist.zoom);
		const d = dvec * IVec2{ zoom, zoom };

		self.tag_type.* = .text;
		pd.vMess(null, "crs ii", .{ canvas, "move", &self.tag, d[0], d[1] });
		self.tag_type.* = .label;
		pd.vMess(null, "crs ii", .{ canvas, "move", &self.tag, d[0], d[1] });
		self.drawBorder(glist, self.getRect(glist), false);
		glist.fixLinesFor(obj);
	}

	fn visC(self: *Radix, glist: *GList, visible: c_int) callconv(.c) void {
		const obj: *Object = &self.obj;
		if (!obj.g.shouldVis(glist)) {
			return;
		}
		const canvas = glist.getCanvas();
		if (visible == 0) {
			if (self.lbl != &pd.s_) {
				self.tag_type.* = .label;
				pd.vMess(null, "crs", .{ canvas, "delete", &self.tag });
			}

			self.tag_type.* = .text;
			pd.vMess(null, "crs", .{ canvas, "delete", &self.tag });

			self.tag_type.* = .border;
			glist.eraseIoFor(obj, &self.tag);
			pd.vMess(null, "crs", .{ canvas, "delete", &self.tag });
			return;
		}

		// draw the border
		const rect = self.getRect(glist);
		self.drawBorder(glist, rect, true);

		// draw the text
		const fontsize: c_uint = if (self.font_size != 0)
			@intCast(self.font_size)
		else glist.getFont();
		const uz = glist.getZoom();
		const iz: c_int = @intCast(uz);
		{
			self.tag_type.* = .text;
			const tags = [_][*]const u8{ &self.tag, "text" };
			const pos = rect.p1 + IVec2{ margin.left, margin.top } * IVec2{ iz, iz };
			pd.vMess("pdtk_text_new", "c S ii s i k", .{
				canvas,
				tags.len, &tags,
				pos[0], pos[1],
				&self.rad.buf,
				pd.hostFontSize(fontsize, uz),
				if (glist.isSelected(&obj.g))
					pd.this().gui.selectcolor
				else pd.this().gui.foregroundcolor,
			});
		}
		if (self.lbl == &pd.s_) {
			return;
		}

		// draw the label
		const label = glist.realizeDollar(self.lbl).name;
		const p1 = switch (self.b.where) {
			.left => blk: {
				const len = std.mem.len(label);
				const wid: c_int = @intCast(len * pd.zoomFontWidth(fontsize, uz, false));
				break :blk rect.p1 + IVec2{ -3 * iz - wid, 2 * iz };
			},
			.right => blk: {
				const dz = iz * 2;
				break :blk IVec2{ rect.p2[0], rect.p1[1] } + IVec2{ dz, dz };
			},
			.up => blk: {
				const h: c_int = @intCast(pd.zoomFontHeight(fontsize, uz, false));
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
			fontsize * uz, pd.this().gui.foregroundcolor,
		});
	}

	fn redrawC(self: *Radix, glist: *GList) callconv(.c) void {
		self.rad.write() catch |e| {
			self.err(e);
			@memcpy(self.rad.buf[0..4], "err\x00");
		};
		self.tag_type.* = .text;
		pd.vMess("pdtk_text_set", "cs s", .{
			glist, &self.tag,
			&self.rad.buf,
		});
		if (self.rad.width == 0 and self.rad.resize) {
			self.drawBorder(self.gl, self.getRect(self.gl), false);
		}
	}

	fn sendItUp(self: *Radix) void {
		const canvas = self.gl.getCanvas();
		if (canvas.editor != null and self.obj.g.shouldVis(self.gl)) {
			pd.queueGui(self, canvas, @ptrCast(&redrawC));
		}
	}

	fn setC(self: *Radix, f: Float) callconv(.c) void {
		if (@as(bf.Uf, @bitCast(self.rad.value)) != @as(bf.Uf, @bitCast(f))) {
			self.rad.value = f;
			self.sendItUp();
		}
	}

	fn bangC(self: *Radix) callconv(.c) void {
		if (self.obj.outlets) |outlet| {
			outlet.float(self.rad.value);
		} else if (self.sndx.thing) |thing| {
			if (self.snd == self.rcv) {
				pd.post.err(self, "%s: infinite loop", .{ self.snd.name });
			} else {
				thing.float(self.rad.value);
			}
		}
	}

	fn floatC(self: *Radix, f: Float) callconv(.c) void {
		self.setC(f);
		self.bangC();
	}

	fn keyC(self: *Radix, _: *Symbol, f: Float) callconv(.c) void {
		if (f == 0) {
			self.b.grabbed = false;
			self.drawBorder(self.gl, self.getRect(self.gl), false);
		}
	}

	fn motionC(self: *Radix, dx: Float, dy: Float, released: Float) callconv(.c) void {
		if (released != 0 or (dx == 0 and dy == 0)) {
			return;
		}
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
		if (self.b.range.lo and nval < self.range[0]) {
			nval = self.range[0];
			// prevent having to drag all the way back to where limit was reached
			self.grab = pos - self.step / FVec2{ 4, 4 };
			self.alt = nval;
		}
		if (self.b.range.hi and nval > self.range[1]) {
			nval = self.range[1];
			self.grab = pos - self.step / FVec2{ 4, 4 };
			self.alt = nval;
		}
		if (@as(bf.Uf, @bitCast(self.rad.value)) != @as(bf.Uf, @bitCast(nval))) {
			self.rad.value = nval;
			self.sendItUp();
			self.bangC();
		}
	}

	/// called when clicked on in run mode
	fn clickC(
		self: *Radix, gl: *GList,
		xpos: c_int, ypos: c_int,
		shift: c_int, alt: c_int, _: c_int, doit: c_int,
	) callconv(.c) c_int {
		if (doit == 0) {
			return 1;
		}
		if (alt != 0) {
			if (self.rad.value != 0) {
				self.alt = self.rad.value;
				self.floatC(0);
			} else {
				self.floatC(self.alt);
			}
			gl.grab(&self.obj.g, null, @ptrCast(&keyC), 0, 0);
		} else {
			const pos: FVec2 = @floatFromInt(IVec2{ xpos, ypos });
			// start in the middle of a step rather than at the beginning of one
			self.grab = pos - self.step / FVec2{ 4, 4 };
			self.b.shift = (shift != 0);
			self.alt = self.rad.value;
			gl.grab(&self.obj.g, @ptrCast(&motionC), @ptrCast(&keyC), xpos, ypos);
		}
		self.b.grabbed = true;
		self.drawBorder(gl, self.getRect(gl), false);
		return 1;
	}

	/// Get unresolved `rcv`, `snd`, and `lbl` symbols.
	///
	/// Symbols are already resolved if radix is loaded from a patch,
	/// so we have to find the unresolved versions in the object's binbuf.
	fn getRSL(self: *Radix) ![3]*Symbol {
		return if (self.obj.binbuf) |binbuf| blk: {
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

	fn saveC(self: *Radix, b: *pd.BinBuf) callconv(.c) void {
		save(self, b) catch |e| self.err(e);
	}
	inline fn save(self: *Radix, b: *pd.BinBuf) !void {
		var buf_min: [16:0]u8 = undefined;
		var buf_max: [16:0]u8 = undefined;
		const none: Atom = .symbol(.gen("_"));
		(if (self.b.range.lo) Atom.float(self.range[0]) else none).bufPrint(&buf_min);
		(if (self.b.range.hi) Atom.float(self.range[1]) else none).bufPrint(&buf_max);
		const rsl = try self.getRSL();

		try b.addV("ssiis" ++ "iiffss" ++ "iisssi;", .{
			Symbol.gen("#X"), Symbol.gen("obj"),
			self.obj.pix[0], self.obj.pix[1],
			Symbol.gen("radix"),

			self.rad.base, self.rad.prec,
			self.step[0], -self.step[1],
			Symbol.gen(&buf_min), Symbol.gen(&buf_max),

			self.rad.width, self.font_size,
			rsl[0], rsl[1],
			rsl[2], @as(u8, @intFromEnum(self.b.where)),
		});
	}

	fn propertiesC(self: *Radix, _: *GList) callconv(.c) void {
		properties(self) catch |e| self.err(e);
	}
	inline fn properties(self: *Radix) !void {
		var buf_min: [16:0]u8 = undefined;
		var buf_max: [16:0]u8 = undefined;
		const none: Atom = .symbol(.gen("_"));
		(if (self.b.range.lo) Atom.float(self.range[0]) else none).bufPrint(&buf_min);
		(if (self.b.range.hi) Atom.float(self.range[1]) else none).bufPrint(&buf_max);
		const rsl = try self.getRSL();

		self.obj.g.pd.stub("dialog_radix::setup", self, "ii ff ss ii ss si", .{
			self.rad.base, self.rad.prec,
			self.step[0], -self.step[1],
			&buf_min, &buf_max,
			self.rad.width, self.font_size,
			rsl[0].name, rsl[1].name,
			rsl[2].name, @as(u8, @intFromEnum(self.b.where)),
		});
	}

	fn paramC(
		self: *Radix,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		param(self, av[0..ac]) catch |e| self.err(e);
	}
	inline fn param(self: *Radix, av: []const Atom) !void {
		if (av.len != 12) {
			return error.WrongArgCount;
		}
		const obj: *Object = &self.obj;
		const visible = self.gl.isVisible();
		const none: Atom = .symbol(.gen("_"));
		const rsl = try self.getRSL();

		self.gl.setUndoState(&obj.g.pd, .gen("param"), &.{
			.float(@floatFromInt(self.rad.base)),
			.float(@floatFromInt(self.rad.prec)),
			.float(self.step[0]),
			.float(-self.step[1]),
			if (self.b.range.lo) .float(self.range[0]) else none,
			if (self.b.range.hi) .float(self.range[1]) else none,
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

		self.rad.base = if (av[0].getFloat()) |f| @intFromFloat(f) else self.rad.base;
		self.rad.prec = if (av[1].getFloat()) |f| @intFromFloat(f) else self.rad.prec;
		self.rad.reset();
		const width: u16 = @intFromFloat(av[6].getFloat() orelse 0);
		self.rad.width = @min(width, 1000);
		try self.rad.write();

		self.step = .{
			av[2].getFloat() orelse self.step[0],
			if (av[3].getFloat()) |f| -f else self.step[1],
		};

		var rstate: LimitState = .{ .lo = true, .hi = true };
		self.range = .{
			av[4].getFloat() orelse blk: { rstate.lo = false; break :blk 0; },
			av[5].getFloat() orelse blk: { rstate.hi = false; break :blk 0; },
		};
		self.b.range = rstate;

		const fs: u16 = @intFromFloat(av[7].getFloat() orelse 0);
		self.font_size = @min(fs, 36);

		const rcv_old = self.rcv;
		const rcv_raw = av[8].getSymbol() orelse &pd.s_;
		const rcv_new = unescape(rcv_raw);
		if (rcv_old != &pd.s_) {
			if (rcv_new != &pd.s_) {
				if (rcv_old != rcv_new) { // symbol to symbol
					obj.g.pd.unbind(self.gl.realizeDollar(rcv_old));
					obj.g.pd.bind(self.gl.realizeDollar(rcv_new));
				}
			} else { // symbol to inlet
				obj.g.pd.unbind(self.gl.realizeDollar(rcv_old));
				_ = try obj.inlet(&obj.g.pd, null, null);
			}
		} else if (rcv_new != &pd.s_) { // inlet to symbol
			if (obj.inlets) |inlet| {
				deleteLinesForIo(self.gl, obj, inlet, null);
				inlet.deinit();
			}
			obj.g.pd.bind(self.gl.realizeDollar(rcv_new));
		}
		self.rcv = rcv_new;

		const snd_old = self.snd;
		const snd_raw = av[9].getSymbol() orelse &pd.s_;
		const snd_new = unescape(snd_raw);
		if (snd_old != &pd.s_) {
			if (snd_new == &pd.s_) { // symbol to outlet
				_ = try obj.outlet(null);
			}
		} else if (snd_new != &pd.s_) { // outlet to symbol
			if (obj.outlets) |outlet| {
				deleteLinesForIo(self.gl, obj, null, outlet);
				outlet.deinit();
			}
		}
		self.snd = snd_new;
		self.sndx = self.gl.realizeDollar(snd_new);

		const lbl_raw = av[10].getSymbol() orelse &pd.s_;
		self.lbl = unescape(lbl_raw);
		const where: u2 = @intFromFloat(av[11].getFloat() orelse 0);
		self.b.where = @enumFromInt(where);

		if (self.obj.binbuf) |binbuf| {
			const slc = binbuf.getSlice();
			if (slc.len > 9) {
				slc[9] = .{ .type = .dollsym, .w = .{ .symbol = rcv_raw } };
			}
			if (slc.len > 10) {
				slc[10] = .{ .type = .dollsym, .w = .{ .symbol = snd_raw } };
			}
			if (slc.len > 11) {
				slc[11] = .{ .type = .dollsym, .w = .{ .symbol = lbl_raw } };
			}
		}

		if (visible) {
			if (obj.g.shouldVis(self.gl)) {
				self.visC(self.gl, 1);
			}
			self.gl.fixLinesFor(obj);
		}
		self.gl.setDirty(true);
	}

	fn stepC(
		self: *Radix,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
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

	fn readC(
		self: *Radix,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		self.read(self.rad.base, av[0..ac]) catch |e| self.err(e);
	}
	fn read(self: *Radix, base: u16, av: []const Atom) !void {
		if (av.len < 1) {
			return error.NotEnoughArgs;
		}
		var res: [32]u8 = undefined;
		const cp: [*:0]const u8 = if (av[0].type == .float)
			try std.fmt.bufPrintZ(&res, "{}", .{ av[0].w.float })
		else av[0].w.symbol.name;
		self.floatC(try rx.parseFloat(cp, base));
	}

	fn anythingC(
		self: *Radix,
		s: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		if (s.name[0] == 'b') {
			self.read(rx.getBase(std.mem.sliceTo(s.name, 0)[1..]), av[0..ac])
				catch |e| self.err(e);
		} else {
			pd.post.err(self, name ++ ": no method for '%s'", .{ s.name });
		}
	}

	fn baseC(
		self: *Radix,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		const a = av[0..ac];
		if (pd.floatArg(0, a)) |f| { // set
			self.rad.base = @intFromFloat(@max(0, f));
			if (pd.floatArg(1, a)) |g| {
				self.rad.prec = @intFromFloat(@max(0, g));
			} else |_| {}
			self.rad.reset();
			self.sendItUp();
		} else |_| { // get
			pd.post.log(self, .normal, "base: %u", .{ self.rad.base });
		}
	}

	fn precC(
		self: *Radix,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		if (pd.floatArg(0, av[0..ac])) |f| { // set
			self.rad.setPrecision(f);
			self.sendItUp();
		} else |_| { // get
			pd.post.log(self, .normal, "precision: %u", .{ self.rad.prec });
		}
	}

	fn initC(_: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Radix {
		return pd.wrap(*Radix, init(av[0..ac]), name);
	}
	inline fn init(av: []const Atom) !*Radix {
		const gl = GList.getCurrent() orelse return error.NoCurrentGList;
		const self: *Radix = @ptrCast(try class.pd());
		const obj: *Object = &self.obj;
		errdefer obj.g.pd.deinit();

		var tag: [@sizeOf(usize) * 2 + 2 :0]u8 = undefined;
		var w: Writer = .fixed(&tag);
		try w.print("{x}._", .{ @intFromPtr(obj) });
		tag[w.end] = 0;

		var rad: rx.Rad = .init(
			@intFromFloat(pd.floatArg(0, av) catch 10),
			@intFromFloat(pd.floatArg(1, av) catch 0),
		);
		rad.width = @intFromFloat(@min(pd.floatArg(6, av) catch 0, 500));

		var rstate: LimitState = .{ .lo = true, .hi = true };
		const rcv: *Symbol = unescape(pd.symbolArg(8, av) catch &pd.s_);
		const snd: *Symbol = unescape(pd.symbolArg(9, av) catch &pd.s_);

		if (rcv == &pd.s_) {
			_ = try obj.inlet(&obj.g.pd, null, null);
		} else {
			obj.g.pd.bind(gl.realizeDollar(rcv));
		}
		if (snd == &pd.s_) {
			_ = try obj.outlet(&pd.s_float);
		}

		self.* = .{
			.gl = gl,
			.rad = rad,
			.step = .{
				pd.floatArg(2, av) catch 0,
				if (pd.floatArg(3, av)) |f| -f else |_| -3,
			},
			.range = .{
				pd.floatArg(4, av) catch blk: { rstate.lo = false; break :blk 0; },
				pd.floatArg(5, av) catch blk: { rstate.hi = false; break :blk 0; },
			},
			.font_size = @intFromFloat(@min(pd.floatArg(7, av) catch 0, 36)),
			.rcv = rcv,
			.snd = snd,
			.sndx = gl.realizeDollar(snd),
			.lbl = unescape(pd.symbolArg(10, av) catch &pd.s_),
			.b = .{
				.where = @enumFromInt(@as(u2, @intFromFloat(pd.floatArg(11, av) catch 0))),
				.range = rstate,
			},
			.tag = tag,
			.tag_type = @ptrCast(&self.tag[w.end - 1]),
		};
		return self;
	}

	fn freeC(self: *Radix) callconv(.c) void {
		if (self.rcv != &pd.s_) {
			self.obj.g.pd.unbind(self.gl.realizeDollar(self.rcv));
		}
		pd.deleteStubForKey(self);
		pd.unqueueGui(self);
	}

	const widget_behavior: cnv.WidgetBehavior = .{
		.getrect = @ptrCast(&getRectC),
		.displace = @ptrCast(&displaceC),
		.select = @ptrCast(&selectC),
		.delete = @ptrCast(&deleteC),
		.vis = @ptrCast(&visC),
		.click = @ptrCast(&clickC),
	};

	inline fn setup() !void {
		class = try .init(Radix, name, &.{ .gimme }, &initC, &freeC, .{
			.no_inlet = true,
			.patchable = true,
		});
		class.addBang(@ptrCast(&bangC));
		class.addFloat(@ptrCast(&floatC));
		class.addAnything(@ptrCast(&anythingC));
		class.addMethod(@ptrCast(&setC), .gen("set"), &.{ .float });
		class.addMethod(@ptrCast(&readC), .gen("read"), &.{ .gimme });
		class.addMethod(@ptrCast(&stepC), .gen("step"), &.{ .gimme });
		class.addMethod(@ptrCast(&baseC), .gen("base"), &.{ .gimme });
		class.addMethod(@ptrCast(&precC), .gen("prec"), &.{ .gimme });
		class.addMethod(@ptrCast(&paramC), .gen("param"), &.{ .gimme });

		class.setWidget(&widget_behavior);
		class.setSaveFn(@ptrCast(&saveC));
		class.setPropertiesFn(@ptrCast(&propertiesC));
		pd.vMess(null, "r", .{ @embedFile("tcl/dialog_radix.tcl") });
	}
};

export fn radix_setup() void {
	_ = pd.wrap(void, Radix.setup(), @src().fn_name);
}
