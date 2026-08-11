const std = @import("std");
const pd = @import("pd");
const wr = @import("write.zig");
const tx = @import("trax.zig");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Float = pd.Float;
const Sample = pd.Sample;
const Symbol = pd.Symbol;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Writer = Io.Writer;
const Meta = tx.Meta;
const Arena = tx.Arena;

const toggle = @import("toggle.zig").toggle;
const find = std.mem.findScalar;

var s_open: *Symbol = undefined;
pub var s_play: *Symbol = undefined;

pub const Player = extern struct {
	/// outlet for sending metadata and open/play states
	outlet: *pd.Outlet,
	/// Whether a track has been opened
	open: bool = false,
	/// Whether a track is currently playing
	play: bool = false,

	pub const Error = error{NoFileOpened};

	pub inline fn init(obj: *pd.Object) pd.Oom!Player {
		return .{
			.outlet = try .init(obj, null),
		};
	}

	pub inline fn assertFileOpened(self: *const Player) Error!void {
		if (!self.open) {
			return error.NoFileOpened;
		}
	}

	pub inline fn sendState(self: *Player, s: *Symbol, state: bool) void {
		self.outlet.anything(s, &.{ .float(@floatFromInt(@intFromBool(state))) });
	}

	inline fn setPlay(self: *Player, av: []const Atom) Error!void {
		try self.assertFileOpened();
		if (toggle(&self.play, av)) {
			self.sendState(s_play, self.play);
		}
	}
};

const secs = 1000;
const mins = 60 * secs;
const hours = 60 * mins;

fn printTime(writer: *Writer, ms: i64) Writer.Error!void {
	if (ms < 0) {
		return writer.print("?:?", .{});
	}
	const t: u64 = @bitCast(ms);
	const hr: u8 = @truncate(@divFloor(t, hours));
	const mn: u8 = @truncate(@mod(@divFloor(t, mins), 60));
	const sc: u8 = @truncate(@mod(@divFloor(t, secs), 60));

	if (hr >= 1) {
		try writer.print("{}:", .{ hr });
	}
	return writer.print("{:0>2}:{:0>2}", .{ mn, sc });
}

test printTime {
	var buf: [16]u8 = undefined;
	var w: Writer = .fixed(&buf);
	try printTime(&w, 1*mins + 3*secs);
	try std.testing.expect(std.mem.eql(u8, w.buffered(), "01:03"));
	w.end = 0;
	try printTime(&w, 2*hours + 30*mins + 45*secs);
	try std.testing.expect(std.mem.eql(u8, w.buffered(), "2:30:45"));
}

pub fn timeSym(ms: i64) *Symbol {
	var buf: [32:0]u8 = undefined;
	var w: Writer = .fixed(&buf);
	printTime(&w, ms) catch return pd.s.empty();
	buf[w.end] = 0;
	return .gen(buf[0..w.end :0]);
}

inline fn isDigit(c: u8) bool {
	return ('0' <= c and c <= '9');
}

fn alignBuffer(w: *Writer, buf: []const u8, fmt: []const u8) Writer.Error!void {
	const fill = fmt[1];
	const has_al = !isDigit(fmt[2]);
	const alignment: std.fmt.Alignment = if (has_al) switch (fmt[2]) {
		'<' => .left,
		'^' => .center,
		else => .right,
	} else .right;
	const wpos: usize = if (has_al) 3 else 2;
	const width = std.fmt.parseInt(usize, fmt[wpos..], 10) catch 0;
	try w.alignBuffer(buf, width, alignment, fill);
}

/// Returns the number of samples consumed
pub inline fn leavedToPlanar(
	leaved: [*]const Sample,
	planar: [*][*]Sample,
	channels: usize,
	frames: usize,
) usize {
	var l = leaved;
	for (0..frames) |frame| {
		for (0..channels) |channel| {
			planar[channel][frame] = l[0];
			l += 1;
		}
	}
	return l - leaved;
}

