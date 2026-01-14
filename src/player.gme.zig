const std = @import("std");
const pd = @import("pd");
const gm = @import("gme");
const arc = @import("player.arc.zig");
const pr = @import("player.zig");

const Atom = pd.Atom;
const Float = pd.Float;
const Sample = pd.Sample;
const Symbol = pd.Symbol;

var s_mask: *Symbol = undefined;

const GmeInit = fn(*const gm.Type, c_uint) anyerror!*gm.Emu;
const ArcInit = fn (std.mem.Allocator, [:0]const u8) anyerror!arc.ArcReader;

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
	/// short-to-float converted samples and resampler input
	ibuf: [nch * frames]Sample = undefined,
	/// resampler output
	obuf: [nch * frames]Sample = undefined,
	mask: c_uint,
	/// samples directly from the emulator
	raw: [nch * frames]i16 = undefined,

	const Gme = @This();

	var dict: std.AutoHashMap(*Symbol, *const fn(*const Gme) Atom) = undefined;
	pub fn freeDict() void {
		dict.deinit();
	}

	pub fn get(self: *const Gme, s: *Symbol) ?Atom {
		const a = (dict.get(s) orelse return null)(self);
		return if (a.type == .symbol and a.w.symbol == &pd.s_) null else a;
	}

	pub inline fn init(obj: *pd.Object, av: []const Atom) !Gme {
		inline for (0..nch) |_| {
			_ = try obj.outlet(&pd.s_signal);
		}
		return .{
			.player = try .init(obj),
			.path = &pd.s_,
			.mask = for (av) |a| {
				if (a.type == .float) {
					break @intFromFloat(a.w.float);
				}
			} else 0,
		};
	}

	pub inline fn deinit(self: *Gme) void {
		if (self.player.open) {
			self.info.deinit();
			self.emu.deinit();
		}
	}

	/// Gme often sets a new fade-out on seeks and track changes.
	/// We want to play tracks forever and handle fade-out at the patch level.
	inline fn playForever(emu: *gm.Emu) void {
		emu.setFade(-1, 0);
	}

	pub fn loadTrack(self: *Gme, index: usize) !void {
		const idx: c_uint = @intCast(index);
		try self.emu.startTrack(idx);
		playForever(self.emu);
		const info = try self.emu.trackInfo(idx);
		self.info.deinit();
		self.info = info;
	}

	pub inline fn open(self: *Gme, av: []const Atom) !void {
		const s = try pd.symbolArg(0, av);
		const path = std.mem.sliceTo(s.name, 0);
		const signature: u32 = blk: {
			var file = try std.fs.cwd().openFile(path, .{});
			defer file.close();
			var sig_buf: [4]u8 = undefined;
			var reader = file.reader(&sig_buf);
			break :blk @bitCast((try reader.interface.take(4))[0..4].*);
		};

		const initEmu: GmeInit = if (nch > 2) gm.emuMultiChannel else gm.emu;
		var arc_reader: ?arc.ArcReader = inline for (arc.types) |t| {
			const sig: u32 = t.signature;
			if (signature == sig) {
				const initArc: ArcInit = t.init;
				break try initArc(pd.mem, path);
			}
		} else null;

		var srate: Float = undefined;
		const emu: *gm.Emu = blk: { if (arc_reader) |*ar| {
			defer ar.close();
			const sizes = try pd.mem.alloc(c_ulong, ar.count);
			defer pd.mem.free(sizes);
			const buf = try pd.mem.alloc(u8, ar.size);
			defer pd.mem.free(buf);

			var bp = buf;
			var n: u32 = 0;
			var emu_type: ?*const gm.Type = null;
			while (try ar.next(bp)) |entry| {
				const t = gm.Type.fromExtension(entry.name) orelse continue;
				if (emu_type == null) {
					emu_type = t;
				}
				if (emu_type == t) {
					sizes[n] = @intCast(entry.size);
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

		self.deinit(); // safe to delete the previous emulator
		self.path = s;
		self.emu = emu;
		self.info = info;
		self.ratio = srate / pd.sampleRate();
		self.loadM3u(path) catch {};
	}

	/// Load a .m3u file with the same name as current file if it exists
	inline fn loadM3u(self: *Gme, path: []const u8) !void {
		const ext = ".m3u";
		const end = std.mem.lastIndexOf(u8, path, ".") orelse path.len;
		var ext_path = try pd.mem.allocSentinel(u8, end + ext.len, 0);
		defer pd.mem.free(ext_path);

		@memcpy(ext_path[0..end], path[0..end]);
		@memcpy(ext_path[end..][0..ext.len], ext);
		ext_path[ext_path.len] = 0;
		try self.emu.loadM3u(ext_path);
	}

	pub inline fn printAuto(self: *const Gme, writer: *std.Io.Writer) !void {
		// general track info: %game% - %song%
		const info = self.info;
		if (info.game[0] != 0) {
			try writer.print("{s}", .{ info.game });
			if (info.song[0] != 0) {
				try writer.print(" - {s}", .{ info.song });
			}
		} else if (info.song[0] != 0) {
			try writer.print("{s}", .{ info.song });
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
			break :blk if (intro < 0 and loop < 0) ms
				else @max(0, intro) + @max(0, 2 * loop);
		};
	}

	pub inline fn trackCount(self: *const Gme) usize {
		return self.emu.trackCount();
	}

	fn mute(self: *Gme, av: []const Atom) void {
		for (av) |*a| {
			self.mask = if (a.type == .symbol) // mute all channels
				(@as(c_uint, 1) << @intCast(self.emu.voiceCount())) - 1
			else blk: {
				var d: c_int = @intFromFloat(a.w.float);
				if (d == 0) { // unmute all channels
					break :blk 0;
				}
				d -= if (d > 0) 1 else 0;
				// toggle the bit at i position
				const i = @mod(d, @as(c_int, @intCast(self.emu.voiceCount())));
				break :blk self.mask ^ (@as(c_uint, 1) << @intCast(i));
			};
		}
	}

	pub fn Impl(Self: type) type { return struct {
		const perform: fn(*Self, [*]usize, *u32) callconv(.@"inline") anyerror!void
			= Self.perform;
		const err: fn(*const Self, anyerror) callconv(.@"inline") void = Self.err;

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
			gme.mask = (@as(u32, 1) << @intCast(gme.emu.voiceCount())) - 1;
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
			const voices: u6 = @intCast(gme.emu.voiceCount());
			for (0..voices) |i| {
				buf[i] = '0' + @as(u8, @intCast((gme.mask >> @intCast(i)) & 1));
			}
			buf[voices] = 0;
			pd.post.log(self, .normal, "%s", .{ &buf });
		}

		fn performC(w: [*]usize) callconv(.c) [*]usize {
			const self: *Self = @ptrFromInt(w[1]);
			const base: *Gme = &self.base;
			const player: *pr.Player = &base.player;
			if (player.play) {
				var i: u32 = undefined;
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

		fn dspC(self: *Self, sp: [*]*pd.Signal) callconv(.c) void {
			const base: *Gme = &self.base;
			for (&base.outs, sp[2..][0..nch]) |*o, s| {
				o.* = s.vec;
			}
			pd.dsp.add(&performC, .{ self, sp[1].len, sp[1].vec, sp[0].vec });
		}

		pub inline fn extend() !void {
			s_mask = .gen("mask");

			dict = .init(pd.mem);
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
			class.addMethod(@ptrCast(&maskC), s_mask, &.{ .gimme });
			class.addMethod(@ptrCast(&bMaskC), .gen("bmask"), &.{});
			class.addMethod(@ptrCast(&dspC), .gen("dsp"), &.{ .cant });
		}
	};}

	const meta = struct {
		fn path(self: *const Gme) Atom {
			return .symbol(self.path);
		}
		fn time(self: *const Gme) Atom {
			return .float(@floatFromInt(self.length()));
		}
		fn ftime(self: *const Gme) Atom {
			return .symbol(pr.timeSym(self.length()));
		}
		fn fade(self: *const Gme) Atom {
			return .float(@floatFromInt(self.info.fade_length));
		}
		fn tracks(self: *const Gme) Atom {
			return .float(@floatFromInt(self.emu.trackCount()));
		}
		fn voices(self: *const Gme) Atom {
			return .float(@floatFromInt(self.emu.voiceCount()));
		}
		fn system(self: *const Gme) Atom {
			return .symbol(.gen(self.info.system));
		}
		fn game(self: *const Gme) Atom {
			return .symbol(.gen(self.info.game));
		}
		fn song(self: *const Gme) Atom {
			return .symbol(.gen(self.info.song));
		}
		fn author(self: *const Gme) Atom {
			return .symbol(.gen(self.info.author));
		}
		fn copyright(self: *const Gme) Atom {
			return .symbol(.gen(self.info.copyright));
		}
		fn comment(self: *const Gme) Atom {
			return .symbol(.gen(self.info.comment));
		}
		fn dumper(self: *const Gme) Atom {
			return .symbol(.gen(self.info.dumper));
		}
	};
};}
