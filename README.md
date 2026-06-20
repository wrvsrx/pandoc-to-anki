# pandoc-to-anki

Rust CLI for generating Anki packages from configured Pandoc JSON AST inputs.

The current implementation reads `config.json`, extracts identified `anki` fenced div blocks from each configured Pandoc AST, and creates one Basic Anki note for each block.

The Anki Rust dependency is vendored as a git submodule at `externals/anki`, currently pointing at the fork tag `markdown-to-anki-26.05-buildfix`, based on Anki release tag `26.05`.

Initialize submodules before building:

```sh
git submodule update --init --recursive
```

`anki_proto` requires `protoc` at build time. The project dev shell provides it through `shell.nix`.

Build the Nix package with submodules enabled:

```sh
nix build '.?submodules=1'
```

The packaged CLI is available at:

```sh
./result/bin/pandoc-to-anki --help
```

## Usage

Create a config:

```json
{
  "deck": "Pandoc To Anki",
  "entries": [
    {
      "namespace": "rust-lifetimes",
      "path": "notes/rust/lifetimes.md",
      "command": "pandoc -f markdown -t json"
    }
  ]
}
```

Generate an APKG:

```sh
cargo run -- --config config.json --output notes.apkg
```

If `command` is omitted, `path` is read directly as a Pandoc JSON AST file.
If `command` is present, the file at `path` is sent to the command's stdin, and the command must print Pandoc JSON to stdout.
Relative paths are resolved from the config file's directory. Commands are also run from the config file's directory.

An input block like:

```markdown
::: {#card-1 .anki}
first block

following block 1

following block 2
:::
```

creates one note where `rust-lifetimes#card-1` is the persistent Anki note `guid`, the first Pandoc block is the front, and the remaining blocks are the back. `anki` blocks without an id are ignored.
