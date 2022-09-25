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
      in rec {
        packages = rec {
          markdown_to_anki-python = poetry2nix.mkPoetryApplication poetryAttrsSet;
          markdown_to_anki = stdenv.mkDerivation rec {
            name = "markdown_to_anki";
            src = ./.;
            buildInputs = [
              (haskellPackages.ghcWithPackages (ps: with ps; [
                pandoc
                uuid
                utf8-string
                optparse-applicative
                cryptohash-sha256
                utf8-string
              ]))
            ];
            buildPhase = ''
              env --chdir=src ghc Main
            '';
            installPhase = ''
              mkdir -p $out/bin
              install -m755 src/Main $out/bin/${name}
            '';
          };
          default = markdown_to_anki;
        };
        devShell = mkShell {
          inputsFrom = with packages; [ markdown_to_anki ];
          buildInputs = [
            poetry
            (poetry2nix.mkPoetryEnv poetryAttrsSet)
          ];
        };
      }
  );
}
