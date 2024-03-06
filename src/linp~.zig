const pd = @import("pd");
const tg = @import("toggle.zig");

const LinPTilde = extern struct {
	const Self = @This();
	var class: *pd.Class = undefined;

	obj: pd.Object,
	o_pause: *pd.Outlet,
	target: pd.Sample,
	value: pd.Sample,
	biginc: pd.Sample,
	inc: pd.Sample,
	invn: pd.Float,
	dspticktomsec: pd.Float,
	inletvalue: pd.Float,
	inletwas: pd.Float,
	ticksleft: u32,
	retarget: bool,
	paused: bool,

	fn tglPause(self: *Self, av: []const pd.Atom) bool {
		const changed = tg.toggle(&self.paused, av);
		if (changed) {
			self.o_pause.float(@floatFromInt(@intFromBool(self.paused)));
		}
		return changed;
	}

	fn perform(w: [*]usize) *usize {
		const n = w[1];
		const self: *Self = @ptrFromInt(w[2]);
		const out: [*]pd.Sample = @ptrFromInt(w[3]);

		if (pd.bigOrSmall(self.value)) {
			self.value = 0;
		}
		if (self.retarget) {
			const nticks = @max(1,
				@as(u32, @intFromFloat(self.inletwas * self.dspticktomsec)));
			self.ticksleft = nticks;
			self.biginc = (self.target - self.value)
				/ @as(pd.Sample, @floatFromInt(nticks));
			self.inc = self.invn * self.biginc;
			self.retarget = false;
		}

		if (!self.paused) {
			if (self.ticksleft > 0) {
				var f = self.value;
				for (out[0..n]) |*o| {
					o.* = f;
					f += self.inc;
				}
				self.value += self.biginc;
				self.ticksleft -= 1;
				return &w[4];
			} else {
				self.value = self.target;
			}
		}

		const f = self.value;
		for (out[0..n]) |*o| {
			o.* = f;
		}
		return &w[4];
	}

	fn dsp(self: *Self, sp: [*]*pd.Signal) void {
		// if (sp[0].s_un.s_n & 7) {
			pd.dsp.add(@ptrCast(&perform), 3, sp[0].len, self, sp[0].vec);
		// } else {
			// dsp_add(@ptrCast(&perf8), 3, self, sp[0].s_un.s_n, sp[0].s_vec);
		// }
		self.invn = 1 / @as(pd.Float, @floatFromInt(sp[0].len));
		self.dspticktomsec = sp[0].srate
			/ @as(pd.Float, @floatFromInt(1000 * sp[0].len));
	}

	fn stop(self: *Self) void {
		self.target = self.value;
		self.ticksleft = 0;
		self.retarget = false;
	}

	fn pause(self: *Self, _: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom) void {
		if (!self.tglPause(av[0..ac]) or self.value == self.target) {
			return;
		}
	}

	fn float(self: *Self, f: pd.Float) void {
		if (self.inletvalue <= 0) {
			self.target = f;
			self.value = f;
			self.ticksleft = 0;
			self.retarget = false;
		} else {
			self.target = f;
			self.inletwas = self.inletvalue;
			self.inletvalue = 0;
			self.retarget = true;
			if (tg.set(&self.paused, false)) {
				self.o_pause.float(@floatFromInt(@intFromBool(self.paused)));
			}
		}
	}

	fn new() ?*Self {
		const self: *Self = @ptrCast(class.new() orelse return null);
		const obj = &self.obj;
		_ = obj.inletFloat(&self.inletvalue);
		_ = obj.outlet(pd.s.signal);
		self.o_pause = obj.outlet(pd.s.float).?;
		self.paused = false;
		self.retarget = false;
		self.ticksleft = 0;
		self.value = 0;
		self.target = 0;
		self.inletvalue = 0;
		self.inletwas = 0;
		return self;
	}

	fn setup() void {
		class = pd.class(pd.symbol("linp~"), @ptrCast(&new), null,
			@sizeOf(Self), .{}, &.{}).?;

		class.addFloat(@ptrCast(&float));
		class.addMethod(@ptrCast(&stop), pd.symbol("stop"), &.{});
		class.addMethod(@ptrCast(&dsp), pd.symbol("dsp"), &.{ .cant });
		class.addMethod(@ptrCast(&pause), pd.symbol("pause"), &.{ .gimme });
	}
};

export fn linp_tilde_setup() void {
	LinPTilde.setup();
}
