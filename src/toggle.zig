pub usingnamespace @import("pd.zig");
const pd = @This();

pub const Tgl = extern struct {
	const Self = @This();

	state: bool,

	pub inline fn set(self: *Self, state: bool) bool {
		if (self.state == state) {
			return false;
		}
		self.state = state;
		return true;
	}

	pub inline fn toggle(self: *Self, av: []pd.Atom) bool {
		return self.set(if (av.len >= 1 and av[0].type == pd.AtomType.FLOAT)
			(av[0].w.float != 0) else !self.state);
	}
};
