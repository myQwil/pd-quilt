const pd = @import("pd");

/// returns `true` if new state is different from current state
pub inline fn set(state: *bool, new_state: bool) bool {
	return if (state.* == new_state) false else blk: {
		state.* = new_state;
		break :blk true;
	};
}

/// toggle state, or set to arg if one is given
///
/// returns `true` if new state is different from current state
pub inline fn toggle(state: *bool, av: []const pd.Atom) bool {
	return set(state, if (pd.floatArg(0, av)) |f| (f != 0) else |_| !state.*);
}
