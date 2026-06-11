const pd = @import("pd");

const Sample = pd.Sample;
const Float = pd.Float;

pub fn Ramp(Owner: type) type { return extern struct {
	/// remaining samples
	remain: usize = 0,
	/// target value
	target: Sample = 0,

	const Self = @This();

	pub inline fn setInc(self: *const Self, owner: *Owner) void {
		owner.inc = (self.target - owner.value) / @as(Sample, @floatFromInt(self.remain));
	}

	pub inline fn reset(self: *Self, samples: Float, target: Sample) void {
		self.remain = @intFromFloat(@max(1, samples));
		self.target = target;
	}

	pub inline fn process(self: *Self, owner: *Owner, output: []Sample) void {
		var ramp = self;
		var out = output;
		while (true) {
			var f = owner.value;
			if (ramp.remain > out.len) {
				for (out) |*o| {
					o.* = f;
					f += owner.inc;
				}
				ramp.remain -= out.len;
				owner.value = f;
			} else {
				for (out[0..ramp.remain]) |*o| {
					o.* = f;
					f += owner.inc;
				}
				owner.value = ramp.target;
				if (owner.b.index < owner.ramps.len - 1) {
					owner.b.index += 1;
					out = out[ramp.remain..];
					ramp = &owner.ramps[owner.b.index];
					ramp.setInc(owner);
					continue;
				} else {
					@memset(out[ramp.remain..], owner.value);
					ramp.remain = 0;
				}
			}
			break;
		}
	}
};}
