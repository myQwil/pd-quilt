const pd = @import("pd");
const pr = @import("player.zig");
const av = @import("player.av.zig");
const ra = @import("player.rabbit.zig");
const ru = @import("player.rubber.zig");

const Atom = pd.Atom;
const Float = pd.Float;
const Sample = pd.Sample;

pub fn Impl(Root: type) type { return extern struct {
	obj: pd.Object = undefined,
	base: Base,
	rabbit: ra.Rabbit,
	rubber: ru.Rubber,
	planar: [*][*]Sample,

	const Self = @This();
	pub var class: *pd.Class = undefined;

	// Implementations
	pub const Base = av.Base(ra.frames);
	const BaseImpl = Base.Impl(Self);
	const Player = pr.Impl(Self);
	const Rabbit = ra.Impl(Self);
	const Rubber = ru.Impl(Self);

	pub inline fn err(self: *const Self, e: anyerror) void {
		pd.post.err(self, Root.name ++ ": %s", .{ @errorName(e).ptr });
	}

	pub inline fn conv(self: *Self, i: c_uint) void {
		self.rabbit.conv(i, self.base.nch) catch |e| self.err(e);
	}

	pub fn reset(self: *Self) void {
		self.base.reset();
		self.rabbit.reset() catch |e| self.err(e);
		self.rubber.reset();
	}

	pub fn restart(self: *Self) void {
		self.reset();
		self.base.frame.pts = 0;
		self.rubber.processStartPad(self.planar, self.base.nch, ra.frames);
	}

	fn performC(w: [*]usize) callconv(.c) [*]usize {
		const self: *Self = @ptrFromInt(w[1]);
		const base: *Base = &self.base;
		const player: *pr.Player = &base.player;
		if (player.play) {
			var i: u32 = undefined;
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
		return w + 5;
	}
	pub inline fn perform(self: *Self, w: [*]usize, ip: *u32) !void {
		var i: u32 = 0;
		errdefer ip.* = i;
		const n = w[2];
		const inlet2: [*]Sample = @ptrFromInt(w[3]);
		const inlet1: [*]Sample = @ptrFromInt(w[4]);

		const b = &self.base;
		const in = b.ibuf;
		const out = b.obuf;
		const frm = b.frame;
		const pkt = b.packet;
		const rbt = self.rabbit.state;
		const rbr = self.rubber.state;
		const data = &self.rabbit.data;
		var outs: [32][*]Sample = undefined;
		for (0..b.nch) |j| {
			outs[j] = b.outs[j];
		}

		while (i < n) {
			var m = rbr.available();
			while (m <= 0) {
				outer: while (data.output_frames_gen <= 0) {
					if (data.input_frames <= 0) {
						while (b.format.readFrame(pkt)) {
							defer pkt.unref();
							if (pkt.stream_index == b.audio.idx) {
								try b.audio.ctx.sendPacket(pkt);
								try b.audio.ctx.receiveFrame(frm);
								data.input_frames = try b.swr.convert(
									@ptrCast(&in), ra.frames,
									@ptrCast(frm.extended_data), frm.nb_samples,
								);
								data.data_in = in;
								data.input_frames = ra.frames;
								break;
							} else if (b.sub_open and pkt.stream_index == b.subtitle.idx) {
								var sub: av.Subtitle = undefined;
								if (try b.subtitle.ctx.decodeSubtitle(&sub, pkt)) {
									pd.post.do("\n%s", .{ pkt.data });
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
						data.data_in += @as(usize, @intCast(data.input_frames_used)) * b.nch;
					}
				}
				const used: u8 = @intCast(data.output_frames_gen);
				_ = pr.leavedToPlanar(data.data_out, self.planar, b.nch, used);
				rbr.setTimeRatio(1 / @min(@max(ra.slowest, inlet2[i]), ra.fastest));
				rbr.process(self.planar, used, false);
				data.output_frames_gen = 0;
				m = rbr.available();
			}
			const used = rbr.retrieve(&outs, @min(@as(u32, @intCast(m)), n - i));
			for (0..b.nch) |ch| {
				outs[ch] += used;
			}
			i += used;
		}
	}

	fn dspC(self: *Self, sp: [*]*pd.Signal) callconv(.c) void {
		const base: *Base = &self.base;
		for (base.outs[0..base.nch], sp[2..][0..base.nch]) |*o, s| {
			o.* = s.vec;
		}
		pd.dsp.add(&performC, .{ self, sp[1].len, sp[1].vec, sp[0].vec });
	}

	fn initC(_: *pd.Symbol, ac: c_uint, args: [*]const Atom) callconv(.c) ?*Self {
		return pd.wrap(*Self, init(args[0..ac]), Root.name);
	}
	inline fn init(args: []const Atom) !*Self {
		const self: *Self = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		var base: Base = try .init(obj, args);
		errdefer base.deinit();

		const nch = base.nch;
		var rabbit: ra.Rabbit = try .init(obj, nch);
		errdefer rabbit.deinit();

		var rubber: ru.Rubber = try .init(obj, nch, args);
		errdefer rubber.deinit();

		const pslice = try pd.mem.alloc([*]Sample, nch);
		for (0..nch) |ch| {
			const slice = try pd.mem.alloc(Sample, ra.frames);
			pslice[ch] = slice.ptr;
		}
		self.* = .{
			.base = base,
			.rabbit = rabbit,
			.rubber = rubber,
			.planar = pslice.ptr,
		};
		return self;
	}

	fn deinitC(self: *Self) callconv(.c) void {
		const nch = self.base.nch;
		for (0..nch) |ch| {
			pd.mem.free(self.planar[ch][0..ra.frames]);
		}
		pd.mem.free(self.planar[0..nch]);

		self.rubber.deinit();
		self.rabbit.deinit();
		self.base.deinit();
	}

	fn classFreeC(_: *pd.Class) callconv(.c) void {
		Base.freeDict();
	}

	pub inline fn setup() !void {
		class = try .init(Self, Root.name, &.{ .gimme }, &initC, &deinitC, .{});
		try BaseImpl.extend();
		try Rubber.extend();
		Player.extend();
		Rabbit.extend();
		class.addMethod(@ptrCast(&dspC), .gen("dsp"), &.{ .cant });
		class.setFreeFn(&classFreeC);
	}
};}
