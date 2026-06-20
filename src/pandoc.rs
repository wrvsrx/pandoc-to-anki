use anyhow::{anyhow, Context, Result};
use pandoc_ast::{Attr, Block, Format, Inline, MathType, Pandoc};

use crate::export::NoteInput;

const ANKI_CLASS: &str = "anki";

pub fn notes_from_json(input: &str) -> Result<Vec<NoteInput>> {
    let document: Pandoc =
        serde_json::from_str(input).context("failed to parse Pandoc JSON AST")?;
    let notes = notes_from_blocks(&document.blocks);
    if notes.is_empty() {
        return Err(anyhow!("no ::: anki fenced div blocks found"));
    }
    Ok(notes)
}

fn notes_from_blocks(blocks: &[Block]) -> Vec<NoteInput> {
    let mut notes = Vec::new();
    collect_notes(blocks, &mut notes);
    notes
}

fn collect_notes(blocks: &[Block], notes: &mut Vec<NoteInput>) {
    for block in blocks {
        match block {
            Block::Div(attr, children) if has_class(attr, ANKI_CLASS) => {
                if let Some(note) = note_from_anki_div(attr, children) {
                    notes.push(note);
                }
            }
            Block::Div(_, children) | Block::BlockQuote(children) => collect_notes(children, notes),
            _ => {}
        }
    }
}

fn note_from_anki_div(attr: &Attr, blocks: &[Block]) -> Option<NoteInput> {
    let (front, back) = blocks.split_first()?;
    let guid = note_guid(attr)?;
    Some(NoteInput {
        guid,
        front: render_block(front),
        back: render_blocks(back),
    })
}

fn has_class((_, classes, _): &Attr, class: &str) -> bool {
    classes.iter().any(|candidate| candidate == class)
}

fn note_guid((id, _, _): &Attr) -> Option<String> {
    (!id.is_empty()).then(|| id.clone())
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

        let notes = notes_from_json(input).unwrap();

        assert_eq!(notes.len(), 1);
        assert_eq!(notes[0].guid, "card-1");
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

        let notes = notes_from_json(input).unwrap();

        assert_eq!(notes.len(), 1);
        assert_eq!(notes[0].guid, "card-2");
    }
}
