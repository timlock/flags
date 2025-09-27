const std = @import("std");

const Error = error{
    NoBoolFlag,
    ParseBoolError,
    ParseIntError,
    ParseFloatError,
    ParseEnumError,
};

const Flag = struct {
    value: *anyopaque,
    long: []const u8,
    activated: bool = false,
    parser: Options,

    const Options = struct {
        setter_fn: *const fn (value: *anyopaque, input: []const u8) Error!void,
        activate_fn: ?*const fn (value: *anyopaque) Error!void = null,
        short: ?u8 = null,
    };

    const Self = @This();

    fn init(
        value: *anyopaque,
        long: []const u8,
        options: Options,
    ) Flag {
        return .{
            .value = value,
            .long = long,
            .parser = options,
        };
    }

    pub fn set(self: *Flag, input: []const u8) Error!void {
        try self.parser.setter_fn(self.value, input);
        self.activated = true;
    }

    pub fn activate(self: *Flag) Error!void {
        const activate_fn = self.parser.activate_fn orelse return Error.NoBoolFlag;
        try activate_fn(self.value);
        self.activated = true;
    }
};

test "activate bool flag" {
    var bool_value = false;
    var bool_flag = Flag.init(&bool_value, "bool", .{
        .setter_fn = set_bool,
        .activate_fn = activate_bool,
    });
    try std.testing.expect(!bool_value);
    try std.testing.expect(!bool_flag.activated);

    try bool_flag.activate();
    try std.testing.expect(bool_value);
    try std.testing.expect(bool_flag.activated);
}

test "set bool flag" {
    var bool_value = false;
    var bool_flag = Flag.init(&bool_value, "bool", .{
        .setter_fn = set_bool,
        .activate_fn = activate_bool,
    });

    try std.testing.expect(!bool_value);
    try std.testing.expect(!bool_flag.activated);

    try bool_flag.set("true");
    try std.testing.expect(bool_value);
    try std.testing.expect(bool_flag.activated);
}

test "parse bool error" {
    var bool_value = false;
    var bool_flag = Flag.init(&bool_value, "bool", .{
        .setter_fn = set_bool,
        .activate_fn = activate_bool,
    });

    try std.testing.expect(!bool_value);
    try std.testing.expect(!bool_flag.activated);

    try std.testing.expectError(Error.ParseBoolError, bool_flag.set("no bool value"));
    try std.testing.expect(!bool_flag.activated);
}

test "set int flag" {
    var int_value: i32 = 0;
    var int_flag = Flag.init(&int_value, "int", .{
        .setter_fn = set_int_factory(i32),
    });

    try std.testing.expectEqual(0, int_value);
    try std.testing.expect(!int_flag.activated);

    try std.testing.expectError(Error.NoBoolFlag, int_flag.activate());
    try std.testing.expect(!int_flag.activated);

    try int_flag.set("1");
    try std.testing.expectEqual(1, int_value);
    try std.testing.expect(int_flag.activated);
}

test "parse int error" {
    var int_value: i32 = 0;
    var int_flag = Flag.init(&int_value, "int", .{
        .setter_fn = set_int_factory(i32),
    });

    try std.testing.expectEqual(0, int_value);
    try std.testing.expect(!int_flag.activated);

    try std.testing.expectError(Error.NoBoolFlag, int_flag.activate());
    try std.testing.expect(!int_flag.activated);

    try std.testing.expectError(Error.ParseIntError, int_flag.set("no int value"));
    try std.testing.expect(!int_flag.activated);
}

test "set float flag" {
    var float_value: f32 = 0;
    var float_flag = Flag.init(&float_value, "float", .{});
    try std.testing.expectEqual(0, float_value);
    try std.testing.expect(!float_flag.activated);

    try float_flag.set("1.2");
    try std.testing.expect(float_flag.activated);
    try std.testing.expectEqual(1.2, float_value);
}

test "parse float error" {
    var float_value: f32 = 0;
    var float_flag = Flag.init(&float_value, "float", .{});
    try std.testing.expectEqual(0, float_value);
    try std.testing.expect(!float_flag.activated);

    try std.testing.expectError(Error.NoBoolFlag, float_flag.activate());
    try std.testing.expect(!float_flag.activated);

    try std.testing.expectError(Error.ParseFloatError, float_flag.set("no int value"));
    try std.testing.expect(!float_flag.activated);
}

test "set string flag" {
    var string_value = "empty";
    var string_flag = Flag.init(&string_value, "string", .{});
    try std.testing.expectEqual("empty", string_value);
    try std.testing.expect(!string_flag.activated);

    try string_flag.set("full");
    try std.testing.expect(string_flag.activated);
    try std.testing.expectEqual("full", string_value);
}

test "set enum flag" {
    const MyEnum = enum { A, B };
    var enum_value = MyEnum.A;

    var enum_flag = Flag.init(&enum_value, "enum", .{});
    try std.testing.expectEqual(MyEnum.A, enum_value);
    try std.testing.expect(!enum_flag.activated);

    try enum_flag.set("B");
    try std.testing.expect(enum_flag.activated);
    try std.testing.expectEqual(MyEnum.B, enum_value);
}

