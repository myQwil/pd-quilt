const pd = @import("pd");
const ra = @import("rabbit");
const Inlet = @import("inlet.zig").Inlet;

const Float = pd.Float;

pub const frames = 0x10;

/// fastest speed gets stuck if it's too close to the exact number of frames
pub const fastest: f64 = @as(Float, @floatFromInt(frames)) - 0x1p-7;
pub const slowest: f64 = 1 / @as(Float, @floatFromInt(frames));

pub const Rabbit = extern struct {
	data: ra.Data,
	state: *ra.State,
	speed: *Float,

	pub inline fn init(obj: *pd.Object, channels: u8) !Rabbit {
		const inlet: *Inlet = @ptrCast(@alignCast(try obj.inletSignal(1.0)));
		return .{
			.state = try .init(.sinc_fast, channels),
			.speed = &inlet.un.floatsignalvalue,
			.data = .{
				.data_in = undefined,
				.data_out = undefined,
				.output_frames = frames,
			},
		};
	}

	pub inline fn deinit(self: *Rabbit) void {
		self.state.deinit();
	}

	pub inline fn conv(self: *Rabbit, i: c_uint, nch: c_uint) ra.Error!void {
		try ra.Converter.expectValid(i);
		const new_state: *ra.State = try .init(@enumFromInt(i), nch);
		self.state.deinit();
		self.state = new_state;
	}

	pub inline fn reset(self: *Rabbit) ra.Error!void {
		self.data.output_frames_gen = 0;
		self.data.input_frames = 0;
		try self.state.reset();
	}

	pub inline fn setRatio(self: *Rabbit, f: f64) void {
		self.data.src_ratio = 1 / @min(@max(slowest, f), fastest);
	}
};

pub fn Impl(Self: type) type { return struct {
	const conv: fn(*Self, c_uint) callconv(.@"inline") void = Self.conv;

	fn convC(self: *Self, f: Float) callconv(.c) void {
		conv(self, @intFromFloat(f));
	}

	fn speedC(self: *Self, f: Float) callconv(.c) void {
		const rabbit: *Rabbit = &self.rabbit;
		rabbit.speed.* = f;
	}

	pub inline fn extend() void {
		const class: *pd.Class = Self.class;
		class.addMethod(@ptrCast(&convC), .gen("conv"), &.{ .float });
		class.addMethod(@ptrCast(&speedC), .gen("speed"), &.{ .float });
	}
};}
