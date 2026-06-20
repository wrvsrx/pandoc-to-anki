{
  mkShell,
  rustc,
  cargo,
  rustfmt,
  protobuf,
}:
mkShell {
  nativeBuildInputs = [
    rustc
    cargo
    protobuf

    rustfmt
  ];
}
