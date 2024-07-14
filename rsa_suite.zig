const std = @import("std");
const print = @import("std").debug.print;
const rng = std.crypto.random;

pub fn main() !void {
    print("Generating primes:\n", .{});
    const prime1 = generatePrime();
    const prime2 = generatePrime();
    print("Primes p and q: {} {}\nProving they are prime:\n", .{ prime1, prime2 });
    _ = egcd(prime1, prime2, true);

    const pubkey = generatePubKey(prime1, prime2);
    print("\n\nFound the public key exponent\ne, n = {} \t {}\n", .{ pubkey.e, pubkey.n });
    print("Finding the private key exponent through inverse mod with egcd\n", .{});
    const prikey = generatePriKey(pubkey);
    print("\n\nFound the full keypair: \ne = {} \nd = {} \nn = {}\n", .{ prikey.e, prikey.d, prikey.n });
    print("Proving d * e === 1 (mod totient)\n", .{});
    const quotient = @divFloor(@as(u256, prikey.d) * prikey.e, prikey.totient);
    const remainder = @mod(@as(u256, prikey.d) * prikey.e, prikey.totient);
    print("{} * {} = {} * {} + {}\n", .{ prikey.d, prikey.e, prikey.totient, quotient, remainder });
}
pub fn generatePrime() u128 {
    const randint = rng.intRangeAtMost(u64, 20, 40);
    const euler_polynomial = randint * randint + randint + 41; //generate euler prime
    return euler_polynomial;
    // const mersenne_prime = std.math.pow(u128, 2, euler_polynomial) - 1; //generate mersenne prime from euler prime
    // return mersenne_prime;
}

const keypair = struct {
    e: u256 = undefined,
    d: u256 = undefined,
    n: u256 = undefined,
    totient: u256 = undefined,
};
pub fn generatePubKey(p: u128, q: u128) keypair {
    const totient: u256 = @as(u256, p - 1) * (q - 1);
    const e: u256 = generatePrime();
    const n = @as(u256, p) * q;
    return keypair{ .e = e, .n = n, .totient = totient };
}
pub fn generatePriKey(kp: keypair) keypair {
    const potential_kp = egcd(kp.totient, kp.e, true);
    const raw_d = @mod(@as(i257, potential_kp.t), @as(i257, kp.totient));
    return keypair{ .e = kp.e, .d = @as(u256, @intCast(raw_d)), .n = kp.n, .totient = kp.totient };
}
const row = struct {
    a: u256 = 0,
    b: u256 = 0,
    q: u256 = 0,
    r: u256 = 0,
    s: i256 = 0,
    t: i256 = 0,
};

const egcdResult = struct {
    gcd: u256,
    s: i256,
    t: i256,
};
pub fn egcd(_a: u256, _b: u256, debug: bool) egcdResult {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();
    const rows: u8 = 100;
    //const cols: u8 = 10;
    var table = alloc.alloc(row, rows) catch unreachable;
    var a = @as(u256, _a);
    var b = @as(u256, _b);
    if (b > a) { //swap variables to make a > b
        a += b;
        b = a - b;
        a -= b;
    }
    var c: u8 = 2;
    table[c].a = a;
    table[c].b = b;
    table[c].r = 1;
    table[c - 2].s = 1; // s1
    table[c - 1].s = 0; // s2
    table[c].s = 1; //s3
    table[c - 2].t = 0; // t1
    table[c - 1].t = 1; // t2
    print("  a  |  b  |  q  |  r  |  s  |  t\n", .{});
    while (table[c].r != 0) {
        table[c].q = @divTrunc(table[c].a, table[c].b); //q = a/b
        table[c].r = @mod(table[c].a, table[c].b); //r = a%b
        table[c + 1].a = table[c].b; //a = b
        table[c + 1].b = table[c].r; //b = r
        table[c].s = @as(i256, @truncate(@as(i257, table[c - 2].s) - @as(i257, table[c].q) * table[c - 1].s));
        table[c].t = @as(i256, @truncate(@as(i257, table[c - 2].t) - @as(i257, table[c].q) * table[c - 1].t));
        if (debug) {
            print("{d} | {d} | {d} | {d} | {d} | {d}", .{ table[c].a, table[c].b, table[c].q, table[c].r, table[c].s, table[c].t });
            print("\n", .{});
        }
        if (table[c].r == 0) {
            std.debug.print("gcd is {d}\n", .{table[c].b});
            print("bezier coeffs are s={0d}, t={1d}: {0d}*{2d}+{1d}*{3d}={4d}\n", .{ table[c - 1].s, table[c - 1].t, table[2].a, table[2].b, table[c].b });
            return egcdResult{ .gcd = table[c].b, .s = table[c - 1].s, .t = table[c - 1].t };
        }
        c += 1;
    }
    print("gcd is 1\n", .{});
    defer alloc.free(table);
    return egcdResult{ .gcd = 1, .s = table[c - 1].s, .t = table[c - 1].t };
}
