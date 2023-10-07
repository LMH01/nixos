{ lib, rustPlatform, fetchFromGitHub, pkg-config }:

rustPlatform.buildRustPackage rec {
  pname = "alpha_tui";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "LMH01";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-6WnZqiPxFL1oQIW7XTT4VCREJVp60ENNn8+uotRIaiI=";
  };

  cargoHash = "sha256-BRogDbUD0tl1eT6cLoFY/ddLmXsvm6CGpJ/MZnaSrzI=";

  nativeBuildInputs = [ pkg-config ];

  # Needed to get openssl-sys to use pkg-config.
  OPENSSL_NO_VENDOR = 1;

  meta = with lib; {
    description = "Compiler and runtime environment for Alpha-Notation written in Rust";
    homepage = "https://github.com/LMH01/alpha_tui/";
    changelog = "https://github.com/LMH01/alpha_tui/blob/${version}/docs/changelog.md";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ LMH01 ];
  };
}
