pub const Register = enum(usize) {
    R_0 = 0,
    R_1,
    R_2,
    R_3,
    R_4,
    R_5,
    R_6,
    R_7,
    R_PC,
    R_COND,
    R_COUNT,
};

pub const Condition = enum(u16) {
    FL_P = 1 << 0, // 0b1 positive
    FL_Z = 1 << 1, // 0b10 zero
    FL_N = 1 << 2, // ob100 negative
};
