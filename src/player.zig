const std = @import("std");
const pd = @import("pd");
const wr = @import("write.zig");

const Atom = pd.Atom;
const Float = pd.Float;
const Sample = pd.Sample;
const Symbol = pd.Symbol;
const Writer = std.Io.Writer;

const toggle = @import("toggle.zig").toggle;
const indexOf = std.mem.indexOfScalar;

var buffer: [pd.max_string:0]u8 = undefined;
var s_open: *Symbol = undefined;
pub var s_play: *Symbol = undefined;

pub const Player = extern struct {
	// outlet for sending metadata and open/play states
	outlet: *pd.Outlet,
	/// Whether a track has been opened
	open: bool = false,
	/// Whether a track is currently playing
	play: bool = false,

	pub inline fn init(obj: *pd.Object) !Player {
		return .{
			.outlet = try .init(obj, null),
		};
	}

	pub inline fn assertFileOpened(self: *const Player) error{NoFileOpened}!void {
		if (!self.open) {
			return error.NoFileOpened;
		}
	}

	pub inline fn sendState(self: *Player, s: *Symbol, state: bool) void {
		self.outlet.anything(s, &.{ .float(@floatFromInt(@intFromBool(state))) });
	}

	inline fn setPlay(self: *Player, av: []const Atom) error{NoFileOpened}!void {
		try self.assertFileOpened();
		if (toggle(&self.play, av)) {
			self.sendState(s_play, self.play);
		}
	}
};

const secs = 1000;
const mins = 60 * secs;
const hours = 60 * mins;

fn printTime(writer: *Writer, ms: i64) !void {
	if (ms < 0) {
		return writer.print("?:?", .{});
	}
	const t: u64 = @intCast(ms);
	const hr: u8 = @intCast(@divFloor(t, hours));
	const mn: u8 = @intCast(@mod(@divFloor(t, mins), 60));
	const sc: u8 = @intCast(@mod(@divFloor(t, secs), 60));

	if (hr >= 1) {
		try writer.print("{}:", .{ hr });
	}
	try writer.print("{:0>2}:{:0>2}", .{ mn, sc });
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
	printTime(&w, ms) catch return &pd.s_;
	buf[w.end] = 0;
	return .gen(buf[0..w.end :0]);
}

