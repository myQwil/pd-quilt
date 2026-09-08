//! An implementation of the FFmpeg libraries for the audio playback
//! of various media formats. Includes playlist functionality and
//! playback speed manipulation.

const pd = @import("pd");
const av = @import("av");
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
pub const Subtitle = av.Subtitle;
const Meta = tx.Meta;
const Pile = tx.Pile;

var s_pos: *Symbol = undefined;
var s_append: *Symbol = undefined;
pub var s_done: *Symbol = undefined;

fn indexFromFloat(f: Float, len: usize) ?u32 {
	const i: i32 = @intFromFloat(f);
	if (i < 0 or len <= i) {
		return null;
	}
	return @bitCast(i);
}

pub const stereo = (
	(1 << @intFromEnum(av.Channel.front_left)) |
	(1 << @intFromEnum(av.Channel.front_right))
);

const Stream = struct {
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

		const ctx: *av.Codec.Context = try .create(try stream.codecpar.codec_id.decoder());
		errdefer ctx.destroy();

		try ctx.parametersToContext(stream.codecpar);
		ctx.pkt_timebase = stream.time_base;
		try ctx.open(null, null);

		return .{
			.ctx = ctx,
			.idx = i,
		};
	}

	pub fn deinit(self: *Stream) void {
		self.ctx.destroy();
	}
};

