//! An implementation of the Game Music Emu library.
//! Compatible formats include: AY, GBS, GYM, HES, KSS, NSF/NSFE, AP, SPC, RSN, VGM/VGZ.

const std = @import("std");
const pd = @import("pd");
const gm = @import("gme");
const arc = @import("player.arc.zig");
const pr = @import("player.zig");
const tx = @import("trax.zig");

const Atom = pd.Atom;
const Float = pd.Float;
const Sample = pd.Sample;
const Symbol = pd.Symbol;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Meta = tx.Meta;
const Arena = tx.Arena;

var s_mask: *Symbol = undefined;

const GmeInit = fn(*const gm.Type, c_uint) anyerror!*gm.Emu;
const ArcInit = arc.ArcReader.InitFn;

inline fn sampleRate(t: *const gm.Type) Float {
	return if (t == gm.gme_spc_type) 32000.0 else pd.sampleRate();
}

pub fn Base(nch: comptime_int, frames: comptime_int) type { return extern struct {
	player: pr.Player,
	/// array for storing signal buffer addresses
	outs: [nch][*]Sample = undefined,
	emu: *gm.Emu = undefined, // safe if player.open or player.play is true
	info: *gm.Info = undefined, // safe if player.open or player.play is true
	path: *Symbol,
	/// ratio between file samplerate and pd samplerate
	ratio: f64 = 1,
	langs: tx.LangSet = .{},
	/// short-to-float converted samples and resampler input
	ibuf: [nch * frames]Sample = undefined,
	/// resampler output
	obuf: [nch * frames]Sample = undefined,
	/// bit mask for muting channels
	mask: c_uint,
	/// samples directly from the emulator
	raw: [nch * frames]i16 = undefined,

	const Gme = @This();

	var dict: std.AutoHashMap(*Symbol, *const fn(*const Gme) *const Arena) = undefined;
	pub fn freeDict() void {
		dict.deinit();
	}

	pub fn get(self: *const Gme, trax: *const Meta, s: *Symbol) ?*const Arena {
		if (trax.get(s, self.langs.slice())) |arena| {
			return arena;
		}
		if (dict.get(s)) |func| {
			return func(self);
		}
		return null;
	}

	pub inline fn init(obj: *pd.Object, av: []const Atom) !Gme {
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
		self.langs.deinit(gpa);
		if (self.player.open) {
			self.info.deinit();
			self.emu.deinit();
		}
	}

	pub fn loadTrack(self: *Gme, index: usize) !void {
		const idx: c_uint = @truncate(index);
		try self.emu.startTrack(idx);
		const info = try self.emu.trackInfo(idx);
		self.info.deinit();
		self.info = info;
	}

	pub inline fn getTrax(self: *const Gme, gpa: Allocator, io: Io) Meta {
		self.player.assertFileOpened() catch return .{};
		return Meta.fromPath(gpa, io, self.path.name) catch Meta{} orelse .{};
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

		const initEmu: GmeInit = if (nch > 2) gm.emuMultiChannel else gm.emu;
		var arc_reader: ?arc.ArcReader = inline for (arc.types) |t| {
			const sig: u32 = t.signature;
			if (signature == sig) {
				break try @as(ArcInit, t.init)(gpa, io, path);
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
			const emu = try initEmu(t, @intFromFloat(srate));
			errdefer emu.deinit();
			if (t.trackCount() == 1) {
				try emu.loadTracks(buf.ptr, sizes[0..n]);
			} else {
				try emu.loadData(buf[0..sizes[0]]);
			}
			break :blk emu;
		} else {
			const t = try gm.Type.fromFile(path) orelse return error.FileNoMatch;
			srate = sampleRate(t);
			const emu = try initEmu(t, @intFromFloat(srate));
			errdefer emu.deinit();
			try emu.loadFile(path);
			break :blk emu;
		}};
		emu.ignoreSilence(true);
		emu.muteVoices(self.mask);
		const info = try emu.trackInfo(0); // throwaway, something to deinit

		// safe to delete the previous emulator
		if (self.player.open) {
			self.info.deinit();
			self.emu.deinit();
		}
		self.path = s;
		self.emu = emu;
		self.info = info;
		self.ratio = srate / pd.sampleRate();
		self.loadM3u(gpa, path) catch {};
	}

	/// Load a .m3u file with the same name as current file if it exists
	inline fn loadM3u(self: *Gme, gpa: Allocator, path: []const u8) !void {
		const ext = ".m3u";
		const end = std.mem.findScalarLast(u8, path, '.') orelse path.len;
		var ext_path = try gpa.allocSentinel(u8, end + ext.len, 0);
		defer gpa.free(ext_path);

		@memcpy(ext_path[0..end], path[0..end]);
		@memcpy(ext_path[end..][0..ext.len], ext);
		ext_path[ext_path.len] = 0;
		try self.emu.loadM3u(ext_path);
	}

	pub inline fn printAuto(self: *const Gme, trax: *const Meta, w: *Io.Writer) !void {
		// general track info: %artist% - %title%
		if (self.get(trax, .gen("game"))) |game| {
			try game.write(w);
			if (self.get(trax, .gen("song"))) |song| {
				try w.writeAll(" - ");
				try song.write(w);
			}
		} else if (self.get(trax, .gen("song"))) |song| {
			try song.write(w);
		}
	}

	pub fn seek(self: *Gme, msec: Float) !void {
		try self.emu.seekScaled(@intFromFloat(msec));
	}

	fn length(self: *const Gme) i64 {
		const ms = self.info.length;
		return if (ms >= 0) ms else blk: { // try intro + 2 loops
			const intro = self.info.intro_length;
			const loop = self.info.loop_length;
			break :blk if (intro < 0 and loop < 0)
				ms
			else @max(0, intro) + @max(0, 2 * loop);
		};
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
		const err: fn(*const Self, anyerror) callconv(.@"inline") void = Self.err;
		const gpa = Self.gpa;

		fn muteC(
			self: *Self,
			_: *Symbol, ac: c_uint, av: [*]const Atom,
		) callconv(.c) void {
			const gme: *Gme = &self.base;
			gme.mute(av[0..ac]);
			if (gme.player.open) {
				gme.emu.muteVoices(gme.mask);
			}
		}

		fn soloC(
			self: *Self,
			_: *Symbol, ac: c_uint, av: [*]const Atom,
		) callconv(.c) void {
			const gme: *Gme = &self.base;
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
			self: *Self,
			_: *Symbol, ac: c_uint, av: [*]const Atom,
		) callconv(.c) void {
			const gme: *Gme = &self.base;
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

		fn bMaskC(self: *Self) callconv(.c) void {
			const gme: *Gme = &self.base;
			var buf: [32:0]u8 = undefined;
			const voices: u6 = @truncate(gme.emu.voiceCount());
			for (0..voices) |i| {
				buf[i] = '0' + @as(u8, @truncate((gme.mask >> @truncate(i)) & 1));
			}
			buf[voices] = 0;
			pd.post.log(self, .normal, &buf, .{});
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
					err(self, e);
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

		fn langsC(
			self: *Self,
			_: *Symbol, ac: c_uint, args: [*]const pd.Atom,
		) callconv(.c) void {
			const base: *Gme = &self.base;
			base.langs.replaceWith(gpa, args[0..ac]) catch |e| err(self, e);
		}

		fn dspC(self: *Self, sp: [*]*pd.Signal) callconv(.c) void {
			const base: *Gme = &self.base;
			for (&base.outs, sp[2..][0..nch]) |*o, s| {
				o.* = s.vec;
			}
			pd.dsp.add(&performC, .{ self, sp[1].len, sp[1].vec, sp[0].vec });
		}

		pub inline fn extend() !void {
			s_mask = .gen("mask");

			dict = .init(gpa);
			errdefer dict.deinit();
			inline for ([_][:0]const u8{
				"path", "time", "ftime", "fade", "tracks", "voices",
				"system", "game", "song", "author", "copyright", "comment", "dumper",
			}) |field_name| {
				try dict.put(.gen(field_name.ptr), @field(meta, field_name));
			}

			const class: *pd.Class = Self.class;
			class.addMethod(@ptrCast(&muteC), .gen("mute"), &.{ .gimme });
			class.addMethod(@ptrCast(&soloC), .gen("solo"), &.{ .gimme });
			class.addMethod(@ptrCast(&langsC), .gen("langs"), &.{ .gimme });
			class.addMethod(@ptrCast(&maskC), s_mask, &.{ .gimme });
			class.addMethod(@ptrCast(&bMaskC), .gen("bmask"), &.{});
			class.addMethod(@ptrCast(&dspC), .gen("dsp"), &.{ .cant });
		}
	};}

	const meta = struct {
		fn path(self: *const Gme) *const Arena {
			return .string(std.mem.sliceTo(self.path.name, 0));
		}
		fn time(self: *const Gme) *const Arena {
			return .float(@floatFromInt(self.length()));
		}
		fn ftime(self: *const Gme) *const Arena {
			const ts = pr.timeSym(self.length());
			return .string(std.mem.sliceTo(ts.name, 0));
		}
		fn fade(self: *const Gme) *const Arena {
			return .float(@floatFromInt(self.info.fade_length));
		}
		fn tracks(self: *const Gme) *const Arena {
			return .float(@floatFromInt(self.emu.trackCount()));
		}
		fn voices(self: *const Gme) *const Arena {
			return .float(@floatFromInt(self.emu.voiceCount()));
		}
		fn system(self: *const Gme) *const Arena {
			return .string(std.mem.sliceTo(self.info.system, 0));
		}
		fn game(self: *const Gme) *const Arena {
			return .string(std.mem.sliceTo(self.info.game, 0));
		}
		fn song(self: *const Gme) *const Arena {
			return .string(std.mem.sliceTo(self.info.song, 0));
		}
		fn author(self: *const Gme) *const Arena {
			return .string(std.mem.sliceTo(self.info.author, 0));
		}
		fn copyright(self: *const Gme) *const Arena {
			return .string(std.mem.sliceTo(self.info.copyright, 0));
		}
		fn comment(self: *const Gme) *const Arena {
			return .string(std.mem.sliceTo(self.info.comment, 0));
		}
		fn dumper(self: *const Gme) *const Arena {
			return .string(std.mem.sliceTo(self.info.dumper, 0));
		}
	};
};}
