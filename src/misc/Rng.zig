const Rng = @This();

const pd = @import("pd");
const std = @import("std");

const Pd = pd.Pd;
const Float = pd.Float;

state: u32,

var seed: u32 = undefined;

pub inline fn next(self: *Rng) Float {
	self.state = self.state *% 472940017 +% 832416023;
	return @as(Float, @floatFromInt(self.state)) * 0x1p-32;
}

pub inline fn init() Rng {
	seed = seed *% 435898247 +% 938284287;
	return .{ .state = seed };
}

pub fn Impl(Self: type) type { return struct {
	fn stateC(p: *const Pd) callconv(.c) void {
		pd.post.log(p, .normal, "%u", .{ Self.Box.stateConst(p).rng.state });
	}

	fn seedC(p: *Pd, f: Float) callconv(.c) void {
		Self.Box.state(p).rng.state = @intFromFloat(f);
	}

	pub inline fn extend(io: std.Io) void {
		io.random(std.mem.asBytes(&seed));
		seed |= 1; // odd numbers only

		const class: *pd.Class = Self.class;
		class.addMethod(&.{ .float }, seedC, .gen("seed"));
		class.addMethod(&.{}, stateC, .gen("state"));
	}
};}
