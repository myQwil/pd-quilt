const pd = @import("pd");
const tg = @import("toggle.zig");

const Atom = pd.Atom;
const Float = pd.Float;
const Symbol = pd.Symbol;

const parseTimeUnits = parsetimeunits;
extern fn parsetimeunits(*anyopaque, Float, *Symbol, *Float, *c_int) void;

pub const Timer = extern struct {
	/// Outputs the state of `paused`.
	outlet: *pd.Outlet,
	unitname: *Symbol,
	unit: Float = 1,
	in_samples: bool = false,
	paused: bool = false,

	pub inline fn init(obj: *pd.Object, av: []const Atom) !Timer {
		var self: Timer = .{
			.outlet = try .init(obj, &pd.s_float),
			.unitname = .gen("msec"),
		};
		if (av.len >= 1) {
			self.parseUnits(av);
		}
		return self;
	}

	pub inline fn timeSince(self: *const Timer, f: f64) f64 {
		return pd.timeSinceWithUnits(f, @floatCast(self.unit), self.in_samples);
	}

	pub inline fn parseUnits(self: *Timer, av: []const Atom) void {
		for (av[0..@min(av.len, 2)]) |*a| {
			if (a.type == .float) {
				self.unit = a.w.float;
			} else {
				self.unitname = a.w.symbol;
			}
		}
		var samps: c_int = undefined;
		parseTimeUnits(self, self.unit, self.unitname, &self.unit, &samps);
		self.in_samples = (samps != 0);
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
