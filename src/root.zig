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

        pub fn set(self: *Self, value: []const u8) Error!void {
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
                .int => self.value = std.fmt.parseInt(T, value, 10) catch return Error.ParseIntError,
                .float => self.value = std.fmt.parseFloat(T, value) catch return Error.ParseFloatError,
                .@"enum" => {
                    if (std.meta.stringToEnum(T, value)) |enum_field| {
                        self.value = enum_field;
                    } else return Error.ParseEnumError;
                },
                else => @compileError("Unsupported type for Flag.parse: " ++ @typeName(T)),
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

        pub fn setter(self: *Self) Setter {
            return Setter.init(self);
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

const Setter = struct {
    ptr: *anyopaque,
    setFn: *const fn (self: *anyopaque, value: []const u8) Error!void,
    activateFn: *const fn (self: *anyopaque) Error!void,

    fn init(ptr: anytype) Setter {
        const T = @TypeOf(ptr);
        const ptr_info = @typeInfo(T);

        const gen = struct {
            pub fn set(pointer: *anyopaque, value: []const u8) Error!void {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptr_info.pointer.child.set(self, value);
            }

            pub fn activate(pointer: *anyopaque) Error!void {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptr_info.pointer.child.activate(self);
            }
        };

        return .{
            .ptr = ptr,
            .setFn = gen.set,
            .activateFn = gen.activate,
        };
    }

    pub fn set(self: Setter, value: []const u8) Error!void {
        return self.setFn(self.ptr, value);
    }

    pub fn activate(self: Setter) Error!void {
        return self.activateFn(self.ptr);
    }
};

test "set bool flag setter" {
    const BoolFlag = Flag(bool);

    var bool_flag = BoolFlag.init(false, "bool", 'b');
    try std.testing.expectEqual(false, bool_flag.value);
    try std.testing.expect(!bool_flag.activated);

    var setter = bool_flag.setter();

    try setter.set("true");
    try std.testing.expectEqual(true, bool_flag.value);
    try std.testing.expect(bool_flag.activated);
}

pub const FlagSet = struct {
    name: []const u8,
    long_map: std.StringArrayHashMap(AnyFlag),
    short_map: std.AutoArrayHashMap(u8, []const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) FlagSet {
        return .{
            .name = name,
            .long_map = std.StringArrayHashMap(AnyFlag).init(allocator),
            .short_map = std.AutoArrayHashMap(u8, []const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn bind(self: *FlagSet, comptime T: type, value: *T, name: []const u8) !void {
        const flag = AnyFlag.init(T, value, name, name[0]);

        try self.short_map.put(name[0], name);
        try self.long_map.put(name, flag);
    }

    pub fn parse(self: *FlagSet, args: [][]const u8) !void {
        var key: ?[]const u8 = null;
        for (args) |arg| {
            if (key) |key_unwraped| {
                var setter = self.long_map.get(key_unwraped).?;
                try setter.setterFn(setter.value, arg);
                key = null;
            } else {
                key = arg;
            }
        }
    }
    pub fn deinit(self: *FlagSet) FlagSet {
        self.long_map.deinit();
        self.short_map.deinit();
    }
};

test "flagset" {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    var fs = FlagSet.init(gpa, "default");

    var bool_value = false;
    try fs.bind(bool, &bool_value, "bool");
    var int_value: i32 = 0;
    try fs.bind(i32, &int_value, "int");

    var args_list = try std.ArrayList([]const u8).initCapacity(gpa, 100);
    defer args_list.deinit(gpa);
    try args_list.append(gpa, "bool");
    try args_list.append(gpa, "true");
    try args_list.append(gpa, "int");
    try args_list.append(gpa, "1");

    const slice = try args_list.toOwnedSlice(gpa);

    try fs.parse(slice);
    std.debug.print("bool: {any} int: {any}\n", .{ bool_value, int_value });
}
test "any flag" {
    var bool_value = false;
    var flag = AnyFlag.init2(bool, &bool_value, "", ' ', FlagParser(bool));
    try flag.setterFn(&bool_value, "true");
}

pub fn FlagParser(comptime T: type) type {
    return struct {
        pub fn setter(ptr: *anyopaque, input: []const u8) Error!void {
            const value_t: *T = @ptrCast(@alignCast(ptr));

            if (T == []const u8 or T == []u8) {
                value_t.* = input;
            } else switch (@typeInfo(T)) {
                .bool => {
                    if (std.mem.eql(u8, "true", input)) {
                        value_t.* = true;
                    } else if (std.mem.eql(u8, "false", input)) {
                        value_t.* = false;
                    } else {
                        return Error.ParseBoolError;
                    }
                },
                .int => value_t.* = std.fmt.parseInt(T, input, 10) catch return Error.ParseIntError,
                .float => value_t.* = std.fmt.parseFloat(T, input) catch return Error.ParseFloatError,
                .@"enum" => {
                    if (std.meta.stringToEnum(T, input)) |enum_field| {
                        value_t.* = enum_field;
                    } else return Error.ParseEnumError;
                },
                else => @compileError("Unsupported type for Flag.parse: " ++ @typeName(T)),
            }
        }
        pub fn activate(ptr: *anyopaque) Error!void {
            if (T != bool) {
                return Error.NoBoolFlag;
            }

            const value_t: *T = @ptrCast(@alignCast(ptr));
            value_t.* = true;
        }
    };
}

pub fn IntFlagParser(comptime T: type) type {
    return struct {
        pub fn setter(ptr: *anyopaque, input: []const u8) Error!void {
            const value_t: *T = @ptrCast(@alignCast(ptr));

            if (T == []const u8 or T == []u8) {
                value_t.* = input;
            } else switch (@typeInfo(T)) {
                .bool => {
                    if (std.mem.eql(u8, "true", input)) {
                        value_t.* = true;
                    } else if (std.mem.eql(u8, "false", input)) {
                        value_t.* = false;
                    } else {
                        return Error.ParseBoolError;
                    }
                },
                .int => value_t.* = std.fmt.parseInt(T, input, 10) catch return Error.ParseIntError,
                .float => value_t.* = std.fmt.parseFloat(T, input) catch return Error.ParseFloatError,
                .@"enum" => {
                    if (std.meta.stringToEnum(T, input)) |enum_field| {
                        value_t.* = enum_field;
                    } else return Error.ParseEnumError;
                },
                else => @compileError("Unsupported type for Flag.parse: " ++ @typeName(T)),
            }
        }
        pub fn activate(ptr: *anyopaque) Error!void {
            if (T != bool) {
                return Error.NoBoolFlag;
            }

            const value_t: *T = @ptrCast(@alignCast(ptr));
            value_t.* = true;
        }
    };
}

const BoolFlagParser = struct {
    pub fn setter(ptr: *anyopaque, input: []const u8) Error!void {
        const value_t: *bool = @ptrCast(@alignCast(ptr));
        if (std.mem.eql(u8, "true", input)) {
            value_t.* = true;
        } else if (std.mem.eql(u8, "false", input)) {
            value_t.* = false;
        } else {
            return Error.ParseBoolError;
        }
    }

    pub fn activate(ptr: *anyopaque) Error!void {
        const value_t: *bool = @ptrCast(@alignCast(ptr));
        value_t.* = true;
    }
};

const AnyFlag = struct {
    value: *anyopaque,
    long: []const u8,
    short: u8,
    activated: bool = false,
    setterFn: *const fn (value: *anyopaque, input: []const u8) Error!void,
    activateFn: *const fn (value: *anyopaque) Error!void,
    const Self = @This();

    pub fn init2(
        comptime T: type,
        value: *T,
        long: []const u8,
        short: u8,
        comptime gen: type,
    ) Self {
        return .{
            .value = value,
            .long = long,
            .short = short,
            .setterFn = gen.setter,
            .activateFn = gen.activate,
        };
    }

    pub fn init(comptime T: type, value: *T, long: []const u8, short: u8) AnyFlag {
        const gen = struct {
            pub fn setter(ptr: *anyopaque, input: []const u8) Error!void {
                const value_t: *T = @ptrCast(@alignCast(ptr));

                if (T == []const u8 or T == []u8) {
                    value_t.* = input;
                } else switch (@typeInfo(T)) {
                    .bool => {
                        if (std.mem.eql(u8, "true", input)) {
                            value_t.* = true;
                        } else if (std.mem.eql(u8, "false", input)) {
                            value_t.* = false;
                        } else {
                            return Error.ParseBoolError;
                        }
                    },
                    .int => value_t.* = std.fmt.parseInt(T, input, 10) catch return Error.ParseIntError,
                    .float => value_t.* = std.fmt.parseFloat(T, input) catch return Error.ParseFloatError,
                    .@"enum" => {
                        if (std.meta.stringToEnum(T, input)) |enum_field| {
                            value_t.* = enum_field;
                        } else return Error.ParseEnumError;
                    },
                    else => @compileError("Unsupported type for Flag.parse: " ++ @typeName(T)),
                }
            }
            pub fn activate(ptr: *anyopaque) Error!void {
                if (T != bool) {
                    return Error.NoBoolFlag;
                }

                const value_t: *T = @ptrCast(@alignCast(ptr));
                value_t.* = true;
            }
        };
        return .{
            .value = value,
            .long = long,
            .short = short,
            .setterFn = gen.setter,
            .activateFn = gen.activate,
        };
    }

    pub fn set(self: *AnyFlag, input: []const u8) Error!void {
        try self.setterFn(self.value, input);
        self.activated = true;
    }

    pub fn activate(self: *AnyFlag) Error!void {
        try self.activateFn(self.value);
        self.activated = true;
    }
};
