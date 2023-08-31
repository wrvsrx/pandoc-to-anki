{ cabal2nix
, cabal-install
, haskellPackages
}:
haskellPackages.shellFor {
  packages = ps: [ (ps.callPackage ./default.nix { }) ];
  nativeBuildInputs = [
    cabal2nix
    cabal-install
    haskellPackages.cabal-fmt
  ];
}
