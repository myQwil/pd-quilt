const std = @import("std");
const pd = @import("pd");
const av = @import("av");
const arc = @import("player.arc.zig");
const pr = @import("player.zig");
const Playlist = @import("playlist.zig").Playlist;
pub const Subtitle = av.Subtitle;

const Atom = pd.Atom;
const Float = pd.Float;
const Sample = pd.Sample;
const Symbol = pd.Symbol;

const io = std.Io.Threaded.global_single_threaded.ioBasic();

var s_pos: *Symbol = undefined;
var s_bpm: *Symbol = undefined;
var s_date: *Symbol = undefined;
pub var s_done: *Symbol = undefined;

pub fn trimRange(
	comptime T: type, slice: []const T, exclude: []const T,
) struct { usize, usize } {
	var begin: usize = 0;
	var end: usize = slice.len;
	while (begin < end and std.mem.indexOfScalar(T, exclude, slice[begin]) != null) {
		begin += 1;
	}
	while (end > begin and std.mem.indexOfScalar(T, exclude, slice[end - 1]) != null) {
		end -= 1;
	}
	return .{ begin, end };
}

const Stream = extern struct {
	ctx: *av.Codec.Context = undefined,
	idx: usize = 0,

	fn init(ic: *const av.FormatContext, t: av.MediaType, i: usize) !Stream {
		if (i >= ic.nb_streams) {
			return error.StreamIndexOutOfBounds;
		}
		if (ic.streams[i].codecpar.codec_type != t) {
			return error.StreamTypeMismatch;
		}
		const stream = ic.streams[i];

		const ctx: *av.Codec.Context = try .init(try stream.codecpar.codec_id.decoder());
		errdefer ctx.deinit();

		try ctx.parametersToContext(stream.codecpar);
		ctx.pkt_timebase = stream.time_base;
		try ctx.open(null, null);

		return .{
			.ctx = ctx,
			.idx = i,
		};
	}

	pub fn deinit(self: *Stream) void {
		self.ctx.deinit();
	}
};

