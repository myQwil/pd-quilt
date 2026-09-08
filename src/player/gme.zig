//! An implementation of the Game Music Emu library.
//! Compatible formats include: AY, GBS, GYM, HES, KSS, NSF/NSFE, AP, SPC, RSN, VGM/VGZ.

const pd = @import("pd");
const gm = @import("gme");
const std = @import("std");
const arc = @import("arc.zig");
const pr = @import("player.zig");
const tx = @import("../trax/trax.zig");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Float = pd.Float;
const Sample = pd.Sample;
const Symbol = pd.Symbol;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Meta = tx.Meta;
const Pile = tx.Pile;

var s_mask: *Symbol = undefined;

const EmuCreateFn = fn(*const gm.Type, c_uint) anyerror!*gm.Emu;
const ArcInitFn = arc.ArcReader.InitFn;

inline fn sampleRate(t: *const gm.Type) Float {
	return if (t == gm.gme_spc_type) 32000.0 else pd.sampleRate();
}

pub fn Base(nch: comptime_int, frames: comptime_int) type { return struct {
	player: pr.Player,
	/// array for storing signal buffer addresses
	outs: [nch][*]Sample = undefined,
	/// emulator for currently opened file
	emu: *gm.Emu = undefined, // safe if player.open or player.play is true
	/// path of currently opened file
	path: *Symbol,
	/// ratio between file samplerate and pd samplerate
	ratio: f64 = 1,
	/// short-to-float converted samples and resampler input
	ibuf: [nch * frames]Sample = undefined,
	/// resampler output
	obuf: [nch * frames]Sample = undefined,
	/// bit mask for muting channels
	mask: c_uint,
	/// samples directly from the emulator
	raw: [nch * frames]i16 = undefined,
	track_length: c_int = -1,
	intro_length: c_int = -1,
	loop_length: c_int = -1,
	fade_length: c_int = -1,

	const Gme = @This();

	pub var dict: std.AutoHashMapUnmanaged(*Symbol, *const fn(*const Gme) *const Pile)
		= .empty;
	pub fn freeDict(gpa: Allocator) void {
		dict.deinit(gpa);
	}

	pub inline fn init(obj: *pd.Object, av: []const Atom) pd.Oom!Gme {
		inline for (0..nch) |_| {
			_ = try obj.outlet(pd.s.signal());
		}
		return .{
			.player = try .init(obj),
			.path = pd.s.empty(),
			.mask = for (av) |a| {
				if (a.type == .float) {
					break @intFromFloat(a.w.float);
				}
			} else 0,
		};
	}

	pub inline fn deinit(self: *Gme, gpa: Allocator) void {
		self.player.deinit(gpa);
		if (self.player.open) {
			self.emu.destroy();
		}
	}

	pub fn loadTrack(self: *Gme, gpa: Allocator, io: Io, index: usize) gm.Error!void {
		const idx: c_uint = @truncate(index);
		try self.emu.startTrack(idx);
		self.loadMetadata(gpa, io, idx)
			catch |e| pd.post.err(null, "Gme.loadMetadata: %s", .{ @errorName(e).ptr });
	}

	inline fn loadMetadata(self: *Gme, gpa: Allocator, io: Io, idx: c_uint) !void {
		self.player.meta.deinit(gpa);
		self.player.meta = .{};

		const info = try self.emu.trackInfo(idx);
		defer info.destroy();
		self.track_length = info.length;
		self.intro_length = info.intro_length;
		self.loop_length = info.loop_length;
		self.fade_length = info.fade_length;

		const ch = self.player.chaps;
		var meta: tx.Meta = if (idx < ch.tbl.items.len) switch (ch.tbl.items[idx].typ) {
			.bare => .{},
			.trax => try .fromPath(gpa, io, ch.get(idx)),
			.title => blk: {
				var meta: tx.Meta = .{};
				_ = try tx.putGet(
					&meta.data, gpa, .gen("song"), pd.s.empty(), ch.get(idx), false);
				break :blk meta;
			},
		} else .{};
		errdefer meta.deinit(gpa);
		inline for ([_][:0]const u8{
			"system", "game", "song", "author", "copyright", "comment", "dumper",
		}) |field| {
			if (!meta.data.contains(.gen(field))) {
				const name = std.mem.sliceTo(@field(info, field), 0);
				_ = try tx.putGet(&meta.data, gpa, .gen(field), pd.s.empty(), name, false);
			} 
		}
		self.player.meta = meta;
	}

	pub inline fn open(self: *Gme, gpa: Allocator, io: Io, av: []const Atom) !void {
		const s = try pd.symbolArg(0, av);
		const path = std.mem.sliceTo(s.name, 0);
		const signature: u32 = blk: {
			var file = try Io.Dir.cwd().openFile(io, path, .{});
			defer file.close(io);
			var sig_buf: [4]u8 = undefined;
			var reader = file.reader(io, &sig_buf);
			break :blk @bitCast((try reader.interface.take(4))[0..4].*);
		};

		const createEmu: EmuCreateFn = if (nch > 2)
			gm.Emu.createMultiChannel
		else gm.Emu.create;
		var arc_reader: ?arc.ArcReader = inline for (arc.types) |t| {
			const sig: u32 = t.signature;
			if (signature == sig) {
				break try @as(ArcInitFn, t.init)(gpa, io, path);
			}
		} else null;

		var srate: Float = undefined;
		const emu: *gm.Emu = blk: { if (arc_reader) |*ar| {
			defer ar.close();
			const sizes = try gpa.alloc(c_ulong, ar.count);
			defer gpa.free(sizes);
			const buf = try gpa.alloc(u8, ar.size);
			defer gpa.free(buf);

			var bp = buf;
			var n: u32 = 0;
			var emu_type: ?*const gm.Type = null;
			while (try ar.next(bp)) |entry| {
				const t = gm.Type.fromExtension(entry.name) orelse continue;
				if (emu_type == null) {
					emu_type = t;
				}
				if (emu_type == t) {
					sizes[n] = @truncate(entry.size);
					bp = bp[sizes[n]..];
					n += 1;
				}
			}

			const t = emu_type orelse return error.ArchiveNoMatch;
			srate = sampleRate(t);
			const emu = try createEmu(t, @intFromFloat(srate));
			errdefer emu.destroy();
			if (t.trackCount() == 1) {
				try emu.loadTracks(buf.ptr, sizes[0..n]);
			} else {
				try emu.loadData(buf[0..sizes[0]]);
			}
			break :blk emu;
		} else {
			const t = try gm.Type.fromFile(path) orelse return error.FileNoMatch;
			srate = sampleRate(t);
			const emu = try createEmu(t, @intFromFloat(srate));
			errdefer emu.destroy();
			try emu.loadFile(path);
			break :blk emu;
		}};
		emu.ignoreSilence(true);
		emu.muteVoices(self.mask);

		// safe to delete the previous emulator
		if (self.player.open) {
			self.emu.destroy();
		}
		self.path = s;
		self.emu = emu;
		self.ratio = srate / pd.sampleRate();
		self.loadChapters(gpa, io, path)
			catch |e| pd.post.err(null, "Gme.loadChapters: %s", .{ @errorName(e).ptr });
	}

	inline fn loadChapters(self: *Gme, gpa: Allocator, io: Io, path: []const u8) !void {
		// load a .trax sidecar
		self.player.chaps.deinit(gpa);
		self.player.chaps = try .fromPath(gpa, io, self.path.name);

		// load a .m3u sidecar
		const ext = ".m3u";
		const end = std.mem.findScalarLast(u8, path, '.') orelse path.len;
		var ext_path = try gpa.allocSentinel(u8, end + ext.len, 0);
		defer gpa.free(ext_path);

		@memcpy(ext_path[0..end], path[0..end]);
		@memcpy(ext_path[end..][0..ext.len], ext);
		ext_path[ext_path.len] = 0;
		self.emu.loadM3u(ext_path) catch {};
	}

	pub inline fn printAuto(self: *const Gme, w: *Io.Writer) Io.Writer.Error!void {
		try self.player.printAuto(w, "game", "song");
	}

	pub fn seek(self: *Gme, msec: Float) gm.Error!void {
		try self.emu.seekScaled(@intFromFloat(msec));
	}

	fn length(self: *const Gme) i64 {
		return if (self.track_length >= 0)
			self.track_length
		else if (self.intro_length < 0 and self.loop_length < 0)
			-1 // decide a length at the patch level
		else // intro + 2 loops
			@max(0, self.intro_length) + @max(0, 2 * self.loop_length);
	}

	pub inline fn trackCount(self: *const Gme) usize {
		return self.emu.trackCount();
	}

	fn mute(self: *Gme, av: []const Atom) void {
		for (av) |*a| {
			self.mask = if (a.type == .symbol) // mute all channels
				(@as(c_uint, 1) << @truncate(self.emu.voiceCount())) - 1
			else blk: {
				var d: c_int = @intFromFloat(a.w.float);
				if (d == 0) { // unmute all channels
					break :blk 0;
				}
				d -= if (d > 0) 1 else 0;
				// toggle the bit at i position
				break :blk self.mask ^ (@as(c_uint, 1) << pos: {
					const i = @mod(d, @as(pd.uint, @truncate(self.emu.voiceCount())));
					break :pos @truncate(@as(c_uint, @bitCast(i)));
				});
			};
		}
	}

	pub fn Impl(Self: type) type { return struct {
		const perform: fn(*Self, [*]usize, *usize) callconv(.@"inline") anyerror!void
			= Self.perform;
		const err: fn(*const Pd, anyerror) callconv(.@"inline") void = Self.err;
		const gpa = Self.gpa;
		const Box = Self.Box;

		fn muteC(
			p: *Pd,
			_: *Symbol, ac: c_uint, av: [*]const Atom,
		) callconv(.c) void {
			const gme: *Gme = &Box.state(p).base;
			gme.mute(av[0..ac]);
			if (gme.player.open) {
				gme.emu.muteVoices(gme.mask);
			}
		}

		fn soloC(
			p: *Pd,
			_: *Symbol, ac: c_uint, av: [*]const Atom,
		) callconv(.c) void {
			const gme: *Gme = &Box.state(p).base;
			const prev = gme.mask;
			gme.mask = (@as(c_uint, 1) << @truncate(gme.emu.voiceCount())) - 1;
			gme.mute(av[0..ac]);
			if (prev == gme.mask) {
				gme.mask = 0;
			}
			if (gme.player.open) {
				gme.emu.muteVoices(gme.mask);
			}
		}

		fn maskC(
			p: *Pd,
			_: *Symbol, ac: c_uint, av: [*]const Atom,
		) callconv(.c) void {
			const gme: *Gme = &Box.state(p).base;
			if (ac > 0 and av[0].type == .float) {
				// set
				gme.mask = @intFromFloat(av[0].w.float);
				if (gme.player.open) {
					gme.emu.muteVoices(gme.mask);
				}
			} else {
				// get
				gme.player.outlet.anything(s_mask, &.{ .float(@floatFromInt(gme.mask)) });
			}
		}

		fn bMaskC(p: *Pd) callconv(.c) void {
			const self = Box.state(p);
			const gme: *Gme = &self.base;
			var buf: [32:0]u8 = undefined;
			const voices: u6 = @truncate(gme.emu.voiceCount());
			for (0..voices) |i| {
				buf[i] = '0' + @as(u8, @truncate((gme.mask >> @truncate(i)) & 1));
			}
			buf[voices] = 0;
			pd.post.log(p, .normal, &buf, .{});
		}

		fn performC(w: [*]usize) callconv(.c) [*]usize {
			const self: *Self = @ptrFromInt(w[1]);
			const base: *Gme = &self.base;
			const player: *pr.Player = &base.player;
			if (player.play) {
				var i: usize = undefined;
				perform(self, w, &i) catch |e| {
					player.play = false;
					player.sendState(pr.s_play, player.play);
					err(@ptrFromInt(@intFromPtr(self) - @offsetOf(Box, "body")), e);
					inline for (base.outs[0..nch]) |ch| {
						@memset(ch[i..w[2]], 0);
					}
				};
			} else {
				inline for (base.outs[0..nch]) |ch| {
					@memset(ch[0..w[2]], 0);
				}
			}
			return w + 5;
		}

		fn dspC(p: *Pd, sp: [*]*pd.Signal) callconv(.c) void {
			const self = Box.state(p);
			const base: *Gme = &self.base;
			for (&base.outs, sp[2..][0..nch]) |*o, s| {
				o.* = s.vec;
			}
			pd.dsp.add(performC, .{ self, sp[1].len, sp[1].vec, sp[0].vec });
		}

		pub inline fn extend() Allocator.Error!void {
			s_mask = .gen("mask");

			errdefer dict.deinit(gpa);
			inline for ([_][:0]const u8{
				"path", "time", "ftime", "fade", "tracks", "voices",
			}) |field_name| {
				try dict.put(gpa, .gen(field_name.ptr), @field(dispatch, field_name));
			}

			const class: *pd.Class = Self.class;
			class.addMethod(&.{ .gimme }, muteC, .gen("mute"));
			class.addMethod(&.{ .gimme }, soloC, .gen("solo"));
			class.addMethod(&.{ .gimme }, maskC, s_mask);
			class.addMethod(&.{}, bMaskC, .gen("bmask"));
			class.addMethod(&.{ .cant }, dspC, .gen("dsp"));
		}
	};}

	const dispatch = struct {
		fn path(self: *const Gme) *const Pile {
			return .string(std.mem.sliceTo(self.path.name, 0));
		}
		fn time(self: *const Gme) *const Pile {
			return .float(@floatFromInt(self.length()));
		}
		fn ftime(self: *const Gme) *const Pile {
			const ts = pr.timeSym(self.length());
			return .string(std.mem.sliceTo(ts.name, 0));
		}
		fn fade(self: *const Gme) *const Pile {
			return .float(@floatFromInt(self.fade_length));
		}
		fn tracks(self: *const Gme) *const Pile {
			return .float(@floatFromInt(self.emu.trackCount()));
		}
		fn voices(self: *const Gme) *const Pile {
			return .float(@floatFromInt(self.emu.voiceCount()));
		}
	};
};}
