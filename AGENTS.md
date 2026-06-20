# AGENTS.md

## Project State

This repository is being rebuilt from scratch as a Rust CLI. The legacy Haskell/Cabal/Nix implementation was intentionally removed and should not be restored unless explicitly requested.

The current milestone reads `config.json`, loads one or more Pandoc JSON AST inputs, extracts supported identified `anki` fenced div blocks, and exports an `.apkg` through Anki's official Rust collection exporter.

## Build Requirements

The official Anki Rust dependency builds protobuf code and requires `protoc`.

Initialize the forked Anki submodule first:

```sh
git submodule update --init --recursive
```

Use:

```sh
cargo check
```

Build the Nix package with submodules enabled so the Anki submodule is included in the flake source:

```sh
nix build '.?submodules=1'
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
5. If `command` is present, the file at `path` is sent to the command's stdin; it is run with `sh -c` from the config file's directory and must print Pandoc JSON to stdout.
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
nix build '.?submodules=1'
```

For APKG verification:

```sh
cargo run -- --config testdata/config-pandoc.json --output /tmp/pandoc-to-anki.apkg
python -m zipfile -l /tmp/pandoc-to-anki.apkg
```

Expected package entries include `meta`, a collection file such as `collection.anki21b`, a compatibility `collection.anki2`, and `media`.

## Release Workflow

When asked to release a version, use this sequence:

1. Bump `version` in `Cargo.toml` from the current `*-dev` version to the release version, such as `0.1.0-dev` to `0.1.0`. The Nix package version is read from `Cargo.toml`.
2. Do not edit `Cargo.lock` by hand; run a Cargo command such as `cargo check` so Cargo updates the root package version in the lockfile.
3. Run the relevant verification commands from the section above, including `nix build '.?submodules=1'` when packaging changes are involved.
4. Commit the release version with a message like `chore: release 0.1.0`.
5. Create a git tag with the exact release version, such as `git tag 0.1.0`, pointing at the release commit.
6. Bump `Cargo.toml` to the next development version, such as `0.2.0-dev`.
7. Run `cargo check` again so Cargo updates `Cargo.lock`.
8. Commit the development-version bump with a message like `chore: bump version to 0.2.0-dev`.
