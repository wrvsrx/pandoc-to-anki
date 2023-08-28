{ mkDerivation, aeson, base, blaze-html, bytestring, containers
, cryptohash-sha256, data-default, lib, optparse-applicative
, pandoc, pandoc-types, req, text, utf8-string, uuid
}:
mkDerivation {
  pname = "markdown-to-anki";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    aeson base blaze-html bytestring containers cryptohash-sha256
    data-default optparse-applicative pandoc pandoc-types req text
    utf8-string uuid
  ];
  license = lib.licenses.mit;
  mainProgram = "markdown-to-anki";
}
