const std = @import("std");
const Float = @import("pd").Float;

pub const float_bits = @bitSizeOf(Float);
pub const mantissa_bits = std.math.floatMantissaBits(Float);
pub const exponent_bits = std.math.floatExponentBits(Float);

pub const Uf = std.meta.Int(.unsigned, float_bits);
pub const Um = std.meta.Int(.unsigned, mantissa_bits);
pub const Ue = std.meta.Int(.unsigned, exponent_bits);

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
