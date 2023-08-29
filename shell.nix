{ cabal2nix
, cabal-install
, haskellPackages
}:
haskellPackages.shellFor
{
  packages = ps: [
    (ps.callPackage ./default.nix { })
    ps.shake
  ];
  nativeBuildInputs = [
    cabal2nix
    cabal-install
    haskellPackages.cabal-fmt
  ];
}
