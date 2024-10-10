const rt = @import("root");
const std = @import("std");
const gme = @import("gme");
const pd = @import("pd");
const pr = @import("player.zig");
const rb = @import("rabbit.zig");
const arc = @import("arc.zig");
var s_mask: *pd.Symbol = undefined;

fn identifyArchive(path: []const u8) ?*const arc.Reader {
	var file = std.fs.cwd().openFile(path, .{}) catch return null;
	defer file.close();

	var buffered = std.io.bufferedReader(file.reader());
	const reader = buffered.reader();
	const buf = reader.readBytesNoEof(4) catch return null;
	const h = arc.fourChar(buf);
	for (arc.types) |t| {
		if (h == t.head) {
			return t.reader;
		}
	}
	return null;
}

pub const Gme = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	base: pr.Player,
	rabt: rb.Rabbit,
	raw: [rt.nch * rb.frames]i16,
	in: [rt.nch * rb.frames]pd.Sample, // input buffer
	out: [rt.nch * rb.frames]pd.Sample, // output buffer
	outs: [rt.nch][*]pd.Sample, // outlets
	emu: *gme.Emu, // safe if open or play is true
	info: *gme.Info, // safe if open or play is true
	path: *pd.Symbol,
	speed: *pd.Float,
	tempo: *pd.Float,
	mask: u32,
	voices: u32,

	fn err(self: ?*Self, e: anyerror) void {
		pd.post.err(self, "%s", @errorName(e).ptr);
	}

	fn reset(self: *Self) void {
		self.emu.setFade(-1, 0);
		self.rabt.reset() catch |e| self.err(e);
	}

	fn seek(self: *Self, f: pd.Float) void {
		if (!self.base.open) {
			return;
		}
		self.emu.seek(@intFromFloat(f)) catch |e| self.err(e);
		self.reset();
	}

	fn setSpeed(self: *Self, f: pd.Float) void {
		self.speed.* = f;
	}

	fn setTempo(self: *Self, f: pd.Float) void {
		self.tempo.* = f;
	}

	fn conv(self: *Self, f: pd.Float) void {
		self.rabt.setConverter(@intFromFloat(f), rt.nch) catch |e| self.err(e);
	}

	fn perform(w: [*]usize) *usize {
		const self: *Self = @ptrFromInt(w[1]);
		const outs = self.outs;
		const n = w[2];

		if (!self.base.play) {
			for (0..rt.nch) |c| {
				@memset(outs[c][0..n], 0);
			}
			return &w[5];
		}
		const emu = self.emu;
		const data = &self.rabt.data;
		const inlet2: [*]pd.Sample = @ptrFromInt(w[3]);
		const inlet1: [*]pd.Sample = @ptrFromInt(w[4]);
		for (0..n, inlet1, inlet2) |i, in1, in2| {
			while (data.out_frames_gen <= 0) {
				if (data.in_frames <= 0) {
					emu.setTempo(in2);
					emu.play(&self.raw) catch |e| self.err(e);
					for (&self.in, &self.raw) |*in, *raw| {
						in.* = @as(pd.Sample, @floatFromInt(raw.*)) * 0x1p-15;
					}
					data.in = &self.in;
					data.in_frames = rb.frames;
				}
				data.out = &self.out;
				self.rabt.setSpeed(in1);
				self.rabt.state.process(data) catch |e| self.err(e);
				data.in_frames -= data.in_frames_used;
				data.in += @as(usize, @intCast(data.in_frames_used)) * rt.nch;
			}
			for (0..rt.nch) |c| {
				outs[c][i] = data.out[c];
			}
			data.out += rt.nch;
			data.out_frames_gen -= 1;
		}
		return &w[5];
	}

	fn dsp(self: *Self, sp: [*]*pd.Signal) void {
		for (&self.outs, sp[2 .. 2 + rt.nch]) |*o, s| {
			o.* = s.vec;
		}
		pd.dsp.add(@ptrCast(&perform), 4, self, sp[1].len, sp[1].vec, sp[0].vec);
	}

	fn doMute(self: *Self, av: []const pd.Atom) void {
		const voices: i32 = @intCast(self.voices);
		for (av) |*a| {
			switch (a.type) {
				.float => {
					const d: i32 = @intFromFloat(a.w.float);
					if (d == 0) {
						self.mask = 0; // unmute all channels
						continue;
					}
					self.mask ^= @as(u32, 1) // toggle the bit at d position
						<< @intCast(@mod(d - @intFromBool(d > 0), voices));
				},
				else => { // symbol, mute all channels
					self.mask = (@as(u32, 1) << @intCast(self.voices)) - 1;
				},
			}
		}
	}

	fn mute(self: *Self, _: ?*pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		self.doMute(av[0..ac]);
		if (self.base.open) {
			self.emu.muteVoices(self.mask);
		}
	}

	fn solo(self: *Self, _: ?*pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		const prev = self.mask;
		self.mask = (@as(u32, 1) << @intCast(self.voices)) - 1;
		self.doMute(av[0..ac]);
		if (prev == self.mask) {
			self.mask = 0;
		}
		if (self.base.open) {
			self.emu.muteVoices(self.mask);
		}
	}

	fn doMask(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		if (ac > 0 and av[0].type == .float) { // set
			self.mask = @intFromFloat(av[0].w.float);
			if (self.base.open) {
				self.emu.muteVoices(self.mask);
			}
		} else { // get
			var flt = [1]pd.Atom{.{ .type = .float,
				.w = .{ .float = @floatFromInt(self.mask) } }};
			self.base.o_meta.anything(s_mask, 1, &flt);
		}
	}

	fn bMask(self: *Self) void {
		var buf: [32:0]u8 = undefined;
		for (0..self.voices) |i| {
			buf[i] = '0' + @as(u8, @intCast((self.mask >> @intCast(i)) & 1));
		}
		buf[self.voices] = '\x00';
		pd.post.log(self, .normal, &buf);
	}

	fn sampleRate(self: *Self, t: *const gme.Type) i32 {
		const pd_srate = pd.sampleRate();
		const srate = if (t == gme.gme_spc_type) 32000.0 else pd_srate;
		self.rabt.ratio = srate / pd_srate;
		return @intFromFloat(srate);
	}

	fn tryLoad(self: *Self, index: u32) !void {
		try self.emu.startTrack(index);
		const info = try self.emu.trackInfo(index);
		self.info.free();
		self.info = info;
		self.reset();
	}

	fn tryOpen(self: *Self, s: *pd.Symbol) !void {
		const prev_emu = self.emu;

		const path = s.name[0..std.mem.len(s.name)];
		const new_fn: *const fn(*const gme.Type, i32) gme.Error!*gme.Emu
			= if (rt.nch > 2) gme.Type.emuMultiChannel else gme.Type.emu;
		if (identifyArchive(path)) |reader| {
			try reader.open(s.name, false);
			defer reader.close();
			const sizes = try pd.mem.alloc(usize, reader.count());
			defer pd.mem.free(sizes);
			const buf = try pd.mem.alloc(u8, reader.size());
			defer pd.mem.free(buf);

			var bp = buf.ptr;
			var n: u32 = 0;
			var emu_type: ?*const gme.Type = null;
			while (try reader.next()) {
				try reader.read(bp);
				if (gme.Type.fromExtension(reader.entryName())) |t| {
					if (t.trackCount() == 1) {
						if (emu_type == null)
							emu_type = t;
						if (emu_type == t) {
							sizes[n] = reader.entrySize();
							bp += sizes[n];
							n += 1;
						}
					}
				}
			}

			const t = emu_type orelse return error.ArchiveNoMatch;
			self.emu = try new_fn(t, self.sampleRate(t));
			errdefer { self.emu.delete(); self.emu = prev_emu; }
			try self.emu.loadTracks(buf.ptr, sizes[0..n]);
		} else {
			const t = try gme.Type.fromFile(s.name) orelse return error.FileNoMatch;
			self.emu = try new_fn(t, self.sampleRate(t));
			errdefer { self.emu.delete(); self.emu = prev_emu; }
			try self.emu.loadFile(s.name);
		}

		self.emu.ignoreSilence(true);
		self.emu.muteVoices(self.mask);
		self.emu.setTempo(self.tempo.*);
		try self.tryLoad(0);

		// safe to delete the previous emulator
		prev_emu.delete();

		// check for a .m3u file of the same name
		const buf_size = 259;
		var m3u_path: [buf_size:0]u8 = undefined;
		const sym = s.name[0..std.mem.len(s.name)];
		const i = @min(buf_size, std.mem.lastIndexOf(u8, sym, ".") orelse sym.len);
		if (buf_size - i >= 4) {
			@memcpy(m3u_path[0..i], s.name[0..i]);
			@memcpy(m3u_path[i..i+4], ".m3u");
			m3u_path[i+4] = '\x00';
			self.emu.loadM3u(&m3u_path) catch {};
		}

		self.path = s;
		self.base.open = true;
		self.base.play = false;
		self.voices = self.emu.voiceCount();

		var atom = [1]pd.Atom{.{ .type = .float,
			.w = .{.float = @floatFromInt(@intFromBool(self.base.open))} }};
		self.base.o_meta.anything(pr.s_open, atom.len, &atom);
	}

	fn open(self: *Self, s: *pd.Symbol) void {
		self.tryOpen(s) catch |e| self.err(e);
	}

	fn length(self: *Self) pd.Float {
		const f: pd.Float = @floatFromInt(self.info.length);
		return if (f >= 0) f else blk: { // try intro + 2 loops
			const intro = self.info.intro_length;
			const loop = self.info.loop_length;
			break :blk if (intro < 0 and loop < 0) f else @floatFromInt(
				@max(0, intro) + @max(0, 2 * loop));
		};
	}

	fn tryPrint(self: *Self, av: []const pd.Atom) !void {
		if (!self.base.open)
			return error.NoFileOpened;
		if (av.len > 0)
			return try self.base.print(av);

		// general track info: %game% - %song%
		const info = self.info;
		if (info.game[0] != '\x00') {
			pd.post.start("%s", info.game);
			if (info.song[0] != '\x00') {
				pd.post.start(" - %s", info.song);
			}
			pd.post.end();
		} else if (info.song[0] != '\x00') {
			pd.post.do("%s", info.song);
		}
	}

	fn print(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		self.tryPrint(av[0..ac]) catch |e| self.err(e);
	}

	fn tryFloat(self: *Self, f: pd.Float) !bool {
		if (!self.base.open) {
			return error.NoFileOpened;
		}
		const track: i32 = @intFromFloat(f);
		if (0 < track and track <= self.emu.trackCount()) {
			try self.tryLoad(@intCast(track - 1));
			return true;
		}
		self.seek(0);
		return false;
	}

	fn float(self: *Self, f: pd.Float) void {
		self.base.play = self.tryFloat(f) catch |e| blk: {
			self.err(e);
			break :blk false;
		};
		var play = [1]pd.Atom{.{ .type = .float, .w = .{
			.float = @floatFromInt(@intFromBool(self.base.play)) } }};
		self.base.o_meta.anything(pr.s_play, 1, &play);
	}

	fn stop(self: *Self) void {
		self.float(0);
	}

	fn tryNew(av: []const pd.Atom) !*Self {
		const self: *Self = @ptrCast(pr.Player.new(class, rt.nch)
			orelse return error.NoSetup);
		errdefer @as(*pd.Pd, @ptrCast(self)).free();
		try self.rabt.init(rt.nch);
		errdefer self.rabt.state.delete();

		const obj = &self.base.obj;
		const in2 = obj.inletSignal(1).?;
		self.speed = &in2.un.floatsignalvalue;
		const in3 = obj.inletSignal(1).?;
		self.tempo = &in3.un.floatsignalvalue;

		self.mask = 0;
		self.voices = 16;
		self.path = pd.s._;
		if (av.len > 0) {
			self.solo(null, @intCast(av.len), av.ptr);
		}
		return self;
	}

	fn new(_: *pd.Symbol, ac: u32, av: [*]const pd.Atom) ?*Self {
		return tryNew(av[0..ac]) catch |e| blk: {
			err(null, e);
			break :blk null;
		};
	}

	fn free(self: *Self) void {
		self.info.free();
		self.emu.delete();
		self.rabt.state.delete();
	}

	pub fn setup(s: *pd.Symbol) void {
		const dict = &pr.dict;
		inline for ([_][:0]const u8{
			"path", "time", "ftime", "fade", "tracks", "voices",
			"system", "game", "song", "author", "copyright", "comment", "dumper",
		}) |meta| {
			dict.put(pd.symbol(meta.ptr), @field(Dict, meta)) catch {};
		}
		s_mask = pd.symbol("mask");
		class = pr.Player.class(s, @ptrCast(&new), @ptrCast(&free), @sizeOf(Self));
		class.addFloat(@ptrCast(&float));
		class.addMethod(@ptrCast(&dsp), pd.symbol("dsp"), &.{ .cant });
		class.addMethod(@ptrCast(&conv), pd.symbol("conv"), &.{ .float });
		class.addMethod(@ptrCast(&seek), pd.symbol("seek"), &.{ .float });
		class.addMethod(@ptrCast(&setSpeed), pd.symbol("speed"), &.{ .float });
		class.addMethod(@ptrCast(&setTempo), pd.symbol("tempo"), &.{ .float });
		class.addMethod(@ptrCast(&print), pd.symbol("print"), &.{ .gimme });
		class.addMethod(@ptrCast(&mute), pd.symbol("mute"), &.{ .gimme });
		class.addMethod(@ptrCast(&solo), pd.symbol("solo"), &.{ .gimme });
		class.addMethod(@ptrCast(&doMask), s_mask, &.{ .gimme });
		class.addMethod(@ptrCast(&open), pr.s_open, &.{ .symbol });
		class.addMethod(@ptrCast(&stop), pd.symbol("stop"), &.{});
		class.addMethod(@ptrCast(&bMask), pd.symbol("bmask"), &.{});
	}
};

