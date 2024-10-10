const pd = @import("pd");
const rb = @import("rabbit");

pub const frames = 16;
// fastest speed gets stuck if it's too close to the exact number of frames
const fastest: pd.Float = frames - 0x1p-7;
const slowest: pd.Float = 1 / @as(pd.Float, @floatFromInt(frames));

pub const Rabbit = extern struct {
	const Self = @This();

	state: *rb.State,
	data: rb.Data,
	ratio: f64, // audio_file_samplerate / pd_samplerate

	pub fn setSpeed(self: *Self, f: pd.Float) void {
		self.data.ratio = 1 / @min(@max(slowest, f * self.ratio), fastest);
	}

	pub fn reset(self: *Self) rb.Error!void {
		try self.state.reset();
		self.data.in_frames = 0;
		self.data.out_frames_gen = 0;
	}

	pub fn setConverter(self: *Self, i: i32, nch: u32) rb.Error!void {
		try rb.Converter.expectValid(i);
		const new_state = try rb.State.new(@enumFromInt(i), nch);
		self.state.delete();
		self.state = new_state;
	}

	pub fn init(self: *Self, nch: u32) rb.Error!void {
		self.state = try rb.State.new(.sinc_fast, nch);
		self.ratio = 1.0;
		self.data.ratio = 1.0;
		self.data.out_frames = frames;
	}
};
