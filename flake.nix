{
  description = "pandoc to anki";

  inputs = {
    nixpkgs.url = "github:wrvsrx/nixpkgs/patched-nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { inputs, ... }:
      {
        systems = [ "x86_64-linux" ];
        perSystem =
          { pkgs, ... }:
          let
            cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
          in
          {
            packages.default = pkgs.rustPlatform.buildRustPackage {
              pname = "pandoc-to-anki";
              version = cargoToml.package.version;

              src = ./.;

              cargoLock = {
                lockFile = ./Cargo.lock;
                outputHashes = {
                  "percent-encoding-iri-2.2.0" = "sha256-kCBeS1PNExyJd4jWfDfctxq6iTdAq69jtxFQgCCQ8kQ=";
                };
              };

              nativeBuildInputs = [
                pkgs.protobuf
              ];
            };

            formatter = pkgs.nixfmt;
          };
      }
    );
}
