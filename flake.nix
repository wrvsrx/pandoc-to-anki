{
  description = "pandoc ast to anki";
  inputs = {
    flake-lock.url = "github:wrvsrx/flake-lock";
    nixpkgs.follows = "flake-lock/nixpkgs";
    flake-parts.follows = "flake-lock/flake-parts";
  };
  outputs = inputs': inputs'.flake-parts.lib.mkFlake { inputs = inputs'; } ({ inputs, ... }: {
    systems = [ "x86_64-linux" ];
    perSystem = { system, pkgs, ... }: {
      packages = rec {
        markdown-to-anki = pkgs.haskellPackages.callPackage ./default.nix { };
        default = markdown-to-anki;
      };
      devShells.default = pkgs.callPackage ./shell.nix { };
    };
  }
  );
}
