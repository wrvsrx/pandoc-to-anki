use anyhow::{anyhow, Context, Result};
use pandoc_ast::{Attr, Block, Caption, Cell, Format, Inline, MathType, Pandoc, Row};

use crate::export::NoteInput;

const ANKI_CLASS: &str = "anki";

pub fn notes_from_json(input: &str, namespace: &str) -> Result<Vec<NoteInput>> {
    let document: Pandoc =
        serde_json::from_str(input).context("failed to parse Pandoc JSON AST")?;
    let notes = notes_from_blocks(&document.blocks, namespace);
    if notes.is_empty() {
        return Err(anyhow!("no identified ::: anki fenced div blocks found"));
    }
    Ok(notes)
}

fn notes_from_blocks(blocks: &[Block], namespace: &str) -> Vec<NoteInput> {
    let mut notes = Vec::new();
    collect_notes(blocks, namespace, &mut notes);
    notes
}

fn collect_notes(blocks: &[Block], namespace: &str, notes: &mut Vec<NoteInput>) {
    for block in blocks {
        match block {
            Block::Div(attr, children) if has_class(attr, ANKI_CLASS) => {
                if let Some(note) = note_from_anki_div(attr, children, namespace) {
                    notes.push(note);
                }
            }
            _ => collect_nested_notes(block, namespace, notes),
        }
    }
}

fn collect_nested_notes(block: &Block, namespace: &str, notes: &mut Vec<NoteInput>) {
    match block {
        Block::BlockQuote(children) | Block::Figure(_, _, children) | Block::Div(_, children) => {
            collect_notes(children, namespace, notes)
        }
        Block::OrderedList(_, items) | Block::BulletList(items) => {
            for item in items {
                collect_notes(item, namespace, notes);
            }
        }
        Block::DefinitionList(items) => {
            for (_, definitions) in items {
                for definition in definitions {
                    collect_notes(definition, namespace, notes);
                }
            }
        }
        Block::Table(_, caption, _, head, bodies, foot) => {
            collect_caption_notes(caption, namespace, notes);
            for row in &head.1 {
                collect_row_notes(row, namespace, notes);
            }
            for (_, _, body_head, body_rows) in bodies {
                for row in body_head.iter().chain(body_rows) {
                    collect_row_notes(row, namespace, notes);
                }
            }
            for row in &foot.1 {
                collect_row_notes(row, namespace, notes);
            }
        }
        _ => {}
    }
}

fn collect_caption_notes((_, blocks): &Caption, namespace: &str, notes: &mut Vec<NoteInput>) {
    collect_notes(blocks, namespace, notes);
}

fn collect_row_notes((_, cells): &Row, namespace: &str, notes: &mut Vec<NoteInput>) {
    for cell in cells {
        collect_cell_notes(cell, namespace, notes);
    }
}

fn collect_cell_notes((_, _, _, _, blocks): &Cell, namespace: &str, notes: &mut Vec<NoteInput>) {
    collect_notes(blocks, namespace, notes);
}

fn note_from_anki_div(attr: &Attr, blocks: &[Block], namespace: &str) -> Option<NoteInput> {
    let (front, back) = blocks.split_first()?;
    let guid = note_guid(attr, namespace)?;
    Some(NoteInput {
        guid,
        front: render_block(front),
        back: render_blocks(back),
    })
}

fn has_class((_, classes, _): &Attr, class: &str) -> bool {
    classes.iter().any(|candidate| candidate == class)
}

fn note_guid((id, _, _): &Attr, namespace: &str) -> Option<String> {
    (!id.is_empty()).then(|| format!("{namespace}#{id}"))
}

fn render_blocks(blocks: &[Block]) -> String {
    blocks
        .iter()
        .map(render_block)
        .collect::<Vec<_>>()
        .join("\n")
}

fn render_block(block: &Block) -> String {
    match block {
        Block::Plain(inlines) | Block::Para(inlines) => {
            format!("<p>{}</p>", render_inlines(inlines))
        }
        Block::LineBlock(lines) => lines
            .iter()
            .map(|line| render_inlines(line))
            .collect::<Vec<_>>()
            .join("<br>\n"),
        Block::CodeBlock(_, code) => format!("<pre><code>{}</code></pre>", escape_html(code)),
        Block::RawBlock(format, raw) if is_html(format) => raw.clone(),
        Block::RawBlock(_, raw) => escape_html(raw),
        Block::BlockQuote(blocks) => format!("<blockquote>{}</blockquote>", render_blocks(blocks)),
        Block::OrderedList(_, items) => render_list("ol", items),
        Block::BulletList(items) => render_list("ul", items),
        Block::Header(level, _, inlines) => {
            let level = (*level).clamp(1, 6);
            format!("<h{level}>{}</h{level}>", render_inlines(inlines))
        }
        Block::HorizontalRule => "<hr>".to_string(),
        Block::Div(_, blocks) => render_blocks(blocks),
        Block::Null => String::new(),
        _ => format!("<p>{}</p>", escape_html(&format!("{block:?}"))),
    }
}

fn render_list(tag: &str, items: &[Vec<Block>]) -> String {
    let items = items
        .iter()
        .map(|item| format!("<li>{}</li>", render_blocks(item)))
        .collect::<Vec<_>>()
        .join("\n");
    format!("<{tag}>{items}</{tag}>")
}

fn render_inlines(inlines: &[Inline]) -> String {
    inlines
        .iter()
        .map(render_inline)
        .collect::<Vec<_>>()
        .join("")
}

