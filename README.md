# markdown-to-anki

Rust CLI for generating Anki packages from Pandoc JSON AST input.

The current implementation extracts `::: anki` fenced div blocks from a Pandoc AST and creates one Basic Anki note for each block.

The Anki Rust dependency is vendored as a git submodule at `externals/anki`, currently pointing at the fork tag `markdown-to-anki-26.05-buildfix`, based on Anki release tag `26.05`.

Initialize submodules before building:

```sh
git submodule update --init --recursive
```

`anki_proto` requires `protoc` at build time. The project dev shell provides it through `shell.nix`.

## Usage

Convert Markdown to Pandoc JSON and generate an APKG:

```sh
pandoc -f markdown -t json notes.md | cargo run -- apkg --output notes.apkg
```

Or read the AST from a file:

```sh
cargo run -- apkg --input notes.json --output notes.apkg
```

An input block like:

```markdown
::: anki
first block

following block 1

following block 2
:::
```

creates one note where the first Pandoc block is the front, and the remaining blocks are the back.

## Demo

To run the fixed demo exporter:

```sh
cargo run -- demo --output demo.apkg
```

This creates a fixed demo deck named `Markdown To Anki Demo`.
