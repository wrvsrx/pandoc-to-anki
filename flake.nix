{
  description = "pandoc ast to anki";
  inputs = {
    flake-lock.url = "github:wrvsrx/flake-lock";
    nixpkgs.follows = "flake-lock/nixpkgs";
    flake-parts.follows = "flake-lock/flake-parts";
  };
  outputs = inputs': inputs'.flake-parts.lib.mkFlake { inputs = inputs'; } ({ inputs, ... }: {
    systems = [ "x86_64-linux" ];
    perSystem = { system, pkgs, ... }:
      let
        poetryAttrsSet = {
          projectDir = ./.;
          overrides = pkgs.poetry2nix.overrides.withDefaults (final: prev: {
            pandoc = prev.pandoc.overrideAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.setuptools ];
            });
            genanki = prev.genanki.overrideAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.pytest-runner ];
            });
          });
          preferWheels = true;
        };
      in

      rec {
        packages = rec {
          markdown-to-anki-python = inputs.poetry2nix.mkPoetryApplication poetryAttrsSet;
          markdown-to-anki = pkgs.callPackage ./default.nix { };
          default = markdown-to-anki;
        };
        devShells.default = pkgs.mkShell {
          inputsFrom = [ packages.markdown-to-anki ];
          buildInputs = with pkgs; [
            poetry
            (poetry2nix.mkPoetryEnv poetryAttrsSet)
          ];
        };
      };
  }
  );
}