fn render_inline(inline: &Inline) -> String {
    match inline {
        Inline::Str(text) => escape_html(text),
        Inline::Emph(inlines) => format!("<em>{}</em>", render_inlines(inlines)),
        Inline::Underline(inlines) => format!("<u>{}</u>", render_inlines(inlines)),
        Inline::Strong(inlines) => format!("<strong>{}</strong>", render_inlines(inlines)),
        Inline::Strikeout(inlines) => format!("<s>{}</s>", render_inlines(inlines)),
        Inline::Superscript(inlines) => format!("<sup>{}</sup>", render_inlines(inlines)),
        Inline::Subscript(inlines) => format!("<sub>{}</sub>", render_inlines(inlines)),
        Inline::SmallCaps(inlines) => render_inlines(inlines),
        Inline::Quoted(_, inlines) => format!("&ldquo;{}&rdquo;", render_inlines(inlines)),
        Inline::Cite(_, inlines) => render_inlines(inlines),
        Inline::Code(_, code) => format!("<code>{}</code>", escape_html(code)),
        Inline::Space => " ".to_string(),
        Inline::SoftBreak => "\n".to_string(),
        Inline::LineBreak => "<br>".to_string(),
        Inline::Math(math_type, math) => render_math(*math_type, math),
        Inline::RawInline(format, raw) if is_html(format) => raw.clone(),
        Inline::RawInline(_, raw) => escape_html(raw),
        Inline::Link(_, inlines, (url, title)) => format!(
            "<a href=\"{}\" title=\"{}\">{}</a>",
            escape_attr(url),
            escape_attr(title),
            render_inlines(inlines)
        ),
        Inline::Image(_, alt, (url, title)) => format!(
            "<img src=\"{}\" title=\"{}\" alt=\"{}\">",
            escape_attr(url),
            escape_attr(title),
            escape_attr(&plain_text(alt))
        ),
        Inline::Note(blocks) => render_blocks(blocks),
        Inline::Span(_, inlines) => render_inlines(inlines),
    }
}

fn render_math(math_type: MathType, math: &str) -> String {
    match math_type {
        MathType::DisplayMath => format!("\\[{}\\]", escape_html(math)),
        MathType::InlineMath => format!("\\({}\\)", escape_html(math)),
    }
}

fn plain_text(inlines: &[Inline]) -> String {
    inlines
        .iter()
        .map(|inline| match inline {
            Inline::Str(text) => text.clone(),
            Inline::Space | Inline::SoftBreak | Inline::LineBreak => " ".to_string(),
            other => render_inline(other),
        })
        .collect()
}

fn is_html(Format(format): &Format) -> bool {
    format.eq_ignore_ascii_case("html")
}

fn escape_html(input: &str) -> String {
    input
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
}

fn escape_attr(input: &str) -> String {
    escape_html(input).replace('"', "&quot;")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extracts_anki_div_as_front_and_back() {
        let input = r#"{
          "pandoc-api-version": [1, 23],
          "meta": {},
          "blocks": [
            {
              "t": "Div",
              "c": [
                ["card-1", ["anki"], []],
                [
                  {"t": "Para", "c": [{"t": "Str", "c": "first"}, {"t": "Space"}, {"t": "Str", "c": "block"}]},
                  {"t": "Para", "c": [{"t": "Str", "c": "following"}, {"t": "Space"}, {"t": "Str", "c": "block"}, {"t": "Space"}, {"t": "Str", "c": "1"}]},
                  {"t": "Para", "c": [{"t": "Str", "c": "following"}, {"t": "Space"}, {"t": "Str", "c": "block"}, {"t": "Space"}, {"t": "Str", "c": "2"}]}
                ]
              ]
            }
          ]
        }"#;

        let notes = notes_from_json(input, "test-entry").unwrap();

        assert_eq!(notes.len(), 1);
        assert_eq!(notes[0].guid, "test-entry#card-1");
        assert_eq!(notes[0].front, "<p>first block</p>");
        assert_eq!(
            notes[0].back,
            "<p>following block 1</p>\n<p>following block 2</p>"
        );
    }

    #[test]
    fn skips_anki_div_without_id() {
        let input = r#"{
          "pandoc-api-version": [1, 23],
          "meta": {},
          "blocks": [
            {
              "t": "Div",
              "c": [
                ["", ["anki"], []],
                [
                  {"t": "Para", "c": [{"t": "Str", "c": "front"}]},
                  {"t": "Para", "c": [{"t": "Str", "c": "back"}]}
                ]
              ]
            },
            {
              "t": "Div",
              "c": [
                ["card-2", ["anki"], []],
                [
                  {"t": "Para", "c": [{"t": "Str", "c": "front"}]},
                  {"t": "Para", "c": [{"t": "Str", "c": "back"}]}
                ]
              ]
            }
          ]
        }"#;

        let notes = notes_from_json(input, "test-entry").unwrap();

        assert_eq!(notes.len(), 1);
        assert_eq!(notes[0].guid, "test-entry#card-2");
    }

    #[test]
    fn extracts_anki_div_inside_list_item() {
        let input = r#"{
          "pandoc-api-version": [1, 23],
          "meta": {},
          "blocks": [
            {
              "t": "BulletList",
              "c": [
                [
                  {
                    "t": "Div",
                    "c": [
                      ["card-1", ["anki"], []],
                      [
                        {"t": "Para", "c": [{"t": "Str", "c": "front"}]},
                        {"t": "Para", "c": [{"t": "Str", "c": "back"}]}
                      ]
                    ]
                  }
                ]
              ]
            }
          ]
        }"#;

        let notes = notes_from_json(input, "test-entry").unwrap();

        assert_eq!(notes.len(), 1);
        assert_eq!(notes[0].guid, "test-entry#card-1");
        assert_eq!(notes[0].front, "<p>front</p>");
        assert_eq!(notes[0].back, "<p>back</p>");
    }
}
