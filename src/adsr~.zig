//! Attack/decay/sustain/release envelope generator.

const pd = @import("pd");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Sample = pd.Sample;
const Symbol = pd.Symbol;
const Float = pd.Float;

const Adsr = extern struct {
	obj: pd.Object,
	/// ramp periods
	ramps: [3]Ramp = @splat(.{}),
	/// per-sample increment
	inc: Sample = 0,
	/// current value
	value: Sample = 0,
	/// attack target value
	peak: Sample = 1,
	/// decay target value
	sustain: Sample,
	/// attack duration
	attack: Float,
	/// decay duration
	decay: Float,
	/// release duration
	release: Float,
	/// samples per millisecond
	ratio: Float = 0,
	b: packed struct(u8) {
		/// restart envelope
		retarget: bool = false,
		/// jump to zero before next attack
		delay: bool = false,
		/// release a sustain or an attack/decay in progress
		release: bool = false,
		/// ramp index
		index: u5 = 0,
	} = .{},

	const Ramp = @import("ramp.zig").Ramp(@This());

	const name = "adsr~";
	var class: *pd.Class = undefined;
	const parentPtr = pd.parentPtr(Adsr);

	fn performC(w: [*]usize) callconv(.c) [*]usize {
		const self: *Adsr = @ptrFromInt(w[1]);
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
				self.ramps[2].reset(self.ratio * self.decay, self.sustain * self.peak);
			}
			self.ramps[self.b.index].setInc(self);
			self.b.retarget = false;
		}
		self.ramps[self.b.index].process(self, out);
		return w + 4;
	}

	fn dspC(p: *Pd, sp: [*]*pd.Signal) callconv(.c) void {
		const self = parentPtr(p);
		pd.dsp.add(performC, .{ self, sp[0].len, sp[0].vec });
		self.ratio = sp[0].srate / 1000;
	}

	fn bangC(p: *Pd) callconv(.c) void {
		const self = parentPtr(p);
		self.b.retarget = true;
	}

	fn floatC(p: *Pd, f: Float) callconv(.c) void {
		const self = parentPtr(p);
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

	fn stopC(p: *Pd) callconv(.c) void {
		const self = parentPtr(p);
		self.b.release = true;
		self.b.retarget = true;
	}

	fn list(self: *Adsr, av: []const Atom) void {
		sw: switch (@min(av.len, 4)) {
			4 => { if (av[3].getFloat()) |f| self.release = f; continue :sw 3; },
			3 => { if (av[2].getFloat()) |f| self.sustain = f; continue :sw 2; },
			2 => { if (av[1].getFloat()) |f| self.decay = f; continue :sw 1; },
			1 => { if (av[0].getFloat()) |f| self.attack = f; },
			else => {},
		}
	}

	fn listC(p: *Pd, _: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		const self = parentPtr(p);
		self.list(av[0..ac]);
	}

	fn anythingC(p: *Pd, s: *Symbol, ac: c_uint, av: [*]const Atom) callconv(.c) void {
		var buf: [4]Atom = undefined;
		buf[0] = .symbol(s);
		const len = @min(ac, 3);
		@memcpy(buf[1..][0..len], av[0..len]);
		parentPtr(p).list(buf[0 .. 1 + len]);
	}

	fn attackC(p: *Pd, f: Float) callconv(.c) void {
		parentPtr(p).attack = f;
	}

	fn decayC(p: *Pd, f: Float) callconv(.c) void {
		parentPtr(p).decay = f;
	}

	fn sustainC(p: *Pd, f: Float) callconv(.c) void {
		parentPtr(p).sustain = f;
	}

	fn releaseC(p: *Pd, f: Float) callconv(.c) void {
		parentPtr(p).release = f;
	}

	fn initC(a: Float, d: Float, s: Float, r: Float) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(a, d, s, r), name);
	}
	inline fn init(a: Float, d: Float, s: Float, r: Float) !*Pd {
		const self: *Adsr = try pd.gpa.create(Adsr);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		_ = try obj.inletFloat(&self.attack);
		_ = try obj.inletFloat(&self.decay);
		_ = try obj.inletFloat(&self.sustain);
		_ = try obj.inletFloat(&self.release);
		_ = try obj.outlet(pd.s.signal());

		self.* = .{
			.obj = self.obj,
			.attack = a,
			.decay = d,
			.sustain = s,
			.release = r,
		};
		return &obj.g.pd;
	}

	inline fn setup() !void {
		const args: [4]Atom.Type = @splat(.deffloat);
		class = try .init(Adsr, name, &args, initC, null, .{});
		class.addBang(bangC);
		class.addFloat(floatC);
		class.addList(listC);
		class.addAnything(anythingC);
		class.addMethod(&.{ .cant }, dspC, .gen("dsp"));
		class.addMethod(&.{ .float }, attackC, .gen("a"));
		class.addMethod(&.{ .float }, decayC, .gen("d"));
		class.addMethod(&.{ .float }, sustainC, .gen("s"));
		class.addMethod(&.{ .float }, releaseC, .gen("r"));
		class.addMethod(&.{}, stopC, .gen("stop"));
	}
};

export fn adsr_tilde_setup() void {
	_ = pd.wrap(void, Adsr.setup(), @src().fn_name);
}
