{
  description = "pandoc ast to anki";
  inputs = {
    nur-wrvsrx.url = "github:wrvsrx/nur-packages";
    nixpkgs.follows = "nur-wrvsrx/nixpkgs";
    flake-parts.follows = "nur-wrvsrx/flake-parts";
  };
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { inputs, ... }: {
        systems = [ "x86_64-linux" ];
        perSystem = { system, pkgs, ... }: {
          packages = rec {
            markdown-to-anki = pkgs.haskellPackages.callPackage ./default.nix { };
            default = markdown-to-anki;
          };
          devShells.default = pkgs.callPackage ./shell.nix { };
          formatter = pkgs.nixpkgs-fmt;
        };
      }
    );
}
