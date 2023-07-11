fn main() {
    let a = x & (y ^ (z | w)); // Invalid: x & y ^ z | w
    let b = (x + y) << (z >= w); // Invalid: x + y << z >= w
    let c = x < (y > z); // Invalid: x < y > z
    let d = x && (y || z); // Invalid: x && y || z
}
