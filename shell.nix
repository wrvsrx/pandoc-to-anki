{ mkShell
, cabal2nix
, cabal-install
, haskellPackages
, markdown-to-anki
}:
mkShell {
  inputsFrom = [ markdown-to-anki.env ];
  buildInputs = [
    # poetry
    # (poetry2nix.mkPoetryEnv poetryAttrsSet)
    cabal2nix
    cabal-install
    haskellPackages.cabal-fmt
  ];
}
