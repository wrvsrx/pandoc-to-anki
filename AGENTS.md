# AGENTS.md

## Project State

This repository is being rebuilt from scratch as a Rust CLI. The legacy Haskell/Cabal/Nix implementation was intentionally removed and should not be restored unless explicitly requested.

The current milestone reads a Pandoc JSON AST, extracts supported `::: anki` fenced div blocks, and exports an `.apkg` through Anki's official Rust collection exporter.

## Build Requirements

The official Anki Rust dependency builds protobuf code and requires `protoc`.

Initialize the forked Anki submodule first:

```sh
git submodule update --init --recursive
```

Use:

```sh
nix shell nixpkgs#protobuf -c cargo check
```

To run the demo exporter:

```sh
nix shell nixpkgs#protobuf -c cargo run -- demo --output /tmp/markdown-to-anki-demo.apkg
```

To generate an APKG from Pandoc JSON:

```sh
pandoc -f markdown -t json notes.md | nix shell nixpkgs#protobuf -c cargo run -- apkg --output /tmp/notes.apkg
```

Generated `.apkg` files are ignored by git.

## Current Architecture

- `src/main.rs` defines the CLI.
- `src/pandoc.rs` extracts `Div` blocks with class `anki` from Pandoc JSON and renders each note's front/back HTML.
- `src/export.rs` creates a temporary Anki collection, adds `Basic` notes, and calls `Collection::export_apkg()`.
- The project depends on official Anki Rust code through the forked submodule at `externals/anki`, currently pointing at fork tag `markdown-to-anki-26.05-buildfix`, based on Anki release tag `26.05`, using `externals/anki/rslib` as a path dependency.
- `tokio` is included with `io-util` because Anki's crate needs that feature through Cargo feature unification.

The first Pandoc-backed version intentionally uses the stock Anki `Basic` note type. Keep APKG generation separated from Pandoc parsing so the official Anki export path remains easy to test independently.

## Development Direction

Planned next steps:

1. Broaden Pandoc block/inline HTML rendering as needed.
2. Improve GUID mapping conventions for Markdown blocks.
3. Add media extraction/import support.

## Verification

Before handing off changes, run:

```sh
nix shell nixpkgs#protobuf -c cargo check
cargo fmt --check
```

For APKG verification:

```sh
nix shell nixpkgs#protobuf -c cargo run -- demo --output /tmp/markdown-to-anki-demo.apkg
python -m zipfile -l /tmp/markdown-to-anki-demo.apkg
```

Expected package entries include `meta`, a collection file such as `collection.anki21b`, a compatibility `collection.anki2`, and `media`.
