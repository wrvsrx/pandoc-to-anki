# markdown-to-anki

Experimental Rust rewrite for generating Anki packages from Markdown-derived data.

The first milestone only verifies that this project can create an `.apkg` through Anki's official Rust collection exporter.

The Anki Rust dependency is vendored as a git submodule at `externals/anki`, currently pointing at the fork tag `markdown-to-anki-26.05-buildfix`, based on Anki release tag `26.05`.

## Demo

Initialize submodules before building:

```sh
git submodule update --init --recursive
```

`anki_proto` requires `protoc` at build time. With Nix:

```sh
nix shell nixpkgs#protobuf -c cargo run -- apkg --output demo.apkg
```

This creates a fixed demo deck named `Markdown To Anki Demo`.
