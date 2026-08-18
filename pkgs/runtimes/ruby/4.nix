{ defs }:
[
  {
    def = defs."4.0.0";
    status = {
      level = "degraded";
      reason = "YJIT and ZJIT are disabled; upstream enables both by default whenever the toolchain allows.";
      needs = "rustc >= 1.85 — 4.0 builds both JITs from one crate requiring Rust edition 2024, and the pinned nixpkgs ships 1.80.1.";
    };
    releases = {
      "4.0.0" = "sha256-LoOJyMByy2WMk6E3JzLZ6shAgsiLBldQ2x5SpaxjAnE=";
      "4.0.1" = "sha256-OSS+LQXbMPTjX4Wb8Ci+hfS33QFxQUL9gj5K9d4vr50=";
      "4.0.2" = "sha256-UVArJrULaN9JYzNspB42jN6SySj6+RZU3kxMF5H4Kqw=";
      "4.0.3" = "sha256-d5ZKzDcNXIN1uVAuW6bBPAPvkaueufUhyE+0K5yaaw8=";
      "4.0.4" = "sha256-819u36Pauz9yP50M8ZBsZRKud/TkEqseaMxukdIw+oA=";
      "4.0.5" = "sha256-fWFJB5pj+K4dMmyfplxgGbotwxVerns5FZgXkRyIlY4=";
      "4.0.6" = "sha256-g30pno993yvjGiKaen4BnTVJeYJRF5iayzsysam+Jio=";
    };
  }
]
