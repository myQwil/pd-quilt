const pd = @import("pd");
const std = @import("std");
const Writer = std.Io.Writer;

pub fn fmtG(stream: *Writer, f: pd.Float) !void {
	const gmin = @exp(@log(10.0) * -4);
	const gmax = @exp(@log(10.0) * 6);

	const g = @abs(f);
	if (g != 0 and (g < gmin or gmax <= g)) {
		try stream.print("{e}", .{ f });
	} else {
		try stream.print("{d}", .{ f });
	}
}

pub fn writeVec(writer: *Writer, vec: []const pd.Word) !void {
	if (vec.len == 0) {
		_ = try writer.write("[]");
		return;
	}
	try writer.writeByte('[');
	try fmtG(writer, vec[0].float);
	for (vec[1..]) |w| {
		_ = try writer.write(", ");
		try fmtG(writer, w.float);
	}
	try writer.writeByte(']');
}

pub fn ellipsis(writer: *Writer) void {
	const buf = writer.buffer;
	@memcpy(buf[buf.len - 4 ..][0..3], "...");
	writer.end = buf.len - 1;
}
