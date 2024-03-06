pub usingnamespace @import("pd.zig");
const pd = @This();

pub const um = if (pd.Float == f64) u52 else u23;
pub const ue = if (pd.Float == f64) u11 else u8;

pub const UFloat = packed union {
	b: packed struct {
		mantissa: um,
		exponent: ue,
		sign: u1,
	},
	u: pd.FloatUInt,
	f: pd.Float,
};