pub fn Base(frames: comptime_int) type { return extern struct {
	layout: av.ChannelLayout,
	playlist: Playlist = .{},
	player: pr.Player,
	audio: Stream = .{},
	subtitle: Stream = .{},
	ibuf: [*]Sample,
	obuf: [*]Sample,
	outs: [*][*]Sample,
	packet: *av.Packet,
	frame: *av.Frame,
	format: *av.FormatContext = undefined,
	swr: *av.SwrContext = undefined,
	/// ratio between file samplerate and pd samplerate
	ratio: f64 = 1,
	nch: u8,
	sub_open: bool = false,

	const Av = @This();

	var dict: std.AutoHashMap(*Symbol, *const fn(*const Av) Atom) = undefined;
	pub fn freeDict() void {
		dict.deinit();
	}

	pub inline fn init(obj: *pd.Object, args: []const Atom) !Av {
		const stereo =
			(1 << @intFromEnum(av.Channel.front_left)) |
			(1 << @intFromEnum(av.Channel.front_right));
		const layout: av.ChannelLayout = try .fromMask(for (args) |a| {
			if (a.type == .float) {
				break @intFromFloat(a.w.float);
			}
		} else stereo);

		const nch: u8 = @intCast(layout.nb_channels);
		for (0..nch) |_| {
			_ = try obj.outlet(&pd.s_signal);
		}

		const packet: *av.Packet = try .init();
		errdefer packet.deinit();

		const frame: *av.Frame = try .init();
		errdefer frame.deinit();

		const ibuf = try pd.mem.alloc(Sample, nch * frames);
		errdefer pd.mem.free(ibuf);

		const obuf = try pd.mem.alloc(Sample, nch * frames);
		errdefer pd.mem.free(obuf);

		const outs = try pd.mem.alloc([*]Sample, nch);
		errdefer pd.mem.free(outs);

		return .{
			.player = try .init(obj),
			.ibuf = ibuf.ptr,
			.obuf = obuf.ptr,
			.outs = outs.ptr,
			.layout = layout,
			.packet = packet,
			.frame = frame,
			.nch = nch,
		};
	}

	pub inline fn deinit(self: *Av) void {
		pd.mem.free(self.ibuf[0 .. self.nch * frames]);
		pd.mem.free(self.obuf[0 .. self.nch * frames]);
		pd.mem.free(self.outs[0 .. self.nch]);
		self.playlist.deinit();
		self.packet.deinit();
		self.frame.deinit();
		if (self.player.open) {
			self.format.deinit();
			self.audio.deinit();
			self.swr.deinit();
		}
		if (self.sub_open) {
			self.subtitle.deinit();
		}
	}

	fn newSwr(self: *Av, a: *const av.Codec.Context) !*av.SwrContext {
		var cl: av.ChannelLayout = if (a.ch_layout.u.mask != 0)
			try .fromMask(a.ch_layout.u.mask)
		else .default(a.ch_layout.nb_channels);
		const sf: av.SampleFormat = if (@bitSizeOf(Float) == 64) .dbl else .flt;
		return .init(&self.layout, sf, 1, &cl, a.sample_fmt, 1, 0, null);
	}

	pub fn loadTrack(self: *Av, idx: usize) !void {
		if (idx >= self.playlist.len) {
			return error.IndexOutOfBounds;
		}
		const format: *av.FormatContext = try .init(
			self.playlist.ptr[idx].name, null, null, null);
		errdefer format.deinit();

		try format.findStreamInfo(null);
		format.seek2any = 1;

		var audio: Stream = try .init(format, .audio, for (0..format.nb_streams) |i| {
			if (format.streams[i].codecpar.codec_type == .audio) {
				break i;
			}
		} else {
			return error.NoAudioStreamFound;
		});
		errdefer audio.deinit();
		const swr: *av.SwrContext = try self.newSwr(audio.ctx);

		// safe to delete the previous track
		if (self.player.open) {
			self.format.deinit();
			self.audio.deinit();
			self.swr.deinit();
		}
		self.format = format;
		self.audio = audio;
		self.swr = swr;
		self.ratio = @as(f64, @floatFromInt(audio.ctx.sample_rate)) / pd.sampleRate();
		self.frame.pts = 0;
		self.loadMetadata(std.mem.sliceTo(self.playlist.ptr[idx].name, 0))
			catch |e| pd.post.err(null, "Av.loadMetadata: %s", .{ @errorName(e).ptr });
	}

	inline fn loadMetadata(self: *Av, path: [:0]const u8) !void {
		const ext = ".txt";
		const i = std.mem.lastIndexOf(u8, path, ".") orelse path.len;
		var ext_path = try pd.mem.alloc(u8, i + ext.len);
		defer pd.mem.free(ext_path);

		@memcpy(ext_path[0..i], path[0..i]);
		@memcpy(ext_path[i..][0..ext.len], ext);
		const file = std.Io.Dir.cwd().openFile(io, ext_path, .{ .mode = .read_only })
			catch return;
		defer file.close(io);

		var buf: [std.fs.max_path_bytes:0]u8 = undefined;
		var r = file.reader(io, &buf);
		const dct = &self.format.metadata;
		while (r.interface.takeDelimiterExclusive('\n')) |line| {
			defer _ = r.interface.take(1) catch {};
			const trim = trimRange(u8, line, " \r");
			const begin = r.interface.seek - line.len + trim[0];
			const end = r.interface.seek - line.len + trim[1];
			if (begin > end or buf[begin] == '#') {
				continue;
			}
			const eql = std.mem.indexOfScalar(u8, buf[begin..end], '=') orelse continue;
			buf[end] = 0;
			buf[begin + eql] = 0;

			const key = buf[begin..][0..eql :0];
			const val = buf[begin + eql + 1 .. end :0];
			dct.set(key.ptr, val.ptr, .{})
				catch |e| pd.post.err(null, "dct.set: %s", .{ @errorName(e).ptr });
		} else |e| if (e != error.EndOfStream) {
			return e;
		}
	}

	pub inline fn open(self: *Av, args: []const Atom) !void {
		try self.playlist.readArgs(args);
	}

	pub inline fn reset(self: *Av) void {
		self.audio.ctx.flushBuffers();
		// empty out the current frame
		while (self.swr.convert(@ptrCast(&self.ibuf), frames, null, 0)) |n| {
			if (n <= 0) {
				break;
			}
		} else |_| {}
	}

	pub inline fn printAuto(self: *const Av, writer: *std.Io.Writer) !void {
		// general track info: %artist% - %title%
		const mdata = self.format.metadata.toConst();
		if (mdata.get("artist", null, .{})) |artist| {
			try writer.print("{s}", .{ artist.value });
			if (mdata.get("title", null, .{})) |title| {
				try writer.print(" - {s}", .{ title.value });
			}
		} else if (mdata.get("title", null, .{})) |title| {
			try writer.print("{s}", .{ title.value });
		}
	}

	pub fn seek(self: *Av, f: Float) !void {
		const ts: i64 = @intFromFloat(f * 1000);
		try self.format.seekFile(-1, 0, ts, self.format.duration, .{});

		const ratio = self.format.streams[self.audio.idx].time_base;
		const num: f64 = @floatFromInt(ratio.num);
		const den: f64 = @floatFromInt(ratio.den);
		self.frame.pts = @intFromFloat(f * den / (num * 1000));
	}

	pub inline fn pos(self: *Av) !void {
		try self.player.assertFileOpened();
		const ratio = self.format.streams[self.audio.idx].time_base.q2d();
		const f = @as(f64, @floatFromInt(self.frame.pts)) * ratio * 1000;
		self.player.outlet.anything(s_pos, &.{ .float(@floatCast(f)) });
	}

	pub inline fn trackCount(self: *const Av) usize {
		return self.playlist.len;
	}

	pub fn get(self: *const Av, s: *Symbol) ?Atom {
		if (dict.get(s)) |func| {
			return func(self);
		}
		const dct = self.format.metadata.toConst();
		if (dct.get(s.name, null, .{})) |entry| {
			return .symbol(.gen(entry.value));
		}
		// try matching close-enough terms
		var request: ?*const av.Dictionary.Entry = null;
		if (s == s_date) {
			request = dct.get("time", null, .{})
				orelse dct.get("tyer", null, .{})
				orelse dct.get("tdat", null, .{})
				orelse dct.get("tdrc", null, .{});
		} else if (s == s_bpm) {
			request = dct.get("tbpm", null, .{});
		}
		return if (request) |entry| .symbol(.gen(entry.value)) else null;
	}

	pub fn Impl(Self: type) type { return struct {
		const perform: fn(*Self, [*]usize, *u32) callconv(.@"inline") anyerror!void
			= Self.perform;
		const err: fn(*const Self, anyerror) callconv(.@"inline") void = Self.err;

		fn posC(self: *Self) callconv(.c) void {
			const base: *Av = &self.base;
			base.pos() catch |e| err(self, e);
		}

		fn audioC(self: *Self, f: Float) callconv(.c) void {
			audio(self, f) catch |e| err(self, e);
		}
		inline fn audio(self: *Self, f: Float) !void {
			const base: *Av = &self.base;
			try base.player.assertFileOpened();
			var a: Stream = try .init(base.format, .audio, @intFromFloat(f));
			errdefer a.deinit();
			const swr = try base.newSwr(a.ctx);

			base.audio.deinit();
			base.swr.deinit();
			base.audio = a;
			base.swr = swr;
			base.ratio = @as(f64, @floatFromInt(a.ctx.sample_rate)) / pd.sampleRate();
			pd.post.log(self, .normal, "audio stream set to %u", .{ a.idx });
		}

		fn subtitleC(self: *Self, f: Float) callconv(.c) void {
			subtitle(self, f) catch |e| err(self, e);
		}
		inline fn subtitle(self: *Self, f: Float) !void {
			const base: *Av = &self.base;
			try base.player.assertFileOpened();
			if (f < 0) {
				if (base.sub_open) {
					base.subtitle.deinit();
					base.sub_open = false;
				}
				return;
			}
			const s: Stream = try .init(base.format, .subtitle, @intFromFloat(f));
			if (base.sub_open) {
				base.subtitle.deinit();
			}
			base.subtitle = s;
			base.sub_open = true;
			pd.post.log(self, .normal, "subtitle stream set to %u", .{ s.idx });
		}

		pub inline fn extend() !void {
			s_bpm = .gen("bpm");
			s_date = .gen("date");
			s_done = .gen("done");
			s_pos = .gen("pos");

			dict = .init(pd.mem);
			errdefer dict.deinit();
			inline for ([_][:0]const u8{
				"path", "time", "ftime", "tracks",
				"samplefmt", "samplerate", "bitrate", "codec",
			}) |field_name| {
				try dict.put(.gen(field_name), @field(meta, field_name));
			}

			const class: *pd.Class = Self.class;
			class.addMethod(@ptrCast(&posC), s_pos, &.{});
			class.addMethod(@ptrCast(&audioC), .gen("audio"), &.{ .float });
			class.addMethod(@ptrCast(&subtitleC), .gen("subtitle"), &.{ .float });
		}
	};}

	const meta = struct {
		fn path(self: *const Av) Atom {
			return .symbol(.gen(self.format.url));
		}
		fn time(self: *const Av) Atom {
			return .float(@as(Float, @floatFromInt(self.format.duration)) / 1000.0);
		}
		fn ftime(self: *const Av) Atom {
			return .symbol(pr.timeSym(@divTrunc(self.format.duration, 1000)));
		}
		fn tracks(self: *const Av) Atom {
			return .float(@floatFromInt(self.playlist.len));
		}
		fn samplefmt(self: *const Av) Atom {
			return .symbol(.gen(self.audio.ctx.sample_fmt.getName() orelse "unknown"));
		}
		fn samplerate(self: *const Av) Atom {
			return .float(@floatFromInt(self.audio.ctx.sample_rate));
		}
		fn bitrate(self: *const Av) Atom {
			const bit_rate: Float = @floatFromInt(self.format.bit_rate);
			return .float(bit_rate / 1000);
		}
		fn codec(self: *const Av) Atom {
			return .symbol(.gen(@tagName(self.audio.ctx.codec_id).ptr));
		}
	};
};}
