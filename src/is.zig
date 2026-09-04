//! Checks an atom's type.

const pd = @import("pd");

const Pd = pd.Pd;
const Atom = pd.Atom;
const Symbol = pd.Symbol;

const Proxy = extern struct {
	obj: pd.Pd,
	owner: *Is,

	const name = "_is_pxy";
	var class: *pd.Class = undefined;

	fn anythingC(p: *const Pd, s: *Symbol, _: c_uint, _: [*]const Atom) callconv(.c) void {
		const self: *const Proxy = @fieldParentPtr("obj", p);
		self.owner.type = s;
	}

	inline fn create(owner: *Is) pd.Oom!*Proxy {
		const self: *Proxy = try pd.gpa.create(Proxy);
		self.obj = .{ .class = class };
		self.* = .{
			.obj = self.obj,
			.owner = owner,
		};
		return self;
	}

	inline fn setup() pd.Class.Error!void {
		const opts: pd.Class.Options = .{ .bare = true, .no_inlet = true };
		class = try .create(name, &.{}, null, null, @sizeOf(Proxy), opts);
		class.addAnything(&anythingC);
	}
};

const Is = extern struct {
	obj: pd.Object,
	out: *pd.Outlet,
	type: *Symbol,
	proxy: *Proxy,

	const name = "is";
	var class: *pd.Class = undefined;
	const parentPtr = pd.parentPtr(Is, "obj");
	const parentConstPtr = pd.parentConstPtr(Is, "obj");

	fn printC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		pd.post.log(self, .normal, name ++ ": %s", .{ self.type.name });
	}

	fn bangC(p: *const Pd) callconv(.c) void {
		const self = parentConstPtr(p);
		self.out.float(if (self.type == pd.s.bang()) 1.0 else 0.0);
	}

	fn anythingC(p: *const Pd, s: *Symbol, ac: c_uint, _: [*]const Atom) callconv(.c) void {
		const self = parentConstPtr(p);
		const t: *Symbol = if (ac > 0) s else pd.s.symbol();
		self.out.float(if (self.type == t) 1 else 0);
	}

	fn setC(p: *Pd, s: *Symbol) callconv(.c) void {
		parentPtr(p).type = s;
	}

	fn createC(s: *Symbol) callconv(.c) ?*Pd {
		return pd.wrap(*Pd, create(s), name);
	}
	inline fn create(s: *Symbol) pd.Oom!*Pd {
		const self: *Is = try pd.gpa.create(Is);
		self.obj = .{ .g = .{ .pd = .{ .class = class } } };
		const obj: *pd.Object = &self.obj;
		errdefer obj.g.pd.destroy();

		const proxy: *Proxy = try .create(self);
		errdefer proxy.obj.destroy();

		_ = try obj.inlet(&proxy.obj, null, null);
		self.* = .{
			.obj = self.obj,
			.out = try .create(obj, pd.s.float()),
			.type = if (s != pd.s.empty()) s else pd.s.float(),
			.proxy = proxy,
		};
		return &obj.g.pd;
	}

	fn destroyC(p: *const Pd) callconv(.c) void {
		parentConstPtr(p).proxy.obj.destroy();
	}

	inline fn setup() pd.Class.Error!void {
		class = try .create(name, &.{ .defsymbol }, createC, destroyC, @sizeOf(Is), .{});
		class.addBang(&bangC);
		class.addAnything(&anythingC);
		class.addMethod(&.{}, &printC, .gen("print"));
		class.addMethod(&.{ .symbol }, &setC, .gen("set"));
		try Proxy.setup();
	}
};

export fn is_setup() void {
	_ = pd.wrap(void, Is.setup(), @src().fn_name);
}
