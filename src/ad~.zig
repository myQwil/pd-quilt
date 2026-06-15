//! Attack/decay envelope generator.

const pd = @import("pd");

const Atom = pd.Atom;
const Sample = pd.Sample;
const Symbol = pd.Symbol;
const Float = pd.Float;

const AttackDecay = extern struct {
	obj: pd.Object,
	/// ramp periods
	ramps: [3]Ramp = @splat(.{}),
	/// per-sample increment
	inc: Sample = 0,
	/// current value
	value: Sample = 0,
	/// attack target value
	peak: Sample = 1,
	/// attack duration
	attack: Float,
	/// decay duration
	decay: Float,
	/// release duration
	release: Float = 10,
	/// samples per millisecond
	ratio: Float = 0,
	b: packed struct(u8) {
		/// restart envelope
		retarget: bool = false,
		/// jump to zero before next attack
		delay: bool = false,
		/// release an attack/decay in progress
		release: bool = false,
		/// ramp index
		index: u5 = 0,
	} = .{},

	const Ramp = @import("ramp.zig").Ramp(@This());

	const name = "ad~";
	var class: *pd.Class = undefined;

	fn performC(w: [*]usize) callconv(.c) [*]usize {
		const self: *AttackDecay = @ptrFromInt(w[1]);
		const out = @as([*]Sample, @ptrFromInt(w[3]))[0..w[2]];

		if (self.b.retarget) {
			if (self.b.release) {
				self.b.index = 2;
				self.ramps[2].reset(self.ratio * self.release, 0);
				self.b.release = false;
			} else {
				if (self.b.delay) {
					self.ramps[0].reset(self.ratio * self.release, 0);
					self.b.index = 0;
				} else {
					self.b.index = 1;
				}
				self.ramps[1].reset(self.ratio * self.attack, self.peak);
				self.ramps[2].reset(self.ratio * self.decay, 0);
			}
			self.ramps[self.b.index].setInc(self);
			self.b.retarget = false;
		}
		self.ramps[self.b.index].process(self, out);
		return w + 4;
	}

	fn dspC(self: *AttackDecay, sp: [*]*pd.Signal) callconv(.c) void {
		pd.dsp.add(&performC, .{ self, sp[0].len, sp[0].vec });
		self.ratio = sp[0].srate / 1000;
	}

	fn bangC(self: *AttackDecay) callconv(.c) void {
		self.b.retarget = true;
	}

	fn floatC(self: *AttackDecay, f: Float) callconv(.c) void {
		if (f == 0) {
			self.b.release = true;
		} else if (f < 0) {
			self.b.delay = true;
			self.peak = -f;
		} else {
			self.b.delay = false;
			self.peak = f;
		}
		self.b.retarget = true;
	}

	fn stopC(self: *AttackDecay) callconv(.c) void {
		self.b.release = true;
		self.b.retarget = true;
	}

	fn list(self: *AttackDecay, av: []const Atom) void {
		sw: switch (@min(av.len, 2)) {
			2 => { if (av[1].getFloat()) |f| self.decay = f; continue :sw 1; },
			1 => { if (av[0].getFloat()) |f| self.attack = f; },
			else => {},
		}
	}

	fn listC(
		self: *AttackDecay,
		_: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		self.list(av[0..ac]);
	}

	fn anythingC(
		self: *AttackDecay,
		s: *Symbol, ac: c_uint, av: [*]const Atom,
	) callconv(.c) void {
		if (ac > 0) {
			self.list(&.{ .symbol(s), av[0] });
		}
	}

	fn attackC(self: *AttackDecay, f: Float) callconv(.c) void {
		self.attack = f;
	}

	fn decayC(self: *AttackDecay, f: Float) callconv(.c) void {
		self.decay = f;
	}

	fn releaseC(self: *AttackDecay, f: Float) callconv(.c) void {
		self.release = f;
	}

	fn initC(a: Float, d: Float) callconv(.c) ?*AttackDecay {
		return pd.wrap(*AttackDecay, init(a, d), name);
	}
	inline fn init(a: Float, d: Float) !*AttackDecay {
		const self: *AttackDecay = @ptrCast(try class.pd());
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inletFloat(&self.attack);
		_ = try obj.inletFloat(&self.decay);
		_ = try obj.outlet(pd.s.signal());

		self.* = .{
			.obj = self.obj,
			.attack = a,
			.decay = d,
		};
		return self;
	}

	inline fn setup() !void {
		const args: []const Atom.Type = &.{
			.deffloat,
			.deffloat,
		};
		class = try .init(AttackDecay, name, args, &initC, null, .{});
		class.addBang(@ptrCast(&bangC));
		class.addFloat(@ptrCast(&floatC));
		class.addList(@ptrCast(&listC));
		class.addAnything(@ptrCast(&anythingC));
		class.addMethod(@ptrCast(&dspC), .gen("dsp"), &.{ .cant });
		class.addMethod(@ptrCast(&attackC), .gen("a"), &.{ .float });
		class.addMethod(@ptrCast(&decayC), .gen("d"), &.{ .float });
		class.addMethod(@ptrCast(&releaseC), .gen("r"), &.{ .float });
		class.addMethod(@ptrCast(&stopC), .gen("stop"), &.{});
	}
};

export fn ad_tilde_setup() void {
	_ = pd.wrap(void, AttackDecay.setup(), @src().fn_name);
}
