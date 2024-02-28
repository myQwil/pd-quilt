pub const unitbit32 = 0x3p19; // bit 32 has place value 1
pub const hioffset: u1 = blk: {
	const builtin = @import("builtin");
	break :blk if (builtin.target.cpu.arch.endian() == .little) 1 else 0;
};

pub const TabFudge = extern union {
	d: f64,
	i: [2]i32,
};
