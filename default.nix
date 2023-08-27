{ stdenvNoCC
, haskellPackages
}:
stdenvNoCC.mkDerivation rec {
  name = "markdown-to-anki";
  src = ./src;
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
    ghc Main
  '';
  installPhase = ''
    mkdir -p $out/bin
    install -m755 Main $out/bin/${name}
  '';
}