pub fn Base(frames: comptime_int) type { return struct {
	layout: av.ChannelLayout,
	playlist: tx.Playlist = .{},
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

	pub var dict: std.AutoHashMapUnmanaged(*Symbol, *const fn(*const Av) *const Pile)
		= .empty;
	pub fn freeDict(gpa: Allocator) void {
		dict.deinit(gpa);
	}

	pub inline fn init(gpa: Allocator, obj: *pd.Object, arg: Atom) !Av {
		const layout: av.ChannelLayout = try .fromMask(if (arg.getSymbol()) |s|
			std.fmt.parseInt(u64, std.mem.sliceTo(s.name, 0), 0) catch stereo
		else @as(u64, @intFromFloat(arg.w.float)));

		const nch: u8 = @truncate(@as(c_uint, @bitCast(layout.nb_channels)));
		for (0..nch) |_| {
			_ = try obj.outlet(pd.s.signal());
		}

		const packet: *av.Packet = try .create();
		errdefer packet.destroy();

		const frame: *av.Frame = try .create();
		errdefer frame.destroy();

		const ibuf = try gpa.alloc(Sample, nch * frames);
		errdefer gpa.free(ibuf);

		const obuf = try gpa.alloc(Sample, nch * frames);
		errdefer gpa.free(obuf);

		const outs = try gpa.alloc([*]Sample, nch);
		errdefer gpa.free(outs);

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

	pub inline fn deinit(self: *Av, gpa: Allocator) void {
		gpa.free(self.ibuf[0 .. self.nch * frames]);
		gpa.free(self.obuf[0 .. self.nch * frames]);
		gpa.free(self.outs[0 .. self.nch]);
		self.playlist.deinit(gpa);
		self.player.deinit(gpa);
		self.packet.destroy();
		self.frame.destroy();
		if (self.player.open) {
			self.format.closeInput();
			self.audio.deinit();
			self.swr.destroy();
		}
		if (self.sub_open) {
			self.subtitle.deinit();
		}
	}

	fn newSwr(self: *Av, a: *const av.Codec.Context) !*av.SwrContext {
		var cl: av.ChannelLayout = if (a.ch_layout.u.mask != 0)
			try .fromMask(a.ch_layout.u.mask)
		else .default(pd.uFromI(a.ch_layout.nb_channels));
		const sf: av.SampleFormat = if (@bitSizeOf(Float) == 64) .dbl else .flt;
		return .create(&self.layout, sf, 1, &cl, a.sample_fmt, 1, 0, null);
	}

	pub fn loadTrack(self: *Av, gpa: Allocator, io: Io, idx: usize) !void {
		if (idx >= self.trackCount()) {
			return error.IndexOutOfBounds;
		}
		const url = self.playlist.get(idx);
		const format: *av.FormatContext = try .openInput(url, null, null, null);
		errdefer format.closeInput();

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
			self.format.closeInput();
			self.audio.deinit();
			self.swr.destroy();
			self.player.meta.deinit(gpa);
			self.player.meta = .{};
		}
		self.format = format;
		self.audio = audio;
		self.swr = swr;
		self.ratio = @as(f64, @floatFromInt(audio.ctx.sample_rate)) / pd.sampleRate();
		self.frame.pts = 0;
		self.loadMetadata(gpa, io, url)
			catch |e| pd.post.err(null, "Av.loadMetadata: %s", .{ @errorName(e).ptr });
	}

	inline fn loadMetadata(self: *Av, gpa: Allocator, io: Io, url: [*:0]const u8) !void {
		var meta: tx.Meta = try .fromPath(gpa, io, url);
		errdefer meta.deinit(gpa);

		const dct = &self.format.metadata;
		var prev: ?*const av.Dictionary.Entry = null;
		while (dct.iterate(prev)) |entry| : (prev = entry) {
			const key = try gpa.dupeSentinel(u8, std.mem.sliceTo(entry.key, 0), 0);
			defer gpa.free(key);
			tx.makeLowerCase(key);
			const k: *Symbol = .gen(key);
			if (!meta.data.contains(k)) {
				const v = std.mem.sliceTo(entry.value, 0);
				_ = try tx.putGet(&meta.data, gpa, k, pd.s.empty(), v, false);
			}
		}
		self.player.meta = meta;
	}

	pub inline fn open(
		self: *Av,
		gpa: Allocator,
		io: Io,
		args: []const Atom,
	) tx.AppendError!void {
		try self.playlist.replace(gpa, io, args);
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

	pub inline fn printAuto(self: *const Av, w: *Io.Writer) Io.Writer.Error!void {
		try self.player.printAuto(w, "artist", "title");
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
		return self.playlist.tbl.items.len;
	}

	pub fn Impl(Self: type) type { return struct {
		const perform: fn(*Self, [*]usize, *usize) callconv(.@"inline") anyerror!void
			= Self.perform;
		const err: fn(*const Pd, anyerror) callconv(.@"inline") void = Self.err;
		const gpa = Self.gpa;
		const io = Self.io;
		const Box = Self.Box;

		fn posC(p: *Pd) callconv(.c) void {
			const self = Box.state(p);
			const base: *Av = &self.base;
			base.pos() catch |e| err(p, e);
		}

		fn appendC(p: *Pd, _: *Symbol, ac: c_uint, args: [*]const Atom) callconv(.c) void {
			const self = Box.state(p);
			const base: *Av = &self.base;
			base.playlist.appendArgs(gpa, io, args[0..ac]) catch |e| err(p, e);
			const count: Float = @floatFromInt(base.trackCount());
			base.player.outlet.anything(s_append, &.{ .float(count) });
		}

		fn audioC(p: *Pd, f: Float) callconv(.c) void {
			audio(p, f) catch |e| err(p, e);
		}
		inline fn audio(p: *Pd, f: Float) !void {
			const self = Box.state(p);
			const base: *Av = &self.base;
			try base.player.assertFileOpened();
			var a: Stream = try .init(base.format, .audio, @intFromFloat(f));
			errdefer a.deinit();
			const swr = try base.newSwr(a.ctx);

			base.audio.deinit();
			base.swr.destroy();
			base.audio = a;
			base.swr = swr;
			base.ratio = @as(f64, @floatFromInt(a.ctx.sample_rate)) / pd.sampleRate();
			pd.post.log(p, .normal, "audio stream set to %u", .{ a.idx });
		}

		fn subtitleC(p: *Pd, f: Float) callconv(.c) void {
			subtitle(p, f) catch |e| err(p, e);
		}
		inline fn subtitle(p: *Pd, f: Float) !void {
			const self = Box.state(p);
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
			pd.post.log(p, .normal, "subtitle stream set to %u", .{ s.idx });
		}

		pub inline fn extend() Allocator.Error!void {
			s_done = .gen("done");
			s_pos = .gen("pos");
			s_append = .gen("append");

			errdefer dict.deinit(gpa);
			inline for ([_][:0]const u8{
				"path", "time", "ftime", "tracks",
				"samplefmt", "samplerate", "bitrate", "codec",
			}) |field_name| {
				try dict.put(gpa, .gen(field_name), @field(dispatch, field_name));
			}

			const class: *pd.Class = Self.class;
			class.addMethod(&.{}, posC, s_pos);
			class.addMethod(&.{ .float }, audioC, .gen("audio"));
			class.addMethod(&.{ .float }, subtitleC, .gen("subtitle"));
			class.addMethod(&.{ .gimme }, appendC, .gen("append"));
		}
	};}

	const dispatch = struct {
		fn path(self: *const Av) *const Pile {
			return .string(std.mem.sliceTo(self.format.url, 0));
		}
		fn time(self: *const Av) *const Pile {
			return .float(@as(Float, @floatFromInt(self.format.duration)) / 1000.0);
		}
		fn ftime(self: *const Av) *const Pile {
			const ts = pr.timeSym(@divTrunc(self.format.duration, 1000));
			return .string(std.mem.sliceTo(ts.name, 0));
		}
		fn tracks(self: *const Av) *const Pile {
			return .float(@floatFromInt(self.trackCount()));
		}
		fn samplefmt(self: *const Av) *const Pile {
			const name = self.audio.ctx.sample_fmt.getName();
			return .string(if (name) |s| std.mem.sliceTo(s, 0) else "unknown");
		}
		fn samplerate(self: *const Av) *const Pile {
			return .float(@floatFromInt(self.audio.ctx.sample_rate));
		}
		fn bitrate(self: *const Av) *const Pile {
			const bit_rate: Float = @floatFromInt(self.format.bit_rate);
			return .float(bit_rate / 1000);
		}
		fn codec(self: *const Av) *const Pile {
			return .string(@tagName(self.audio.ctx.codec_id));
		}
	};
};}