const Dict = struct {
	fn path(self: *Gme) pd.Atom
	{ return .{ .type = .symbol, .w = .{.symbol = self.path} }; }
	fn time(self: *Gme) pd.Atom
	{ return .{ .type = .float, .w = .{.float = self.length()} }; }
	fn ftime(self: *Gme) pd.Atom {
		return pr.fmtTime(@max(0, self.info.length) + @max(0, self.info.fade_length))
			catch pr.blank;
	}
	fn fade(self: *Gme) pd.Atom
	{ return .{ .type = .float, .w = .{.float = @floatFromInt(self.info.fade_length)} }; }
	fn tracks(self: *Gme) pd.Atom
	{ return .{ .type = .float, .w = .{.float = @floatFromInt(self.emu.trackCount())} }; }
	fn voices(self: *Gme) pd.Atom
	{ return .{ .type = .float, .w = .{.float = @floatFromInt(self.emu.voiceCount())} }; }
	fn system(self: *Gme) pd.Atom
	{ return .{ .type = .symbol, .w = .{.symbol = pd.symbol(self.info.system)} }; }
	fn game(self: *Gme) pd.Atom
	{ return .{ .type = .symbol, .w = .{.symbol = pd.symbol(self.info.game)} }; }
	fn song(self: *Gme) pd.Atom
	{ return .{ .type = .symbol, .w = .{.symbol = pd.symbol(self.info.song)} }; }
	fn author(self: *Gme) pd.Atom
	{ return .{ .type = .symbol, .w = .{.symbol = pd.symbol(self.info.author)} }; }
	fn copyright(self: *Gme) pd.Atom
	{ return .{ .type = .symbol, .w = .{.symbol = pd.symbol(self.info.copyright)} }; }
	fn comment(self: *Gme) pd.Atom
	{ return .{ .type = .symbol, .w = .{.symbol = pd.symbol(self.info.comment)} }; }
	fn dumper(self: *Gme) pd.Atom
	{ return .{ .type = .symbol, .w = .{.symbol = pd.symbol(self.info.dumper)} }; }
};