pub fn Impl(Self: type) type { return struct {
	/// Perform this after seeking or loading a new track.
	const resetBuffers: fn(*Self) void = Self.resetBuffers;
	/// Perform this after loading a new track.
	const prepNewTrack: fn(*Self) void = Self.prepNewTrack;
	/// Print error to Pd console
	const err: fn(*const Self, anyerror) callconv(.@"inline") void = Self.err;
	const gpa = Self.gpa;
	const io = Self.io;
	const parentPtr = Self.parentPtr;
	const parentConstPtr = Self.parentConstPtr;

	const Base = Self.Base;
	const GetMetaFn = fn(*const Base, *const Meta, *Symbol) ?*const Arena;
	/// Returns the value of a given metadata field if available.
	const bGet: GetMetaFn = Base.get;
	/// Returns a trax.Meta object
	const bTrax: fn(*const Base, Allocator, Io) callconv(.@"inline") Meta = Base.getTrax;
	/// Seek to a time in milliseconds.
	const bSeek: fn(*Base, Float) anyerror!void = Base.seek;
	/// Load a track in the playlist by index.
	const bLoadTrack: fn(*Base, usize) anyerror!void = Base.loadTrack;
	/// Open a file or playlist and load the first track.
	const bOpen: fn(*Base, Allocator, Io, []const Atom) callconv(.@"inline") anyerror!void
		= Base.open;
	/// Print function for when no args are specified.
	const bPrint: fn (*const Base, *const Meta, *Writer) callconv(.@"inline") anyerror!void
		= Base.printAuto;
	/// Returns the number of tracks in the current playlist.
	const bTrackCount: fn(*const Base) callconv(.@"inline") usize = Base.trackCount;


	fn getNone(_: *const Base, _: *const Meta, _: *Symbol) ?*const Arena {
		return null;
	}

	fn printC(
		p: *const Pd,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		const self = parentConstPtr(p);
		var buffer: [pd.max_string:0]u8 = undefined;
		var writer: Writer = .fixed(&buffer);
		print(self, &writer, av[0..ac]) catch wr.ellipsis(&writer);
		if (writer.end > 0) {
			buffer[writer.end] = 0;
			pd.post.log(self, .normal, "%s", .{ &buffer });
		}
	}
	inline fn print(self: *const Self, w: *Writer, av: []const Atom) Writer.Error!void {
		const base: *const Base = &self.base;
		const player: *const Player = &base.player;
		const getfn: *const GetMetaFn = if (player.open) &bGet else &getNone;
		var trax: Meta = bTrax(base, gpa, io);
		defer trax.deinit(gpa);
		if (av.len == 0) {
			return bPrint(base, &trax, w);
		}

		const ilast = av.len - 1;
		for (av, 0..av.len) |*a, i| {
			if (a.type == .float) {
				try wr.fmtG(w, a.w.float);
			} else {
				var str: [:0]const u8 = std.mem.sliceTo(a.w.symbol.name, 0);
				while (true) {
					const pctpos: usize = (find(u8, str, '%') orelse break);
					const exclm: bool = str[pctpos + 1] == '!';
					const pos: usize = pctpos + @as(usize, if (exclm) 2 else 1);

					const pctend: usize = (find(u8, str[pos..], '%') orelse break) + pos;
					const cons: ?usize = find(u8, str[pos..pctend], ':');
					const end = if (cons) |c| c + pos else pctend;
					defer str = str[pctend + 1 ..];

					try w.writeAll(str[0..pctpos]);
					if (exclm) {
						// skip metadata search and just format the string
						if (cons != null) {
							try alignBuffer(w, str[pos..end], str[end..pctend]);
						} else {
							try w.writeAll(str[pos..end]);
						}
						continue;
					}

					const kpos = w.end;
					try w.writeAll(str[pos..end]);
					try w.writeByte(0);
					const key: *Symbol = .gen(w.buffer[kpos..][0 .. end - pos :0].ptr);
					const meta: *const Arena = getfn(base, &trax, key) orelse &.{};
					w.end = kpos;

					var mbuf: [std.fmt.float.bufferSize(.decimal, Float)]u8 = undefined;
					for (0..meta.tbl.items.len) |j| {
						if (j > 0) {
							try w.writeByte('/');
						}
						const val = meta.get(j);
						const mstr: []const u8 = switch (val) {
							.float => |f| blk: {
								var mw: Writer = .fixed(&mbuf);
								try wr.fmtG(&mw, f);
								break :blk mw.buffered();
							},
							.string => |s| s,
						};

						if (cons == null or pctend < end + 3) {
							try w.writeAll(mstr);
						} else {
							try alignBuffer(w, mstr, str[end..pctend]);
						}
					}
				}
				try w.writeAll(str);
			}
			if (i < ilast) {
				try w.writeByte(' ');
			}
		}
	}

	fn getC(p: *const Pd, s: *Symbol) callconv(.c) void {
		const self = parentConstPtr(p);
		get(self, s) catch |e| err(self, e);
	}
	fn get(self: *const Self, s: *Symbol) pd.Oom!void {
		const base: *const Base = &self.base;
		const player: *const Player = &base.player;
		const getfn: *const GetMetaFn = if (player.open) &bGet else &getNone;
		var trax: Meta = bTrax(base, gpa, io);
		defer trax.deinit(gpa);
		if (getfn(base, &trax, s)) |a| {
			try a.send(gpa, player.outlet, s);
		} else {
			player.outlet.anything(s, &.{});
		}
	}

	fn anythingC(
		p: *const Pd,
		s: *Symbol, _: c_uint, _: [*]const Atom,
	) callconv(.c) void {
		const self = parentConstPtr(p);
		get(self, s) catch |e| err(self, e);
	}

	fn seekC(p: *Pd, f: Float) callconv(.c) void {
		const self = parentPtr(p);
		seek(self, f) catch |e| err(self, e);
	}
	inline fn seek(self: *Self, msec: Float) !void {
		const base: *Base = &self.base;
		const player: *Player = &base.player;
		try player.assertFileOpened();
		try bSeek(base, msec);
		resetBuffers(self);
	}

	fn openC(
		p: *Pd,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		const self = parentPtr(p);
		const base: *Base = &self.base;
		const player: *Player = &base.player;
		const result: bool = blk: { if (open(base, av[0..ac])) {
			player.open = true;
			player.play = false;
			resetBuffers(self);
			prepNewTrack(self);
			break :blk true;
		} else |e| {
			// previous track is only replaced on a successful open,
			// so open/play states should be left alone on failure
			err(self, e);
			break :blk false;
		}};
		player.sendState(s_open, result);
	}
	inline fn open(base: *Base, av: []const Atom) !void {
		try bOpen(base, gpa, io, av);
		try bLoadTrack(base, 0);
	}

	fn listC(
		p: *Pd,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		const self = parentPtr(p);
		const player: *Player = &self.base.player;
		player.play = list(self, av[0..ac]) catch |e| blk: {
			err(self, e);
			break :blk false;
		};
		player.sendState(s_play, player.play);
	}
	fn list(self: *Self, av: []const Atom) !bool {
		const base: *Base = &self.base;
		const player: *Player = &base.player;
		try player.assertFileOpened();

		const track: u32 = @intFromFloat(try pd.floatArg(0, av));
		const result: bool = blk: { if (0 < track and track <= bTrackCount(base)) {
			try bLoadTrack(base, track - 1);
			if (pd.floatArg(1, av)) |msec| {
				try bSeek(base, msec);
			} else |_| {}
			break :blk true;
		} else {
			// rewind when index is zero or out of bounds
			try bSeek(base, 0);
			break :blk false;
		}};
		resetBuffers(self);
		prepNewTrack(self);
		return result;
	}

	fn stopC(p: *Pd) callconv(.c) void {
		listC(p, pd.s.empty(), 1, &.{ .float(0) });
	}

	/// toggle the play/pause state, or set to arg if one is given
	fn playC(p: *Pd,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		const self = parentPtr(p);
		const player: *Player = &self.base.player;
		player.setPlay(av[0..ac]) catch |e| err(self, e);
	}

	/// toggle the play/pause state
	fn bangC(p: *Pd) callconv(.c) void {
		const self = parentPtr(p);
		const player: *Player = &self.base.player;
		player.setPlay(&.{}) catch |e| err(self, e);
	}

	pub inline fn extend() void {
		s_open = .gen("open");
		s_play = .gen("play");

		const class: *pd.Class = Self.class;
		class.addBang(bangC);
		class.addList(listC);
		class.addAnything(anythingC);
		class.addMethod(&.{}, stopC, .gen("stop"));
		class.addMethod(&.{ .float }, seekC, .gen("seek"));
		class.addMethod(&.{ .symbol }, getC, .gen("get"));
		class.addMethod(&.{ .gimme }, printC, .gen("print"));
		class.addMethod(&.{ .gimme }, openC, s_open);
		class.addMethod(&.{ .gimme }, playC, s_play);
	}
};}
