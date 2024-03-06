pub usingnamespace @import("toggle.zig");
const pd = @This();
const A = pd.AtomType;

extern fn parsetimeunits(*anyopaque, pd.Float, *pd.Symbol, *pd.Float, *u32) void;

pub const Timer = extern struct {
	const Self = @This();

	obj: pd.Object,
	o_pause: *pd.Outlet,
	unitname: *pd.Symbol,
	unit: pd.Float,
	samps: u32,
	pause: pd.Tgl,

	pub inline fn time_since(self: *Self, f: f64) f64 {
		return pd.getTimeSinceWithUnits(f, @floatCast(self.unit), self.samps);
	}

	pub inline fn parse_units(self: *Self, av: []pd.Atom) void {
		for (av[0..@min(av.len, 2)]) |a| {
			switch (a.type) {
				A.FLOAT => self.unit = a.w.float,
				A.SYMBOL => self.unitname = a.w.symbol,
				else => {},
			}
		}
		parsetimeunits(self, self.unit, self.unitname, &self.unit, &self.samps);
	}

	pub inline fn set_pause(self: *Self, state: bool) void {
		if (self.pause.set(state)) {
			self.o_pause.float(@floatFromInt(@intFromBool(self.pause.state)));
		}
	}

	pub inline fn tgl_pause(self: *Self, av: []pd.Atom) bool {
		const changed = self.pause.toggle(av);
		if (changed) {
			self.o_pause.float(@floatFromInt(@intFromBool(self.pause.state)));
		}
		return changed;
	}

	pub inline fn init(self: *Self, av: []pd.Atom) void {
		self.unit = 1;
		self.samps = 0;
		self.unitname = pd.symbol("msec");
		self.o_pause = self.obj.outlet(pd.s.float);
		if (av.len >= 1) {
			self.parse_units(av);
		}
	}
};
