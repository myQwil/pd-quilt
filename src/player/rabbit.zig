const pd = @import("pd");
const ra = @import("rabbit");
const Inlet = @import("../misc/inlet.zig").Inlet;
pub const uint = ra.uint;
pub const InitError = ra.Error || pd.Oom;

const Pd = pd.Pd;
const Float = pd.Float;

pub const frames = 0x10;

/// fastest speed gets stuck if it's too close to the exact number of frames
pub const fastest: f64 = @as(Float, @floatFromInt(frames)) - 0x1p-7;
pub const slowest: f64 = 1 / @as(Float, @floatFromInt(frames));

pub const Rabbit = struct {
	data: ra.Data,
	state: *ra.State,
	speed: *Float,

	pub inline fn init(obj: *pd.Object, channels: u8) InitError!Rabbit {
		const inlet: *Inlet = @ptrCast(@alignCast(try obj.inletSignal(1.0)));
		return .{
			.state = try .create(.sinc_fast, channels),
			.speed = &inlet.un.floatsignalvalue,
			.data = .{
				.data_in = undefined,
				.data_out = undefined,
				.output_frames = frames,
			},
		};
	}

	pub inline fn deinit(self: *const Rabbit) void {
		self.state.destroy();
	}

	pub inline fn conv(self: *Rabbit, i: uint, nch: uint) ra.Error!void {
		try ra.Converter.expectValid(i);
		const new_state: *ra.State = try .create(@enumFromInt(i), nch);
		self.state.destroy();
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
	const conv: fn(*Pd, uint) callconv(.@"inline") void = Self.conv;
	const Box = Self.Box;

	fn convC(p: *Pd, f: Float) callconv(.c) void {
		conv(p, @trunc(f));
	}

	fn speedC(p: *Pd, f: Float) callconv(.c) void {
		const self = Box.state(p);
		const rabbit: *Rabbit = &self.rabbit;
		rabbit.speed.* = f;
	}

	pub inline fn extend() void {
		const class: *pd.Class = Self.class;
		class.addMethod(&.{ .float }, convC, .gen("conv"));
		class.addMethod(&.{ .float }, speedC, .gen("speed"));
	}
};}
