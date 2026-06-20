{
  mkShell,
  rustc,
  cargo,
  protobuf,
}:
mkShell {
  nativeBuildInputs = [
    rustc
    cargo
    protobuf
  ];
}
