const pd = @import("main.zig");
const iem = @import("iem.zig");
const cnv = @import("canvas.zig");
pub const __builtin_bswap16 = @import("std").zig.c_builtins.__builtin_bswap16;
pub const __builtin_bswap32 = @import("std").zig.c_builtins.__builtin_bswap32;
pub const __builtin_bswap64 = @import("std").zig.c_builtins.__builtin_bswap64;
pub const __builtin_signbit = @import("std").zig.c_builtins.__builtin_signbit;
pub const __builtin_signbitf = @import("std").zig.c_builtins.__builtin_signbitf;
pub const __builtin_popcount = @import("std").zig.c_builtins.__builtin_popcount;
pub const __builtin_ctz = @import("std").zig.c_builtins.__builtin_ctz;
pub const __builtin_clz = @import("std").zig.c_builtins.__builtin_clz;
pub const __builtin_sqrt = @import("std").zig.c_builtins.__builtin_sqrt;
pub const __builtin_sqrtf = @import("std").zig.c_builtins.__builtin_sqrtf;
pub const __builtin_sin = @import("std").zig.c_builtins.__builtin_sin;
pub const __builtin_sinf = @import("std").zig.c_builtins.__builtin_sinf;
pub const __builtin_cos = @import("std").zig.c_builtins.__builtin_cos;
pub const __builtin_cosf = @import("std").zig.c_builtins.__builtin_cosf;
pub const __builtin_exp = @import("std").zig.c_builtins.__builtin_exp;
pub const __builtin_expf = @import("std").zig.c_builtins.__builtin_expf;
pub const __builtin_exp2 = @import("std").zig.c_builtins.__builtin_exp2;
pub const __builtin_exp2f = @import("std").zig.c_builtins.__builtin_exp2f;
pub const __builtin_log = @import("std").zig.c_builtins.__builtin_log;
pub const __builtin_logf = @import("std").zig.c_builtins.__builtin_logf;
pub const __builtin_log2 = @import("std").zig.c_builtins.__builtin_log2;
pub const __builtin_log2f = @import("std").zig.c_builtins.__builtin_log2f;
pub const __builtin_log10 = @import("std").zig.c_builtins.__builtin_log10;
pub const __builtin_log10f = @import("std").zig.c_builtins.__builtin_log10f;
pub const __builtin_abs = @import("std").zig.c_builtins.__builtin_abs;
pub const __builtin_labs = @import("std").zig.c_builtins.__builtin_labs;
pub const __builtin_llabs = @import("std").zig.c_builtins.__builtin_llabs;
pub const __builtin_fabs = @import("std").zig.c_builtins.__builtin_fabs;
pub const __builtin_fabsf = @import("std").zig.c_builtins.__builtin_fabsf;
pub const __builtin_floor = @import("std").zig.c_builtins.__builtin_floor;
pub const __builtin_floorf = @import("std").zig.c_builtins.__builtin_floorf;
pub const __builtin_ceil = @import("std").zig.c_builtins.__builtin_ceil;
pub const __builtin_ceilf = @import("std").zig.c_builtins.__builtin_ceilf;
pub const __builtin_trunc = @import("std").zig.c_builtins.__builtin_trunc;
pub const __builtin_truncf = @import("std").zig.c_builtins.__builtin_truncf;
pub const __builtin_round = @import("std").zig.c_builtins.__builtin_round;
pub const __builtin_roundf = @import("std").zig.c_builtins.__builtin_roundf;
pub const __builtin_strlen = @import("std").zig.c_builtins.__builtin_strlen;
pub const __builtin_strcmp = @import("std").zig.c_builtins.__builtin_strcmp;
pub const __builtin_object_size = @import("std").zig.c_builtins.__builtin_object_size;
pub const __builtin___memset_chk = @import("std").zig.c_builtins.__builtin___memset_chk;
pub const __builtin_memset = @import("std").zig.c_builtins.__builtin_memset;
pub const __builtin___memcpy_chk = @import("std").zig.c_builtins.__builtin___memcpy_chk;
pub const __builtin_memcpy = @import("std").zig.c_builtins.__builtin_memcpy;
pub const __builtin_expect = @import("std").zig.c_builtins.__builtin_expect;
pub const __builtin_nanf = @import("std").zig.c_builtins.__builtin_nanf;
pub const __builtin_huge_valf = @import("std").zig.c_builtins.__builtin_huge_valf;
pub const __builtin_inff = @import("std").zig.c_builtins.__builtin_inff;
pub const __builtin_isnan = @import("std").zig.c_builtins.__builtin_isnan;
pub const __builtin_isinf = @import("std").zig.c_builtins.__builtin_isinf;
pub const __builtin_isinf_sign = @import("std").zig.c_builtins.__builtin_isinf_sign;
pub const __has_builtin = @import("std").zig.c_builtins.__has_builtin;
pub const __builtin_assume = @import("std").zig.c_builtins.__builtin_assume;
pub const __builtin_unreachable = @import("std").zig.c_builtins.__builtin_unreachable;
pub const __builtin_constant_p = @import("std").zig.c_builtins.__builtin_constant_p;
pub const __builtin_mul_overflow = @import("std").zig.c_builtins.__builtin_mul_overflow;
pub extern var pd_compatibilitylevel: c_int;
pub extern fn __assert_fail(__assertion: [*:0]const u8, __file: [*:0]const u8, __line: c_uint, __function: [*:0]const u8) noreturn;
pub extern fn __assert_perror_fail(__errnum: c_int, __file: [*:0]const u8, __line: c_uint, __function: [*:0]const u8) noreturn;
pub extern fn __assert(__assertion: [*:0]const u8, __file: [*:0]const u8, __line: c_int) noreturn;
pub const ptrdiff_t = c_long;
pub const wchar_t = c_int;
pub const max_align_t = extern struct {
    __clang_max_align_nonce1: c_longlong align(8) = @import("std").mem.zeroes(c_longlong),
    __clang_max_align_nonce2: c_longdouble align(16) = @import("std").mem.zeroes(c_longdouble),
};
pub const __u_char = u8;
pub const __u_short = c_ushort;
pub const __u_int = c_uint;
pub const __u_long = c_ulong;
pub const __int8_t = i8;
pub const __uint8_t = u8;
pub const __int16_t = c_short;
pub const __uint16_t = c_ushort;
pub const __int32_t = c_int;
pub const __uint32_t = c_uint;
pub const __int64_t = c_long;
pub const __uint64_t = c_ulong;
pub const __int_least8_t = __int8_t;
pub const __uint_least8_t = __uint8_t;
pub const __int_least16_t = __int16_t;
pub const __uint_least16_t = __uint16_t;
pub const __int_least32_t = __int32_t;
pub const __uint_least32_t = __uint32_t;
pub const __int_least64_t = __int64_t;
pub const __uint_least64_t = __uint64_t;
pub const __quad_t = c_long;
pub const __u_quad_t = c_ulong;
pub const __intmax_t = c_long;
pub const __uintmax_t = c_ulong;
pub const __dev_t = c_ulong;
pub const __uid_t = c_uint;
pub const __gid_t = c_uint;
pub const __ino_t = c_ulong;
pub const __ino64_t = c_ulong;
pub const __mode_t = c_uint;
pub const __nlink_t = c_ulong;
pub const __off_t = c_long;
pub const __off64_t = c_long;
pub const __pid_t = c_int;
pub const __fsid_t = extern struct {
    __val: [2]c_int = @import("std").mem.zeroes([2]c_int),
};
pub const __clock_t = c_long;
pub const __rlim_t = c_ulong;
pub const __rlim64_t = c_ulong;
pub const __id_t = c_uint;
pub const __time_t = c_long;
pub const __useconds_t = c_uint;
pub const __suseconds_t = c_long;
pub const __suseconds64_t = c_long;
pub const __daddr_t = c_int;
pub const __key_t = c_int;
pub const __clockid_t = c_int;
pub const __timer_t = ?*anyopaque;
pub const __blksize_t = c_long;
pub const __blkcnt_t = c_long;
pub const __blkcnt64_t = c_long;
pub const __fsblkcnt_t = c_ulong;
pub const __fsblkcnt64_t = c_ulong;
pub const __fsfilcnt_t = c_ulong;
pub const __fsfilcnt64_t = c_ulong;
pub const __fsword_t = c_long;
pub const __ssize_t = c_long;
pub const __syscall_slong_t = c_long;
pub const __syscall_ulong_t = c_ulong;
pub const __loff_t = __off64_t;
pub const __caddr_t = [*c]u8;
pub const __intptr_t = c_long;
pub const __socklen_t = c_uint;
pub const __sig_atomic_t = c_int;
pub const int_least8_t = __int_least8_t;
pub const int_least16_t = __int_least16_t;
pub const int_least32_t = __int_least32_t;
pub const int_least64_t = __int_least64_t;
pub const uint_least8_t = __uint_least8_t;
pub const uint_least16_t = __uint_least16_t;
pub const uint_least32_t = __uint_least32_t;
pub const uint_least64_t = __uint_least64_t;
pub const int_fast8_t = i8;
pub const int_fast16_t = c_long;
pub const int_fast32_t = c_long;
pub const int_fast64_t = c_long;
pub const uint_fast8_t = u8;
pub const uint_fast16_t = c_ulong;
pub const uint_fast32_t = c_ulong;
pub const uint_fast64_t = c_ulong;
pub const intmax_t = __intmax_t;
pub const uintmax_t = __uintmax_t;
pub const struct___va_list_tag_1 = extern struct {
    gp_offset: c_uint = @import("std").mem.zeroes(c_uint),
    fp_offset: c_uint = @import("std").mem.zeroes(c_uint),
    overflow_arg_area: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
    reg_save_area: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
};
pub const __builtin_va_list = [1]struct___va_list_tag_1;
pub const __gnuc_va_list = __builtin_va_list;
const union_unnamed_2 = extern union {
    __wch: c_uint,
    __wchb: [4]u8,
};
pub const __mbstate_t = extern struct {
    __count: c_int = @import("std").mem.zeroes(c_int),
    __value: union_unnamed_2 = @import("std").mem.zeroes(union_unnamed_2),
};
pub const struct__G_fpos_t = extern struct {
    __pos: __off_t = @import("std").mem.zeroes(__off_t),
    __state: __mbstate_t = @import("std").mem.zeroes(__mbstate_t),
};
pub const __fpos_t = struct__G_fpos_t;
pub const struct__G_fpos64_t = extern struct {
    __pos: __off64_t = @import("std").mem.zeroes(__off64_t),
    __state: __mbstate_t = @import("std").mem.zeroes(__mbstate_t),
};
pub const __fpos64_t = struct__G_fpos64_t;
pub const struct__IO_marker = opaque {};
pub const _IO_lock_t = anyopaque;
pub const struct__IO_codecvt = opaque {};
pub const struct__IO_wide_data = opaque {};
pub const struct__IO_FILE = extern struct {
    _flags: c_int = @import("std").mem.zeroes(c_int),
    _IO_read_ptr: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    _IO_read_end: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    _IO_read_base: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    _IO_write_base: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    _IO_write_ptr: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    _IO_write_end: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    _IO_buf_base: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    _IO_buf_end: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    _IO_save_base: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    _IO_backup_base: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    _IO_save_end: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    _markers: ?*struct__IO_marker = @import("std").mem.zeroes(?*struct__IO_marker),
    _chain: [*c]struct__IO_FILE = @import("std").mem.zeroes([*c]struct__IO_FILE),
    _fileno: c_int = @import("std").mem.zeroes(c_int),
    _flags2: c_int = @import("std").mem.zeroes(c_int),
    _old_offset: __off_t = @import("std").mem.zeroes(__off_t),
    _cur_column: c_ushort = @import("std").mem.zeroes(c_ushort),
    _vtable_offset: i8 = @import("std").mem.zeroes(i8),
    _shortbuf: [1]u8 = @import("std").mem.zeroes([1]u8),
    _lock: ?*_IO_lock_t = @import("std").mem.zeroes(?*_IO_lock_t),
    _offset: __off64_t = @import("std").mem.zeroes(__off64_t),
    _codecvt: ?*struct__IO_codecvt = @import("std").mem.zeroes(?*struct__IO_codecvt),
    _wide_data: ?*struct__IO_wide_data = @import("std").mem.zeroes(?*struct__IO_wide_data),
    _freeres_list: [*c]struct__IO_FILE = @import("std").mem.zeroes([*c]struct__IO_FILE),
    _freeres_buf: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
    _prevchain: [*c][*c]struct__IO_FILE = @import("std").mem.zeroes([*c][*c]struct__IO_FILE),
    _mode: c_int = @import("std").mem.zeroes(c_int),
    _unused2: [20]u8 = @import("std").mem.zeroes([20]u8),
};
pub const __FILE = struct__IO_FILE;
pub const FILE = struct__IO_FILE;
pub const cookie_read_function_t = fn (?*anyopaque, [*c]u8, usize) callconv(.C) __ssize_t;
pub const cookie_write_function_t = fn (?*anyopaque, [*c]const u8, usize) callconv(.C) __ssize_t;
pub const cookie_seek_function_t = fn (?*anyopaque, [*c]__off64_t, c_int) callconv(.C) c_int;
pub const cookie_close_function_t = fn (?*anyopaque) callconv(.C) c_int;
pub const struct__IO_cookie_io_functions_t = extern struct {
    read: ?*const cookie_read_function_t = @import("std").mem.zeroes(?*const cookie_read_function_t),
    write: ?*const cookie_write_function_t = @import("std").mem.zeroes(?*const cookie_write_function_t),
    seek: ?*const cookie_seek_function_t = @import("std").mem.zeroes(?*const cookie_seek_function_t),
    close: ?*const cookie_close_function_t = @import("std").mem.zeroes(?*const cookie_close_function_t),
};
pub const cookie_io_functions_t = struct__IO_cookie_io_functions_t;
pub const va_list = __gnuc_va_list;
pub const off_t = __off_t;
pub const fpos_t = __fpos_t;
pub extern var stdin: [*c]FILE;
pub extern var stdout: [*c]FILE;
pub extern var stderr: [*c]FILE;
pub extern fn remove(__filename: [*:0]const u8) c_int;
pub extern fn rename(__old: [*:0]const u8, __new: [*:0]const u8) c_int;
pub extern fn renameat(__oldfd: c_int, __old: [*:0]const u8, __newfd: c_int, __new: [*:0]const u8) c_int;
pub extern fn fclose(__stream: *FILE) c_int;
pub extern fn tmpfile() [*c]FILE;
pub extern fn tmpnam([*c]u8) [*c]u8;
pub extern fn tmpnam_r(__s: [*:0]u8) [*c]u8;
pub extern fn tempnam(__dir: [*:0]const u8, __pfx: [*:0]const u8) [*c]u8;
pub extern fn fflush(__stream: *FILE) c_int;
pub extern fn fflush_unlocked(__stream: *FILE) c_int;
pub extern fn fopen(__filename: [*:0]const u8, __modes: [*:0]const u8) [*c]FILE;
pub extern fn freopen(noalias __filename: [*:0]const u8, noalias __modes: [*:0]const u8, noalias __stream: *FILE) [*c]FILE;
pub extern fn fdopen(__fd: c_int, __modes: [*:0]const u8) [*c]FILE;
pub extern fn fopencookie(noalias __magic_cookie: *anyopaque, noalias __modes: [*:0]const u8, __io_funcs: cookie_io_functions_t) [*c]FILE;
pub extern fn fmemopen(__s: *anyopaque, __len: usize, __modes: [*:0]const u8) [*c]FILE;
pub extern fn open_memstream(__bufloc: *[*]u8, __sizeloc: *usize) [*c]FILE;
pub extern fn setbuf(noalias __stream: *FILE, noalias __buf: [*:0]u8) void;
pub extern fn setvbuf(noalias __stream: *FILE, noalias __buf: [*:0]u8, __modes: c_int, __n: usize) c_int;
pub extern fn setbuffer(noalias __stream: *FILE, noalias __buf: [*:0]u8, __size: usize) void;
pub extern fn setlinebuf(__stream: *FILE) void;
pub extern fn fprintf(__stream: *FILE, __format: [*:0]const u8, ...) c_int;
pub extern fn printf(__format: [*:0]const u8, ...) c_int;
pub extern fn sprintf(__s: [*:0]u8, __format: [*:0]const u8, ...) c_int;
pub extern fn vfprintf(__s: *FILE, __format: [*:0]const u8, __arg: *pd._va_list_tag_1) c_int;
pub extern fn vprintf(__format: [*:0]const u8, __arg: *pd._va_list_tag_1) c_int;
pub extern fn vsprintf(__s: [*:0]u8, __format: [*:0]const u8, __arg: *pd._va_list_tag_1) c_int;
pub extern fn snprintf(__s: [*:0]u8, __maxlen: c_ulong, __format: [*:0]const u8, ...) c_int;
pub extern fn vsnprintf(__s: [*:0]u8, __maxlen: c_ulong, __format: [*:0]const u8, __arg: *pd._va_list_tag_1) c_int;
pub extern fn vasprintf(noalias __ptr: *[*]u8, noalias __f: [*:0]const u8, __arg: *pd._va_list_tag_1) c_int;
pub extern fn __asprintf(noalias __ptr: *[*]u8, noalias __fmt: [*:0]const u8, ...) c_int;
pub extern fn asprintf(noalias __ptr: *[*]u8, noalias __fmt: [*:0]const u8, ...) c_int;
pub extern fn vdprintf(__fd: c_int, noalias __fmt: [*:0]const u8, __arg: *pd._va_list_tag_1) c_int;
pub extern fn dprintf(__fd: c_int, noalias __fmt: [*:0]const u8, ...) c_int;
pub extern fn fscanf(noalias __stream: *FILE, noalias __format: [*:0]const u8, ...) c_int;
pub extern fn scanf(noalias __format: [*:0]const u8, ...) c_int;
pub extern fn sscanf(noalias __s: [*:0]const u8, noalias __format: [*:0]const u8, ...) c_int;
pub const _Float32 = f32;
pub const _Float64 = f64;
pub const _Float32x = f64;
pub const _Float64x = c_longdouble;
pub extern fn vfscanf(noalias __s: *FILE, noalias __format: [*:0]const u8, __arg: *pd._va_list_tag_1) c_int;
pub extern fn vscanf(noalias __format: [*:0]const u8, __arg: *pd._va_list_tag_1) c_int;
pub extern fn vsscanf(noalias __s: [*:0]const u8, noalias __format: [*:0]const u8, __arg: *pd._va_list_tag_1) c_int;
pub extern fn fgetc(__stream: *FILE) c_int;
pub extern fn getc(__stream: *FILE) c_int;
pub extern fn getchar() c_int;
pub extern fn getc_unlocked(__stream: *FILE) c_int;
pub extern fn getchar_unlocked() c_int;
pub extern fn fgetc_unlocked(__stream: *FILE) c_int;
pub extern fn fputc(__c: c_int, __stream: *FILE) c_int;
pub extern fn putc(__c: c_int, __stream: *FILE) c_int;
pub extern fn putchar(__c: c_int) c_int;
pub extern fn fputc_unlocked(__c: c_int, __stream: *FILE) c_int;
pub extern fn putc_unlocked(__c: c_int, __stream: *FILE) c_int;
pub extern fn putchar_unlocked(__c: c_int) c_int;
pub extern fn getw(__stream: *FILE) c_int;
pub extern fn putw(__w: c_int, __stream: *FILE) c_int;
pub extern fn fgets(noalias __s: [*:0]u8, __n: c_int, noalias __stream: *FILE) [*c]u8;
pub extern fn __getdelim(noalias __lineptr: *[*]u8, noalias __n: *usize, __delimiter: c_int, noalias __stream: *FILE) __ssize_t;
pub extern fn getdelim(noalias __lineptr: *[*]u8, noalias __n: *usize, __delimiter: c_int, noalias __stream: *FILE) __ssize_t;
pub extern fn getline(noalias __lineptr: *[*]u8, noalias __n: *usize, noalias __stream: *FILE) __ssize_t;
pub extern fn fputs(noalias __s: [*:0]const u8, noalias __stream: *FILE) c_int;
pub extern fn puts(__s: [*:0]const u8) c_int;
pub extern fn ungetc(__c: c_int, __stream: *FILE) c_int;
pub extern fn fread(__ptr: *anyopaque, __size: c_ulong, __n: c_ulong, __stream: *FILE) c_ulong;
pub extern fn fwrite(__ptr: *const anyopaque, __size: c_ulong, __n: c_ulong, __s: *FILE) c_ulong;
pub extern fn fread_unlocked(noalias __ptr: *anyopaque, __size: usize, __n: usize, noalias __stream: *FILE) usize;
pub extern fn fwrite_unlocked(noalias __ptr: *const anyopaque, __size: usize, __n: usize, noalias __stream: *FILE) usize;
pub extern fn fseek(__stream: *FILE, __off: c_long, __whence: c_int) c_int;
pub extern fn ftell(__stream: *FILE) c_long;
pub extern fn rewind(__stream: *FILE) void;
pub extern fn fseeko(__stream: *FILE, __off: __off_t, __whence: c_int) c_int;
pub extern fn ftello(__stream: *FILE) __off_t;
pub extern fn fgetpos(noalias __stream: *FILE, noalias __pos: *fpos_t) c_int;
pub extern fn fsetpos(__stream: *FILE, __pos: *const fpos_t) c_int;
pub extern fn clearerr(__stream: *FILE) void;
pub extern fn feof(__stream: *FILE) c_int;
pub extern fn ferror(__stream: *FILE) c_int;
pub extern fn clearerr_unlocked(__stream: *FILE) void;
pub extern fn feof_unlocked(__stream: *FILE) c_int;
pub extern fn ferror_unlocked(__stream: *FILE) c_int;
pub extern fn perror(__s: [*:0]const u8) void;
pub extern fn fileno(__stream: *FILE) c_int;
pub extern fn fileno_unlocked(__stream: *FILE) c_int;
pub extern fn pclose(__stream: *FILE) c_int;
pub extern fn popen(__command: [*:0]const u8, __modes: [*:0]const u8) [*c]FILE;
pub extern fn ctermid(__s: [*:0]u8) [*c]u8;
pub extern fn flockfile(__stream: *FILE) void;
pub extern fn ftrylockfile(__stream: *FILE) c_int;
pub extern fn funlockfile(__stream: *FILE) void;
pub extern fn __uflow([*c]FILE) c_int;
pub extern fn __overflow([*c]FILE, c_int) c_int;
pub const t_int = c_long;
pub const t_float = f32;
pub const t_floatarg = f32;
pub const t_symbol = pd.Symbol;
pub const t_gotfn = ?*const fn (?*anyopaque, ...) callconv(.C) void;
pub const struct__methodentry = extern struct {
    me_name: [*c]t_symbol = @import("std").mem.zeroes([*c]t_symbol),
    me_fun: t_gotfn = @import("std").mem.zeroes(t_gotfn),
    me_arg: [6]u8 = @import("std").mem.zeroes([6]u8),
};
pub const t_methodentry = pd.Methodentry;
pub const t_method = ?*const fn () callconv(.C) void;
pub const t_pd = ?*struct__class;
pub const t_bangmethod = ?*const fn ([*c]pd.Pd) callconv(.C) void;
pub const struct__gobj = extern struct {
    g_pd: t_pd = @import("std").mem.zeroes(t_pd),
    g_next: [*c]struct__gobj = @import("std").mem.zeroes([*c]struct__gobj),
};
pub const t_gobj = pd.GObj;
pub const struct__binbuf = opaque {};
pub const struct__outlet = opaque {};
pub const struct__inlet = opaque {};
pub const struct__text = extern struct {
    te_g: t_gobj = @import("std").mem.zeroes(t_gobj),
    te_binbuf: ?*struct__binbuf = @import("std").mem.zeroes(?*struct__binbuf),
    te_outlet: ?*struct__outlet = @import("std").mem.zeroes(?*struct__outlet),
    te_inlet: ?*struct__inlet = @import("std").mem.zeroes(?*struct__inlet),
    te_xpix: c_short = @import("std").mem.zeroes(c_short),
    te_ypix: c_short = @import("std").mem.zeroes(c_short),
    te_width: c_short = @import("std").mem.zeroes(c_short),
    te_type: u8 = @import("std").mem.zeroes(u8),
};
pub const t_object = pd.Object;
pub const struct__tick = extern struct {
    k_point: t_float = @import("std").mem.zeroes(t_float),
    k_inc: t_float = @import("std").mem.zeroes(t_float),
    k_lperb: c_int = @import("std").mem.zeroes(c_int),
};
pub const t_tick = pd.Tick;
// /usr/include/pd/g_canvas.h:73:18: warning: struct demoted to opaque type - has bitfield
pub const struct__updateheader = opaque {};
pub const t_updateheader = pd.Updateheader;
pub const struct__selection = extern struct {
    sel_what: [*c]t_gobj = @import("std").mem.zeroes([*c]t_gobj),
    sel_next: [*c]struct__selection = @import("std").mem.zeroes([*c]struct__selection),
};
pub const t_selection = pd.Selection;
pub const struct__rtext = opaque {};
pub const t_glistmotionfn = ?*const fn (?*anyopaque, pd.Float, pd.Float, pd.Float) callconv(.C) void;
pub const t_glistkeyfn = ?*const fn (?*anyopaque, [*c]pd.Symbol, pd.Float) callconv(.C) void;
pub const struct__guiconnect = opaque {};
pub const struct__outconnect = opaque {};
// /usr/include/pd/g_canvas.h:128:18: warning: struct demoted to opaque type - has bitfield
pub const struct__editor = opaque {};
pub const t_editor = pd.Editor;
pub const struct__canvasenvironment = opaque {};
// /usr/include/pd/g_canvas.h:201:18: warning: struct demoted to opaque type - has bitfield
pub const struct__glist = opaque {};
const union_unnamed_4 = extern union {
    gs_glist: ?*struct__glist,
    gs_array: [*c]struct__array,
};
pub const struct__gstub = extern struct {
    gs_un: union_unnamed_4 = @import("std").mem.zeroes(union_unnamed_4),
    gs_which: c_int = @import("std").mem.zeroes(c_int),
    gs_refcount: c_int = @import("std").mem.zeroes(c_int),
};
pub const t_gstub = pd.GStub;
pub const struct__array = extern struct {
    a_n: c_int = @import("std").mem.zeroes(c_int),
    a_elemsize: c_int = @import("std").mem.zeroes(c_int),
    a_vec: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    a_templatesym: [*c]t_symbol = @import("std").mem.zeroes([*c]t_symbol),
    a_valid: c_int = @import("std").mem.zeroes(c_int),
    a_gp: t_gpointer = @import("std").mem.zeroes(t_gpointer),
    a_stub: [*c]t_gstub = @import("std").mem.zeroes([*c]t_gstub),
};
pub const union_word = extern union {
    w_float: t_float,
    w_symbol: [*c]t_symbol,
    w_gpointer: [*c]t_gpointer,
    w_array: [*c]struct__array,
    w_binbuf: ?*struct__binbuf,
    w_index: c_int,
};
pub const t_word = union_word;
pub const struct__scalar = extern struct {
    sc_gobj: t_gobj = @import("std").mem.zeroes(t_gobj),
    sc_template: [*c]t_symbol = @import("std").mem.zeroes([*c]t_symbol),
    sc_vec: [1]t_word = @import("std").mem.zeroes([1]t_word),
};
const union_unnamed_3 = extern union {
    gp_scalar: [*c]struct__scalar,
    gp_w: [*c]union_word,
};
pub const struct__gpointer = extern struct {
    gp_un: union_unnamed_3 = @import("std").mem.zeroes(union_unnamed_3),
    gp_valid: c_int = @import("std").mem.zeroes(c_int),
    gp_stub: [*c]t_gstub = @import("std").mem.zeroes([*c]t_gstub),
};
pub const t_gpointer = pd.GPointer;
pub const t_pointermethod = ?*const fn ([*c]pd.Pd, [*c]pd.GPointer) callconv(.C) void;
pub const t_floatmethod = ?*const fn ([*c]pd.Pd, pd.Float) callconv(.C) void;
pub const t_symbolmethod = ?*const fn ([*c]pd.Pd, [*c]pd.Symbol) callconv(.C) void;
pub const struct__atom = extern struct {
    a_type: t_atomtype = @import("std").mem.zeroes(t_atomtype),
    a_w: union_word = @import("std").mem.zeroes(union_word),
};
pub const t_atom = pd.Atom;
pub const t_listmethod = ?*const fn ([*c]pd.Pd, [*c]pd.Symbol, c_int, [*c]pd.Atom) callconv(.C) void;
pub const t_anymethod = ?*const fn ([*c]pd.Pd, [*c]pd.Symbol, c_int, [*c]pd.Atom) callconv(.C) void;
pub const t_getrectfn = ?*const fn ([*c]pd.GObj, ?*cnv.GList, [*c]c_int, [*c]c_int, [*c]c_int, [*c]c_int) callconv(.C) void;
pub const t_displacefn = ?*const fn ([*c]pd.GObj, ?*cnv.GList, c_int, c_int) callconv(.C) void;
pub const t_selectfn = ?*const fn ([*c]pd.GObj, ?*cnv.GList, c_int) callconv(.C) void;
pub const t_activatefn = ?*const fn ([*c]pd.GObj, ?*cnv.GList, c_int) callconv(.C) void;
pub const t_deletefn = ?*const fn ([*c]pd.GObj, ?*cnv.GList) callconv(.C) void;
pub const t_visfn = ?*const fn ([*c]pd.GObj, ?*cnv.GList, c_int) callconv(.C) void;
pub const t_clickfn = ?*const fn ([*c]pd.GObj, ?*cnv.GList, c_int, c_int, c_int, c_int, c_int, c_int) callconv(.C) c_int;
pub const struct__widgetbehavior = extern struct {
    w_getrectfn: t_getrectfn = @import("std").mem.zeroes(t_getrectfn),
    w_displacefn: t_displacefn = @import("std").mem.zeroes(t_displacefn),
    w_selectfn: t_selectfn = @import("std").mem.zeroes(t_selectfn),
    w_activatefn: t_activatefn = @import("std").mem.zeroes(t_activatefn),
    w_deletefn: t_deletefn = @import("std").mem.zeroes(t_deletefn),
    w_visfn: t_visfn = @import("std").mem.zeroes(t_visfn),
    w_clickfn: t_clickfn = @import("std").mem.zeroes(t_clickfn),
};
pub const struct__gtemplate = opaque {};
pub const struct__dataslot = extern struct {
    ds_type: c_int = @import("std").mem.zeroes(c_int),
    ds_name: [*c]t_symbol = @import("std").mem.zeroes([*c]t_symbol),
    ds_arraytemplate: [*c]t_symbol = @import("std").mem.zeroes([*c]t_symbol),
};
pub const t_dataslot = cnv.DataSlot;
pub const struct__template = extern struct {
    t_pdobj: t_pd = @import("std").mem.zeroes(t_pd),
    t_list: ?*struct__gtemplate = @import("std").mem.zeroes(?*struct__gtemplate),
    t_sym: [*c]t_symbol = @import("std").mem.zeroes([*c]t_symbol),
    t_n: c_int = @import("std").mem.zeroes(c_int),
    t_vec: [*c]t_dataslot = @import("std").mem.zeroes([*c]t_dataslot),
    t_next: [*c]struct__template = @import("std").mem.zeroes([*c]struct__template),
};
pub const t_template = cnv.Template;
pub const t_parentgetrectfn = ?*const fn ([*c]pd.GObj, ?*cnv.GList, [*c]pd.Word, [*c]cnv.Template, pd.Float, pd.Float, [*c]c_int, [*c]c_int, [*c]c_int, [*c]c_int) callconv(.C) void;
pub const t_parentdisplacefn = ?*const fn ([*c]pd.GObj, ?*cnv.GList, [*c]pd.Word, [*c]cnv.Template, pd.Float, pd.Float, c_int, c_int) callconv(.C) void;
pub const t_parentselectfn = ?*const fn ([*c]pd.GObj, ?*cnv.GList, [*c]pd.Word, [*c]cnv.Template, pd.Float, pd.Float, c_int) callconv(.C) void;
pub const t_parentactivatefn = ?*const fn ([*c]pd.GObj, ?*cnv.GList, [*c]pd.Word, [*c]cnv.Template, pd.Float, pd.Float, c_int) callconv(.C) void;
pub const t_parentvisfn = ?*const fn ([*c]pd.GObj, ?*cnv.GList, [*c]pd.Word, [*c]cnv.Template, pd.Float, pd.Float, c_int) callconv(.C) void;
pub const t_scalar = pd.Scalar;
pub const t_parentclickfn = ?*const fn ([*c]pd.GObj, ?*cnv.GList, [*c]pd.Word, [*c]cnv.Template, [*c]pd.Scalar, [*c]cnv.Array, pd.Float, pd.Float, c_int, c_int, c_int, c_int, c_int, c_int) callconv(.C) c_int;
pub const struct__parentwidgetbehavior = extern struct {
    w_parentgetrectfn: t_parentgetrectfn = @import("std").mem.zeroes(t_parentgetrectfn),
    w_parentdisplacefn: t_parentdisplacefn = @import("std").mem.zeroes(t_parentdisplacefn),
    w_parentselectfn: t_parentselectfn = @import("std").mem.zeroes(t_parentselectfn),
    w_parentactivatefn: t_parentactivatefn = @import("std").mem.zeroes(t_parentactivatefn),
    w_parentvisfn: t_parentvisfn = @import("std").mem.zeroes(t_parentvisfn),
    w_parentclickfn: t_parentclickfn = @import("std").mem.zeroes(t_parentclickfn),
};
pub const t_savefn = ?*const fn ([*c]pd.GObj, ?*pd.BinBuf) callconv(.C) void;
pub const t_propertiesfn = ?*const fn ([*c]pd.GObj, ?*cnv.GList) callconv(.C) void;
// /usr/include/pd/m_imp.h:62:18: warning: struct demoted to opaque type - has bitfield
pub const struct__class = opaque {};
pub const struct__symbol = extern struct {
    s_name: [*c]const u8 = @import("std").mem.zeroes([*c]const u8),
    s_thing: [*c]?*struct__class = @import("std").mem.zeroes([*c]?*struct__class),
    s_next: [*c]struct__symbol = @import("std").mem.zeroes([*c]struct__symbol),
};
pub const A_NULL: c_int = 0;
pub const A_FLOAT: c_int = 1;
pub const A_SYMBOL: c_int = 2;
pub const A_POINTER: c_int = 3;
pub const A_SEMI: c_int = 4;
pub const A_COMMA: c_int = 5;
pub const A_DEFFLOAT: c_int = 6;
pub const A_DEFSYM: c_int = 7;
pub const A_DOLLAR: c_int = 8;
pub const A_DOLLSYM: c_int = 9;
pub const A_GIMME: c_int = 10;
pub const A_CANT: c_int = 11;
pub const t_atomtype = c_uint;
pub const struct__clock = opaque {};
pub const t_text = pd.Object;
pub const t_newmethod = ?*const fn () callconv(.C) ?*anyopaque;
pub extern var pd_objectmaker: t_pd;
pub extern var pd_canvasmaker: t_pd;
pub extern fn pd_typedmess(x: *pd.Pd, s: *pd.Symbol, argc: c_int, argv: [*]pd.Atom) void;
pub extern fn pd_forwardmess(x: *pd.Pd, argc: c_int, argv: [*]pd.Atom) void;
pub extern fn gensym(s: [*:0]const u8) [*c]pd.Symbol;
pub extern fn getfn(x: *const pd.Pd, s: *pd.Symbol) pd.Gotfn;
pub extern fn zgetfn(x: *const pd.Pd, s: *pd.Symbol) pd.Gotfn;
pub extern fn nullfn() void;
pub extern fn pd_vmess(x: *pd.Pd, s: *pd.Symbol, fmt: [*:0]const u8, ...) void;
pub const t_gotfn1 = ?*const fn (?*anyopaque, ?*anyopaque) callconv(.C) void;
pub const t_gotfn2 = ?*const fn (?*anyopaque, ?*anyopaque, ?*anyopaque) callconv(.C) void;
pub const t_gotfn3 = ?*const fn (?*anyopaque, ?*anyopaque, ?*anyopaque, ?*anyopaque) callconv(.C) void;
pub const t_gotfn4 = ?*const fn (?*anyopaque, ?*anyopaque, ?*anyopaque, ?*anyopaque, ?*anyopaque) callconv(.C) void;
pub const t_gotfn5 = ?*const fn (?*anyopaque, ?*anyopaque, ?*anyopaque, ?*anyopaque, ?*anyopaque, ?*anyopaque) callconv(.C) void;
pub extern fn obj_list(x: *pd.Object, s: *pd.Symbol, argc: c_int, argv: [*]pd.Atom) void;
pub extern fn pd_newest() [*c]pd.Pd;
pub extern fn getbytes(nbytes: usize) ?*anyopaque;
pub extern fn getzbytes(nbytes: usize) ?*anyopaque;
pub extern fn copybytes(src: *const anyopaque, nbytes: usize) ?*anyopaque;
pub extern fn freebytes(x: *anyopaque, nbytes: usize) void;
pub extern fn resizebytes(x: *anyopaque, oldsize: usize, newsize: usize) ?*anyopaque;
pub extern fn atom_getfloat(a: *const pd.Atom) pd.Float;
pub extern fn atom_getint(a: *const pd.Atom) pd.Int;
pub extern fn atom_getsymbol(a: *const pd.Atom) [*c]pd.Symbol;
pub extern fn atom_gensym(a: *const pd.Atom) [*c]pd.Symbol;
pub extern fn atom_getfloatarg(which: c_int, argc: c_int, argv: [*]const pd.Atom) pd.Float;
pub extern fn atom_getintarg(which: c_int, argc: c_int, argv: [*]const pd.Atom) pd.Int;
pub extern fn atom_getsymbolarg(which: c_int, argc: c_int, argv: [*]const pd.Atom) [*c]pd.Symbol;
pub extern fn atom_string(a: *const pd.Atom, buf: [*:0]u8, bufsize: c_uint) void;
pub extern fn binbuf_new() ?*pd.BinBuf;
pub extern fn binbuf_free(x: *pd.BinBuf) void;
pub extern fn binbuf_duplicate(y: *const pd.BinBuf) ?*pd.BinBuf;
pub extern fn binbuf_text(x: *pd.BinBuf, text: [*:0]const u8, size: usize) void;
pub extern fn binbuf_gettext(x: *const pd.BinBuf, bufp: *[*]u8, lengthp: *c_int) void;
pub extern fn binbuf_clear(x: *pd.BinBuf) void;
pub extern fn binbuf_add(x: *pd.BinBuf, argc: c_int, argv: [*]const pd.Atom) void;
pub extern fn binbuf_addv(x: *pd.BinBuf, fmt: [*:0]const u8, ...) void;
pub extern fn binbuf_addbinbuf(x: *pd.BinBuf, y: *const pd.BinBuf) void;
pub extern fn binbuf_addsemi(x: *pd.BinBuf) void;
pub extern fn binbuf_restore(x: *pd.BinBuf, argc: c_int, argv: [*]const pd.Atom) void;
pub extern fn binbuf_print(x: *const pd.BinBuf) void;
pub extern fn binbuf_getnatom(x: *const pd.BinBuf) c_int;
pub extern fn binbuf_getvec(x: *const pd.BinBuf) [*c]pd.Atom;
pub extern fn binbuf_resize(x: *pd.BinBuf, newsize: c_int) c_int;
pub extern fn binbuf_eval(x: *const pd.BinBuf, target: *pd.Pd, argc: c_int, argv: [*]const pd.Atom) void;
pub extern fn binbuf_read(b: *pd.BinBuf, filename: [*:0]const u8, dirname: [*:0]const u8, crflag: c_int) c_int;
pub extern fn binbuf_read_via_canvas(b: *pd.BinBuf, filename: [*:0]const u8, canvas: *const cnv.GList, crflag: c_int) c_int;
pub extern fn binbuf_read_via_path(b: *pd.BinBuf, filename: [*:0]const u8, dirname: [*:0]const u8, crflag: c_int) c_int;
pub extern fn binbuf_write(x: *const pd.BinBuf, filename: [*:0]const u8, dir: [*:0]const u8, crflag: c_int) c_int;
pub extern fn binbuf_evalfile(name: *pd.Symbol, dir: *pd.Symbol) void;
pub extern fn binbuf_realizedollsym(s: *pd.Symbol, ac: c_int, av: [*]const pd.Atom, tonew: c_int) [*c]pd.Symbol;
pub extern fn clock_new(owner: *anyopaque, @"fn": pd.Method) ?*pd.Clock;
pub extern fn clock_set(x: *pd.Clock, systime: f64) void;
pub extern fn clock_delay(x: *pd.Clock, delaytime: f64) void;
pub extern fn clock_unset(x: *pd.Clock) void;
pub extern fn clock_setunit(x: *pd.Clock, timeunit: f64, sampflag: c_int) void;
pub extern fn clock_getlogicaltime() f64;
pub extern fn clock_gettimesince(prevsystime: f64) f64;
pub extern fn clock_gettimesincewithunits(prevsystime: f64, units: f64, sampflag: c_int) f64;
pub extern fn clock_getsystimeafter(delaytime: f64) f64;
pub extern fn clock_free(x: *pd.Clock) void;
pub extern fn pd_new(cls: *pd.Class) [*c]pd.Pd;
pub extern fn pd_free(x: *pd.Pd) void;
pub extern fn pd_bind(x: *pd.Pd, s: *pd.Symbol) void;
pub extern fn pd_unbind(x: *pd.Pd, s: *pd.Symbol) void;
pub extern fn pd_findbyclass(s: *pd.Symbol, c: *const pd.Class) [*c]pd.Pd;
pub extern fn pd_pushsym(x: *pd.Pd) void;
pub extern fn pd_popsym(x: *pd.Pd) void;
pub extern fn pd_bang(x: *pd.Pd) void;
pub extern fn pd_pointer(x: *pd.Pd, gp: *pd.GPointer) void;
pub extern fn pd_float(x: *pd.Pd, f: pd.Float) void;
pub extern fn pd_symbol(x: *pd.Pd, s: *pd.Symbol) void;
pub extern fn pd_list(x: *pd.Pd, s: *pd.Symbol, argc: c_int, argv: [*]pd.Atom) void;
pub extern fn pd_anything(x: *pd.Pd, s: *pd.Symbol, argc: c_int, argv: [*]pd.Atom) void;
pub extern fn gpointer_init(gp: *pd.GPointer) void;
pub extern fn gpointer_copy(gpfrom: *const pd.GPointer, gpto: *pd.GPointer) void;
pub extern fn gpointer_unset(gp: *pd.GPointer) void;
pub extern fn gpointer_check(gp: *const pd.GPointer, headok: c_int) c_int;
pub extern fn inlet_new(owner: *pd.Object, dest: *pd.Pd, s1: *pd.Symbol, s2: *pd.Symbol) ?*pd.Inlet;
pub extern fn pointerinlet_new(owner: *pd.Object, gp: *pd.GPointer) ?*pd.Inlet;
pub extern fn floatinlet_new(owner: *pd.Object, fp: *pd.Float) ?*pd.Inlet;
pub extern fn symbolinlet_new(owner: *pd.Object, sp: **pd.Symbol) ?*pd.Inlet;
pub extern fn signalinlet_new(owner: *pd.Object, f: pd.Float) ?*pd.Inlet;
pub extern fn inlet_free(x: *pd.Inlet) void;
pub extern fn outlet_new(owner: *pd.Object, s: *pd.Symbol) ?*pd.Outlet;
pub extern fn outlet_bang(x: *pd.Outlet) void;
pub extern fn outlet_pointer(x: *pd.Outlet, gp: *pd.GPointer) void;
pub extern fn outlet_float(x: *pd.Outlet, f: pd.Float) void;
pub extern fn outlet_symbol(x: *pd.Outlet, s: *pd.Symbol) void;
pub extern fn outlet_list(x: *pd.Outlet, s: *pd.Symbol, argc: c_int, argv: [*]pd.Atom) void;
pub extern fn outlet_anything(x: *pd.Outlet, s: *pd.Symbol, argc: c_int, argv: [*]pd.Atom) void;
pub extern fn outlet_getsymbol(x: *pd.Outlet) [*c]pd.Symbol;
pub extern fn outlet_free(x: *pd.Outlet) void;
pub extern fn pd_checkobject(x: *pd.Pd) [*c]pd.Object;
pub extern fn glob_setfilename(dummy: *anyopaque, name: *pd.Symbol, dir: *pd.Symbol) void;
pub extern fn canvas_setargs(argc: c_int, argv: [*]const pd.Atom) void;
pub extern fn canvas_getargs(argcp: *c_int, argvp: *[*]pd.Atom) void;
pub extern fn canvas_getcurrentdir() [*c]pd.Symbol;
pub extern fn canvas_getcurrent() ?*cnv.GList;
pub extern fn canvas_makefilename(c: *const cnv.GList, file: [*:0]const u8, result: [*:0]u8, resultsize: c_int) void;
pub extern fn canvas_getdir(x: *const cnv.GList) [*c]pd.Symbol;
pub const sys_font: [*c]u8 = @extern([*c]u8, .{
    .name = "sys_font",
});
pub const sys_fontweight: [*c]u8 = @extern([*c]u8, .{
    .name = "sys_fontweight",
});
pub extern fn sys_hostfontsize(fontsize: c_int, zoom: c_int) c_int;
pub extern fn sys_zoomfontwidth(fontsize: c_int, zoom: c_int, worstcase: c_int) c_int;
pub extern fn sys_zoomfontheight(fontsize: c_int, zoom: c_int, worstcase: c_int) c_int;
pub extern fn sys_fontwidth(fontsize: c_int) c_int;
pub extern fn sys_fontheight(fontsize: c_int) c_int;
pub extern fn canvas_dataproperties(x: *cnv.GList, sc: *pd.Scalar, b: *pd.BinBuf) void;
pub extern fn canvas_open(x: *const cnv.GList, name: [*:0]const u8, ext: [*:0]const u8, dirresult: [*:0]u8, nameresult: *[*]u8, size: c_uint, bin: c_int) c_int;
pub extern fn canvas_getsr(x: *cnv.GList) pd.Float;
pub extern fn canvas_getsignallength(x: *cnv.GList) c_int;
pub extern fn pd_getparentwidget(x: *pd.Pd) [*c]const cnv.ParentWidgetBehavior;
pub extern fn class_new(name: *pd.Symbol, newmethod: pd.NewMethod, freemethod: pd.Method, size: usize, flags: c_int, arg1: t_atomtype, ...) ?*pd.Class;
pub extern fn class_new64(name: *pd.Symbol, newmethod: pd.NewMethod, freemethod: pd.Method, size: usize, flags: c_int, arg1: t_atomtype, ...) ?*pd.Class;
pub extern fn class_free(c: *pd.Class) void;
pub extern fn class_addcreator(newmethod: pd.NewMethod, s: *pd.Symbol, type1: t_atomtype, ...) void;
pub extern fn class_addmethod(c: *pd.Class, @"fn": pd.Method, sel: *pd.Symbol, arg1: t_atomtype, ...) void;
pub extern fn class_addbang(c: *pd.Class, @"fn": pd.Method) void;
pub extern fn class_addpointer(c: *pd.Class, @"fn": pd.Method) void;
pub extern fn class_doaddfloat(c: *pd.Class, @"fn": pd.Method) void;
pub extern fn class_addsymbol(c: *pd.Class, @"fn": pd.Method) void;
pub extern fn class_addlist(c: *pd.Class, @"fn": pd.Method) void;
pub extern fn class_addanything(c: *pd.Class, @"fn": pd.Method) void;
pub extern fn class_sethelpsymbol(c: *pd.Class, s: *pd.Symbol) void;
pub extern fn class_setwidget(c: *pd.Class, w: *const cnv.WidgetBehavior) void;
pub extern fn class_setparentwidget(c: *pd.Class, w: *const cnv.ParentWidgetBehavior) void;
pub extern fn class_getname(c: *const pd.Class) [*c]const u8;
pub extern fn class_gethelpname(c: *const pd.Class) [*c]const u8;
pub extern fn class_gethelpdir(c: *const pd.Class) [*c]const u8;
pub extern fn class_setdrawcommand(c: *pd.Class) void;
pub extern fn class_isdrawcommand(c: *const pd.Class) c_int;
pub extern fn class_set_extern_dir(s: *pd.Symbol) void;
pub extern fn class_domainsignalin(c: *pd.Class, onset: c_int) void;
pub extern fn class_setsavefn(c: *pd.Class, f: pd.SaveFn) void;
pub extern fn class_getsavefn(c: *const pd.Class) pd.SaveFn;
pub extern fn obj_saveformat(x: *const pd.Object, bb: *pd.BinBuf) void;
pub extern fn class_setpropertiesfn(c: *pd.Class, f: pd.PropertiesFn) void;
pub extern fn class_getpropertiesfn(c: *const pd.Class) pd.PropertiesFn;
pub const t_classfreefn = ?*const fn (?*pd.Class) callconv(.C) void;
pub extern fn class_setfreefn(c: *pd.Class, @"fn": pd.ClassFreeFn) void;
pub extern fn post(fmt: [*:0]const u8, ...) void;
pub extern fn startpost(fmt: [*:0]const u8, ...) void;
pub extern fn poststring(s: [*:0]const u8) void;
pub extern fn postfloat(f: pd.Float) void;
pub extern fn postatom(argc: c_int, argv: [*]const pd.Atom) void;
pub extern fn endpost() void;
pub extern fn bug(fmt: [*:0]const u8, ...) void;
pub extern fn pd_error(object: *const anyopaque, fmt: [*:0]const u8, ...) void;
pub const PD_CRITICAL: c_int = 0;
pub const PD_ERROR: c_int = 1;
pub const PD_NORMAL: c_int = 2;
pub const PD_DEBUG: c_int = 3;
pub const PD_VERBOSE: c_int = 4;
pub const t_loglevel = c_uint;
pub extern fn logpost(object: *const anyopaque, level: c_int, fmt: [*:0]const u8, ...) void;
pub extern fn sys_isabsolutepath(dir: [*:0]const u8) c_int;
pub extern fn sys_bashfilename(from: [*:0]const u8, to: [*:0]u8) void;
pub extern fn sys_unbashfilename(from: [*:0]const u8, to: [*:0]u8) void;
pub extern fn open_via_path(dir: [*:0]const u8, name: [*:0]const u8, ext: [*:0]const u8, dirresult: [*:0]u8, nameresult: *[*]u8, size: c_uint, bin: c_int) c_int;
pub extern fn sched_geteventno() c_int;
pub extern fn sys_getrealtime() f64;
pub extern var sys_idlehook: ?*const fn () callconv(.C) c_int;
pub extern fn sys_open(path: [*:0]const u8, oflag: c_int, ...) c_int;
pub extern fn sys_close(fd: c_int) c_int;
pub extern fn sys_fopen(filename: [*:0]const u8, mode: [*:0]const u8) [*c]FILE;
pub extern fn sys_fclose(stream: *FILE) c_int;
pub extern fn sys_lock() void;
pub extern fn sys_unlock() void;
pub extern fn sys_trylock() c_int;
pub const t_sample = f32;
pub const union__sampleint_union = extern union {
    f: t_sample,
    i: u32,
};
pub const t_sampleint_union = union__sampleint_union;
const union_unnamed_5 = extern union {
    s_length: c_int,
    s_n: c_int,
};
pub const struct__signal = extern struct {
    unnamed_0: union_unnamed_5 = @import("std").mem.zeroes(union_unnamed_5),
    s_vec: [*c]t_sample = @import("std").mem.zeroes([*c]t_sample),
    s_sr: t_float = @import("std").mem.zeroes(t_float),
    s_nchans: c_int = @import("std").mem.zeroes(c_int),
    s_overlap: c_int = @import("std").mem.zeroes(c_int),
    s_refcount: c_int = @import("std").mem.zeroes(c_int),
    s_isborrowed: c_int = @import("std").mem.zeroes(c_int),
    s_isscalar: c_int = @import("std").mem.zeroes(c_int),
    s_borrowedfrom: [*c]struct__signal = @import("std").mem.zeroes([*c]struct__signal),
    s_nextfree: [*c]struct__signal = @import("std").mem.zeroes([*c]struct__signal),
    s_nextused: [*c]struct__signal = @import("std").mem.zeroes([*c]struct__signal),
    s_nalloc: c_int = @import("std").mem.zeroes(c_int),
};
pub const t_signal = pd.Signal;
pub const t_perfroutine = ?*const fn ([*c]pd.Int) callconv(.C) [*c]pd.Int;
pub extern fn signal_new(length: c_int, nchans: c_int, sr: pd.Float, scalarptr: *pd.Sample) [*c]pd.Signal;
pub extern fn signal_setmultiout(sig: *[*]pd.Signal, nchans: c_int) void;
pub extern fn plus_perform(args: *pd.Int) [*c]pd.Int;
pub extern fn plus_perf8(args: *pd.Int) [*c]pd.Int;
pub extern fn zero_perform(args: *pd.Int) [*c]pd.Int;
pub extern fn zero_perf8(args: *pd.Int) [*c]pd.Int;
pub extern fn copy_perform(args: *pd.Int) [*c]pd.Int;
pub extern fn copy_perf8(args: *pd.Int) [*c]pd.Int;
pub extern fn scalarcopy_perform(args: *pd.Int) [*c]pd.Int;
pub extern fn scalarcopy_perf8(args: *pd.Int) [*c]pd.Int;
pub extern fn dsp_add_plus(in1: *pd.Sample, in2: *pd.Sample, out: *pd.Sample, n: c_int) void;
pub extern fn dsp_add_copy(in: *pd.Sample, out: *pd.Sample, n: c_int) void;
pub extern fn dsp_add_scalarcopy(in: *pd.Float, out: *pd.Sample, n: c_int) void;
pub extern fn dsp_add_zero(out: *pd.Sample, n: c_int) void;
pub extern fn sys_getblksize() c_int;
pub extern fn sys_getsr() pd.Float;
pub extern fn sys_get_inchannels() c_int;
pub extern fn sys_get_outchannels() c_int;
pub extern fn dsp_add(f: pd.PerfRoutine, n: c_int, ...) void;
pub extern fn dsp_addv(f: pd.PerfRoutine, n: c_int, vec: [*]pd.Int) void;
pub extern fn pd_fft(buf: *pd.Float, npoints: c_int, inverse: c_int) void;
pub extern fn ilog2(n: c_int) c_int;
pub extern fn mayer_fht(fz: *pd.Sample, n: c_int) void;
pub extern fn mayer_fft(n: c_int, real: *pd.Sample, imag: *pd.Sample) void;
pub extern fn mayer_ifft(n: c_int, real: *pd.Sample, imag: *pd.Sample) void;
pub extern fn mayer_realfft(n: c_int, real: *pd.Sample) void;
pub extern fn mayer_realifft(n: c_int, real: *pd.Sample) void;
pub extern fn canvas_suspend_dsp() c_int;
pub extern fn canvas_resume_dsp(oldstate: c_int) void;
pub extern fn canvas_update_dsp() void;
pub extern var canvas_dspstate: c_int;
pub const struct__resample = extern struct {
    method: c_int = @import("std").mem.zeroes(c_int),
    downsample: c_int = @import("std").mem.zeroes(c_int),
    upsample: c_int = @import("std").mem.zeroes(c_int),
    s_vec: [*c]t_sample = @import("std").mem.zeroes([*c]t_sample),
    s_n: c_int = @import("std").mem.zeroes(c_int),
    coeffs: [*c]t_sample = @import("std").mem.zeroes([*c]t_sample),
    coefsize: c_int = @import("std").mem.zeroes(c_int),
    buffer: [*c]t_sample = @import("std").mem.zeroes([*c]t_sample),
    bufsize: c_int = @import("std").mem.zeroes(c_int),
};
pub const t_resample = pd.Resample;
pub extern fn resample_init(x: *pd.Resample) void;
pub extern fn resample_free(x: *pd.Resample) void;
pub extern fn resample_dsp(x: *pd.Resample, in: *pd.Sample, insize: c_int, out: *pd.Sample, outsize: c_int, method: c_int) void;
pub extern fn resamplefrom_dsp(x: *pd.Resample, in: *pd.Sample, insize: c_int, outsize: c_int, method: c_int) void;
pub extern fn resampleto_dsp(x: *pd.Resample, out: *pd.Sample, insize: c_int, outsize: c_int, method: c_int) void;
pub extern fn mtof(t_float) pd.Float;
pub extern fn ftom(t_float) pd.Float;
pub extern fn rmstodb(t_float) pd.Float;
pub extern fn powtodb(t_float) pd.Float;
pub extern fn dbtorms(t_float) pd.Float;
pub extern fn dbtopow(t_float) pd.Float;
pub extern fn q8_sqrt(t_float) pd.Float;
pub extern fn q8_rsqrt(t_float) pd.Float;
pub extern fn qsqrt(t_float) pd.Float;
pub extern fn qrsqrt(t_float) pd.Float;
pub const struct__garray = opaque {};
pub extern var garray_class: ?*struct__class;
pub extern fn garray_getfloatwords(x: *pd.GArray, size: *c_int, vec: *[*]pd.Word) c_int;
pub extern fn garray_redraw(x: *pd.GArray) void;
pub extern fn garray_npoints(x: *pd.GArray) c_int;
pub extern fn garray_vec(x: *pd.GArray) [*c]u8;
pub extern fn garray_resize_long(x: *pd.GArray, n: c_long) void;
pub extern fn garray_usedindsp(x: *pd.GArray) void;
pub extern fn garray_setsaveit(x: *pd.GArray, saveit: c_int) void;
pub extern fn garray_getglist(x: *pd.GArray) ?*cnv.GList;
pub extern fn garray_getarray(x: *pd.GArray) [*c]cnv.Array;
pub extern var scalar_class: ?*struct__class;
pub extern fn value_get(s: *pd.Symbol) [*c]pd.Float;
pub extern fn value_release(s: *pd.Symbol) void;
pub extern fn value_getfloat(s: *pd.Symbol, f: *pd.Float) c_int;
pub extern fn value_setfloat(s: *pd.Symbol, f: pd.Float) c_int;
pub const t_guicallbackfn = ?*const fn ([*c]pd.GObj, ?*cnv.GList) callconv(.C) void;
pub extern fn sys_pretendguibytes(n: c_int) void;
pub extern fn sys_queuegui(client: *anyopaque, glist: *cnv.GList, f: pd.GuiCallbackFn) void;
pub extern fn sys_unqueuegui(client: *anyopaque) void;
pub extern fn pdgui_vmess(destination: [*:0]const u8, fmt: [*:0]const u8, ...) void;
pub extern fn pdgui_stub_vnew(owner: *pd.Pd, destination: [*:0]const u8, key: *anyopaque, fmt: [*:0]const u8, ...) void;
pub extern fn pdgui_stub_deleteforkey(key: *anyopaque) void;
pub extern var glob_pdobject: ?*struct__class;
pub const t_externclass = ?*struct__class;
pub extern fn c_extern(cls: *pd.Externclass, newroutine: pd.NewMethod, freeroutine: pd.Method, name: *pd.Symbol, size: usize, tiny: c_int, arg1: t_atomtype, ...) void;
pub extern fn c_addmess(@"fn": pd.Method, sel: *pd.Symbol, arg1: t_atomtype, ...) void;
pub const t_bigorsmall32 = extern union {
    f: t_float,
    ui: c_uint,
};
pub fn PD_BADFLOAT(arg_f: t_float) callconv(.C) c_int {
    var f = arg_f;
    _ = &f;
    var pun: t_bigorsmall32 = undefined;
    _ = &pun;
    pun.f = f;
    pun.ui &= @as(c_uint, @bitCast(@as(c_int, 2139095040)));
    return @intFromBool(pun.ui == @as(c_uint, @bitCast(@as(c_int, 0)))) | @intFromBool(pun.ui == @as(c_uint, @bitCast(@as(c_int, 2139095040))));
}
pub fn PD_BIGORSMALL(arg_f: t_float) callconv(.C) c_int {
    var f = arg_f;
    _ = &f;
    var pun: t_bigorsmall32 = undefined;
    _ = &pun;
    pun.f = f;
    return @intFromBool((pun.ui & @as(c_uint, @bitCast(@as(c_int, 536870912)))) == ((pun.ui >> @intCast(1)) & @as(c_uint, @bitCast(@as(c_int, 536870912)))));
}
pub extern fn sys_getversion(major: *c_int, minor: *c_int, bugfix: *c_int) c_uint;
pub fn _sys_getversioncode(arg_major: [*c]c_int, arg_minor: [*c]c_int, arg_bugfix: [*c]c_int) callconv(.C) c_uint {
    var major = arg_major;
    _ = &major;
    var minor = arg_minor;
    _ = &minor;
    var bugfix = arg_bugfix;
    _ = &bugfix;
    var a: c_int = undefined;
    _ = &a;
    var b: c_int = undefined;
    _ = &b;
    var c: c_int = undefined;
    _ = &c;
    _ = sys_getversion(major, minor, bugfix);
    _ = sys_getversion(&a, &b, &c);
    return @as(c_uint, @bitCast(((a << @intCast(16)) + (b << @intCast(8))) + (if (c > @as(c_int, 255)) @as(c_int, 255) else c)));
}
pub extern fn sys_getfunbyname(name: [*:0]const u8) pd.Method;
pub extern fn sys_getfloatsize() c_uint;
pub const struct__instancemidi = opaque {};
pub const struct__instanceinter = opaque {};
pub const struct__instanceeditor_6 = opaque {};
pub const struct__instancetemplate_7 = opaque {};
pub const struct__instancecanvas = extern struct {
    i_editor: ?*struct__instanceeditor_6 = @import("std").mem.zeroes(?*struct__instanceeditor_6),
    i_template: ?*struct__instancetemplate_7 = @import("std").mem.zeroes(?*struct__instancetemplate_7),
    i_newfilename: [*c]t_symbol = @import("std").mem.zeroes([*c]t_symbol),
    i_newdirectory: [*c]t_symbol = @import("std").mem.zeroes([*c]t_symbol),
    i_newargc: c_int = @import("std").mem.zeroes(c_int),
    i_newargv: [*c]t_atom = @import("std").mem.zeroes([*c]t_atom),
    i_reloadingabstraction: ?*struct__glist = @import("std").mem.zeroes(?*struct__glist),
    i_dspstate: c_int = @import("std").mem.zeroes(c_int),
    i_dollarzero: c_int = @import("std").mem.zeroes(c_int),
    i_graph_lastxpix: t_float = @import("std").mem.zeroes(t_float),
    i_graph_lastypix: t_float = @import("std").mem.zeroes(t_float),
};
pub const struct__instanceugen = opaque {};
pub const struct__instancestuff = opaque {};
pub const struct__pdinstance = extern struct {
    pd_systime: f64 = @import("std").mem.zeroes(f64),
    pd_clock_setlist: ?*struct__clock = @import("std").mem.zeroes(?*struct__clock),
    pd_canvaslist: ?*struct__glist = @import("std").mem.zeroes(?*struct__glist),
    pd_templatelist: [*c]struct__template = @import("std").mem.zeroes([*c]struct__template),
    pd_instanceno: c_int = @import("std").mem.zeroes(c_int),
    pd_symhash: [*c][*c]t_symbol = @import("std").mem.zeroes([*c][*c]t_symbol),
    pd_midi: ?*struct__instancemidi = @import("std").mem.zeroes(?*struct__instancemidi),
    pd_inter: ?*struct__instanceinter = @import("std").mem.zeroes(?*struct__instanceinter),
    pd_ugen: ?*struct__instanceugen = @import("std").mem.zeroes(?*struct__instanceugen),
    pd_gui: [*c]struct__instancecanvas = @import("std").mem.zeroes([*c]struct__instancecanvas),
    pd_stuff: ?*struct__instancestuff = @import("std").mem.zeroes(?*struct__instancestuff),
    pd_newest: [*c]t_pd = @import("std").mem.zeroes([*c]t_pd),
    pd_islocked: c_int = @import("std").mem.zeroes(c_int),
};
pub extern var pd_maininstance: struct__pdinstance;
pub extern var s_pointer: t_symbol;
pub extern var s_float: t_symbol;
pub extern var s_symbol: t_symbol;
pub extern var s_bang: t_symbol;
pub extern var s_list: t_symbol;
pub extern var s_anything: t_symbol;
pub extern var s_signal: t_symbol;
pub extern var s__N: t_symbol;
pub extern var s__X: t_symbol;
pub extern var s_x: t_symbol;
pub extern var s_y: t_symbol;
pub extern var s_: t_symbol;
pub extern fn pd_getcanvaslist() ?*cnv.GList;
pub extern fn pd_getdspstate() c_int;
pub extern fn text_getbufbyname(s: *pd.Symbol) ?*pd.BinBuf;
pub extern fn text_notifybyname(s: *pd.Symbol) void;
pub extern fn pd_undo_set_objectstate(canvas: *cnv.GList, x: *pd.Pd, s: *pd.Symbol, undo_argc: c_int, undo_argv: [*]pd.Atom, redo_argc: c_int, redo_argv: [*]pd.Atom) void;
pub const t_bangmethodr = ?*const fn ([*c]pd.Pd) callconv(.C) ?*anyopaque;
pub const t_pointermethodr = ?*const fn ([*c]pd.Pd, [*c]pd.GPointer) callconv(.C) ?*anyopaque;
pub const t_floatmethodr = ?*const fn ([*c]pd.Pd, pd.Float) callconv(.C) ?*anyopaque;
pub const t_symbolmethodr = ?*const fn ([*c]pd.Pd, [*c]pd.Symbol) callconv(.C) ?*anyopaque;
pub const t_listmethodr = ?*const fn ([*c]pd.Pd, [*c]pd.Symbol, c_int, [*c]pd.Atom) callconv(.C) ?*anyopaque;
pub const t_anymethodr = ?*const fn ([*c]pd.Pd, [*c]pd.Symbol, c_int, [*c]pd.Atom) callconv(.C) ?*anyopaque;
pub extern fn pd_init_systems() void;
pub extern fn pd_term_systems() void;
pub extern fn pd_emptylist(x: *pd.Pd) void;
pub extern fn obj_noutlets(x: *const pd.Object) c_int;
pub extern fn obj_ninlets(x: *const pd.Object) c_int;
pub extern fn obj_starttraverseoutlet(x: *const pd.Object, op: [*c]?*pd.Outlet, nout: c_int) ?*pd.Outconnect;
pub extern fn obj_nexttraverseoutlet(lastconnect: *pd.Outconnect, destp: *[*]pd.Object, inletp: [*c]?*pd.Inlet, whichp: *c_int) ?*pd.Outconnect;
pub extern fn obj_connect(source: *pd.Object, outno: c_int, sink: *pd.Object, inno: c_int) ?*pd.Outconnect;
pub extern fn obj_disconnect(source: *pd.Object, outno: c_int, sink: *pd.Object, inno: c_int) void;
pub extern fn outlet_setstacklim() void;
pub extern fn obj_issignalinlet(x: *const pd.Object, m: c_int) c_int;
pub extern fn obj_issignaloutlet(x: *const pd.Object, m: c_int) c_int;
pub extern fn obj_nsiginlets(x: *const pd.Object) c_int;
pub extern fn obj_nsigoutlets(x: *const pd.Object) c_int;
pub extern fn obj_siginletindex(x: *const pd.Object, m: c_int) c_int;
pub extern fn obj_sigoutletindex(x: *const pd.Object, m: c_int) c_int;
pub extern fn obj_findsignalscalar(x: *const pd.Object, m: c_int) [*c]pd.Float;
pub extern fn pd_globallock() void;
pub extern fn pd_globalunlock() void;
pub extern fn glob_evalfile(ignore: *pd.Pd, name: *pd.Symbol, dir: *pd.Symbol) [*c]pd.Pd;
pub extern fn glob_initfromgui(dummy: *anyopaque, s: *pd.Symbol, argc: c_int, argv: [*]pd.Atom) void;
pub extern fn glob_quit(dummy: *anyopaque) void;
pub extern fn glob_exit(dummy: *anyopaque, status: pd.Float) void;
pub extern fn glob_watchdog(dummy: *anyopaque) void;
pub extern fn open_via_helppath(name: [*:0]const u8, dir: [*:0]const u8) void;
pub const struct__tscalar = opaque {};
pub const struct__fielddesc = opaque {};
pub const struct__arrayvis = extern struct {
    av_upd: t_updateheader = @import("std").mem.zeroes(t_updateheader),
    av_garray: ?*struct__garray = @import("std").mem.zeroes(?*struct__garray),
};
pub const t_arrayvis = pd.Arrayvis;
pub const struct__linetraverser = extern struct {
    tr_x: ?*struct__glist = @import("std").mem.zeroes(?*struct__glist),
    tr_ob: [*c]t_object = @import("std").mem.zeroes([*c]t_object),
    tr_nout: c_int = @import("std").mem.zeroes(c_int),
    tr_outno: c_int = @import("std").mem.zeroes(c_int),
    tr_ob2: [*c]t_object = @import("std").mem.zeroes([*c]t_object),
    tr_outlet: ?*struct__outlet = @import("std").mem.zeroes(?*struct__outlet),
    tr_inlet: ?*struct__inlet = @import("std").mem.zeroes(?*struct__inlet),
    tr_nin: c_int = @import("std").mem.zeroes(c_int),
    tr_inno: c_int = @import("std").mem.zeroes(c_int),
    tr_x11: c_int = @import("std").mem.zeroes(c_int),
    tr_y11: c_int = @import("std").mem.zeroes(c_int),
    tr_x12: c_int = @import("std").mem.zeroes(c_int),
    tr_y12: c_int = @import("std").mem.zeroes(c_int),
    tr_x21: c_int = @import("std").mem.zeroes(c_int),
    tr_y21: c_int = @import("std").mem.zeroes(c_int),
    tr_x22: c_int = @import("std").mem.zeroes(c_int),
    tr_y22: c_int = @import("std").mem.zeroes(c_int),
    tr_lx1: c_int = @import("std").mem.zeroes(c_int),
    tr_ly1: c_int = @import("std").mem.zeroes(c_int),
    tr_lx2: c_int = @import("std").mem.zeroes(c_int),
    tr_ly2: c_int = @import("std").mem.zeroes(c_int),
    tr_nextoc: ?*struct__outconnect = @import("std").mem.zeroes(?*struct__outconnect),
    tr_nextoutno: c_int = @import("std").mem.zeroes(c_int),
};
pub const t_linetraverser = pd.Linetraverser;
pub extern fn g_editor_newpdinstance() void;
pub extern fn g_template_newpdinstance() void;
pub extern fn g_editor_freepdinstance() void;
pub extern fn g_template_freepdinstance() void;
pub extern fn canvas_setcursor(x: *cnv.GList, cursornum: c_uint) void;
pub extern var canvas_whichfind: ?*struct__glist;
pub extern var vinlet_class: ?*struct__class;
pub extern var voutlet_class: ?*struct__class;
pub extern var glist_valid: c_int;
pub extern fn gobj_getrect(x: *pd.GObj, owner: *cnv.GList, x1: *c_int, y1: *c_int, x2: *c_int, y2: *c_int) void;
pub extern fn gobj_displace(x: *pd.GObj, owner: *cnv.GList, dx: c_int, dy: c_int) void;
pub extern fn gobj_select(x: *pd.GObj, owner: *cnv.GList, state: c_int) void;
pub extern fn gobj_activate(x: *pd.GObj, owner: *cnv.GList, state: c_int) void;
pub extern fn gobj_delete(x: *pd.GObj, owner: *cnv.GList) void;
pub extern fn gobj_vis(x: *pd.GObj, glist: *cnv.GList, flag: c_int) void;
pub extern fn gobj_click(x: *pd.GObj, glist: *cnv.GList, xpix: c_int, ypix: c_int, shift: c_int, alt: c_int, dbl: c_int, doit: c_int) c_int;
pub extern fn gobj_save(x: *pd.GObj, b: *pd.BinBuf) void;
pub extern fn gobj_shouldvis(x: *pd.GObj, glist: *cnv.GList) c_int;
pub extern fn glist_init(x: *cnv.GList) void;
pub extern fn glist_add(x: *cnv.GList, g: *pd.GObj) void;
pub extern fn glist_clear(x: *cnv.GList) void;
pub extern fn glist_getcanvas(x: *cnv.GList) ?*cnv.GList;
pub extern fn glist_isselected(x: *cnv.GList, y: *pd.GObj) c_int;
pub extern fn glist_select(x: *cnv.GList, y: *pd.GObj) void;
pub extern fn glist_deselect(x: *cnv.GList, y: *pd.GObj) void;
pub extern fn glist_noselect(x: *cnv.GList) void;
pub extern fn glist_selectall(x: *cnv.GList) void;
pub extern fn glist_delete(x: *cnv.GList, y: *pd.GObj) void;
pub extern fn glist_retext(x: *cnv.GList, y: *pd.Object) void;
pub extern fn glist_grab(x: *cnv.GList, y: *pd.GObj, motionfn: cnv.GListMotionFn, keyfn: cnv.GListKeyFn, xpos: c_int, ypos: c_int) void;
pub extern fn glist_isvisible(x: *cnv.GList) c_int;
pub extern fn glist_istoplevel(x: *cnv.GList) c_int;
pub extern fn glist_findgraph(x: *cnv.GList) ?*cnv.GList;
pub extern fn glist_getfont(x: *cnv.GList) c_int;
pub extern fn glist_fontwidth(x: *cnv.GList) c_int;
pub extern fn glist_fontheight(x: *cnv.GList) c_int;
pub extern fn glist_getzoom(x: *cnv.GList) c_int;
pub extern fn glist_sort(canvas: *cnv.GList) void;
pub extern fn glist_read(x: *cnv.GList, filename: *pd.Symbol, format: *pd.Symbol) void;
pub extern fn glist_mergefile(x: *cnv.GList, filename: *pd.Symbol, format: *pd.Symbol) void;
pub extern fn glist_pixelstox(x: *cnv.GList, xpix: pd.Float) pd.Float;
pub extern fn glist_pixelstoy(x: *cnv.GList, ypix: pd.Float) pd.Float;
pub extern fn glist_xtopixels(x: *cnv.GList, xval: pd.Float) pd.Float;
pub extern fn glist_ytopixels(x: *cnv.GList, yval: pd.Float) pd.Float;
pub extern fn glist_dpixtodx(x: *cnv.GList, dxpix: pd.Float) pd.Float;
pub extern fn glist_dpixtody(x: *cnv.GList, dypix: pd.Float) pd.Float;
pub extern fn glist_getnextxy(gl: *cnv.GList, xval: *c_int, yval: *c_int) void;
pub extern fn glist_glist(g: *cnv.GList, s: *pd.Symbol, argc: c_int, argv: [*]pd.Atom) void;
pub extern fn glist_addglist(g: *cnv.GList, sym: *pd.Symbol, x1: pd.Float, y1: pd.Float, x2: pd.Float, y2: pd.Float, px1: pd.Float, py1: pd.Float, px2: pd.Float, py2: pd.Float) ?*cnv.GList;
pub extern fn glist_arraydialog(parent: *cnv.GList, name: *pd.Symbol, size: pd.Float, saveit: pd.Float, newgraph: pd.Float) void;
pub extern fn glist_writetobinbuf(x: *cnv.GList, wholething: c_int) ?*pd.BinBuf;
pub extern fn glist_isgraph(x: *cnv.GList) c_int;
pub extern fn glist_redraw(x: *cnv.GList) void;
pub extern fn glist_drawiofor(glist: *cnv.GList, ob: *pd.Object, firsttime: c_int, tag: [*:0]const u8, x1: c_int, y1: c_int, x2: c_int, y2: c_int) void;
pub extern fn glist_eraseiofor(glist: *cnv.GList, ob: *pd.Object, tag: [*:0]const u8) void;
pub extern fn canvas_create_editor(x: *cnv.GList) void;
pub extern fn canvas_destroy_editor(x: *cnv.GList) void;
pub extern fn canvas_deletelinesforio(x: *cnv.GList, text: *pd.Object, inp: *pd.Inlet, outp: *pd.Outlet) void;
pub extern fn text_setto(x: *pd.Object, glist: *cnv.GList, buf: [*:0]const u8, bufsize: c_int) void;
pub extern fn text_drawborder(x: *pd.Object, glist: *cnv.GList, tag: [*:0]const u8, width: c_int, height: c_int, firsttime: c_int) void;
pub extern fn text_eraseborder(x: *pd.Object, glist: *cnv.GList, tag: [*:0]const u8) void;
pub extern fn text_xpix(x: *pd.Object, glist: *cnv.GList) c_int;
pub extern fn text_ypix(x: *pd.Object, glist: *cnv.GList) c_int;
pub extern const text_widgetbehavior: struct__widgetbehavior;
pub extern fn rtext_new(glist: *cnv.GList, who: *pd.Object) ?*pd.Rtext;
pub extern fn glist_findrtext(gl: *cnv.GList, who: *pd.Object) ?*pd.Rtext;
pub extern fn rtext_draw(x: *pd.Rtext) void;
pub extern fn rtext_erase(x: *pd.Rtext) void;
pub extern fn rtext_height(x: *pd.Rtext) c_int;
pub extern fn rtext_displace(x: *pd.Rtext, dx: c_int, dy: c_int) void;
pub extern fn rtext_select(x: *pd.Rtext, state: c_int) void;
pub extern fn rtext_activate(x: *pd.Rtext, state: c_int) void;
pub extern fn rtext_free(x: *pd.Rtext) void;
pub extern fn rtext_key(x: *pd.Rtext, n: c_int, s: *pd.Symbol) void;
pub extern fn rtext_mouse(x: *pd.Rtext, xval: c_int, yval: c_int, flag: c_int) void;
pub extern fn rtext_retext(x: *pd.Rtext) void;
pub extern fn rtext_width(x: *pd.Rtext) c_int;
pub extern fn rtext_gettag(x: *pd.Rtext) [*c]const u8;
pub extern fn rtext_gettext(x: *pd.Rtext, buf: *[*]u8, bufsize: *c_int) void;
pub extern fn rtext_getseltext(x: *pd.Rtext, buf: *[*]u8, bufsize: *c_int) void;
pub extern fn rtext_getowner(x: *pd.Rtext) [*c]pd.Object;
pub extern var canvas_class: ?*struct__class;
pub extern fn canvas_new(dummy: *anyopaque, sel: *pd.Symbol, argc: c_int, argv: [*]pd.Atom) ?*cnv.GList;
pub extern fn canvas_makebindsym(s: *pd.Symbol) [*c]pd.Symbol;
pub extern fn canvas_fixlinesfor(x: *cnv.GList, text: *pd.Object) void;
pub extern fn canvas_deletelinesfor(x: *cnv.GList, text: *pd.Object) void;
pub extern fn canvas_stowconnections(x: *cnv.GList) void;
pub extern fn canvas_restoreconnections(x: *cnv.GList) void;
pub extern fn canvas_redraw(x: *cnv.GList) void;
pub extern fn canvas_closebang(x: *cnv.GList) void;
pub extern fn canvas_initbang(x: *cnv.GList) void;
pub extern fn canvas_addinlet(x: *cnv.GList, who: *pd.Pd, sym: *pd.Symbol) ?*pd.Inlet;
pub extern fn canvas_rminlet(x: *cnv.GList, ip: *pd.Inlet) void;
pub extern fn canvas_addoutlet(x: *cnv.GList, who: *pd.Pd, sym: *pd.Symbol) ?*pd.Outlet;
pub extern fn canvas_rmoutlet(x: *cnv.GList, op: *pd.Outlet) void;
pub extern fn canvas_redrawallfortemplate(tmpl: *cnv.Template, action: c_int) void;
pub extern fn canvas_redrawallfortemplatecanvas(x: *cnv.GList, action: c_int) void;
pub extern fn canvas_setcurrent(x: *cnv.GList) void;
pub extern fn canvas_unsetcurrent(x: *cnv.GList) void;
pub extern fn canvas_realizedollar(x: *cnv.GList, s: *pd.Symbol) [*c]pd.Symbol;
pub extern fn canvas_getrootfor(x: *cnv.GList) ?*cnv.GList;
pub extern fn canvas_dirty(x: *cnv.GList, n: pd.Float) void;
pub const t_canvasapply = ?*const fn (?*cnv.GList, pd.Int, pd.Int, pd.Int) callconv(.C) c_int;
pub extern fn canvas_resortinlets(x: *cnv.GList) void;
pub extern fn canvas_resortoutlets(x: *cnv.GList) void;
pub extern fn canvas_free(x: *cnv.GList) void;
pub extern fn canvas_updatewindowlist() void;
pub extern fn canvas_editmode(x: *cnv.GList, state: pd.Float) void;
pub extern fn canvas_isabstraction(x: *const cnv.GList) c_int;
pub extern fn canvas_istable(x: *const cnv.GList) c_int;
pub extern fn canvas_showtext(x: *const cnv.GList) c_int;
pub extern fn canvas_vis(x: *cnv.GList, f: pd.Float) void;
pub extern fn canvas_getenv(x: *const cnv.GList) ?*cnv.CanvasEnvironment;
pub extern fn canvas_rename(x: *cnv.GList, s: *pd.Symbol, dir: *pd.Symbol) void;
pub extern fn canvas_loadbang(x: *cnv.GList) void;
pub extern fn canvas_hitbox(x: *cnv.GList, y: *pd.GObj, xpos: c_int, ypos: c_int, x1p: *c_int, y1p: *c_int, x2p: *c_int, y2p: *c_int) c_int;
pub extern fn canvas_setdeleting(x: *cnv.GList, flag: c_int) c_int;
pub const t_undofn = ?*const fn (?*cnv.GList, ?*anyopaque, c_int) callconv(.C) c_int;
pub extern fn canvas_setundo(x: *cnv.GList, undofn: pd.Undofn, buf: *anyopaque, name: [*:0]const u8) void;
pub extern fn canvas_noundo(x: *cnv.GList) void;
pub extern fn canvas_getindex(x: *cnv.GList, y: *pd.GObj) c_int;
pub extern fn canvas_connect(x: *cnv.GList, fwhoout: pd.Float, foutno: pd.Float, fwhoin: pd.Float, finno: pd.Float) void;
pub extern fn canvas_disconnect(x: *cnv.GList, index1: pd.Float, outno: pd.Float, index2: pd.Float, inno: pd.Float) void;
pub extern fn canvas_isconnected(x: *cnv.GList, ob1: *pd.Object, n1: c_int, ob2: *pd.Object, n2: c_int) c_int;
pub extern fn canvas_selectinrect(x: *cnv.GList, lox: c_int, loy: c_int, hix: c_int, hiy: c_int) void;
pub extern fn pd_checkglist(x: *pd.Pd) ?*cnv.GList;
pub const t_canvas_path_iterator = ?*const fn ([*c]const u8, ?*anyopaque) callconv(.C) c_int;
pub extern fn canvas_path_iterate(x: *const cnv.GList, fun: pd.Canvas_path_iterator, user_data: *anyopaque) c_int;
pub extern fn linetraverser_start(t: *pd.Linetraverser, x: *cnv.GList) void;
pub extern fn linetraverser_next(t: *pd.Linetraverser) ?*pd.Outconnect;
pub extern fn linetraverser_skipobject(t: *pd.Linetraverser) void;
pub extern fn garray_template(x: *pd.GArray) [*c]cnv.Template;
pub extern fn graph_array(gl: *cnv.GList, s: *pd.Symbol, tmpl: *pd.Symbol, f: pd.Float, flags: pd.Float) ?*pd.GArray;
pub extern fn array_new(templatesym: *pd.Symbol, parent: *pd.GPointer) [*c]cnv.Array;
pub extern fn array_resize(x: *cnv.Array, n: c_int) void;
pub extern fn array_free(x: *cnv.Array) void;
pub extern fn array_redraw(a: *cnv.Array, glist: *cnv.GList) void;
pub extern fn array_resize_and_redraw(array: *cnv.Array, glist: *cnv.GList, n: c_int) void;
pub extern fn gstub_new(gl: *cnv.GList, a: *cnv.Array) [*c]pd.GStub;
pub extern fn gstub_cutoff(gs: *pd.GStub) void;
pub extern fn gpointer_setglist(gp: *pd.GPointer, glist: *cnv.GList, x: *pd.Scalar) void;
pub extern fn gpointer_setarray(gp: *pd.GPointer, array: *cnv.Array, w: *pd.Word) void;
pub extern fn word_init(wp: *pd.Word, tmpl: *cnv.Template, gp: *pd.GPointer) void;
pub extern fn word_restore(wp: *pd.Word, tmpl: *cnv.Template, argc: c_int, argv: [*]pd.Atom) void;
pub extern fn scalar_new(owner: *cnv.GList, templatesym: *pd.Symbol) [*c]pd.Scalar;
pub extern fn word_free(wp: *pd.Word, tmpl: *cnv.Template) void;
pub extern fn scalar_getbasexy(x: *pd.Scalar, basex: *pd.Float, basey: *pd.Float) void;
pub extern fn scalar_redraw(x: *pd.Scalar, glist: *cnv.GList) void;
pub extern fn canvas_writescalar(templatesym: *pd.Symbol, w: *pd.Word, b: *pd.BinBuf, amarrayelement: c_int) void;
pub extern fn canvas_readscalar(x: *cnv.GList, natoms: c_int, vec: [*]pd.Atom, p_nextmsg: *c_int, selectit: c_int) c_int;
pub extern fn array_getcoordinate(glist: *cnv.GList, elem: [*:0]u8, xonset: c_int, yonset: c_int, wonset: c_int, indx: c_int, basex: pd.Float, basey: pd.Float, xinc: pd.Float, xfielddesc: *pd.Fielddesc, yfielddesc: *pd.Fielddesc, wfielddesc: *pd.Fielddesc, xp: *pd.Float, yp: *pd.Float, wp: *pd.Float) void;
pub extern fn array_getfields(elemtemplatesym: *pd.Symbol, elemtemplatecanvasp: [*c]?*cnv.GList, elemtemplatep: *[*]cnv.Template, elemsizep: *c_int, xfielddesc: *pd.Fielddesc, yfielddesc: *pd.Fielddesc, wfielddesc: *pd.Fielddesc, xonsetp: *c_int, yonsetp: *c_int, wonsetp: *c_int) c_int;
pub extern fn template_new(sym: *pd.Symbol, argc: c_int, argv: [*]pd.Atom) [*c]cnv.Template;
pub extern fn template_free(x: *cnv.Template) void;
pub extern fn template_match(x1: *cnv.Template, x2: *cnv.Template) c_int;
pub extern fn template_find_field(x: *cnv.Template, name: *pd.Symbol, p_onset: *c_int, p_type: *c_int, p_arraytype: **pd.Symbol) c_int;
pub extern fn template_getfloat(x: *cnv.Template, fieldname: *pd.Symbol, wp: *pd.Word, loud: c_int) pd.Float;
pub extern fn template_setfloat(x: *cnv.Template, fieldname: *pd.Symbol, wp: *pd.Word, f: pd.Float, loud: c_int) void;
pub extern fn template_getsymbol(x: *cnv.Template, fieldname: *pd.Symbol, wp: *pd.Word, loud: c_int) [*c]pd.Symbol;
pub extern fn template_setsymbol(x: *cnv.Template, fieldname: *pd.Symbol, wp: *pd.Word, s: *pd.Symbol, loud: c_int) void;
pub extern fn gtemplate_get(x: *pd.Gtemplate) [*c]cnv.Template;
pub extern fn template_findbyname(s: *pd.Symbol) [*c]cnv.Template;
pub extern fn template_findcanvas(tmpl: *cnv.Template) ?*cnv.GList;
pub extern fn template_notify(tmpl: *cnv.Template, s: *pd.Symbol, argc: c_int, argv: [*]pd.Atom) void;
pub extern fn fielddesc_getcoord(f: *pd.Fielddesc, tmpl: *cnv.Template, wp: *pd.Word, loud: c_int) pd.Float;
pub extern fn fielddesc_setcoord(f: *pd.Fielddesc, tmpl: *cnv.Template, wp: *pd.Word, pix: pd.Float, loud: c_int) void;
pub extern fn fielddesc_cvttocoord(f: *pd.Fielddesc, val: pd.Float) pd.Float;
pub extern fn fielddesc_cvtfromcoord(f: *pd.Fielddesc, coord: pd.Float) pd.Float;
pub extern fn guiconnect_new(who: *pd.Pd, sym: *pd.Symbol) ?*pd.Guiconnect;
pub extern fn guiconnect_notarget(x: *pd.Guiconnect, timedelay: f64) void;
pub extern fn iemgui_raute2dollar(s: *pd.Symbol) [*c]pd.Symbol;
pub extern fn iemgui_dollar2raute(s: *pd.Symbol) [*c]pd.Symbol;
pub extern fn iemgui_put_in_braces(s: *pd.Symbol) [*c]pd.Symbol;
pub extern var clone_class: ?*struct__class;
pub extern fn signal_setborrowed(sig: *pd.Signal, sig2: *pd.Signal) void;
pub extern fn signal_makereusable(sig: *pd.Signal) void;
pub const horizontal: c_int = 0;
pub const vertical: c_int = 1;
pub const t_iem_orientation = c_uint;
// /usr/include/pd/g_all_guis.h:117:18: warning: struct demoted to opaque type - has bitfield
pub const struct__iem_fstyle_flags = opaque {};
pub const t_iem_fstyle_flags = iem.FontStyleFlags;
// /usr/include/pd/g_all_guis.h:137:18: warning: struct demoted to opaque type - has bitfield
pub const struct__iem_init_symargs = opaque {};
pub const t_iem_init_symargs = iem.InitSymArgs;
pub const t_iemfunptr = ?*const fn (?*anyopaque, ?*cnv.GList, c_int) callconv(.C) void;
pub const t_iemdrawfunptr = ?*const fn (?*anyopaque, ?*cnv.GList) callconv(.C) void;
pub const struct__iemgui_drawfunctions = extern struct {
    draw_new: t_iemdrawfunptr = @import("std").mem.zeroes(t_iemdrawfunptr),
    draw_config: t_iemdrawfunptr = @import("std").mem.zeroes(t_iemdrawfunptr),
    draw_iolets: t_iemfunptr = @import("std").mem.zeroes(t_iemfunptr),
    draw_update: t_iemdrawfunptr = @import("std").mem.zeroes(t_iemdrawfunptr),
    draw_select: t_iemdrawfunptr = @import("std").mem.zeroes(t_iemdrawfunptr),
    draw_erase: t_iemdrawfunptr = @import("std").mem.zeroes(t_iemdrawfunptr),
    draw_move: t_iemdrawfunptr = @import("std").mem.zeroes(t_iemdrawfunptr),
};
pub const t_iemgui_drawfunctions = iem.DrawFunctions;
pub const struct__iemgui_private_8 = opaque {};
pub const struct__iemgui = extern struct {
    x_obj: t_object = @import("std").mem.zeroes(t_object),
    x_glist: ?*struct__glist = @import("std").mem.zeroes(?*struct__glist),
    x_draw: t_iemfunptr = @import("std").mem.zeroes(t_iemfunptr),
    x_h: c_int = @import("std").mem.zeroes(c_int),
    x_w: c_int = @import("std").mem.zeroes(c_int),
    x_private: ?*struct__iemgui_private_8 = @import("std").mem.zeroes(?*struct__iemgui_private_8),
    x_ldx: c_int = @import("std").mem.zeroes(c_int),
    x_ldy: c_int = @import("std").mem.zeroes(c_int),
    x_font: [1000]u8 = @import("std").mem.zeroes([1000]u8),
    x_fsf: t_iem_fstyle_flags = @import("std").mem.zeroes(t_iem_fstyle_flags),
    x_fontsize: c_int = @import("std").mem.zeroes(c_int),
    x_isa: t_iem_init_symargs = @import("std").mem.zeroes(t_iem_init_symargs),
    x_fcol: c_int = @import("std").mem.zeroes(c_int),
    x_bcol: c_int = @import("std").mem.zeroes(c_int),
    x_lcol: c_int = @import("std").mem.zeroes(c_int),
    x_snd: [*c]t_symbol = @import("std").mem.zeroes([*c]t_symbol),
    x_rcv: [*c]t_symbol = @import("std").mem.zeroes([*c]t_symbol),
    x_lab: [*c]t_symbol = @import("std").mem.zeroes([*c]t_symbol),
    x_snd_unexpanded: [*c]t_symbol = @import("std").mem.zeroes([*c]t_symbol),
    x_rcv_unexpanded: [*c]t_symbol = @import("std").mem.zeroes([*c]t_symbol),
    x_lab_unexpanded: [*c]t_symbol = @import("std").mem.zeroes([*c]t_symbol),
    x_binbufindex: c_int = @import("std").mem.zeroes(c_int),
    x_labelbindex: c_int = @import("std").mem.zeroes(c_int),
};
pub const t_iemgui = iem.Gui;
pub const struct__bng = extern struct {
    x_gui: t_iemgui = @import("std").mem.zeroes(t_iemgui),
    x_flashed: c_int = @import("std").mem.zeroes(c_int),
    x_flashtime_break: c_int = @import("std").mem.zeroes(c_int),
    x_flashtime_hold: c_int = @import("std").mem.zeroes(c_int),
    x_clock_hld: ?*struct__clock = @import("std").mem.zeroes(?*struct__clock),
    x_clock_brk: ?*struct__clock = @import("std").mem.zeroes(?*struct__clock),
    x_clock_lck: ?*struct__clock = @import("std").mem.zeroes(?*struct__clock),
    x_lastflashtime: f64 = @import("std").mem.zeroes(f64),
};
pub const t_bng = pd.Bng;
pub const struct__slider = extern struct {
    x_gui: t_iemgui = @import("std").mem.zeroes(t_iemgui),
    x_pos: c_int = @import("std").mem.zeroes(c_int),
    x_val: c_int = @import("std").mem.zeroes(c_int),
    x_lin0_log1: c_int = @import("std").mem.zeroes(c_int),
    x_steady: c_int = @import("std").mem.zeroes(c_int),
    x_min: f64 = @import("std").mem.zeroes(f64),
    x_max: f64 = @import("std").mem.zeroes(f64),
    x_k: f64 = @import("std").mem.zeroes(f64),
    x_fval: t_float = @import("std").mem.zeroes(t_float),
    x_orientation: t_iem_orientation = @import("std").mem.zeroes(t_iem_orientation),
};
pub const t_slider = pd.Slider;
pub const struct__radio = extern struct {
    x_gui: t_iemgui = @import("std").mem.zeroes(t_iemgui),
    x_on: c_int = @import("std").mem.zeroes(c_int),
    x_on_old: c_int = @import("std").mem.zeroes(c_int),
    x_change: c_int = @import("std").mem.zeroes(c_int),
    x_number: c_int = @import("std").mem.zeroes(c_int),
    x_drawn: c_int = @import("std").mem.zeroes(c_int),
    x_fval: t_float = @import("std").mem.zeroes(t_float),
    x_orientation: t_iem_orientation = @import("std").mem.zeroes(t_iem_orientation),
    x_compat: c_int = @import("std").mem.zeroes(c_int),
};
pub const t_radio = pd.Radio;
pub const struct__toggle = extern struct {
    x_gui: t_iemgui = @import("std").mem.zeroes(t_iemgui),
    x_on: t_float = @import("std").mem.zeroes(t_float),
    x_nonzero: t_float = @import("std").mem.zeroes(t_float),
};
pub const t_toggle = pd.Toggle;
pub const struct__my_canvas = extern struct {
    x_gui: t_iemgui = @import("std").mem.zeroes(t_iemgui),
    x_at: [3]t_atom = @import("std").mem.zeroes([3]t_atom),
    x_vis_w: c_int = @import("std").mem.zeroes(c_int),
    x_vis_h: c_int = @import("std").mem.zeroes(c_int),
};
pub const t_my_canvas = pd.My_canvas;
// /usr/include/pd/g_all_guis.h:254:18: warning: struct demoted to opaque type - has bitfield
pub const struct__vu = opaque {};
pub const t_vu = pd.Vu;
pub const struct__my_numbox = extern struct {
    x_gui: t_iemgui = @import("std").mem.zeroes(t_iemgui),
    x_clock_reset: ?*struct__clock = @import("std").mem.zeroes(?*struct__clock),
    x_clock_wait: ?*struct__clock = @import("std").mem.zeroes(?*struct__clock),
    x_val: t_float = @import("std").mem.zeroes(t_float),
    x_min: f64 = @import("std").mem.zeroes(f64),
    x_max: f64 = @import("std").mem.zeroes(f64),
    x_k: f64 = @import("std").mem.zeroes(f64),
    x_lin0_log1: c_int = @import("std").mem.zeroes(c_int),
    x_buf: [32]u8 = @import("std").mem.zeroes([32]u8),
    x_numwidth: c_int = @import("std").mem.zeroes(c_int),
    x_log_height: c_int = @import("std").mem.zeroes(c_int),
};
pub const t_my_numbox = pd.My_numbox;
pub const iemgui_color_hex: [*c]c_int = @extern([*c]c_int, .{
    .name = "iemgui_color_hex",
});
pub const iemgui_vu_db2i: [*c]c_int = @extern([*c]c_int, .{
    .name = "iemgui_vu_db2i",
});
pub const iemgui_vu_col: [*c]c_int = @extern([*c]c_int, .{
    .name = "iemgui_vu_col",
});
pub const iemgui_vu_scale_str: [*c][*c]u8 = @extern([*c][*c]u8, .{
    .name = "iemgui_vu_scale_str",
});
pub extern fn iemgui_clip_size(size: c_int) c_int;
pub extern fn iemgui_clip_font(size: c_int) c_int;
pub extern fn iemgui_dollararg2sym(s: *pd.Symbol, nth_arg: c_int, tail_len: c_int, pargc: c_int, pargv: [*]pd.Atom) [*c]pd.Symbol;
pub extern fn iemgui_verify_snd_ne_rcv(iemgui: *iem.Gui) void;
pub extern fn iemgui_all_sym2dollararg(iemgui: *iem.Gui, srlsym: **pd.Symbol) void;
pub extern fn iemgui_new_dogetname(iemgui: *iem.Gui, indx: c_int, argv: [*]pd.Atom) [*c]pd.Symbol;
pub extern fn iemgui_new_getnames(iemgui: *iem.Gui, indx: c_int, argv: [*]pd.Atom) void;
pub extern fn iemgui_all_dollararg2sym(iemgui: *iem.Gui, srlsym: **pd.Symbol) void;
pub extern fn iemgui_all_loadcolors(iemgui: *iem.Gui, bcol: *pd.Atom, fcol: *pd.Atom, lcol: *pd.Atom) void;
pub extern fn iemgui_all_dollar2raute(srlsym: **pd.Symbol) void;
pub extern fn iemgui_all_raute2dollar(srlsym: **pd.Symbol) void;
pub extern fn iemgui_send(x: *anyopaque, iemgui: *iem.Gui, s: *pd.Symbol) void;
pub extern fn iemgui_receive(x: *anyopaque, iemgui: *iem.Gui, s: *pd.Symbol) void;
pub extern fn iemgui_label(x: *anyopaque, iemgui: *iem.Gui, s: *pd.Symbol) void;
pub extern fn iemgui_label_pos(x: *anyopaque, iemgui: *iem.Gui, s: *pd.Symbol, ac: c_int, av: [*]pd.Atom) void;
pub extern fn iemgui_label_font(x: *anyopaque, iemgui: *iem.Gui, s: *pd.Symbol, ac: c_int, av: [*]pd.Atom) void;
pub extern fn iemgui_size(x: *anyopaque, iemgui: *iem.Gui) void;
pub extern fn iemgui_delta(x: *anyopaque, iemgui: *iem.Gui, s: *pd.Symbol, ac: c_int, av: [*]pd.Atom) void;
pub extern fn iemgui_pos(x: *anyopaque, iemgui: *iem.Gui, s: *pd.Symbol, ac: c_int, av: [*]pd.Atom) void;
pub extern fn iemgui_color(x: *anyopaque, iemgui: *iem.Gui, s: *pd.Symbol, ac: c_int, av: [*]pd.Atom) void;
pub extern fn iemgui_displace(z: *pd.GObj, glist: *cnv.GList, dx: c_int, dy: c_int) void;
pub extern fn iemgui_select(z: *pd.GObj, glist: *cnv.GList, selected: c_int) void;
pub extern fn iemgui_delete(z: *pd.GObj, glist: *cnv.GList) void;
pub extern fn iemgui_vis(z: *pd.GObj, glist: *cnv.GList, vis: c_int) void;
pub extern fn iemgui_save(iemgui: *iem.Gui, srl: **pd.Symbol, bflcol: **pd.Symbol) void;
pub extern fn iemgui_zoom(iemgui: *iem.Gui, zoom: pd.Float) void;
pub extern fn iemgui_newzoom(iemgui: *iem.Gui) void;
pub extern fn iemgui_properties(iemgui: *iem.Gui, srl: **pd.Symbol) void;
pub extern fn iemgui_dialog(iemgui: *iem.Gui, srl: **pd.Symbol, argc: c_int, argv: [*]pd.Atom) c_int;
pub extern fn iemgui_setdialogatoms(iemgui: *iem.Gui, argc: c_int, argv: [*]pd.Atom) void;
pub extern fn canvas_getdollarzero() c_int;
pub extern fn iem_inttosymargs(symargp: *iem.InitSymArgs, n: c_int) void;
pub extern fn iem_symargstoint(symargp: *iem.InitSymArgs) c_int;
pub extern fn iem_inttofstyle(fstylep: *iem.FontStyleFlags, n: c_int) void;
pub extern fn iem_fstyletoint(fstylep: *iem.FontStyleFlags) c_int;
pub extern fn iemgui_setdrawfunctions(iemgui: *iem.Gui, w: *iem.DrawFunctions) void;
pub extern fn iemgui_new(cls: *pd.Class) ?*iem.Gui;
pub extern fn iemgui_free(x: *iem.Gui) void;
pub extern fn iemgui_dolabel(x: *anyopaque, iemgui: *iem.Gui, s: *pd.Symbol, senditup: c_int) void;
pub extern fn iemgui_new_dialog(x: *anyopaque, iemgui: *iem.Gui, objname: [*:0]const u8, width: pd.Float, width_min: pd.Float, height: pd.Float, height_min: pd.Float, range_min: pd.Float, range_max: pd.Float, range_checkmode: c_int, mode: c_int, mode_label0: [*:0]const u8, mode_label1: [*:0]const u8, canloadbang: c_int, steady: c_int, number: c_int) void;
pub const __llvm__ = @as(c_int, 1);
pub const __clang__ = @as(c_int, 1);
pub const __clang_major__ = @as(c_int, 18);
pub const __clang_minor__ = @as(c_int, 1);
pub const __clang_patchlevel__ = @as(c_int, 6);
pub const __clang_version__ = "18.1.6 (https://github.com/ziglang/zig-bootstrap 98bc6bf4fc4009888d33941daf6b600d20a42a56)";
pub const __GNUC__ = @as(c_int, 4);
pub const __GNUC_MINOR__ = @as(c_int, 2);
pub const __GNUC_PATCHLEVEL__ = @as(c_int, 1);
pub const __GXX_ABI_VERSION = @as(c_int, 1002);
pub const __ATOMIC_RELAXED = @as(c_int, 0);
pub const __ATOMIC_CONSUME = @as(c_int, 1);
pub const __ATOMIC_ACQUIRE = @as(c_int, 2);
pub const __ATOMIC_RELEASE = @as(c_int, 3);
pub const __ATOMIC_ACQ_REL = @as(c_int, 4);
pub const __ATOMIC_SEQ_CST = @as(c_int, 5);
pub const __MEMORY_SCOPE_SYSTEM = @as(c_int, 0);
pub const __MEMORY_SCOPE_DEVICE = @as(c_int, 1);
pub const __MEMORY_SCOPE_WRKGRP = @as(c_int, 2);
pub const __MEMORY_SCOPE_WVFRNT = @as(c_int, 3);
pub const __MEMORY_SCOPE_SINGLE = @as(c_int, 4);
pub const __OPENCL_MEMORY_SCOPE_WORK_ITEM = @as(c_int, 0);
pub const __OPENCL_MEMORY_SCOPE_WORK_GROUP = @as(c_int, 1);
pub const __OPENCL_MEMORY_SCOPE_DEVICE = @as(c_int, 2);
pub const __OPENCL_MEMORY_SCOPE_ALL_SVM_DEVICES = @as(c_int, 3);
pub const __OPENCL_MEMORY_SCOPE_SUB_GROUP = @as(c_int, 4);
pub const __FPCLASS_SNAN = @as(c_int, 0x0001);
pub const __FPCLASS_QNAN = @as(c_int, 0x0002);
pub const __FPCLASS_NEGINF = @as(c_int, 0x0004);
pub const __FPCLASS_NEGNORMAL = @as(c_int, 0x0008);
pub const __FPCLASS_NEGSUBNORMAL = @as(c_int, 0x0010);
pub const __FPCLASS_NEGZERO = @as(c_int, 0x0020);
pub const __FPCLASS_POSZERO = @as(c_int, 0x0040);
pub const __FPCLASS_POSSUBNORMAL = @as(c_int, 0x0080);
pub const __FPCLASS_POSNORMAL = @as(c_int, 0x0100);
pub const __FPCLASS_POSINF = @as(c_int, 0x0200);
pub const __PRAGMA_REDEFINE_EXTNAME = @as(c_int, 1);
pub const __VERSION__ = "Clang 18.1.6 (https://github.com/ziglang/zig-bootstrap 98bc6bf4fc4009888d33941daf6b600d20a42a56)";
pub const __OBJC_BOOL_IS_BOOL = @as(c_int, 0);
pub const __CONSTANT_CFSTRINGS__ = @as(c_int, 1);
pub const __clang_literal_encoding__ = "UTF-8";
pub const __clang_wide_literal_encoding__ = "UTF-32";
pub const __ORDER_LITTLE_ENDIAN__ = @as(c_int, 1234);
pub const __ORDER_BIG_ENDIAN__ = @as(c_int, 4321);
pub const __ORDER_PDP_ENDIAN__ = @as(c_int, 3412);
pub const __BYTE_ORDER__ = __ORDER_LITTLE_ENDIAN__;
pub const __LITTLE_ENDIAN__ = @as(c_int, 1);
pub const _LP64 = @as(c_int, 1);
pub const __LP64__ = @as(c_int, 1);
pub const __CHAR_BIT__ = @as(c_int, 8);
pub const __BOOL_WIDTH__ = @as(c_int, 8);
pub const __SHRT_WIDTH__ = @as(c_int, 16);
pub const __INT_WIDTH__ = @as(c_int, 32);
pub const __LONG_WIDTH__ = @as(c_int, 64);
pub const __LLONG_WIDTH__ = @as(c_int, 64);
pub const __BITINT_MAXWIDTH__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 8388608, .decimal);
pub const __SCHAR_MAX__ = @as(c_int, 127);
pub const __SHRT_MAX__ = @as(c_int, 32767);
pub const __INT_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __LONG_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __LONG_LONG_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __WCHAR_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __WCHAR_WIDTH__ = @as(c_int, 32);
pub const __WINT_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __WINT_WIDTH__ = @as(c_int, 32);
pub const __INTMAX_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INTMAX_WIDTH__ = @as(c_int, 64);
pub const __SIZE_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __SIZE_WIDTH__ = @as(c_int, 64);
pub const __UINTMAX_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINTMAX_WIDTH__ = @as(c_int, 64);
pub const __PTRDIFF_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __PTRDIFF_WIDTH__ = @as(c_int, 64);
pub const __INTPTR_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INTPTR_WIDTH__ = @as(c_int, 64);
pub const __UINTPTR_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINTPTR_WIDTH__ = @as(c_int, 64);
pub const __SIZEOF_DOUBLE__ = @as(c_int, 8);
pub const __SIZEOF_FLOAT__ = @as(c_int, 4);
pub const __SIZEOF_INT__ = @as(c_int, 4);
pub const __SIZEOF_LONG__ = @as(c_int, 8);
pub const __SIZEOF_LONG_DOUBLE__ = @as(c_int, 16);
pub const __SIZEOF_LONG_LONG__ = @as(c_int, 8);
pub const __SIZEOF_POINTER__ = @as(c_int, 8);
pub const __SIZEOF_SHORT__ = @as(c_int, 2);
pub const __SIZEOF_PTRDIFF_T__ = @as(c_int, 8);
pub const __SIZEOF_SIZE_T__ = @as(c_int, 8);
pub const __SIZEOF_WCHAR_T__ = @as(c_int, 4);
pub const __SIZEOF_WINT_T__ = @as(c_int, 4);
pub const __SIZEOF_INT128__ = @as(c_int, 16);
pub const __INTMAX_TYPE__ = c_long;
pub const __INTMAX_FMTd__ = "ld";
pub const __INTMAX_FMTi__ = "li";
pub const __INTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `L`");
// (no file):95:9
pub const __UINTMAX_TYPE__ = c_ulong;
pub const __UINTMAX_FMTo__ = "lo";
pub const __UINTMAX_FMTu__ = "lu";
pub const __UINTMAX_FMTx__ = "lx";
pub const __UINTMAX_FMTX__ = "lX";
pub const __UINTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `UL`");
// (no file):101:9
pub const __PTRDIFF_TYPE__ = c_long;
pub const __PTRDIFF_FMTd__ = "ld";
pub const __PTRDIFF_FMTi__ = "li";
pub const __INTPTR_TYPE__ = c_long;
pub const __INTPTR_FMTd__ = "ld";
pub const __INTPTR_FMTi__ = "li";
pub const __SIZE_TYPE__ = c_ulong;
pub const __SIZE_FMTo__ = "lo";
pub const __SIZE_FMTu__ = "lu";
pub const __SIZE_FMTx__ = "lx";
pub const __SIZE_FMTX__ = "lX";
pub const __WCHAR_TYPE__ = c_int;
pub const __WINT_TYPE__ = c_uint;
pub const __SIG_ATOMIC_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __SIG_ATOMIC_WIDTH__ = @as(c_int, 32);
pub const __CHAR16_TYPE__ = c_ushort;
pub const __CHAR32_TYPE__ = c_uint;
pub const __UINTPTR_TYPE__ = c_ulong;
pub const __UINTPTR_FMTo__ = "lo";
pub const __UINTPTR_FMTu__ = "lu";
pub const __UINTPTR_FMTx__ = "lx";
pub const __UINTPTR_FMTX__ = "lX";
pub const __FLT16_DENORM_MIN__ = @as(f16, 5.9604644775390625e-8);
pub const __FLT16_HAS_DENORM__ = @as(c_int, 1);
pub const __FLT16_DIG__ = @as(c_int, 3);
pub const __FLT16_DECIMAL_DIG__ = @as(c_int, 5);
pub const __FLT16_EPSILON__ = @as(f16, 9.765625e-4);
pub const __FLT16_HAS_INFINITY__ = @as(c_int, 1);
pub const __FLT16_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __FLT16_MANT_DIG__ = @as(c_int, 11);
pub const __FLT16_MAX_10_EXP__ = @as(c_int, 4);
pub const __FLT16_MAX_EXP__ = @as(c_int, 16);
pub const __FLT16_MAX__ = @as(f16, 6.5504e+4);
pub const __FLT16_MIN_10_EXP__ = -@as(c_int, 4);
pub const __FLT16_MIN_EXP__ = -@as(c_int, 13);
pub const __FLT16_MIN__ = @as(f16, 6.103515625e-5);
pub const __FLT_DENORM_MIN__ = @as(f32, 1.40129846e-45);
pub const __FLT_HAS_DENORM__ = @as(c_int, 1);
pub const __FLT_DIG__ = @as(c_int, 6);
pub const __FLT_DECIMAL_DIG__ = @as(c_int, 9);
pub const __FLT_EPSILON__ = @as(f32, 1.19209290e-7);
pub const __FLT_HAS_INFINITY__ = @as(c_int, 1);
pub const __FLT_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __FLT_MANT_DIG__ = @as(c_int, 24);
pub const __FLT_MAX_10_EXP__ = @as(c_int, 38);
pub const __FLT_MAX_EXP__ = @as(c_int, 128);
pub const __FLT_MAX__ = @as(f32, 3.40282347e+38);
pub const __FLT_MIN_10_EXP__ = -@as(c_int, 37);
pub const __FLT_MIN_EXP__ = -@as(c_int, 125);
pub const __FLT_MIN__ = @as(f32, 1.17549435e-38);
pub const __DBL_DENORM_MIN__ = @as(f64, 4.9406564584124654e-324);
pub const __DBL_HAS_DENORM__ = @as(c_int, 1);
pub const __DBL_DIG__ = @as(c_int, 15);
pub const __DBL_DECIMAL_DIG__ = @as(c_int, 17);
pub const __DBL_EPSILON__ = @as(f64, 2.2204460492503131e-16);
pub const __DBL_HAS_INFINITY__ = @as(c_int, 1);
pub const __DBL_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __DBL_MANT_DIG__ = @as(c_int, 53);
pub const __DBL_MAX_10_EXP__ = @as(c_int, 308);
pub const __DBL_MAX_EXP__ = @as(c_int, 1024);
pub const __DBL_MAX__ = @as(f64, 1.7976931348623157e+308);
pub const __DBL_MIN_10_EXP__ = -@as(c_int, 307);
pub const __DBL_MIN_EXP__ = -@as(c_int, 1021);
pub const __DBL_MIN__ = @as(f64, 2.2250738585072014e-308);
pub const __LDBL_DENORM_MIN__ = @as(c_longdouble, 3.64519953188247460253e-4951);
pub const __LDBL_HAS_DENORM__ = @as(c_int, 1);
pub const __LDBL_DIG__ = @as(c_int, 18);
pub const __LDBL_DECIMAL_DIG__ = @as(c_int, 21);
pub const __LDBL_EPSILON__ = @as(c_longdouble, 1.08420217248550443401e-19);
pub const __LDBL_HAS_INFINITY__ = @as(c_int, 1);
pub const __LDBL_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __LDBL_MANT_DIG__ = @as(c_int, 64);
pub const __LDBL_MAX_10_EXP__ = @as(c_int, 4932);
pub const __LDBL_MAX_EXP__ = @as(c_int, 16384);
pub const __LDBL_MAX__ = @as(c_longdouble, 1.18973149535723176502e+4932);
pub const __LDBL_MIN_10_EXP__ = -@as(c_int, 4931);
pub const __LDBL_MIN_EXP__ = -@as(c_int, 16381);
pub const __LDBL_MIN__ = @as(c_longdouble, 3.36210314311209350626e-4932);
pub const __POINTER_WIDTH__ = @as(c_int, 64);
pub const __BIGGEST_ALIGNMENT__ = @as(c_int, 16);
pub const __WINT_UNSIGNED__ = @as(c_int, 1);
pub const __INT8_TYPE__ = i8;
pub const __INT8_FMTd__ = "hhd";
pub const __INT8_FMTi__ = "hhi";
pub const __INT8_C_SUFFIX__ = "";
pub const __INT16_TYPE__ = c_short;
pub const __INT16_FMTd__ = "hd";
pub const __INT16_FMTi__ = "hi";
pub const __INT16_C_SUFFIX__ = "";
pub const __INT32_TYPE__ = c_int;
pub const __INT32_FMTd__ = "d";
pub const __INT32_FMTi__ = "i";
pub const __INT32_C_SUFFIX__ = "";
pub const __INT64_TYPE__ = c_long;
pub const __INT64_FMTd__ = "ld";
pub const __INT64_FMTi__ = "li";
pub const __INT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `L`");
// (no file):198:9
pub const __UINT8_TYPE__ = u8;
pub const __UINT8_FMTo__ = "hho";
pub const __UINT8_FMTu__ = "hhu";
pub const __UINT8_FMTx__ = "hhx";
pub const __UINT8_FMTX__ = "hhX";
pub const __UINT8_C_SUFFIX__ = "";
pub const __UINT8_MAX__ = @as(c_int, 255);
pub const __INT8_MAX__ = @as(c_int, 127);
pub const __UINT16_TYPE__ = c_ushort;
pub const __UINT16_FMTo__ = "ho";
pub const __UINT16_FMTu__ = "hu";
pub const __UINT16_FMTx__ = "hx";
pub const __UINT16_FMTX__ = "hX";
pub const __UINT16_C_SUFFIX__ = "";
pub const __UINT16_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __INT16_MAX__ = @as(c_int, 32767);
pub const __UINT32_TYPE__ = c_uint;
pub const __UINT32_FMTo__ = "o";
pub const __UINT32_FMTu__ = "u";
pub const __UINT32_FMTx__ = "x";
pub const __UINT32_FMTX__ = "X";
pub const __UINT32_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `U`");
// (no file):220:9
pub const __UINT32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __INT32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __UINT64_TYPE__ = c_ulong;
pub const __UINT64_FMTo__ = "lo";
pub const __UINT64_FMTu__ = "lu";
pub const __UINT64_FMTx__ = "lx";
pub const __UINT64_FMTX__ = "lX";
pub const __UINT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `UL`");
// (no file):228:9
pub const __UINT64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __INT64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_LEAST8_TYPE__ = i8;
pub const __INT_LEAST8_MAX__ = @as(c_int, 127);
pub const __INT_LEAST8_WIDTH__ = @as(c_int, 8);
pub const __INT_LEAST8_FMTd__ = "hhd";
pub const __INT_LEAST8_FMTi__ = "hhi";
pub const __UINT_LEAST8_TYPE__ = u8;
pub const __UINT_LEAST8_MAX__ = @as(c_int, 255);
pub const __UINT_LEAST8_FMTo__ = "hho";
pub const __UINT_LEAST8_FMTu__ = "hhu";
pub const __UINT_LEAST8_FMTx__ = "hhx";
pub const __UINT_LEAST8_FMTX__ = "hhX";
pub const __INT_LEAST16_TYPE__ = c_short;
pub const __INT_LEAST16_MAX__ = @as(c_int, 32767);
pub const __INT_LEAST16_WIDTH__ = @as(c_int, 16);
pub const __INT_LEAST16_FMTd__ = "hd";
pub const __INT_LEAST16_FMTi__ = "hi";
pub const __UINT_LEAST16_TYPE__ = c_ushort;
pub const __UINT_LEAST16_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __UINT_LEAST16_FMTo__ = "ho";
pub const __UINT_LEAST16_FMTu__ = "hu";
pub const __UINT_LEAST16_FMTx__ = "hx";
pub const __UINT_LEAST16_FMTX__ = "hX";
pub const __INT_LEAST32_TYPE__ = c_int;
pub const __INT_LEAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_LEAST32_WIDTH__ = @as(c_int, 32);
pub const __INT_LEAST32_FMTd__ = "d";
pub const __INT_LEAST32_FMTi__ = "i";
pub const __UINT_LEAST32_TYPE__ = c_uint;
pub const __UINT_LEAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __UINT_LEAST32_FMTo__ = "o";
pub const __UINT_LEAST32_FMTu__ = "u";
pub const __UINT_LEAST32_FMTx__ = "x";
pub const __UINT_LEAST32_FMTX__ = "X";
pub const __INT_LEAST64_TYPE__ = c_long;
pub const __INT_LEAST64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_LEAST64_WIDTH__ = @as(c_int, 64);
pub const __INT_LEAST64_FMTd__ = "ld";
pub const __INT_LEAST64_FMTi__ = "li";
pub const __UINT_LEAST64_TYPE__ = c_ulong;
pub const __UINT_LEAST64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINT_LEAST64_FMTo__ = "lo";
pub const __UINT_LEAST64_FMTu__ = "lu";
pub const __UINT_LEAST64_FMTx__ = "lx";
pub const __UINT_LEAST64_FMTX__ = "lX";
pub const __INT_FAST8_TYPE__ = i8;
pub const __INT_FAST8_MAX__ = @as(c_int, 127);
pub const __INT_FAST8_WIDTH__ = @as(c_int, 8);
pub const __INT_FAST8_FMTd__ = "hhd";
pub const __INT_FAST8_FMTi__ = "hhi";
pub const __UINT_FAST8_TYPE__ = u8;
pub const __UINT_FAST8_MAX__ = @as(c_int, 255);
pub const __UINT_FAST8_FMTo__ = "hho";
pub const __UINT_FAST8_FMTu__ = "hhu";
pub const __UINT_FAST8_FMTx__ = "hhx";
pub const __UINT_FAST8_FMTX__ = "hhX";
pub const __INT_FAST16_TYPE__ = c_short;
pub const __INT_FAST16_MAX__ = @as(c_int, 32767);
pub const __INT_FAST16_WIDTH__ = @as(c_int, 16);
pub const __INT_FAST16_FMTd__ = "hd";
pub const __INT_FAST16_FMTi__ = "hi";
pub const __UINT_FAST16_TYPE__ = c_ushort;
pub const __UINT_FAST16_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __UINT_FAST16_FMTo__ = "ho";
pub const __UINT_FAST16_FMTu__ = "hu";
pub const __UINT_FAST16_FMTx__ = "hx";
pub const __UINT_FAST16_FMTX__ = "hX";
pub const __INT_FAST32_TYPE__ = c_int;
pub const __INT_FAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_FAST32_WIDTH__ = @as(c_int, 32);
pub const __INT_FAST32_FMTd__ = "d";
pub const __INT_FAST32_FMTi__ = "i";
pub const __UINT_FAST32_TYPE__ = c_uint;
pub const __UINT_FAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __UINT_FAST32_FMTo__ = "o";
pub const __UINT_FAST32_FMTu__ = "u";
pub const __UINT_FAST32_FMTx__ = "x";
pub const __UINT_FAST32_FMTX__ = "X";
pub const __INT_FAST64_TYPE__ = c_long;
pub const __INT_FAST64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_FAST64_WIDTH__ = @as(c_int, 64);
pub const __INT_FAST64_FMTd__ = "ld";
pub const __INT_FAST64_FMTi__ = "li";
pub const __UINT_FAST64_TYPE__ = c_ulong;
pub const __UINT_FAST64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINT_FAST64_FMTo__ = "lo";
pub const __UINT_FAST64_FMTu__ = "lu";
pub const __UINT_FAST64_FMTx__ = "lx";
pub const __UINT_FAST64_FMTX__ = "lX";
pub const __USER_LABEL_PREFIX__ = "";
pub const __FINITE_MATH_ONLY__ = @as(c_int, 0);
pub const __GNUC_STDC_INLINE__ = @as(c_int, 1);
pub const __GCC_ATOMIC_TEST_AND_SET_TRUEVAL = @as(c_int, 1);
pub const __CLANG_ATOMIC_BOOL_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_CHAR_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_CHAR16_T_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_CHAR32_T_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_WCHAR_T_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_SHORT_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_INT_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_LONG_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_LLONG_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_POINTER_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_BOOL_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_CHAR_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_CHAR16_T_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_CHAR32_T_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_WCHAR_T_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_SHORT_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_INT_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_LONG_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_LLONG_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_POINTER_LOCK_FREE = @as(c_int, 2);
pub const __NO_INLINE__ = @as(c_int, 1);
pub const __PIC__ = @as(c_int, 2);
pub const __pic__ = @as(c_int, 2);
pub const __PIE__ = @as(c_int, 2);
pub const __pie__ = @as(c_int, 2);
pub const __FLT_RADIX__ = @as(c_int, 2);
pub const __DECIMAL_DIG__ = __LDBL_DECIMAL_DIG__;
pub const __ELF__ = @as(c_int, 1);
pub const __GCC_ASM_FLAG_OUTPUTS__ = @as(c_int, 1);
pub const __code_model_small__ = @as(c_int, 1);
pub const __amd64__ = @as(c_int, 1);
pub const __amd64 = @as(c_int, 1);
pub const __x86_64 = @as(c_int, 1);
pub const __x86_64__ = @as(c_int, 1);
pub const __SEG_GS = @as(c_int, 1);
pub const __SEG_FS = @as(c_int, 1);
pub const __seg_gs = @compileError("unable to translate macro: undefined identifier `address_space`");
// (no file):359:9
pub const __seg_fs = @compileError("unable to translate macro: undefined identifier `address_space`");
// (no file):360:9
pub const __corei7 = @as(c_int, 1);
pub const __corei7__ = @as(c_int, 1);
pub const __tune_corei7__ = @as(c_int, 1);
pub const __REGISTER_PREFIX__ = "";
pub const __NO_MATH_INLINES = @as(c_int, 1);
pub const __AES__ = @as(c_int, 1);
pub const __PCLMUL__ = @as(c_int, 1);
pub const __LAHF_SAHF__ = @as(c_int, 1);
pub const __LZCNT__ = @as(c_int, 1);
pub const __RDRND__ = @as(c_int, 1);
pub const __FSGSBASE__ = @as(c_int, 1);
pub const __BMI__ = @as(c_int, 1);
pub const __BMI2__ = @as(c_int, 1);
pub const __POPCNT__ = @as(c_int, 1);
pub const __PRFCHW__ = @as(c_int, 1);
pub const __RDSEED__ = @as(c_int, 1);
pub const __ADX__ = @as(c_int, 1);
pub const __MOVBE__ = @as(c_int, 1);
pub const __FMA__ = @as(c_int, 1);
pub const __F16C__ = @as(c_int, 1);
pub const __FXSR__ = @as(c_int, 1);
pub const __XSAVE__ = @as(c_int, 1);
pub const __XSAVEOPT__ = @as(c_int, 1);
pub const __INVPCID__ = @as(c_int, 1);
pub const __CRC32__ = @as(c_int, 1);
pub const __AVX2__ = @as(c_int, 1);
pub const __AVX__ = @as(c_int, 1);
pub const __SSE4_2__ = @as(c_int, 1);
pub const __SSE4_1__ = @as(c_int, 1);
pub const __SSSE3__ = @as(c_int, 1);
pub const __SSE3__ = @as(c_int, 1);
pub const __SSE2__ = @as(c_int, 1);
pub const __SSE2_MATH__ = @as(c_int, 1);
pub const __SSE__ = @as(c_int, 1);
pub const __SSE_MATH__ = @as(c_int, 1);
pub const __MMX__ = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_1 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_2 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_4 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_8 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_16 = @as(c_int, 1);
pub const __SIZEOF_FLOAT128__ = @as(c_int, 16);
pub const unix = @as(c_int, 1);
pub const __unix = @as(c_int, 1);
pub const __unix__ = @as(c_int, 1);
pub const linux = @as(c_int, 1);
pub const __linux = @as(c_int, 1);
pub const __linux__ = @as(c_int, 1);
pub const __gnu_linux__ = @as(c_int, 1);
pub const __FLOAT128__ = @as(c_int, 1);
pub const __STDC__ = @as(c_int, 1);
pub const __STDC_HOSTED__ = @as(c_int, 1);
pub const __STDC_VERSION__ = @as(c_long, 201710);
pub const __STDC_UTF_16__ = @as(c_int, 1);
pub const __STDC_UTF_32__ = @as(c_int, 1);
pub const _DEBUG = @as(c_int, 1);
pub const __GCC_HAVE_DWARF2_CFI_ASM = @as(c_int, 1);
pub const PD_MAJOR_VERSION = @as(c_int, 0);
pub const PD_MINOR_VERSION = @as(c_int, 55);
pub const PD_BUGFIX_VERSION = @as(c_int, 0);
pub const PD_TEST_VERSION = "";
pub inline fn PD_VERSION(major: anytype, minor: anytype, bugfix: anytype) @TypeOf(((major << @as(c_int, 16)) + (minor << @as(c_int, 8))) + (if (bugfix > @as(c_int, 255)) @as(c_int, 255) else bugfix)) {
    _ = &major;
    _ = &minor;
    _ = &bugfix;
    return ((major << @as(c_int, 16)) + (minor << @as(c_int, 8))) + (if (bugfix > @as(c_int, 255)) @as(c_int, 255) else bugfix);
}
pub const PD_VERSION_CODE = PD_VERSION(PD_MAJOR_VERSION, PD_MINOR_VERSION, PD_BUGFIX_VERSION);
pub const EXTERN = @compileError("unable to translate C expr: unexpected token 'extern'");
// m_pd.h:50:9
pub const EXTERN_STRUCT = @compileError("unable to translate C expr: expected 'an identifier' instead got ''");
// m_pd.h:62:9
pub const PD_INLINE = @compileError("unable to translate C expr: unexpected token 'static'");
// m_pd.h:71:11
pub const ATTRIBUTE_FORMAT_PRINTF = @compileError("unable to translate macro: undefined identifier `format`");
// m_pd.h:80:9
pub const _ASSERT_H = @as(c_int, 1);
pub const _FEATURES_H = @as(c_int, 1);
pub const __KERNEL_STRICT_NAMES = "";
pub inline fn __GNUC_PREREQ(maj: anytype, min: anytype) @TypeOf(((__GNUC__ << @as(c_int, 16)) + __GNUC_MINOR__) >= ((maj << @as(c_int, 16)) + min)) {
    _ = &maj;
    _ = &min;
    return ((__GNUC__ << @as(c_int, 16)) + __GNUC_MINOR__) >= ((maj << @as(c_int, 16)) + min);
}
pub inline fn __glibc_clang_prereq(maj: anytype, min: anytype) @TypeOf(((__clang_major__ << @as(c_int, 16)) + __clang_minor__) >= ((maj << @as(c_int, 16)) + min)) {
    _ = &maj;
    _ = &min;
    return ((__clang_major__ << @as(c_int, 16)) + __clang_minor__) >= ((maj << @as(c_int, 16)) + min);
}
pub const __GLIBC_USE = @compileError("unable to translate macro: undefined identifier `__GLIBC_USE_`");
// /usr/include/features.h:189:9
pub const _DEFAULT_SOURCE = @as(c_int, 1);
pub const __GLIBC_USE_ISOC23 = @as(c_int, 0);
pub const __USE_ISOC11 = @as(c_int, 1);
pub const __USE_ISOC99 = @as(c_int, 1);
pub const __USE_ISOC95 = @as(c_int, 1);
pub const __USE_POSIX_IMPLICITLY = @as(c_int, 1);
pub const _POSIX_SOURCE = @as(c_int, 1);
pub const _POSIX_C_SOURCE = @as(c_long, 200809);
pub const __USE_POSIX = @as(c_int, 1);
pub const __USE_POSIX2 = @as(c_int, 1);
pub const __USE_POSIX199309 = @as(c_int, 1);
pub const __USE_POSIX199506 = @as(c_int, 1);
pub const __USE_XOPEN2K = @as(c_int, 1);
pub const __USE_XOPEN2K8 = @as(c_int, 1);
pub const _ATFILE_SOURCE = @as(c_int, 1);
pub const __WORDSIZE = @as(c_int, 64);
pub const __WORDSIZE_TIME64_COMPAT32 = @as(c_int, 1);
pub const __SYSCALL_WORDSIZE = @as(c_int, 64);
pub const __TIMESIZE = __WORDSIZE;
pub const __USE_TIME_BITS64 = @as(c_int, 1);
pub const __USE_MISC = @as(c_int, 1);
pub const __USE_ATFILE = @as(c_int, 1);
pub const __USE_FORTIFY_LEVEL = @as(c_int, 0);
pub const __GLIBC_USE_DEPRECATED_GETS = @as(c_int, 0);
pub const __GLIBC_USE_DEPRECATED_SCANF = @as(c_int, 0);
pub const __GLIBC_USE_C23_STRTOL = @as(c_int, 0);
pub const _STDC_PREDEF_H = @as(c_int, 1);
pub const __STDC_IEC_559__ = @as(c_int, 1);
pub const __STDC_IEC_60559_BFP__ = @as(c_long, 201404);
pub const __STDC_IEC_559_COMPLEX__ = @as(c_int, 1);
pub const __STDC_IEC_60559_COMPLEX__ = @as(c_long, 201404);
pub const __STDC_ISO_10646__ = @as(c_long, 201706);
pub const __GNU_LIBRARY__ = @as(c_int, 6);
pub const __GLIBC__ = @as(c_int, 2);
pub const __GLIBC_MINOR__ = @as(c_int, 40);
pub inline fn __GLIBC_PREREQ(maj: anytype, min: anytype) @TypeOf(((__GLIBC__ << @as(c_int, 16)) + __GLIBC_MINOR__) >= ((maj << @as(c_int, 16)) + min)) {
    _ = &maj;
    _ = &min;
    return ((__GLIBC__ << @as(c_int, 16)) + __GLIBC_MINOR__) >= ((maj << @as(c_int, 16)) + min);
}
pub const _SYS_CDEFS_H = @as(c_int, 1);
pub const __glibc_has_attribute = @compileError("unable to translate macro: undefined identifier `__has_attribute`");
// /usr/include/sys/cdefs.h:45:10
pub inline fn __glibc_has_builtin(name: anytype) @TypeOf(__has_builtin(name)) {
    _ = &name;
    return __has_builtin(name);
}
pub const __glibc_has_extension = @compileError("unable to translate macro: undefined identifier `__has_extension`");
// /usr/include/sys/cdefs.h:55:10
pub const __LEAF = "";
pub const __LEAF_ATTR = "";
pub const __THROW = @compileError("unable to translate macro: undefined identifier `__nothrow__`");
// /usr/include/sys/cdefs.h:79:11
pub const __THROWNL = @compileError("unable to translate macro: undefined identifier `__nothrow__`");
// /usr/include/sys/cdefs.h:80:11
pub const __NTH = @compileError("unable to translate macro: undefined identifier `__nothrow__`");
// /usr/include/sys/cdefs.h:81:11
pub const __NTHNL = @compileError("unable to translate macro: undefined identifier `__nothrow__`");
// /usr/include/sys/cdefs.h:82:11
pub const __COLD = @compileError("unable to translate macro: undefined identifier `__cold__`");
// /usr/include/sys/cdefs.h:102:11
pub inline fn __P(args: anytype) @TypeOf(args) {
    _ = &args;
    return args;
}
pub inline fn __PMT(args: anytype) @TypeOf(args) {
    _ = &args;
    return args;
}
pub const __CONCAT = @compileError("unable to translate C expr: unexpected token '##'");
// /usr/include/sys/cdefs.h:131:9
pub const __STRING = @compileError("unable to translate C expr: unexpected token '#'");
// /usr/include/sys/cdefs.h:132:9
pub const __ptr_t = ?*anyopaque;
pub const __BEGIN_DECLS = "";
pub const __END_DECLS = "";
pub const __attribute_overloadable__ = @compileError("unable to translate macro: undefined identifier `__overloadable__`");
// /usr/include/sys/cdefs.h:151:10
pub inline fn __bos(ptr: anytype) @TypeOf(__builtin_object_size(ptr, __USE_FORTIFY_LEVEL > @as(c_int, 1))) {
    _ = &ptr;
    return __builtin_object_size(ptr, __USE_FORTIFY_LEVEL > @as(c_int, 1));
}
pub inline fn __bos0(ptr: anytype) @TypeOf(__builtin_object_size(ptr, @as(c_int, 0))) {
    _ = &ptr;
    return __builtin_object_size(ptr, @as(c_int, 0));
}
pub inline fn __glibc_objsize0(__o: anytype) @TypeOf(__bos0(__o)) {
    _ = &__o;
    return __bos0(__o);
}
pub inline fn __glibc_objsize(__o: anytype) @TypeOf(__bos(__o)) {
    _ = &__o;
    return __bos(__o);
}
pub const __warnattr = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/sys/cdefs.h:370:10
pub const __errordecl = @compileError("unable to translate C expr: unexpected token 'extern'");
// /usr/include/sys/cdefs.h:371:10
pub const __flexarr = @compileError("unable to translate C expr: unexpected token '['");
// /usr/include/sys/cdefs.h:379:10
pub const __glibc_c99_flexarr_available = @as(c_int, 1);
pub const __REDIRECT = @compileError("unable to translate C expr: unexpected token '__asm__'");
// /usr/include/sys/cdefs.h:410:10
pub const __REDIRECT_NTH = @compileError("unable to translate C expr: unexpected token '__asm__'");
// /usr/include/sys/cdefs.h:417:11
pub const __REDIRECT_NTHNL = @compileError("unable to translate C expr: unexpected token '__asm__'");
// /usr/include/sys/cdefs.h:419:11
pub const __ASMNAME = @compileError("unable to translate C expr: unexpected token ','");
// /usr/include/sys/cdefs.h:422:10
pub inline fn __ASMNAME2(prefix: anytype, cname: anytype) @TypeOf(__STRING(prefix) ++ cname) {
    _ = &prefix;
    _ = &cname;
    return __STRING(prefix) ++ cname;
}
pub const __REDIRECT_FORTIFY = __REDIRECT;
pub const __REDIRECT_FORTIFY_NTH = __REDIRECT_NTH;
pub const __attribute_malloc__ = @compileError("unable to translate macro: undefined identifier `__malloc__`");
// /usr/include/sys/cdefs.h:452:10
pub const __attribute_alloc_size__ = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/sys/cdefs.h:463:10
pub const __attribute_alloc_align__ = @compileError("unable to translate macro: undefined identifier `__alloc_align__`");
// /usr/include/sys/cdefs.h:469:10
pub const __attribute_pure__ = @compileError("unable to translate macro: undefined identifier `__pure__`");
// /usr/include/sys/cdefs.h:479:10
pub const __attribute_const__ = @compileError("unable to translate C expr: unexpected token '__attribute__'");
// /usr/include/sys/cdefs.h:486:10
pub const __attribute_maybe_unused__ = @compileError("unable to translate macro: undefined identifier `__unused__`");
// /usr/include/sys/cdefs.h:492:10
pub const __attribute_used__ = @compileError("unable to translate macro: undefined identifier `__used__`");
// /usr/include/sys/cdefs.h:501:10
pub const __attribute_noinline__ = @compileError("unable to translate macro: undefined identifier `__noinline__`");
// /usr/include/sys/cdefs.h:502:10
pub const __attribute_deprecated__ = @compileError("unable to translate macro: undefined identifier `__deprecated__`");
// /usr/include/sys/cdefs.h:510:10
pub const __attribute_deprecated_msg__ = @compileError("unable to translate macro: undefined identifier `__deprecated__`");
// /usr/include/sys/cdefs.h:520:10
pub const __attribute_format_arg__ = @compileError("unable to translate macro: undefined identifier `__format_arg__`");
// /usr/include/sys/cdefs.h:533:10
pub const __attribute_format_strfmon__ = @compileError("unable to translate macro: undefined identifier `__format__`");
// /usr/include/sys/cdefs.h:543:10
pub const __attribute_nonnull__ = @compileError("unable to translate macro: undefined identifier `__nonnull__`");
// /usr/include/sys/cdefs.h:555:11
pub inline fn __nonnull(params: anytype) @TypeOf(__attribute_nonnull__(params)) {
    _ = &params;
    return __attribute_nonnull__(params);
}
pub const __returns_nonnull = @compileError("unable to translate macro: undefined identifier `__returns_nonnull__`");
// /usr/include/sys/cdefs.h:568:10
pub const __attribute_warn_unused_result__ = @compileError("unable to translate macro: undefined identifier `__warn_unused_result__`");
// /usr/include/sys/cdefs.h:577:10
pub const __wur = "";
pub const __always_inline = @compileError("unable to translate macro: undefined identifier `__always_inline__`");
// /usr/include/sys/cdefs.h:595:10
pub const __attribute_artificial__ = @compileError("unable to translate macro: undefined identifier `__artificial__`");
// /usr/include/sys/cdefs.h:604:10
pub const __extern_inline = @compileError("unable to translate macro: undefined identifier `__gnu_inline__`");
// /usr/include/sys/cdefs.h:622:11
pub const __extern_always_inline = @compileError("unable to translate macro: undefined identifier `__gnu_inline__`");
// /usr/include/sys/cdefs.h:623:11
pub const __fortify_function = __extern_always_inline ++ __attribute_artificial__;
pub const __restrict_arr = @compileError("unable to translate C expr: unexpected token '__restrict'");
// /usr/include/sys/cdefs.h:666:10
pub inline fn __glibc_unlikely(cond: anytype) @TypeOf(__builtin_expect(cond, @as(c_int, 0))) {
    _ = &cond;
    return __builtin_expect(cond, @as(c_int, 0));
}
pub inline fn __glibc_likely(cond: anytype) @TypeOf(__builtin_expect(cond, @as(c_int, 1))) {
    _ = &cond;
    return __builtin_expect(cond, @as(c_int, 1));
}
pub const __attribute_nonstring__ = "";
pub const __attribute_copy__ = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/sys/cdefs.h:715:10
pub const __LDOUBLE_REDIRECTS_TO_FLOAT128_ABI = @as(c_int, 0);
pub inline fn __LDBL_REDIR1(name: anytype, proto: anytype, alias: anytype) @TypeOf(name ++ proto) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return name ++ proto;
}
pub inline fn __LDBL_REDIR(name: anytype, proto: anytype) @TypeOf(name ++ proto) {
    _ = &name;
    _ = &proto;
    return name ++ proto;
}
pub inline fn __LDBL_REDIR1_NTH(name: anytype, proto: anytype, alias: anytype) @TypeOf(name ++ proto ++ __THROW) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return name ++ proto ++ __THROW;
}
pub inline fn __LDBL_REDIR_NTH(name: anytype, proto: anytype) @TypeOf(name ++ proto ++ __THROW) {
    _ = &name;
    _ = &proto;
    return name ++ proto ++ __THROW;
}
pub const __LDBL_REDIR2_DECL = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/sys/cdefs.h:792:10
pub const __LDBL_REDIR_DECL = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/sys/cdefs.h:793:10
pub inline fn __REDIRECT_LDBL(name: anytype, proto: anytype, alias: anytype) @TypeOf(__REDIRECT(name, proto, alias)) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return __REDIRECT(name, proto, alias);
}
pub inline fn __REDIRECT_NTH_LDBL(name: anytype, proto: anytype, alias: anytype) @TypeOf(__REDIRECT_NTH(name, proto, alias)) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return __REDIRECT_NTH(name, proto, alias);
}
pub const __glibc_macro_warning1 = @compileError("unable to translate macro: undefined identifier `_Pragma`");
// /usr/include/sys/cdefs.h:807:10
pub const __glibc_macro_warning = @compileError("unable to translate macro: undefined identifier `GCC`");
// /usr/include/sys/cdefs.h:808:10
pub const __HAVE_GENERIC_SELECTION = @as(c_int, 1);
pub const __fortified_attr_access = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/sys/cdefs.h:853:11
pub const __attr_access = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/sys/cdefs.h:854:11
pub const __attr_access_none = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/sys/cdefs.h:855:11
pub const __attr_dealloc = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/sys/cdefs.h:865:10
pub const __attr_dealloc_free = "";
pub const __attribute_returns_twice__ = @compileError("unable to translate macro: undefined identifier `__returns_twice__`");
// /usr/include/sys/cdefs.h:872:10
pub const __attribute_struct_may_alias__ = @compileError("unable to translate macro: undefined identifier `__may_alias__`");
// /usr/include/sys/cdefs.h:881:10
pub const __stub___compat_bdflush = "";
pub const __stub_chflags = "";
pub const __stub_fchflags = "";
pub const __stub_gtty = "";
pub const __stub_revoke = "";
pub const __stub_setlogin = "";
pub const __stub_sigreturn = "";
pub const __stub_stty = "";
pub const __ASSERT_VOID_CAST = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/assert.h:40:10
pub const assert = @compileError("unable to translate macro: undefined identifier `__FILE__`");
// /usr/include/assert.h:115:11
pub const __ASSERT_FUNCTION = @compileError("unable to translate C expr: unexpected token '__extension__'");
// /usr/include/assert.h:137:12
pub const static_assert = @compileError("unable to translate C expr: unexpected token '_Static_assert'");
// /usr/include/assert.h:155:10
pub const PD_STATIC_ASSERT = @compileError("unable to translate C expr: unexpected token '_Static_assert'");
// m_pd.h:87:9
pub const PD_DEPRECATED = @compileError("unable to translate macro: undefined identifier `deprecated`");
// m_pd.h:97:11
pub const __STDDEF_H = "";
pub const __need_ptrdiff_t = "";
pub const __need_size_t = "";
pub const __need_wchar_t = "";
pub const __need_NULL = "";
pub const __need_max_align_t = "";
pub const __need_offsetof = "";
pub const _PTRDIFF_T = "";
pub const _SIZE_T = "";
pub const _WCHAR_T = "";
pub const NULL = @import("std").zig.c_translation.cast(?*anyopaque, @as(c_int, 0));
pub const __CLANG_MAX_ALIGN_T_DEFINED = "";
pub const offsetof = @compileError("unable to translate C expr: unexpected token 'an identifier'");
// /home/mike/.local/lib/zig/0.13.0/files/lib/include/__stddef_offsetof.h:16:9
pub const __CLANG_STDINT_H = "";
pub const _STDINT_H = @as(c_int, 1);
pub const __GLIBC_INTERNAL_STARTING_HEADER_IMPLEMENTATION = "";
pub const __GLIBC_USE_LIB_EXT2 = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_BFP_EXT = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_BFP_EXT_C23 = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_EXT = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_FUNCS_EXT = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_FUNCS_EXT_C23 = @as(c_int, 0);
pub const __GLIBC_USE_IEC_60559_TYPES_EXT = @as(c_int, 0);
pub const _BITS_TYPES_H = @as(c_int, 1);
pub const __S16_TYPE = c_short;
pub const __U16_TYPE = c_ushort;
pub const __S32_TYPE = c_int;
pub const __U32_TYPE = c_uint;
pub const __SLONGWORD_TYPE = c_long;
pub const __ULONGWORD_TYPE = c_ulong;
pub const __SQUAD_TYPE = c_long;
pub const __UQUAD_TYPE = c_ulong;
pub const __SWORD_TYPE = c_long;
pub const __UWORD_TYPE = c_ulong;
pub const __SLONG32_TYPE = c_int;
pub const __ULONG32_TYPE = c_uint;
pub const __S64_TYPE = c_long;
pub const __U64_TYPE = c_ulong;
pub const __STD_TYPE = @compileError("unable to translate C expr: unexpected token 'typedef'");
// /usr/include/bits/types.h:137:10
pub const _BITS_TYPESIZES_H = @as(c_int, 1);
pub const __SYSCALL_SLONG_TYPE = __SLONGWORD_TYPE;
pub const __SYSCALL_ULONG_TYPE = __ULONGWORD_TYPE;
pub const __DEV_T_TYPE = __UQUAD_TYPE;
pub const __UID_T_TYPE = __U32_TYPE;
pub const __GID_T_TYPE = __U32_TYPE;
pub const __INO_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __INO64_T_TYPE = __UQUAD_TYPE;
pub const __MODE_T_TYPE = __U32_TYPE;
pub const __NLINK_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __FSWORD_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __OFF_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __OFF64_T_TYPE = __SQUAD_TYPE;
pub const __PID_T_TYPE = __S32_TYPE;
pub const __RLIM_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __RLIM64_T_TYPE = __UQUAD_TYPE;
pub const __BLKCNT_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __BLKCNT64_T_TYPE = __SQUAD_TYPE;
pub const __FSBLKCNT_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __FSBLKCNT64_T_TYPE = __UQUAD_TYPE;
pub const __FSFILCNT_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __FSFILCNT64_T_TYPE = __UQUAD_TYPE;
pub const __ID_T_TYPE = __U32_TYPE;
pub const __CLOCK_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __TIME_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __USECONDS_T_TYPE = __U32_TYPE;
pub const __SUSECONDS_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __SUSECONDS64_T_TYPE = __SQUAD_TYPE;
pub const __DADDR_T_TYPE = __S32_TYPE;
pub const __KEY_T_TYPE = __S32_TYPE;
pub const __CLOCKID_T_TYPE = __S32_TYPE;
pub const __TIMER_T_TYPE = ?*anyopaque;
pub const __BLKSIZE_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __FSID_T_TYPE = @compileError("unable to translate macro: undefined identifier `__val`");
// /usr/include/bits/typesizes.h:73:9
pub const __SSIZE_T_TYPE = __SWORD_TYPE;
pub const __CPU_MASK_TYPE = __SYSCALL_ULONG_TYPE;
pub const __OFF_T_MATCHES_OFF64_T = @as(c_int, 1);
pub const __INO_T_MATCHES_INO64_T = @as(c_int, 1);
pub const __RLIM_T_MATCHES_RLIM64_T = @as(c_int, 1);
pub const __STATFS_MATCHES_STATFS64 = @as(c_int, 1);
pub const __KERNEL_OLD_TIMEVAL_MATCHES_TIMEVAL64 = @as(c_int, 1);
pub const __FD_SETSIZE = @as(c_int, 1024);
pub const _BITS_TIME64_H = @as(c_int, 1);
pub const __TIME64_T_TYPE = __TIME_T_TYPE;
pub const _BITS_WCHAR_H = @as(c_int, 1);
pub const __WCHAR_MAX = __WCHAR_MAX__;
pub const __WCHAR_MIN = -__WCHAR_MAX - @as(c_int, 1);
pub const _BITS_STDINT_INTN_H = @as(c_int, 1);
pub const _BITS_STDINT_UINTN_H = @as(c_int, 1);
pub const _BITS_STDINT_LEAST_H = @as(c_int, 1);
pub const __intptr_t_defined = "";
pub const __INT64_C = @import("std").zig.c_translation.Macros.L_SUFFIX;
pub const __UINT64_C = @import("std").zig.c_translation.Macros.UL_SUFFIX;
pub const INT8_MIN = -@as(c_int, 128);
pub const INT16_MIN = -@as(c_int, 32767) - @as(c_int, 1);
pub const INT32_MIN = -@import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal) - @as(c_int, 1);
pub const INT64_MIN = -__INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INT8_MAX = @as(c_int, 127);
pub const INT16_MAX = @as(c_int, 32767);
pub const INT32_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const INT64_MAX = __INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINT8_MAX = @as(c_int, 255);
pub const UINT16_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT32_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT64_MAX = __UINT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const INT_LEAST8_MIN = -@as(c_int, 128);
pub const INT_LEAST16_MIN = -@as(c_int, 32767) - @as(c_int, 1);
pub const INT_LEAST32_MIN = -@import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal) - @as(c_int, 1);
pub const INT_LEAST64_MIN = -__INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INT_LEAST8_MAX = @as(c_int, 127);
pub const INT_LEAST16_MAX = @as(c_int, 32767);
pub const INT_LEAST32_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const INT_LEAST64_MAX = __INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINT_LEAST8_MAX = @as(c_int, 255);
pub const UINT_LEAST16_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const UINT_LEAST32_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const UINT_LEAST64_MAX = __UINT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const INT_FAST8_MIN = -@as(c_int, 128);
pub const INT_FAST16_MIN = -@import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const INT_FAST32_MIN = -@import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const INT_FAST64_MIN = -__INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INT_FAST8_MAX = @as(c_int, 127);
pub const INT_FAST16_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const INT_FAST32_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const INT_FAST64_MAX = __INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINT_FAST8_MAX = @as(c_int, 255);
pub const UINT_FAST16_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_FAST32_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const UINT_FAST64_MAX = __UINT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const INTPTR_MIN = -@import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const INTPTR_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const UINTPTR_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const INTMAX_MIN = -__INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal)) - @as(c_int, 1);
pub const INTMAX_MAX = __INT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 9223372036854775807, .decimal));
pub const UINTMAX_MAX = __UINT64_C(@import("std").zig.c_translation.promoteIntLiteral(c_int, 18446744073709551615, .decimal));
pub const PTRDIFF_MIN = -@import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal) - @as(c_int, 1);
pub const PTRDIFF_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const SIG_ATOMIC_MIN = -@import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal) - @as(c_int, 1);
pub const SIG_ATOMIC_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const SIZE_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const WCHAR_MIN = __WCHAR_MIN;
pub const WCHAR_MAX = __WCHAR_MAX;
pub const WINT_MIN = @as(c_uint, 0);
pub const WINT_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub inline fn INT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub inline fn INT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub inline fn INT32_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const INT64_C = @import("std").zig.c_translation.Macros.L_SUFFIX;
pub inline fn UINT8_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub inline fn UINT16_C(c: anytype) @TypeOf(c) {
    _ = &c;
    return c;
}
pub const UINT32_C = @import("std").zig.c_translation.Macros.U_SUFFIX;
pub const UINT64_C = @import("std").zig.c_translation.Macros.UL_SUFFIX;
pub const INTMAX_C = @import("std").zig.c_translation.Macros.L_SUFFIX;
pub const UINTMAX_C = @import("std").zig.c_translation.Macros.UL_SUFFIX;
pub const _STDIO_H = @as(c_int, 1);
pub const __need___va_list = "";
pub const __GNUC_VA_LIST = "";
pub const _____fpos_t_defined = @as(c_int, 1);
pub const ____mbstate_t_defined = @as(c_int, 1);
pub const _____fpos64_t_defined = @as(c_int, 1);
pub const ____FILE_defined = @as(c_int, 1);
pub const __FILE_defined = @as(c_int, 1);
pub const __struct_FILE_defined = @as(c_int, 1);
pub const __getc_unlocked_body = @compileError("TODO postfix inc/dec expr");
// /usr/include/bits/types/struct_FILE.h:102:9
pub const __putc_unlocked_body = @compileError("TODO postfix inc/dec expr");
// /usr/include/bits/types/struct_FILE.h:106:9
pub const _IO_EOF_SEEN = @as(c_int, 0x0010);
pub inline fn __feof_unlocked_body(_fp: anytype) @TypeOf((_fp.*._flags & _IO_EOF_SEEN) != @as(c_int, 0)) {
    _ = &_fp;
    return (_fp.*._flags & _IO_EOF_SEEN) != @as(c_int, 0);
}
pub const _IO_ERR_SEEN = @as(c_int, 0x0020);
pub inline fn __ferror_unlocked_body(_fp: anytype) @TypeOf((_fp.*._flags & _IO_ERR_SEEN) != @as(c_int, 0)) {
    _ = &_fp;
    return (_fp.*._flags & _IO_ERR_SEEN) != @as(c_int, 0);
}
pub const _IO_USER_LOCK = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x8000, .hex);
pub const __cookie_io_functions_t_defined = @as(c_int, 1);
pub const _VA_LIST_DEFINED = "";
pub const __off_t_defined = "";
pub const __ssize_t_defined = "";
pub const _IOFBF = @as(c_int, 0);
pub const _IOLBF = @as(c_int, 1);
pub const _IONBF = @as(c_int, 2);
pub const BUFSIZ = @as(c_int, 8192);
pub const EOF = -@as(c_int, 1);
pub const SEEK_SET = @as(c_int, 0);
pub const SEEK_CUR = @as(c_int, 1);
pub const SEEK_END = @as(c_int, 2);
pub const P_tmpdir = "/tmp";
pub const L_tmpnam = @as(c_int, 20);
pub const TMP_MAX = @import("std").zig.c_translation.promoteIntLiteral(c_int, 238328, .decimal);
pub const _BITS_STDIO_LIM_H = @as(c_int, 1);
pub const FILENAME_MAX = @as(c_int, 4096);
pub const L_ctermid = @as(c_int, 9);
pub const FOPEN_MAX = @as(c_int, 16);
pub const __attr_dealloc_fclose = __attr_dealloc(fclose, @as(c_int, 1));
pub const _BITS_FLOATN_H = "";
pub const __HAVE_FLOAT128 = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT128 = @as(c_int, 0);
pub const __HAVE_FLOAT64X = @as(c_int, 1);
pub const __HAVE_FLOAT64X_LONG_DOUBLE = @as(c_int, 1);
pub const _BITS_FLOATN_COMMON_H = "";
pub const __HAVE_FLOAT16 = @as(c_int, 0);
pub const __HAVE_FLOAT32 = @as(c_int, 1);
pub const __HAVE_FLOAT64 = @as(c_int, 1);
pub const __HAVE_FLOAT32X = @as(c_int, 1);
pub const __HAVE_FLOAT128X = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT16 = __HAVE_FLOAT16;
pub const __HAVE_DISTINCT_FLOAT32 = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT64 = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT32X = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT64X = @as(c_int, 0);
pub const __HAVE_DISTINCT_FLOAT128X = __HAVE_FLOAT128X;
pub const __HAVE_FLOAT128_UNLIKE_LDBL = (__HAVE_DISTINCT_FLOAT128 != 0) and (__LDBL_MANT_DIG__ != @as(c_int, 113));
pub const __HAVE_FLOATN_NOT_TYPEDEF = @as(c_int, 0);
pub const __f32 = @import("std").zig.c_translation.Macros.F_SUFFIX;
pub inline fn __f64(x: anytype) @TypeOf(x) {
    _ = &x;
    return x;
}
pub inline fn __f32x(x: anytype) @TypeOf(x) {
    _ = &x;
    return x;
}
pub const __f64x = @import("std").zig.c_translation.Macros.L_SUFFIX;
pub const __CFLOAT32 = @compileError("unable to translate: TODO _Complex");
// /usr/include/bits/floatn-common.h:149:12
pub const __CFLOAT64 = @compileError("unable to translate: TODO _Complex");
// /usr/include/bits/floatn-common.h:160:13
pub const __CFLOAT32X = @compileError("unable to translate: TODO _Complex");
// /usr/include/bits/floatn-common.h:169:12
pub const __CFLOAT64X = @compileError("unable to translate: TODO _Complex");
// /usr/include/bits/floatn-common.h:178:13
pub inline fn __builtin_huge_valf32() @TypeOf(__builtin_huge_valf()) {
    return __builtin_huge_valf();
}
pub inline fn __builtin_inff32() @TypeOf(__builtin_inff()) {
    return __builtin_inff();
}
pub inline fn __builtin_nanf32(x: anytype) @TypeOf(__builtin_nanf(x)) {
    _ = &x;
    return __builtin_nanf(x);
}
pub const __builtin_nansf32 = @compileError("unable to translate macro: undefined identifier `__builtin_nansf`");
// /usr/include/bits/floatn-common.h:221:12
pub const __builtin_huge_valf64 = @compileError("unable to translate macro: undefined identifier `__builtin_huge_val`");
// /usr/include/bits/floatn-common.h:255:13
pub const __builtin_inff64 = @compileError("unable to translate macro: undefined identifier `__builtin_inf`");
// /usr/include/bits/floatn-common.h:256:13
pub const __builtin_nanf64 = @compileError("unable to translate macro: undefined identifier `__builtin_nan`");
// /usr/include/bits/floatn-common.h:257:13
pub const __builtin_nansf64 = @compileError("unable to translate macro: undefined identifier `__builtin_nans`");
// /usr/include/bits/floatn-common.h:258:13
pub const __builtin_huge_valf32x = @compileError("unable to translate macro: undefined identifier `__builtin_huge_val`");
// /usr/include/bits/floatn-common.h:272:12
pub const __builtin_inff32x = @compileError("unable to translate macro: undefined identifier `__builtin_inf`");
// /usr/include/bits/floatn-common.h:273:12
pub const __builtin_nanf32x = @compileError("unable to translate macro: undefined identifier `__builtin_nan`");
// /usr/include/bits/floatn-common.h:274:12
pub const __builtin_nansf32x = @compileError("unable to translate macro: undefined identifier `__builtin_nans`");
// /usr/include/bits/floatn-common.h:275:12
pub const __builtin_huge_valf64x = @compileError("unable to translate macro: undefined identifier `__builtin_huge_vall`");
// /usr/include/bits/floatn-common.h:289:13
pub const __builtin_inff64x = @compileError("unable to translate macro: undefined identifier `__builtin_infl`");
// /usr/include/bits/floatn-common.h:290:13
pub const __builtin_nanf64x = @compileError("unable to translate macro: undefined identifier `__builtin_nanl`");
// /usr/include/bits/floatn-common.h:291:13
pub const __builtin_nansf64x = @compileError("unable to translate macro: undefined identifier `__builtin_nansl`");
// /usr/include/bits/floatn-common.h:292:13
pub const MAXPDSTRING = @as(c_int, 1000);
pub const MAXPDARG = @as(c_int, 5);
pub const PD_LONGINTTYPE = c_long;
pub const PD_FLOATSIZE = @as(c_int, 32);
pub const PD_FLOATTYPE = f32;
pub const PD_FLOATUINTTYPE = u32;
pub const t_array = cnv.Array;
pub const GP_NONE = @as(c_int, 0);
pub const GP_GLIST = @as(c_int, 1);
pub const GP_ARRAY = @as(c_int, 2);
pub const A_DEFSYMBOL = A_DEFSYM;
pub const t_class = pd.Class;
pub const t_outlet = pd.Outlet;
pub const t_inlet = pd.Inlet;
pub const t_binbuf = pd.BinBuf;
pub const t_clock = pd.Clock;
pub const t_outconnect = pd.Outconnect;
pub const t_glist = cnv.GList;
pub const t_canvas = cnv.GList;
pub const T_TEXT = @as(c_int, 0);
pub const T_OBJECT = @as(c_int, 1);
pub const T_MESSAGE = @as(c_int, 2);
pub const T_ATOM = @as(c_int, 3);
pub const te_pd = @compileError("unable to translate macro: undefined identifier `te_g`");
// m_pd.h:295:9
pub const ob_outlet = @compileError("unable to translate macro: undefined identifier `te_outlet`");
// m_pd.h:301:9
pub const ob_inlet = @compileError("unable to translate macro: undefined identifier `te_inlet`");
// m_pd.h:302:9
pub const ob_binbuf = @compileError("unable to translate macro: undefined identifier `te_binbuf`");
// m_pd.h:303:9
pub const ob_pd = @compileError("unable to translate macro: undefined identifier `te_g`");
// m_pd.h:304:9
pub const ob_g = @compileError("unable to translate macro: undefined identifier `te_g`");
// m_pd.h:305:9
pub inline fn mess0(x: anytype, s: anytype) @TypeOf(getfn(x, s).*(x)) {
    _ = &x;
    _ = &s;
    return getfn(x, s).*(x);
}
pub inline fn mess1(x: anytype, s: anytype, a: anytype) @TypeOf(@import("std").zig.c_translation.cast(t_gotfn1, getfn(x, s)).*(x, a)) {
    _ = &x;
    _ = &s;
    _ = &a;
    return @import("std").zig.c_translation.cast(t_gotfn1, getfn(x, s)).*(x, a);
}
pub inline fn mess2(x: anytype, s: anytype, a: anytype, b: anytype) @TypeOf(@import("std").zig.c_translation.cast(t_gotfn2, getfn(x, s)).*(x, a, b)) {
    _ = &x;
    _ = &s;
    _ = &a;
    _ = &b;
    return @import("std").zig.c_translation.cast(t_gotfn2, getfn(x, s)).*(x, a, b);
}
pub inline fn mess3(x: anytype, s: anytype, a: anytype, b: anytype, c: anytype) @TypeOf(@import("std").zig.c_translation.cast(t_gotfn3, getfn(x, s)).*(x, a, b, c)) {
    _ = &x;
    _ = &s;
    _ = &a;
    _ = &b;
    _ = &c;
    return @import("std").zig.c_translation.cast(t_gotfn3, getfn(x, s)).*(x, a, b, c);
}
pub inline fn mess4(x: anytype, s: anytype, a: anytype, b: anytype, c: anytype, d: anytype) @TypeOf(@import("std").zig.c_translation.cast(t_gotfn4, getfn(x, s)).*(x, a, b, c, d)) {
    _ = &x;
    _ = &s;
    _ = &a;
    _ = &b;
    _ = &c;
    _ = &d;
    return @import("std").zig.c_translation.cast(t_gotfn4, getfn(x, s)).*(x, a, b, c, d);
}
pub inline fn mess5(x: anytype, s: anytype, a: anytype, b: anytype, c: anytype, d: anytype, e: anytype) @TypeOf(@import("std").zig.c_translation.cast(t_gotfn5, getfn(x, s)).*(x, a, b, c, d, e)) {
    _ = &x;
    _ = &s;
    _ = &a;
    _ = &b;
    _ = &c;
    _ = &d;
    _ = &e;
    return @import("std").zig.c_translation.cast(t_gotfn5, getfn(x, s)).*(x, a, b, c, d, e);
}
pub const SETSEMI = @compileError("unable to translate C expr: expected ')' instead got '='");
// m_pd.h:366:9
pub const SETCOMMA = @compileError("unable to translate C expr: expected ')' instead got '='");
// m_pd.h:367:9
pub const SETPOINTER = @compileError("unable to translate C expr: expected ')' instead got '='");
// m_pd.h:368:9
pub const SETFLOAT = @compileError("unable to translate C expr: expected ')' instead got '='");
// m_pd.h:370:9
pub const SETSYMBOL = @compileError("unable to translate C expr: expected ')' instead got '='");
// m_pd.h:371:9
pub const SETDOLLAR = @compileError("unable to translate C expr: expected ')' instead got '='");
// m_pd.h:373:9
pub const SETDOLLSYM = @compileError("unable to translate C expr: expected ')' instead got '='");
// m_pd.h:375:9
pub inline fn pd_class(x: anytype) @TypeOf(x.*) {
    _ = &x;
    return x.*;
}
pub const t_widgetbehavior = cnv.WidgetBehavior;
pub const t_parentwidgetbehavior = cnv.ParentWidgetBehavior;
pub const CLASS_DEFAULT = @as(c_int, 0);
pub const CLASS_PD = @as(c_int, 1);
pub const CLASS_GOBJ = @as(c_int, 2);
pub const CLASS_PATCHABLE = @as(c_int, 3);
pub const CLASS_TYPEMASK = @as(c_int, 3);
pub const CLASS_NOINLET = @as(c_int, 8);
pub const CLASS_MULTICHANNEL = @as(c_int, 0x10);
pub const CLASS_NOPROMOTESIG = @as(c_int, 0x20);
pub const CLASS_NOPROMOTELEFT = @as(c_int, 0x40);
pub const CLASS_MAINSIGNALIN = @compileError("unable to translate C expr: unexpected token '('");
// m_pd.h:574:9
pub inline fn class_addfloat(x: anytype, y: anytype) @TypeOf(class_doaddfloat(x, @import("std").zig.c_translation.cast(t_method, y))) {
    _ = &x;
    _ = &y;
    return class_doaddfloat(x, @import("std").zig.c_translation.cast(t_method, y));
}
pub const MAXLOGSIG = @as(c_int, 32);
pub const MAXSIGSIZE = @as(c_int, 1) << MAXLOGSIG;
pub const t_garray = pd.GArray;
pub const t_getbytes = getbytes;
pub const t_freebytes = freebytes;
pub const t_resizebytes = resizebytes;
pub const typedmess = pd_typedmess;
pub const vmess = pd_vmess;
pub const PD_USE_TE_XPIX = "";
pub const t_instancemidi = pd.Instancemidi;
pub const t_instanceinter = pd.Instanceinter;
pub const t_instancecanvas = pd.Instancecanvas;
pub const t_instanceugen = pd.Instanceugen;
pub const t_instancestuff = pd.Instancestuff;
pub const PDTHREADS = @as(c_int, 1);
pub const t_pdinstance = pd.Pdinstance;
pub const PERTHREAD = "";
// m_pd.h:1045:9: warning: macro 'pd_this' contains a runtime value, translated to function
pub inline fn pd_this() @TypeOf(&pd_maininstance) {
    return &pd_maininstance;
}
pub const __m_pd_h_ = "";
pub const SYMTABHASHSIZE = @as(c_int, 16384);
pub const __m_imp_h_ = "";
pub const G_CANVAS_H = "";
pub const IOWIDTH = @as(c_int, 7);
pub const IHEIGHT = @as(c_int, 3);
pub const OHEIGHT = @as(c_int, 3);
pub const IOMIDDLE = @import("std").zig.c_translation.MacroArithmetic.div(IOWIDTH - @as(c_int, 1), @as(c_int, 2));
pub const GLIST_DEFGRAPHWIDTH = @as(c_int, 200);
pub const GLIST_DEFGRAPHHEIGHT = @as(c_int, 140);
pub const GLIST_DEFCANVASXLOC = @as(c_int, 0);
pub const GLIST_DEFCANVASYLOC = @as(c_int, 50);
pub const t_rtext = pd.Rtext;
pub const t_gtemplate = pd.Gtemplate;
pub const t_guiconnect = pd.Guiconnect;
pub const t_tscalar = pd.Tscalar;
pub const t_canvasenvironment = cnv.CanvasEnvironment;
pub const t_fielddesc = pd.Fielddesc;
pub const MA_NONE = @as(c_int, 0);
pub const MA_MOVE = @as(c_int, 1);
pub const MA_CONNECT = @as(c_int, 2);
pub const MA_REGION = @as(c_int, 3);
pub const MA_PASSOUT = @as(c_int, 4);
pub const MA_DRAGTEXT = @as(c_int, 5);
pub const MA_RESIZE = @as(c_int, 6);
pub const gl_gobj = @compileError("unable to translate macro: undefined identifier `gl_obj`");
// /usr/include/pd/g_canvas.h:217:9
pub const gl_pd = gl_gobj.g_pd;
pub const DT_FLOAT = @as(c_int, 0);
pub const DT_SYMBOL = @as(c_int, 1);
pub const DT_TEXT = @as(c_int, 2);
pub const DT_ARRAY = @as(c_int, 3);
pub const THISGUI = pd_this.*.pd_gui;
pub const EDITOR = pd_this.*.pd_gui.*.i_editor;
pub const TEMPLATE = pd_this.*.pd_gui.*.i_template;
pub const CURSOR_RUNMODE_NOTHING = @as(c_int, 0);
pub const CURSOR_RUNMODE_CLICKME = @as(c_int, 1);
pub const CURSOR_RUNMODE_THICKEN = @as(c_int, 2);
pub const CURSOR_RUNMODE_ADDPOINT = @as(c_int, 3);
pub const CURSOR_EDITMODE_NOTHING = @as(c_int, 4);
pub const CURSOR_EDITMODE_CONNECT = @as(c_int, 5);
pub const CURSOR_EDITMODE_DISCONNECT = @as(c_int, 6);
pub const CURSOR_EDITMODE_RESIZE = @as(c_int, 7);
pub const PLOTSTYLE_POINTS = @as(c_int, 0);
pub const PLOTSTYLE_POLY = @as(c_int, 1);
pub const PLOTSTYLE_BEZ = @as(c_int, 2);
pub const RTEXT_DOWN = @as(c_int, 1);
pub const RTEXT_DRAG = @as(c_int, 2);
pub const RTEXT_DBL = @as(c_int, 3);
pub const RTEXT_SHIFT = @as(c_int, 4);
pub const LB_LOAD = @as(c_int, 0);
pub const LB_INIT = @as(c_int, 1);
pub const LB_CLOSE = @as(c_int, 2);
pub const UNDO_FREE = @as(c_int, 0);
pub const UNDO_UNDO = @as(c_int, 1);
pub const UNDO_REDO = @as(c_int, 2);
pub const UNTITLED_STRNCMP = @compileError("unable to translate macro: undefined identifier `strncmp`");
// /usr/include/pd/g_canvas.h:562:9
pub const GRAPH_ARRAY_SAVE = @as(c_int, 1);
pub const GRAPH_ARRAY_PLOTSTYLE = @as(c_int, 6);
pub const GRAPH_ARRAY_SAVESIZE = @as(c_int, 8);
pub const IEM_GUI_COLNR_WHITE = @as(c_int, 0);
pub const IEM_GUI_COLNR_ML_GREY = @as(c_int, 1);
pub const IEM_GUI_COLNR_D_GREY = @as(c_int, 2);
pub const IEM_GUI_COLNR_L_RED = @as(c_int, 3);
pub const IEM_GUI_COLNR_L_ORANGE = @as(c_int, 4);
pub const IEM_GUI_COLNR_L_YELLOW = @as(c_int, 5);
pub const IEM_GUI_COLNR_L_GREEN = @as(c_int, 6);
pub const IEM_GUI_COLNR_L_CYAN = @as(c_int, 7);
pub const IEM_GUI_COLNR_L_BLUE = @as(c_int, 8);
pub const IEM_GUI_COLNR_L_MAGENTA = @as(c_int, 9);
pub const IEM_GUI_COLNR_LL_GREY = @as(c_int, 10);
pub const IEM_GUI_COLNR_M_GREY = @as(c_int, 11);
pub const IEM_GUI_COLNR_DD_GREY = @as(c_int, 12);
pub const IEM_GUI_COLNR_RED = @as(c_int, 13);
pub const IEM_GUI_COLNR_ORANGE = @as(c_int, 14);
pub const IEM_GUI_COLNR_YELLOW = @as(c_int, 15);
pub const IEM_GUI_COLNR_GREEN = @as(c_int, 16);
pub const IEM_GUI_COLNR_CYAN = @as(c_int, 17);
pub const IEM_GUI_COLNR_BLUE = @as(c_int, 18);
pub const IEM_GUI_COLNR_MAGENTA = @as(c_int, 19);
pub const IEM_GUI_COLNR_L_GREY = @as(c_int, 20);
pub const IEM_GUI_COLNR_MD_GREY = @as(c_int, 21);
pub const IEM_GUI_COLNR_BLACK = @as(c_int, 22);
pub const IEM_GUI_COLNR_D_RED = @as(c_int, 23);
pub const IEM_GUI_COLNR_D_ORANGE = @as(c_int, 24);
pub const IEM_GUI_COLNR_D_YELLOW = @as(c_int, 25);
pub const IEM_GUI_COLNR_D_GREEN = @as(c_int, 26);
pub const IEM_GUI_COLNR_D_CYAN = @as(c_int, 27);
pub const IEM_GUI_COLNR_D_BLUE = @as(c_int, 28);
pub const IEM_GUI_COLNR_D_MAGENTA = @as(c_int, 29);
pub const IEM_GUI_COLOR_SELECTED = @as(c_int, 0x0000FF);
pub const IEM_GUI_COLOR_NORMAL = @as(c_int, 0x000000);
pub const IEM_GUI_COLOR_EDITED = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xFF0000, .hex);
pub const IEM_GUI_MAX_COLOR = @as(c_int, 30);
pub const IEM_GUI_DEFAULTSIZE = (sys_zoomfontheight(canvas_getcurrent().*.gl_font, @as(c_int, 1), @as(c_int, 0)) + @as(c_int, 2)) + @as(c_int, 3);
pub const IEM_GUI_DEFAULTSIZE_SCALE = @import("std").zig.c_translation.MacroArithmetic.div(IEM_GUI_DEFAULTSIZE, @as(f64, 15));
pub const IEM_GUI_MINSIZE = @as(c_int, 8);
pub const IEM_GUI_MAXSIZE = @as(c_int, 1000);
pub const IEM_SL_DEFAULTSIZE = @as(c_int, 128);
pub const IEM_SL_MINSIZE = @as(c_int, 2);
pub const IEM_FONT_MINSIZE = @as(c_int, 4);
pub const IEM_BNG_DEFAULTHOLDFLASHTIME = @as(c_int, 250);
pub const IEM_BNG_DEFAULTBREAKFLASHTIME = @as(c_int, 50);
pub const IEM_BNG_MINHOLDFLASHTIME = @as(c_int, 50);
pub const IEM_BNG_MINBREAKFLASHTIME = @as(c_int, 10);
pub const IEM_VU_DEFAULTSIZE = @as(c_int, 4);
pub const IEM_VU_LARGESMALL = @as(c_int, 2);
pub const IEM_VU_MINSIZE = @as(c_int, 2);
pub const IEM_VU_MAXSIZE = @as(c_int, 25);
pub const IEM_VU_STEPS = @as(c_int, 40);
pub const IEM_VU_MINDB = -@as(f64, 99.9);
pub const IEM_VU_MAXDB = @as(f64, 12.0);
pub const IEM_VU_OFFSET = @as(f64, 100.0);
pub const IEM_RADIO_MAX = @as(c_int, 128);
pub const IEM_SYM_UNIQUE_SND = @as(c_int, 256);
pub const IEM_SYM_UNIQUE_RCV = @as(c_int, 512);
pub const IEM_SYM_UNIQUE_LAB = @as(c_int, 1024);
pub const IEM_SYM_UNIQUE_ALL = @as(c_int, 1792);
pub const IEM_FONT_STYLE_ALL = @as(c_int, 255);
pub const IEM_MAX_SYM_LEN = @as(c_int, 127);
pub const IEM_GUI_DRAW_MODE_UPDATE = @as(c_int, 0);
pub const IEM_GUI_DRAW_MODE_MOVE = @as(c_int, 1);
pub const IEM_GUI_DRAW_MODE_NEW = @as(c_int, 2);
pub const IEM_GUI_DRAW_MODE_SELECT = @as(c_int, 3);
pub const IEM_GUI_DRAW_MODE_ERASE = @as(c_int, 4);
pub const IEM_GUI_DRAW_MODE_CONFIG = @as(c_int, 5);
pub const IEM_GUI_DRAW_MODE_IO = @as(c_int, 6);
pub const IEM_GUI_IOHEIGHT = IHEIGHT;
pub inline fn IS_A_POINTER(atom: anytype, index: anytype) @TypeOf((atom + index).*.a_type == A_POINTER) {
    _ = &atom;
    _ = &index;
    return (atom + index).*.a_type == A_POINTER;
}
pub inline fn IS_A_FLOAT(atom: anytype, index: anytype) @TypeOf((atom + index).*.a_type == A_FLOAT) {
    _ = &atom;
    _ = &index;
    return (atom + index).*.a_type == A_FLOAT;
}
pub inline fn IS_A_SYMBOL(atom: anytype, index: anytype) @TypeOf((atom + index).*.a_type == A_SYMBOL) {
    _ = &atom;
    _ = &index;
    return (atom + index).*.a_type == A_SYMBOL;
}
pub inline fn IS_A_DOLLAR(atom: anytype, index: anytype) @TypeOf((atom + index).*.a_type == A_DOLLAR) {
    _ = &atom;
    _ = &index;
    return (atom + index).*.a_type == A_DOLLAR;
}
pub inline fn IS_A_DOLLSYM(atom: anytype, index: anytype) @TypeOf((atom + index).*.a_type == A_DOLLSYM) {
    _ = &atom;
    _ = &index;
    return (atom + index).*.a_type == A_DOLLSYM;
}
pub const IEM_FSTYLE_FLAGS_ALL = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x007fffff, .hex);
pub const IEM_INIT_ARGS_ALL = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x01ffffff, .hex);
pub const IEM_GUI_OLD_SND_FLAG = @as(c_int, 1);
pub const IEM_GUI_OLD_RCV_FLAG = @as(c_int, 2);
pub const IEMGUI_MAX_NUM_LEN = @as(c_int, 32);
pub inline fn IEMGUI_ZOOM(x: anytype) @TypeOf(x.*.x_gui.x_glist.*.gl_zoom) {
    _ = &x;
    return x.*.x_gui.x_glist.*.gl_zoom;
}
pub const IEMGUI_SETDRAWFUNCTIONS = @compileError("unable to translate macro: undefined identifier `w`");
// /usr/include/pd/g_all_guis.h:317:9
pub const __g_all_guis_h_ = "";
pub const _G_fpos_t = struct__G_fpos_t;
pub const _G_fpos64_t = struct__G_fpos64_t;
pub const _IO_marker = struct__IO_marker;
pub const _IO_codecvt = struct__IO_codecvt;
pub const _IO_wide_data = struct__IO_wide_data;
pub const _IO_FILE = struct__IO_FILE;
pub const _IO_cookie_io_functions_t = struct__IO_cookie_io_functions_t;
pub const _methodentry = struct__methodentry;
pub const _gobj = struct__gobj;
pub const _binbuf = struct__binbuf;
pub const _outlet = struct__outlet;
pub const _inlet = struct__inlet;
pub const _text = struct__text;
pub const _tick = struct__tick;
pub const _updateheader = struct__updateheader;
pub const _selection = struct__selection;
pub const _rtext = struct__rtext;
pub const _guiconnect = struct__guiconnect;
pub const _outconnect = struct__outconnect;
pub const _editor = struct__editor;
pub const _canvasenvironment = struct__canvasenvironment;
pub const _glist = struct__glist;
pub const _gstub = struct__gstub;
pub const _array = struct__array;
pub const word = union_word;
pub const _scalar = struct__scalar;
pub const _gpointer = struct__gpointer;
pub const _atom = struct__atom;
pub const _widgetbehavior = struct__widgetbehavior;
pub const _gtemplate = struct__gtemplate;
pub const _dataslot = struct__dataslot;
pub const _template = struct__template;
pub const _parentwidgetbehavior = struct__parentwidgetbehavior;
pub const _class = struct__class;
pub const _symbol = struct__symbol;
pub const _clock = struct__clock;
pub const _sampleint_union = union__sampleint_union;
pub const _signal = struct__signal;
pub const _resample = struct__resample;
pub const _garray = struct__garray;
pub const _instancemidi = struct__instancemidi;
pub const _instanceinter = struct__instanceinter;
pub const _instancecanvas = struct__instancecanvas;
pub const _instanceugen = struct__instanceugen;
pub const _instancestuff = struct__instancestuff;
pub const _pdinstance = struct__pdinstance;
pub const _tscalar = struct__tscalar;
pub const _fielddesc = struct__fielddesc;
pub const _arrayvis = struct__arrayvis;
pub const _linetraverser = struct__linetraverser;
pub const _iem_fstyle_flags = struct__iem_fstyle_flags;
pub const _iem_init_symargs = struct__iem_init_symargs;
pub const _iemgui_drawfunctions = struct__iemgui_drawfunctions;
pub const _iemgui = struct__iemgui;
pub const _bng = struct__bng;
pub const _slider = struct__slider;
pub const _radio = struct__radio;
pub const _toggle = struct__toggle;
pub const _my_canvas = struct__my_canvas;
pub const _vu = struct__vu;
pub const _my_numbox = struct__my_numbox;