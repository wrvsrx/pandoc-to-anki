# markdown-to-anki

Experimental Rust rewrite for generating Anki packages from Markdown-derived data.

The first milestone only verifies that this project can create an `.apkg` through Anki's official Rust collection exporter.

## Demo

`anki_proto` requires `protoc` at build time. With Nix:

```sh
nix shell nixpkgs#protobuf -c cargo run -- apkg --output demo.apkg
```

This creates a fixed demo deck named `Markdown To Anki Demo`.
