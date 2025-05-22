self: super: {
  docker = super.docker.overrideAttrs (oldAttrs: {
    buildInputs = (oldAttrs.buildInputs or []) ++ [ super.go ];
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ super.go ];
    # Ensure that the Go version is set to 1.24.3 (hopefully)
    go = super.go;
  });
}