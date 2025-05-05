const pd = @import("pd");
const pr = @import("player.zig");
const gm = @import("player.gme.zig");
const ra = @import("player.rabbit.zig");
const Inlet = @import("inlet.zig").Inlet;

const Atom = pd.Atom;
const Float = pd.Float;
const Sample = pd.Sample;

pub fn Impl(Root: type) type { return extern struct {
	obj: pd.Object = undefined,
	base: Base,
	rabbit: ra.Rabbit,
	tempo: *Float,

	const Self = @This();
	pub var class: *pd.Class = undefined;

	// Implementations
	pub const Base = gm.Base(Root.nch, ra.frames);
	const BaseImpl = Base.Impl(Self);
	const Player = pr.Impl(Self);
	const Rabbit = ra.Impl(Self);

	pub inline fn err(self: *const Self, e: anyerror) void {
		pd.post.err(self, Root.name ++ ": %s", .{ @errorName(e).ptr });
	}

	pub inline fn conv(self: *Self, i: c_uint) void {
		self.rabbit.conv(i, Root.nch) catch |e| self.err(e);
	}

	fn tempoC(self: *Self, f: Float) callconv(.c) void {
		self.tempo.* = f;
	}

	pub fn reset(self: *Self) void {
		self.rabbit.reset() catch |e| self.err(e);
	}

	pub fn restart(self: *Self) void {
		self.reset();
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
		const data = &self.rabbit.data;
		const raw: []i16 = &b.raw;
		var outs: [Root.nch][*]Sample = b.outs;

		while (i < n) {
			while (data.output_frames_gen <= 0) {
				if (data.input_frames <= 0) {
					emu.setTempo(inlet2[i]);
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
			const used: u8 = @min(@as(u8, @intCast(data.output_frames_gen)), n - i);
			data.data_out += pr.leavedToPlanar(data.data_out, &outs, Root.nch, used);
			inline for (0..Root.nch) |ch| {
				outs[ch] += used;
			}
			data.output_frames_gen -= used;
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

		const in3: *Inlet = @ptrCast(@alignCast(try obj.inletSignal(1.0)));
		self.* = .{
			.base = base,
			.rabbit = rabbit,
			.tempo = &in3.un.floatsignalvalue,
		};
		return self;
	}

	fn deinitC(self: *Self) callconv(.c) void {
		self.base.deinit();
		self.rabbit.deinit();
	}

	fn classFreeC(_: *pd.Class) callconv(.c) void {
		Base.freeDict();
	}

	pub inline fn setup() !void {
		class = try .init(Self, Root.name, &.{ .gimme }, &initC, &deinitC, .{});
		try BaseImpl.extend();
		Rabbit.extend();
		Player.extend();
		class.addMethod(@ptrCast(&tempoC), .gen("tempo"), &.{ .float });
		class.setFreeFn(&classFreeC);
	}
};}
