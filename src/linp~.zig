const pd = @import("pd");
const tg = @import("toggle.zig");

const Sample = pd.Sample;
const Float = pd.Float;

const LinPSignal = extern struct {
	obj: pd.Object = undefined,
	o_pause: *pd.Outlet,
	target: Sample = 0,
	value: Sample = 0,
	biginc: Sample = 0,
	inc: Sample = 0,
	invn: Float = 0,
	dspticktomsec: Float = 0,
	inletvalue: Float = 0,
	inletwas: Float = 0,
	ticksleft: u32 = 0,
	retarget: bool = false,
	paused: bool = false,

	const name = "linp~";
	var class: *pd.Class = undefined;

	fn tglPause(self: *LinPSignal, av: []const pd.Atom) bool {
		const changed = tg.toggle(&self.paused, av);
		if (changed) {
			self.o_pause.float(@floatFromInt(@intFromBool(self.paused)));
		}
		return changed;
	}

	fn performC(w: [*]usize) callconv(.c) [*]usize {
		const self: *LinPSignal = @ptrFromInt(w[1]);
		const out = @as([*]Sample, @ptrFromInt(w[3]))[0..w[2]];

		if (pd.bigOrSmall(self.value)) {
			self.value = 0;
		}
		if (self.retarget) {
			const nticks = @max(1,
				@as(u32, @intFromFloat(self.inletwas * self.dspticktomsec)));
			self.ticksleft = nticks;
			self.biginc = (self.target - self.value)
				/ @as(Sample, @floatFromInt(nticks));
			self.inc = self.invn * self.biginc;
			self.retarget = false;
		}

		if (!self.paused) {
			if (self.ticksleft > 0) {
				var f = self.value;
				for (out) |*o| {
					o.* = f;
					f += self.inc;
				}
				self.value += self.biginc;
				self.ticksleft -= 1;
				return w + 4;
			} else {
				self.value = self.target;
			}
		}
		@memset(out, self.value);
		return w + 4;
	}

	fn dspC(self: *LinPSignal, sp: [*]*pd.Signal) callconv(.c) void {
		pd.dsp.add(&performC, .{ self, sp[0].len, sp[0].vec });
		self.invn = 1 / @as(Float, @floatFromInt(sp[0].len));
		self.dspticktomsec = sp[0].srate
			/ @as(Float, @floatFromInt(1000 * sp[0].len));
	}

	fn stopC(self: *LinPSignal) callconv(.c) void {
		self.target = self.value;
		self.ticksleft = 0;
		self.retarget = false;
	}

	fn pauseC(
		self: *LinPSignal,
		_: *pd.Symbol, ac: c_uint, av: [*]const pd.Atom,
	) callconv(.c) void {
		_ = self.tglPause(av[0..ac]);
	}

	fn floatC(self: *LinPSignal, f: Float) callconv(.c) void {
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

	fn initC() callconv(.c) ?*LinPSignal {
		return pd.wrap(*LinPSignal, init(), name);
	}
	inline fn init() !*LinPSignal {
		const self: *LinPSignal = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inletFloat(&self.inletvalue);
		_ = try obj.outlet(&pd.s_signal);

		self.* = .{
			.o_pause = try .init(obj, &pd.s_float),
		};
		return self;
	}

	inline fn setup() !void {
		class = try .init(LinPSignal, name, &.{}, &initC, null, .{});
		class.addFloat(@ptrCast(&floatC));
		class.addMethod(@ptrCast(&stopC), .gen("stop"), &.{});
		class.addMethod(@ptrCast(&dspC), .gen("dsp"), &.{ .cant });
		class.addMethod(@ptrCast(&pauseC), .gen("pause"), &.{ .gimme });
	}
};

export fn linp_tilde_setup() void {
	_ = pd.wrap(void, LinPSignal.setup(), @src().fn_name);
}
