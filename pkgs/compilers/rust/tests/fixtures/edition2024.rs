// Ruby 4.0 builds YJIT and ZJIT from one crate requiring edition 2024, so this
// is the capability that decides whether those JITs can be enabled at all.
fn main() {
    let v: Vec<u32> = (1..=3).collect();
    println!("{}", v.iter().sum::<u32>());
}
