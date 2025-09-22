const std = @import("std");
const Float = @import("pd").Float;

pub const float_bits = @bitSizeOf(Float);
pub const mantissa_bits = std.math.floatMantissaBits(Float);
pub const exponent_bits = std.math.floatExponentBits(Float);

pub const Uf = @Type(.{ .int = .{ .signedness = .unsigned, .bits = float_bits } });
pub const Um = @Type(.{ .int = .{ .signedness = .unsigned, .bits = mantissa_bits } });
pub const Ue = @Type(.{ .int = .{ .signedness = .unsigned, .bits = exponent_bits } });

pub const BitFloat = packed struct(Uf) {
	mantissa: Um,
	exponent: Ue,
	sign: u1,
};

pub const UnFloat = extern union {
	b: BitFloat,
	f: Float,
	u: Uf,
};
