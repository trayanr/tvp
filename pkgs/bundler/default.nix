{pkgs, tvp}: rec {
  bundler_1_17_3 = import ./common.nix {
	inherit (pkgs) lib buildRubyGem writeScript;
	ruby = tvp.packages.x86_64-linux.ruby_2_7_0;
	version = "1.17.3";
	sha256 = "sha256-vEv3W1SLJ0UaqfRDsYxGpzndIq1596X5C0hTdqZ9w1I=";
  };

  bundler_2_1_2 = import ./common.nix {
	inherit (pkgs) lib buildRubyGem writeScript;
	ruby = tvp.packages.x86_64-linux.ruby_2_7_0;
	version = "2.1.2";
	sha256 = "sha256-o9icmn+/6TZFEsrBC8jcT5w3DkE3XAPNNsrTHu9vuWE=";
  };

  bundler_2_5_11 = import ./common.nix {
	inherit (pkgs) lib buildRubyGem ruby writeScript;
	version = "2.5.11";
	sha256 = "sha256-3XhL/lODSzmlbmQtvG4eyhmi5kVOTVOZTLcpgAWsTC4=";
  };

  bundler_2_5_20 = import ./common.nix {
	inherit (pkgs) lib buildRubyGem ruby writeScript;
	version = "2.5.20";
	sha256 = "sha256-g7zLXMxFbjRwiaoFMY7NJ7uYQMqmTtFsFwO1DUmwq5Q=";
  };

  bundler = bundler_2_5_20;
}
