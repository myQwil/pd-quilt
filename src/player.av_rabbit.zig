const pd = @import("pd");
const std = @import("std");
const pr = @import("player.zig");
const av = @import("player.av.zig");
const ra = @import("player.rabbit.zig");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Float = pd.Float;
const Sample = pd.Sample;

pub fn Impl(Root: type) type { return extern struct {
	obj: pd.Object,
	base: Base,
	rabbit: ra.Rabbit,

	const Self = @This();
	pub var class: *pd.Class = undefined;
	pub const gpa = pd.gpa;
	pub const io = std.Io.Threaded.global_single_threaded.io();
	pub const parentPtr = pd.parentPtr(Self);
	pub const parentConstPtr = pd.parentConstPtr(Self);

	// Implementations
	pub const Base = av.Base(ra.frames);
	const BaseImpl = Base.Impl(Self);
	const Player = pr.Impl(Self);
	const Rabbit = ra.Impl(Self);

	pub inline fn err(self: *const Self, e: anyerror) void {
		pd.post.err(self, Root.name ++ ": %s", .{ @errorName(e).ptr });
	}

	pub inline fn conv(self: *Self, i: ra.uint) void {
		self.rabbit.conv(i, self.base.nch) catch |e| self.err(e);
	}

	pub fn resetBuffers(self: *Self) void {
		self.base.reset();
		self.rabbit.reset() catch |e| self.err(e);
	}

	pub fn prepNewTrack(self: *Self) void {
		self.base.frame.pts = 0;
	}

	fn performC(w: [*]usize) callconv(.c) [*]usize {
		const self: *Self = @ptrFromInt(w[1]);
		const base: *Base = &self.base;
		const player: *pr.Player = &base.player;
		if (player.play) {
			var i: usize = undefined;
			perform(self, w, &i) catch |e| {
				player.play = false;
				player.sendState(pr.s_play, player.play);
				if (e != error.EndOfFile) {
					pd.post.err(self, Root.name ++ ": %s", .{ @errorName(e).ptr });
				}
				for (base.outs[0..base.nch]) |ch| {
					@memset(ch[i..w[2]], 0);
				}
			};
		} else {
			for (base.outs[0..base.nch]) |ch| {
				@memset(ch[0..w[2]], 0);
			}
		}
		return w + 4;
	}
	pub inline fn perform(self: *Self, w: [*]usize, ip: *usize) !void {
		var i: usize = 0;
		errdefer ip.* = i;
		const n = w[2];
		const inlet1: [*]Sample = @ptrFromInt(w[3]);

		const b = &self.base;
		const in = b.ibuf;
		const out = b.obuf;
		const frm = b.frame;
		const pkt = b.packet;
		const rbt = self.rabbit.state;
		const data = &self.rabbit.data;
		var outs: [32][*]Sample = undefined;
		for (0..b.nch) |j| {
			outs[j] = b.outs[j];
		}

		while (i < n) {
			outer: while (data.output_frames_gen <= 0) {
				if (data.input_frames <= 0) {
					while (b.format.readFrame(pkt)) {
						defer pkt.unref();
						if (pkt.stream_index == b.audio.idx) {
							try b.audio.ctx.sendPacket(pkt);
							try b.audio.ctx.receiveFrame(frm);
							data.input_frames = try b.swr.convert(
								@ptrCast(&in), ra.frames,
								@ptrCast(frm.extended_data), frm.nb_samples.u,
							);
							data.data_in = in;
							data.input_frames = ra.frames;
							break;
						} else if (b.sub_open and pkt.stream_index == b.subtitle.idx) {
							var sub: av.Subtitle = undefined;
							if (try b.subtitle.ctx.decodeSubtitle(&sub, pkt)) {
								pd.post.log(self, .normal, "\n%s", .{ pkt.data });
							}
						}
					} else |e| {
						if (e != error.EndOfFile) {
							return e;
						}
						// reached the end
						const player = &b.player;
						if (player.play) {
							player.play = false;
							// try loading next track before fallback to silence
							player.outlet.anything(av.s_done, &.{});
							continue :outer;
						} else {
							try b.seek(0);
							player.sendState(pr.s_play, player.play);
							return e;
						}
					}
				}
				data.data_out = out;
				self.rabbit.setRatio(inlet1[i] * b.ratio);
				try rbt.process(data);
				data.input_frames -= data.input_frames_used;
				if (data.input_frames <= 0) {
					data.data_in = in;
					data.input_frames = try b.swr.convert(
						@ptrCast(&in), ra.frames, null, 0);
				} else {
					data.data_in += data.input_frames_used * b.nch;
				}
			}
			const used: usize = @min(data.output_frames_gen, n - i);
			data.data_out += pr.leavedToPlanar(data.data_out, &outs, b.nch, used);
			for (0..b.nch) |ch| {
				outs[ch] += used;
			}
			data.output_frames_gen -= used;
			i += used;
		}
	}

	fn dspC(p: *Pd, sp: [*]*pd.Signal) callconv(.c) void {
		const self = parentPtr(p);
		const base: *Base = &self.base;
		for (base.outs[0..base.nch], sp[1..][0..base.nch]) |*o, s| {
			o.* = s.vec;
		}
		pd.dsp.add(performC, .{ self, sp[0].len, sp[0].vec });
	}

	fn initC(_: *pd.Symbol, ac: c_uint, args: [*]const Atom) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(args[0..ac]), Root.name);
	}
	inline fn init(args: []const Atom) (ra.InitError || error{FFmpegInvalid})!*Pd {
		const self: *Self = try pd.gpa.create(Self);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		const arg: Atom = if (args.len > 0) args[0] else .float(av.stereo);
		var base: Base = try .init(gpa, obj, arg);
		errdefer base.deinit(gpa);

		const rabbit: ra.Rabbit = try .init(obj, base.nch);
		self.* = .{
			.obj = self.obj,
			.base = base,
			.rabbit = rabbit,
		};
		return &obj.g.pd;
	}

	fn deinitC(p: *Pd) callconv(.c) void {
		const self = parentPtr(p);
		self.rabbit.deinit();
		self.base.deinit(gpa);
	}

	fn classFreeC(_: *pd.Class) callconv(.c) void {
		Base.freeDict();
	}

	pub inline fn setup() (pd.Class.Error || pd.Oom)!void {
		class = try .init(Self, Root.name, &.{ .gimme }, initC, deinitC, .{});
		try BaseImpl.extend();
		Player.extend();
		Rabbit.extend();
		class.addMethod(&.{ .cant }, dspC, .gen("dsp"));
		class.setFreeFn(classFreeC);
	}
};}