test "parse enum error" {
    const MyEnum = enum { A, B };
    var enum_value = MyEnum.A;

    var enum_flag = Flag.init(&enum_value, "enum", .{});
    try std.testing.expectEqual(MyEnum.A, enum_value);
    try std.testing.expect(!enum_flag.activated);

    try std.testing.expectError(Error.NoBoolFlag, enum_flag.activate());
    try std.testing.expect(!enum_flag.activated);

    try std.testing.expectError(Error.ParseEnumError, enum_flag.set("no enum value"));
    try std.testing.expect(!enum_flag.activated);
}

pub const FlagSet = struct {
    name: []const u8,
    long_map: std.StringArrayHashMap(Flag),
    short_map: std.AutoArrayHashMap(u8, []const u8),
    allocator: std.mem.Allocator,

    fn FlagOptions(comptime T: type) type {
        const setter_fn = if (T == []const u8) {
            set_string;
        } else switch (@typeInfo(T)) {
            .bool => set_bool,
            .int => set_int_factory(T),
            .float => set_float_factory(T),
            .@"enum" => set_enum_factory(T),
            else => null,
        };

        const activate_fn = if (T == bool) activate_bool else null;

        return struct {
            short: ?u8 = null,
            default_value: ?T = null,
            setter_fn: ?*const fn (value: *anyopaque, input: []const u8) Error!void = setter_fn,
            activate_fn: ?*const fn (value: *anyopaque) Error!void = activate_fn,
        };
    }

    pub fn init(allocator: std.mem.Allocator, name: []const u8) FlagSet {
        return .{
            .name = name,
            .long_map = std.StringArrayHashMap(Flag).init(allocator),
            .short_map = std.AutoArrayHashMap(u8, []const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn bind(self: *FlagSet, comptime T: type, value: *T, name: []const u8, option: FlagOptions(T)) !void {
        if (option.default_value) |default_value| {
            value.* = default_value;
        }

        if (option.setter_fn == null) {
            @panic("setter_fn should not be null");
        }

        const flag = Flag.init(value, name, .{
            .short = option.short,
            .setter_fn = option.setter_fn.?,
            .activate_fn = option.activate_fn,
        });

        try self.short_map.put(name[0], name);
        try self.long_map.put(name, flag);
    }

    pub fn parse(self: *FlagSet, args: [][]const u8) !void {
        var key: ?[]const u8 = null;
        for (args) |arg| {
            if (key) |key_unwraped| {
                var setter = self.long_map.get(key_unwraped).?;
                try setter.set(arg);
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
    try fs.bind(bool, &bool_value, "bool", .{ .short = 'b' });
    var int_value: i32 = 0;
    try fs.bind(i32, &int_value, "int", .{});

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
    var bool_flag = Flag.init(&bool_value, "", .{
        .setter_fn = set_bool,
        .activate_fn = activate_bool,
        .short = 'b',
    });
    try bool_flag.set("true");
    try std.testing.expect(bool_value);

    var int_value: i32 = 0;
    var int_flag = Flag.init(&int_value, "", .{
        .setter_fn = set_int_factory(i32),
    });
    try int_flag.set("123");
    try std.testing.expectEqual(123, int_value);
}

fn set_int_factory(comptime T: type) *const fn (value: *anyopaque, input: []const u8) Error!void {
    const setterFn = struct {
        fn setter(ptr: *anyopaque, input: []const u8) Error!void {
            const value_t: *T = @ptrCast(@alignCast(ptr));
            value_t.* = std.fmt.parseInt(T, input, 10) catch return Error.ParseIntError;
        }
    }.setter;

    return setterFn;
}

fn set_float_factory(comptime T: type) *const fn (value: *anyopaque, input: []const u8) Error!void {
    const setterFn = struct {
        fn setter(ptr: *anyopaque, input: []const u8) Error!void {
            const value_t: *T = @ptrCast(@alignCast(ptr));
            value_t.* = std.fmt.parseFloat(T, input) catch return Error.ParseFloatError;
        }
    }.setter;

    return setterFn;
}

fn set_enum_factory(comptime T: type) *const fn (value: *anyopaque, input: []const u8) Error!void {
    const setterFn = struct {
        fn setter(ptr: *anyopaque, input: []const u8) Error!void {
            const value_t: *T = @ptrCast(@alignCast(ptr));
            if (std.meta.stringToEnum(T, input)) |enum_field| {
                value_t.* = enum_field;
            } else return Error.ParseEnumError;
        }
    }.setter;

    return setterFn;
}

fn set_string(ptr: *anyopaque, input: []const u8) Error!void {
    const value_t: *[]const u8 = @ptrCast(@alignCast(ptr));
    value_t.* = input;
}

fn set_bool(ptr: *anyopaque, input: []const u8) Error!void {
    const value_t: *bool = @ptrCast(@alignCast(ptr));
    if (std.mem.eql(u8, "true", input)) {
        value_t.* = true;
    } else if (std.mem.eql(u8, "false", input)) {
        value_t.* = false;
    } else {
        return Error.ParseBoolError;
    }
}

fn activate_bool(ptr: *anyopaque) Error!void {
    const value_t: *bool = @ptrCast(@alignCast(ptr));
    value_t.* = true;
}
