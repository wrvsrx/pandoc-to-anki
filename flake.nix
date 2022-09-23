{
  description = "pandoc ast to anki";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
  flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
    in with pkgs; 
      let
        poetryAttrsSet = {
          projectDir = ./.;
          overrides = poetry2nix.overrides.withDefaults (final: prev: {
            genanki = prev.genanki.overrideAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ prev.pytest-runner ];
            });
          });
          preferWheels = true;
        };
      in
        {
          devShell = mkShell {
            buildInputs = [
              (haskellPackages.ghcWithPackages (ps: with ps; [
                pandoc
              ]))
              poetry
              ((poetry2nix.mkPoetryApplication poetryAttrsSet).dependencyEnv)
            ];
        };
      }
  );
}
