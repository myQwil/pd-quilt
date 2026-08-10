//! Similar to `[change]` in that it sends different values through the left outlet,
//! but also sends repeat values through the right outlet.

const pd = @import("pd");

const Pd = pd.Pd;
const Float = pd.Float;

const Same = extern struct {
	obj: pd.Object,
	/// outlet used when `f` has changed
	out_diff: *pd.Outlet,
	/// outlet used when `f` has not changed
	out_same: *pd.Outlet,
	f: Float,

	const name = "same";
	var class: *pd.Class = undefined;
	const parentPtr = pd.parentPtr(Same);
	const parentConstPtr = pd.parentConstPtr(Same);

	fn bangC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		self.out_diff.float(self.f);
	}

	fn floatC(p: *Pd, f: Float) callconv(.c) void {
		const self = parentPtr(p);
		if (self.f != f) {
			self.f = f;
			self.out_diff.float(f);
		} else {
			self.out_same.float(f);
		}
	}

	fn setC(p: *Pd, f: Float) callconv(.c) void {
		parentPtr(p).f = f;
	}

	fn initC(f: Float) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, init(f), name);
	}
	inline fn init(f: Float) pd.Oom!*Pd {
		const self: *Same = try pd.gpa.create(Same);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.deinit();

		self.* = .{
			.obj = self.obj,
			.out_diff = try .init(obj, pd.s.float()),
			.out_same = try .init(obj, pd.s.float()),
			.f = f,
		};
		return &obj.g.pd;
	}

	inline fn setup() pd.Class.Error!void {
		class = try .init(Same, name, &.{ .deffloat }, initC, null, .{});
		class.addBang(bangC);
		class.addFloat(floatC);
		class.addMethod(&.{ .deffloat }, setC, .gen("set"));
	}
};

export fn same_setup() void {
	_ = pd.wrap(void, Same.setup(), @src().fn_name);
}
