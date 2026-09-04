//! An implementation of the FFmpeg libraries for the audio playback
//! of various media formats. Includes playlist functionality and
//! playback speed manipulation.

const std = @import("std");
const pd = @import("pd");
const av = @import("av");
const arc = @import("player.arc.zig");
const pr = @import("player.zig");
const tx = @import("trax.zig");

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
var s_bpm: *Symbol = undefined;
var s_date: *Symbol = undefined;
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
	playlist: tx.SymbolList = .empty,
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
	langs: []*Symbol = &.{},
	/// ratio between file samplerate and pd samplerate
	ratio: f64 = 1,
	nch: u8,
	sub_open: bool = false,

	const Av = @This();

	var dict: std.AutoHashMapUnmanaged(*Symbol, *const fn(*const Av) *const Pile) = .empty;
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
		gpa.free(self.langs);
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

	pub fn loadTrack(self: *Av, idx: usize) !void {
		if (idx >= self.trackCount()) {
			return error.IndexOutOfBounds;
		}
		const format: *av.FormatContext = try .openInput(
			self.playlist.items[idx].name, null, null, null);
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
		}
		self.format = format;
		self.audio = audio;
		self.swr = swr;
		self.ratio = @as(f64, @floatFromInt(audio.ctx.sample_rate)) / pd.sampleRate();
		self.frame.pts = 0;
	}

	pub inline fn getTrax(self: *const Av, gpa: Allocator, io: Io) Meta {
		self.player.assertFileOpened() catch return .{};
		return Meta.fromPath(gpa, io, self.format.url) catch Meta{};
	}

	pub inline fn open(
		self: *Av,
		gpa: Allocator,
		io: Io,
		args: []const Atom,
	) tx.AppendError!void {
		try tx.listReplace(&self.playlist, gpa, io, args);
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

	pub inline fn printAuto(
		self: *const Av,
		trax: *const Meta,
		w: *Io.Writer,
	) Io.Writer.Error!void {
		// general track info: %artist% - %title%
		if (self.get(trax, .gen("artist"))) |artist| {
			try artist.write(w);
			if (self.get(trax, .gen("title"))) |title| {
				try w.writeAll(" - ");
				try title.write(w);
			}
		} else if (self.get(trax, .gen("title"))) |title| {
			try title.write(w);
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
		return self.playlist.items.len;
	}

	pub fn get(self: *const Av, trax: *const Meta, s: *Symbol) ?*const Pile {
		if (trax.get(s, self.langs)) |pile| {
			return pile;
		}
		if (dict.get(s)) |func| {
			return func(self);
		}
		const dct = self.format.metadata.toConst();
		if (dct.get(s.name, null, .{})) |entry| {
			return .parse(std.mem.sliceTo(entry.value, 0));
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
		return if (request) |entry| .parse(std.mem.sliceTo(entry.value, 0)) else null;
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

		fn appendC(
			p: *Pd,
			_: *Symbol, ac: c_uint, args: [*]const pd.Atom,
		) callconv(.c) void {
			const self = Box.state(p);
			const base: *Av = &self.base;
			tx.listAppend(&base.playlist, gpa, io, args[0..ac]) catch |e| err(p, e);
			const count: Float = @floatFromInt(base.trackCount());
			base.player.outlet.anything(s_append, &.{ .float(count) });
		}

		fn dumpC(
			p: *Pd,
			_: *Symbol, ac: c_uint, args: [*]const pd.Atom,
		) callconv(.c) void {
			const self = Box.state(p);
			const base: *Av = &self.base;
			const path = base.format.url;
			const meta_err: anyerror!Meta = if (pd.floatArg(0, args[0..ac])) |f| blk: {
				var chaps = tx.getChapters(gpa, io, path) catch |e| return err(p, e);
				defer chaps.deinit(gpa);
				const chap = chaps.items[indexFromFloat(f, chaps.items.len) orelse return];
				pd.post.log(p, .normal, "at %g:", .{ chap.time });
				break :blk Meta.fromPath(gpa, io, chap.trax.name);
			} else |_| Meta.fromPath(gpa, io, base.format.url);

			if (meta_err) |meta| {
				var m = meta;
				defer m.deinit(gpa);
				const langs: []const *Symbol = base.langs;
				var iter = meta.data.iterator();
				while (iter.next()) |kv| {
					kv.value_ptr.get(langs).print(p, kv.key_ptr.*.name);
				}
			} else |_| {
				const dct = &base.format.metadata;
				var prev: ?*const av.Dictionary.Entry = null;
				while (dct.iterate(prev)) |entry| : (prev = entry) {
					pd.post.log(p, .normal, "%s: %s", .{ entry.key, entry.value });
				}
			}
		}

		fn langsC(
			p: *Pd,
			_: *Symbol, ac: c_uint, args: [*]const pd.Atom,
		) callconv(.c) void {
			const self = Box.state(p);
			const base: *Av = &self.base;
			tx.langReplace(&base.langs, gpa, args[0..ac]) catch |e| err(p, e);
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
			s_bpm = .gen("bpm");
			s_date = .gen("date");
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
			class.addMethod(&.{ .gimme }, langsC, .gen("langs"));
			class.addMethod(&.{ .gimme }, dumpC, .gen("dump"));
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
