const pd = @import("pd");
const pr = @import("player.zig");
const gm = @import("player.gme.zig");
const ra = @import("player.rabbit.zig");
const ru = @import("player.rubber.zig");

const Atom = pd.Atom;
const Float = pd.Float;
const Sample = pd.Sample;

const gpa = pd.gpa;

pub fn Impl(Root: type) type { return extern struct {
	obj: pd.Object = undefined,
	base: Base,
	rabbit: ra.Rabbit,
	rubber: ru.Rubber,
	planar: [Root.nch][*]Sample,

	const Self = @This();
	pub var class: *pd.Class = undefined;

	// Implementations
	pub const Base = gm.Base(Root.nch, ra.frames);
	const BaseImpl = Base.Impl(Self);
	const Player = pr.Impl(Self);
	const Rabbit = ra.Impl(Self);
	const Rubber = ru.Impl(Self);

	pub inline fn err(self: *const Self, e: anyerror) void {
		pd.post.err(self, Root.name ++ ": %s", .{ @errorName(e).ptr });
	}

	pub inline fn conv(self: *Self, i: c_uint) void {
		self.rabbit.conv(i, Root.nch) catch |e| self.err(e);
	}

	pub fn reset(self: *Self) void {
		self.rabbit.reset() catch |e| self.err(e);
		self.rubber.reset();
	}

	pub fn restart(self: *Self) void {
		self.reset();
		self.rubber.processStartPad(&self.planar, Root.nch, ra.frames);
	}

	pub inline fn perform(self: *Self, w: [*]usize, ip: *u32) !void {
		var i: u32 = 0;
		errdefer ip.* = i;
		const n = w[2];
		const inlet2: [*]Sample = @ptrFromInt(w[3]);
		const inlet1: [*]Sample = @ptrFromInt(w[4]);

		const b: *Base = &self.base;
		const in = &b.ibuf;
		const out = &b.obuf;
		const emu = b.emu;
		const rbt = self.rabbit.state;
		const rbr = self.rubber.state;
		const data = &self.rabbit.data;
		const raw: []i16 = &b.raw;
		var outs: [Root.nch][*]Sample = b.outs;

		while (i < n) {
			var m = rbr.available();
			while (m <= 0) {
				while (data.output_frames_gen <= 0) {
					if (data.input_frames <= 0) {
						try emu.play(raw);
						for (raw, in) |*from, *to| {
							to.* = @as(Sample, @floatFromInt(from.*)) * 0x1p-15;
						}
						data.data_in = in;
						data.input_frames = ra.frames;
					}
					data.data_out = out;
					self.rabbit.setRatio(inlet1[i] * b.ratio);
					try rbt.process(data);
					data.input_frames -= data.input_frames_used;
					data.data_in += data.input_frames_used * Root.nch;
				}
				const used: u8 = @intCast(data.output_frames_gen);
				_ = pr.leavedToPlanar(data.data_out, &self.planar, Root.nch, used);
				rbr.setTimeRatio(1 / @min(@max(ra.slowest, inlet2[i]), ra.fastest));
				rbr.process(&self.planar, used, false);
				data.output_frames_gen = 0;
				m = rbr.available();
			}
			const used = rbr.retrieve(&outs, @min(@as(u32, @intCast(m)), n - i));
			inline for (0..Root.nch) |ch| {
				outs[ch] += used;
			}
			i += used;
		}
	}

	fn initC(_: *pd.Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) ?*Self {
		return pd.wrap(*Self, init(av[0..ac]), Root.name);
	}
	inline fn init(av: []const Atom) !*Self {
		const self: *Self = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		const base: Base = try .init(obj, av);
		var rabbit: ra.Rabbit = try .init(obj, Root.nch);
		errdefer rabbit.deinit();

		var rubber: ru.Rubber = try .init(obj, Root.nch, av);
		errdefer rubber.deinit();

		var planar: [Root.nch][*]Sample = undefined;
		inline for (0..Root.nch) |ch| {
			const slice = try gpa.alloc(Sample, ra.frames);
			planar[ch] = slice.ptr;
		}
		self.* = .{
			.base = base,
			.rabbit = rabbit,
			.rubber = rubber,
			.planar = planar,
		};
		return self;
	}

	fn deinitC(self: *Self) callconv(.c) void {
		self.base.deinit();
		self.rabbit.deinit();
		self.rubber.deinit();
		inline for (0..Root.nch) |ch| {
			gpa.free(self.planar[ch][0..ra.frames]);
		}
	}

	fn classFreeC(_: *pd.Class) callconv(.c) void {
		Base.freeDict();
		ru.freeDict();
	}

	pub inline fn setup() !void {
		class = try .init(Self, Root.name, &.{ .gimme }, &initC, &deinitC, .{});
		try BaseImpl.extend();
		try Rubber.extend();
		Rabbit.extend();
		Player.extend();
		class.setFreeFn(&classFreeC);
	}
};}
