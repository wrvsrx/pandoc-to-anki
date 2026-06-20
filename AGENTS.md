# AGENTS.md

## Project State

This repository is being rebuilt from scratch as a Rust CLI. The legacy Haskell/Cabal/Nix implementation was intentionally removed and should not be restored unless explicitly requested.

The current milestone reads `config.json`, loads one or more Pandoc JSON AST inputs, extracts supported identified `anki` fenced div blocks, and exports an `.apkg` through Anki's official Rust collection exporter.

## Build Requirements

The official Anki Rust dependency builds protobuf code and requires `protoc`; the project dev shell provides it through `shell.nix`.

Initialize the forked Anki submodule first:

```sh
git submodule update --init --recursive
```

Use:

```sh
cargo check
```

To generate an APKG from config:

```sh
cargo run -- --config config.json --output /tmp/notes.apkg
```

Generated `.apkg` files are ignored by git.

## Current Architecture

- `src/main.rs` defines the CLI.
- `src/config.rs` reads config JSON with a required top-level `deck` and entries with required `namespace` and `path`, plus optional `command`.
- `src/pandoc.rs` extracts `Div` blocks with class `anki` and a non-empty id from Pandoc JSON, uses `namespace#id` as the Anki note `guid`, and renders each note's front/back HTML.
- `src/export.rs` creates a temporary Anki collection, adds `Basic` notes, and calls `Collection::export_apkg()`.
- The project depends on official Anki Rust code through the forked submodule at `externals/anki`, currently pointing at fork tag `markdown-to-anki-26.05-buildfix`, based on Anki release tag `26.05`, using `externals/anki/rslib` as a path dependency.
- `tokio` is included with `io-util` because Anki's crate needs that feature through Cargo feature unification.

The first Pandoc-backed version intentionally uses the stock Anki `Basic` note type. Keep APKG generation separated from Pandoc parsing so the official Anki export path remains easy to test independently.

Config rules:

1. `deck` is required and applies to all generated notes.
2. Each entry must define `namespace` and `path`.
3. Relative paths are resolved from the config file's directory.
4. If `command` is omitted, `path` is read directly as Pandoc JSON.
5. If `command` is present, it is run with `sh -c` from the config file's directory and must print Pandoc JSON to stdout.
6. Anki note `guid` is `namespace#block_id`; duplicate GUIDs are errors.
7. `anki` blocks without ids are skipped.

## Development Direction

Planned next steps:

1. Broaden Pandoc block/inline HTML rendering as needed.
2. Improve diagnostics for skipped `anki` blocks without ids.
3. Add media extraction/import support.

## Verification

Before handing off changes, run:

```sh
cargo check
cargo fmt --check
```

For APKG verification:

```sh
cargo run -- --config testdata/config-pandoc.json --output /tmp/markdown-to-anki.apkg
python -m zipfile -l /tmp/markdown-to-anki.apkg
```

Expected package entries include `meta`, a collection file such as `collection.anki21b`, a compatibility `collection.anki2`, and `media`.
