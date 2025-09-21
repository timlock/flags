const std = @import("std");

const Error = error{
    NoBoolFlag,
    ParseBoolError,
    ParseIntError,
    ParseFloatError,
    ParseEnumError,
};

pub fn Flag(comptime T: type) type {
    return struct {
        value: T,
        long: []const u8,
        short: u8,
        activated: bool = false,
        const Self = @This();

        pub fn init(default: T, long: []const u8, short: u8) Flag(T) {
            return .{
                .value = default,
                .long = long,
                .short = short,
            };
        }

        pub fn set(self: *Self, value: []const u8) !void {
            if (T == []const u8 or T == []u8) {
                self.value = value;
            } else switch (@typeInfo(T)) {
                .bool => {
                    if (std.mem.eql(u8, "true", value)) {
                        self.value = true;
                    } else if (std.mem.eql(u8, "false", value)) {
                        self.value = false;
                    } else {
                        return Error.ParseBoolError;
                    }
                },
                .int => {
                    self.value = std.fmt.parseInt(T, value, 10) catch return Error.ParseIntError;
                },
                .float => {
                    self.value = std.fmt.parseFloat(T, value) catch return Error.ParseFloatError;
                },
                .@"enum" => {
                    if (std.meta.stringToEnum(T, value)) |enum_field| {
                        self.value = enum_field;
                    } else return Error.ParseEnumError;
                },
                else => {
                    @compileError("Unsupported type for Flag.parse: " ++ @typeName(T));
                },
            }

            self.activated = true;
        }

        pub fn activate(self: *Self) Error!void {
            if (T != bool) {
                return Error.NoBoolFlag;
            }

            self.value = true;
            self.activated = true;
        }
    };
}

test "activate bool flag" {
    const BoolFlag = Flag(bool);

    var bool_flag = BoolFlag.init(false, "bool", 'b');
    try std.testing.expect(!bool_flag.value);
    try std.testing.expect(!bool_flag.activated);

    try bool_flag.activate();
    try std.testing.expect(bool_flag.value);
    try std.testing.expect(bool_flag.activated);
}

test "set bool flag" {
    const BoolFlag = Flag(bool);

    var bool_flag = BoolFlag.init(false, "bool", 'b');
    try std.testing.expectEqual(false, bool_flag.value);
    try std.testing.expect(!bool_flag.activated);

    try bool_flag.set("true");
    try std.testing.expectEqual(true, bool_flag.value);
    try std.testing.expect(bool_flag.activated);
}

test "parse bool error" {
    const BoolFlag = Flag(bool);

    var bool_flag = BoolFlag.init(false, "bool", 'b');
    try std.testing.expectEqual(false, bool_flag.value);
    try std.testing.expect(!bool_flag.activated);

    try std.testing.expectError(Error.ParseBoolError, bool_flag.set("no bool value"));
    try std.testing.expect(!bool_flag.activated);
}

test "set int flag" {
    const IntFlag = Flag(i32);

    var int_flag = IntFlag.init(0, "int", 'i');
    try std.testing.expectEqual(0, int_flag.value);
    try std.testing.expect(!int_flag.activated);

    try std.testing.expectError(Error.NoBoolFlag, int_flag.activate());
    try std.testing.expect(!int_flag.activated);

    try int_flag.set("1");
    try std.testing.expectEqual(1, int_flag.value);
    try std.testing.expect(int_flag.activated);
}

test "parse int error" {
    const IntFlag = Flag(i32);

    var int_flag = IntFlag.init(0, "int", 'i');
    try std.testing.expectEqual(0, int_flag.value);
    try std.testing.expect(!int_flag.activated);

    try std.testing.expectError(Error.NoBoolFlag, int_flag.activate());
    try std.testing.expect(!int_flag.activated);

    try std.testing.expectError(Error.ParseIntError, int_flag.set("no int value"));
    try std.testing.expect(!int_flag.activated);
}

test "set float flag" {
    const FloatFlag = Flag(f64);

    var float_flag = FloatFlag.init(0, "float", 'f');
    try std.testing.expectEqual(0, float_flag.value);
    try std.testing.expect(!float_flag.activated);

    try float_flag.set("1.2");
    try std.testing.expect(float_flag.activated);
    try std.testing.expectEqual(1.2, float_flag.value);
}

test "parse float error" {
    const FloatFlag = Flag(f64);

    var float_flag = FloatFlag.init(0, "float", 'f');
    try std.testing.expectEqual(0, float_flag.value);
    try std.testing.expect(!float_flag.activated);

    try std.testing.expectError(Error.NoBoolFlag, float_flag.activate());
    try std.testing.expect(!float_flag.activated);

    try std.testing.expectError(Error.ParseFloatError, float_flag.set("no int value"));
    try std.testing.expect(!float_flag.activated);
}

test "set string flag" {
    const StringFlag = Flag([]const u8);

    var string_flag = StringFlag.init("empty", "string", 's');
    try std.testing.expectEqual("empty", string_flag.value);
    try std.testing.expect(!string_flag.activated);

    try string_flag.set("full");
    try std.testing.expect(string_flag.activated);
    try std.testing.expectEqual("full", string_flag.value);
}

test "set enum flag" {
    const MyEnum = enum { A, B };
    const EnumFlag = Flag(MyEnum);

    var enum_flag = EnumFlag.init(MyEnum.A, "enum", 'e');
    try std.testing.expectEqual(MyEnum.A, enum_flag.value);
    try std.testing.expect(!enum_flag.activated);

    try enum_flag.set("B");
    try std.testing.expect(enum_flag.activated);
    try std.testing.expectEqual(MyEnum.B, enum_flag.value);
}

test "parse enum error" {
    const MyEnum = enum { A, B };
    const EnumFlag = Flag(MyEnum);

    var enum_flag = EnumFlag.init(MyEnum.A, "enum", 'e');
    try std.testing.expectEqual(MyEnum.A, enum_flag.value);
    try std.testing.expect(!enum_flag.activated);

    try std.testing.expectError(Error.NoBoolFlag, enum_flag.activate());
    try std.testing.expect(!enum_flag.activated);

    try std.testing.expectError(Error.ParseEnumError, enum_flag.set("no enum value"));
    try std.testing.expect(!enum_flag.activated);
}