/// Returns the number of samples consumed
pub inline fn leavedToPlanar(
	leaved: [*]const Sample,
	planar: [*][*]Sample,
	channels: u8,
	frames: u8,
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
	/// Perform this after seeking. Resets internal buffers.
	const reset: fn(*Self) void = Self.reset;
	/// Perform this after loading a new track. Buffer reset and track preparation.
	const restart: fn(*Self) void = Self.restart;
	/// Print error to Pd console
	const err: fn(*const Self, anyerror) callconv(.@"inline") void = Self.err;

	const Base = Self.Base;
	/// Returns the value of a given metadata field if available.
	const bGet: fn(*const Base, *Symbol) ?Atom = Base.get;
	/// Seek to a time in milliseconds.
	const bSeek: fn(*Base, Float) anyerror!void = Base.seek;
	/// Load a track in the playlist by index.
	const bLoadTrack: fn(*Base, usize) anyerror!void = Base.loadTrack;
	/// Open a file or playlist and load the first track.
	const bOpen: fn(*Base, []const Atom) callconv(.@"inline") anyerror!void = Base.open;
	/// Print function for when no args are specified.
	const bPrint: fn (*const Base, *Writer) callconv(.@"inline") anyerror!void
		= Base.printAuto;
	/// Returns the number of tracks in the current playlist.
	const bTrackCount: fn(*const Base) callconv(.@"inline") usize = Base.trackCount;


	fn printC(
		self: *const Self,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		var writer: Writer = .fixed(&buffer);
		print(self, &writer, av[0..ac]) catch wr.ellipsis(&writer);
		if (writer.end > 0) {
			buffer[writer.end] = 0;
			pd.post.log(self, .normal, "%s", .{ &buffer });
		}
	}
	inline fn print(self: *const Self, writer: *Writer, av: []const Atom) !void {
		const base: *const Base = &self.base;
		const player: *const Player = &base.player;
		player.assertFileOpened() catch |e| return err(self, e);
		if (av.len == 0) {
			return bPrint(base, writer);
		}

		const ilast = av.len - 1;
		const buf = writer.buffer;
		for (av, 0..av.len) |*a, i| {
			if (a.type == .float) {
				try wr.fmtG(writer, a.w.float);
			} else {
				var str: [:0]const u8 = std.mem.sliceTo(a.w.symbol.name, 0);
				while (true) {
					const pos: usize = (indexOf(u8, str, '%') orelse break) + 1;
					const end: usize = (indexOf(u8, str[pos..], '%') orelse break) + pos;
					const len = end - pos;
					try writer.writeAll(str[0..end]);
					buf[writer.end] = 0;
					const name = buf[writer.end - len..][0..len :0].ptr;
					const meta: Atom = bGet(base, .gen(name)) orelse .symbol(&pd.s_);
					writer.end -= len + 1;
					if (meta.type == .float) {
						try wr.fmtG(writer, meta.w.float);
					} else {
						try writer.writeAll(std.mem.sliceTo(meta.w.symbol.name, 0));
					}
					str = str[end+1..];
				}
				try writer.writeAll(str);
			}
			if (i < ilast) {
				try writer.writeByte(' ');
			}
		}
	}

	fn sendC(self: *const Self, s: *Symbol) callconv(.c) void {
		send(self, s) catch |e| err(self, e);
	}
	fn send(self: *const Self, s: *Symbol) !void {
		const base: *const Base = &self.base;
		const player: *const Player = &base.player;
		try player.assertFileOpened();
		if (bGet(base, s)) |a| {
			player.outlet.anything(s, &.{ a });
		} else {
			player.outlet.anything(s, &.{});
		}
	}

	fn anythingC(
		self: *const Self,
		s: *Symbol, _: c_uint, _: [*]const Atom,
	) callconv(.c) void {
		send(self, s) catch |e| err(self, e);
	}

	fn seekC(self: *Self, f: Float) callconv(.c) void {
		seek(self, f) catch |e| err(self, e);
	}
	inline fn seek(self: *Self, msec: Float) !void {
		const base: *Base = &self.base;
		const player: *Player = &base.player;
		try player.assertFileOpened();
		try bSeek(base, msec);
		reset(self);
	}

	fn openC(
		self: *Self,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		const base: *Base = &self.base;
		const player: *Player = &base.player;
		const result: bool = blk: { if (open(base, av[0..ac])) {
			player.open = true;
			player.play = false;
			restart(self);
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
		try bOpen(base, av);
		try bLoadTrack(base, 0);
	}

	fn listC(
		self: *Self,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
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
			try bLoadTrack(base, @intCast(track - 1));
			if (pd.floatArg(1, av)) |msec| {
				try bSeek(base, msec);
			} else |_| {}
			break :blk true;
		} else {
			// rewind when index is zero or out of bounds
			try bSeek(base, 0);
			break :blk false;
		}};
		restart(self);
		return result;
	}

	fn stopC(self: *Self) callconv(.c) void {
		listC(self, &pd.s_, 1, &.{ .float(0) });
	}

	/// toggle the play/pause state, or set to arg if one is given
	fn playC(
		self: *Self,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		const player: *Player = &self.base.player;
		player.setPlay(av[0..ac]) catch |e| err(self, e);
	}

	/// toggle the play/pause state
	fn bangC(self: *Self) callconv(.c) void {
		const player: *Player = &self.base.player;
		player.setPlay(&.{}) catch |e| err(self, e);
	}

	pub inline fn extend() void {
		s_open = .gen("open");
		s_play = .gen("play");

		const class: *pd.Class = Self.class;
		class.addBang(@ptrCast(&bangC));
		class.addList(@ptrCast(&listC));
		class.addAnything(@ptrCast(&anythingC));
		class.addMethod(@ptrCast(&stopC), .gen("stop"), &.{});
		class.addMethod(@ptrCast(&seekC), .gen("seek"), &.{ .float });
		class.addMethod(@ptrCast(&sendC), .gen("send"), &.{ .symbol });
		class.addMethod(@ptrCast(&printC), .gen("print"), &.{ .gimme });
		class.addMethod(@ptrCast(&openC), s_open, &.{ .gimme });
		class.addMethod(@ptrCast(&playC), s_play, &.{ .gimme });
	}
};}
