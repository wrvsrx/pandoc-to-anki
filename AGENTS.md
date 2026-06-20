# AGENTS.md

## Project State

This repository is being rebuilt from scratch as a Rust CLI. The legacy Haskell/Cabal/Nix implementation was intentionally removed and should not be restored unless explicitly requested.

The current milestone is a minimal proof that the project can create an `.apkg` through Anki's official Rust collection exporter. It does not parse Markdown or Pandoc input yet.

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
nix shell nixpkgs#protobuf -c cargo run -- apkg --output /tmp/markdown-to-anki-demo.apkg
```

Generated `.apkg` files are ignored by git.

## Current Architecture

- `src/main.rs` defines the CLI.
- `src/export.rs` creates a temporary Anki collection, adds a fixed `Basic` note, and calls `Collection::export_apkg()`.
- The project depends on official Anki Rust code through the forked submodule at `externals/anki`, currently based on release tag `26.05`, using `externals/anki/rslib` as a path dependency.
- `tokio` is included with `io-util` because Anki's crate needs that feature through Cargo feature unification.

The first version intentionally uses the stock Anki `Basic` note type. Do not add JSON or Markdown input handling to this milestone unless requested.

## Development Direction

Planned next step:

1. Read Pandoc JSON AST from stdin or a file.
2. Extract supported fenced div blocks.
3. Convert each block into an Anki note.
4. Map each Markdown block GUID to the Anki note `guid`.
5. Continue using official `Collection::export_apkg()` for package generation.

Keep APKG generation separated from Pandoc parsing so the official Anki export path remains easy to test independently.

## Verification

Before handing off changes, run:

```sh
nix shell nixpkgs#protobuf -c cargo check
nix shell nixpkgs#rustfmt -c cargo fmt --check
```

For APKG verification:

```sh
nix shell nixpkgs#protobuf -c cargo run -- apkg --output /tmp/markdown-to-anki-demo.apkg
python -m zipfile -l /tmp/markdown-to-anki-demo.apkg
```

Expected package entries include `meta`, a collection file such as `collection.anki21b`, a compatibility `collection.anki2`, and `media`.
