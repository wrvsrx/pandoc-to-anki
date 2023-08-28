{ mkDerivation, aeson, base, bytestring, containers
, cryptohash-sha256, lib, optparse-applicative, pandoc
, pandoc-types, text, utf8-string, uuid
}:
mkDerivation {
  pname = "markdown-to-anki";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    aeson base bytestring containers cryptohash-sha256
    optparse-applicative pandoc pandoc-types text utf8-string uuid
  ];
  license = lib.licenses.mit;
  mainProgram = "markdown-to-anki";
}
