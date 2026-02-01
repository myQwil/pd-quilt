const std = @import("std");
const pd = @import("pd");

const Float = pd.Float;

var seed: u32 = undefined;
const io = std.Io.Threaded.global_single_threaded.ioBasic();

pub const Rng = extern struct {
	state: u32,

	pub inline fn next(self: *Rng) Float {
		self.state = self.state *% 472940017 +% 832416023;
		return @as(Float, @floatFromInt(self.state)) * 0x1p-32;
	}

	pub inline fn init() Rng {
		seed = seed *% 435898247 +% 938284287;
		return .{ .state = seed };
	}
};

pub fn Impl(Self: type) type { return struct {
	fn stateC(self: *const Self) callconv(.c) void {
		const rng: *const Rng = &self.rng;
		pd.post.log(self, .normal, "%u", .{ rng.state });
	}

	fn seedC(self: *Self, f: Float) callconv(.c) void {
		const rng: *Rng = &self.rng;
		rng.state = @intFromFloat(f);
	}

	pub inline fn extend() !void {
		io.random(std.mem.asBytes(&seed));
		seed |= 1; // odd numbers only

		const class: *pd.Class = Self.class;
		class.addMethod(@ptrCast(&seedC), .gen("seed"), &.{ .float });
		class.addMethod(@ptrCast(&stateC), .gen("state"), &.{});
	}
};}
