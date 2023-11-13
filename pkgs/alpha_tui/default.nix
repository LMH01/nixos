{ lib
, rustPlatform
, fetchFromGitHub
}:

rustPlatform.buildRustPackage rec {
  pname = "alpha-tui";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "LMH01";
    repo = "alpha_tui";
    rev = "v${version}";
    hash = "sha256-U/278hufT3vvJ548To5CSeg29G0VBRSC6TuhpomQ1rQ=";
  };

  cargoHash = "sha256-EaJKo2zEUU3vRvFAbD77aTPUWvGzzwKIQff2oq0yrag=";

  meta = with lib; {
    description = "My attempt to write a compiler for the Alpha-Notation used in my SysInf lecture";
    homepage = "https://github.com/LMH01/alpha_tui";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ LMH01 ];
    mainProgram = "alpha-tui";
  };
}
