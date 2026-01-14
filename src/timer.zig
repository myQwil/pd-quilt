const pd = @import("pd");
const tg = @import("toggle.zig");

const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;
const TimeUnit = pd.TimeUnit;

fn unitFromArgs(av: []const Atom) !TimeUnit {
	var amount: Float = 1;
	var name: *Symbol = .gen("ms");
	for (av[0..@min(av.len, 2)]) |*a| {
		if (a.type == .float) {
			amount = a.w.float;
		} else {
			name = a.w.symbol;
		}
	}
	return try .init(amount, name);
}

pub const Timer = extern struct {
	/// Outputs the state of `paused`.
	outlet: *pd.Outlet,
	unit: TimeUnit,
	paused: bool = true,

	pub fn init(obj: *pd.Object, av: []const Atom) !Timer {
		return .{
			.outlet = try .init(obj, &pd.s_float),
			.unit = if (av.len > 0) try unitFromArgs(av) else .{},
		};
	}

	pub inline fn timeSince(self: *const Timer, f: f64) f64 {
		return self.unit.timeSince(f);
	}

	pub fn parseUnits(self: *Timer, av: []const Atom) !void {
		self.unit = try unitFromArgs(av);
	}

	pub inline fn setPause(self: *Timer, state: bool) void {
		if (tg.set(&self.paused, state)) {
			self.outlet.float(@floatFromInt(@intFromBool(self.paused)));
		}
	}

	pub inline fn tglPause(self: *Timer, av: []const Atom) bool {
		const changed = tg.toggle(&self.paused, av);
		if (changed) {
			self.outlet.float(@floatFromInt(@intFromBool(self.paused)));
		}
		return changed;
	}
};
