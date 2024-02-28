pub usingnamespace @import("pd.zig");
const pd = @This();

pub const Rng = extern struct {
	const Self = @This();
	var seed: u32 = 1489853723; // fallback value

	obj: pd.Object,
	state: u32,

	fn print_state(self: *const Self, s: *pd.Symbol) void {
		if (s.name[0] != '\x00') {
			pd.startpost("%s: ", s.name);
		}
		pd.post("%u", self.state);
	}

	fn set_seed(self: *Self, f: pd.Float) void {
		self.state = @intFromFloat(f);
	}

	pub inline fn next(self: *Self) pd.Float {
		self.state = self.state * 472940017 + 832416023;
		return @as(pd.Float, @floatFromInt(self.state)) * 0x1p-32;
	}

	pub inline fn init(self: *Self) void {
		seed = seed * 435898247 + 938284287;
	 	self.state = seed;
	}

	pub inline fn extend(class: *pd.Class) void {
		const std = @import("std");
		std.os.getrandom(std.mem.asBytes(&seed)) catch {};
		seed |= 1; // odd numbers only

		const A = pd.AtomType;
		class.addMethod(@ptrCast(&set_seed), pd.symbol("seed"), A.FLOAT, A.NULL);
		class.addMethod(@ptrCast(&print_state), pd.symbol("state"), A.DEFSYM, A.NULL);
	}
};
