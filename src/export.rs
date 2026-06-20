use std::path::Path;

use anki::collection::CollectionBuilder;
use anki::import_export::package::ExportAnkiPackageOptions;
use anki::notetype::{
    CardTemplate, CardTemplateConfig, NoteField, NoteFieldConfig, Notetype, NotetypeConfig,
    NotetypeId, NotetypeKind,
};
use anki::prelude::{TimestampSecs, Usn};
use anyhow::{Context, Result};
use tempfile::Builder;

const BASIC_MODEL_ID: NotetypeId = NotetypeId(1_781_974_503_754);
const BASIC_MODEL_NAME: &str = "Basic+++";
const FRONT_FIELD_ID: i64 = 1_781_974_503_755;
const BACK_FIELD_ID: i64 = 1_781_974_503_756;
const CARD_TEMPLATE_ID: i64 = 1_781_974_503_757;
const DEFAULT_CSS: &str = include_str!("../externals/anki/rslib/src/notetype/styling.css");
const DEFAULT_LATEX_HEADER: &str = include_str!("../externals/anki/rslib/src/notetype/header.tex");
const DEFAULT_LATEX_FOOTER: &str = "\\end{document}";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NoteInput {
    pub guid: String,
    pub front: String,
    pub back: String,
}

pub fn write_apkg(output: impl AsRef<Path>, deck_name: &str, notes: &[NoteInput]) -> Result<()> {
    let output = output.as_ref();
    let temp_dir = Builder::new()
        .prefix("pandoc-to-anki-")
        .tempdir()
        .context("failed to create temporary collection directory")?;
    let collection_path = temp_dir.path().join("demo.anki2");

    let mut collection = CollectionBuilder::new(&collection_path)
        .build()
        .context("failed to create Anki collection")?;

    let deck = collection
        .get_or_create_normal_deck(deck_name)
        .context("failed to create deck")?;

    let mut stable_basic = stable_basic_notetype();
    collection
        .add_or_update_notetype_with_existing_id(&mut stable_basic, true)
        .context("failed to add stable Basic note type")?;
    for notetype in collection
        .get_all_notetypes()
        .context("failed to list note types")?
    {
        if notetype.id != BASIC_MODEL_ID {
            collection
                .remove_notetype(notetype.id)
                .with_context(|| format!("failed to remove unused note type {}", notetype.name))?;
        }
    }
    let notetype = collection
        .get_notetype(BASIC_MODEL_ID)
        .context("failed to look up stable Basic note type")?
        .context("stable Basic note type is missing from the new collection")?;

    for input in notes {
        let mut note = notetype.new_note();
        note.guid = input.guid.clone();
        note.tags = vec!["pandoc-to-anki".to_string()];
        note.set_field(0, &input.front)
            .context("failed to set front field")?;
        note.set_field(1, &input.back)
            .context("failed to set back field")?;

        collection
            .add_note(&mut note, deck.id)
            .context("failed to add note")?;
    }

    collection
        .export_apkg(
            output,
            ExportAnkiPackageOptions {
                with_scheduling: false,
                with_deck_configs: true,
                with_media: false,
                legacy: false,
            },
            "",
            None,
        )
        .context("failed to export Anki package")?;

    Ok(())
}

fn stable_basic_notetype() -> Notetype {
    Notetype {
        id: BASIC_MODEL_ID,
        name: BASIC_MODEL_NAME.to_string(),
        mtime_secs: TimestampSecs(0),
        usn: Usn(0),
        fields: vec![
            stable_field(0, "Front", FRONT_FIELD_ID),
            stable_field(1, "Back", BACK_FIELD_ID),
        ],
        templates: vec![CardTemplate {
            ord: Some(0),
            mtime_secs: TimestampSecs(0),
            usn: Usn(0),
            name: "Card 1".to_string(),
            config: CardTemplateConfig {
                id: Some(CARD_TEMPLATE_ID),
                q_format: "{{Front}}".to_string(),
                a_format: "{{FrontSide}}\n\n<hr id=answer>\n\n{{Back}}".to_string(),
                q_format_browser: String::new(),
                a_format_browser: String::new(),
                target_deck_id: 0,
                browser_font_name: String::new(),
                browser_font_size: 0,
                other: vec![],
            },
        }],
        config: NotetypeConfig {
            kind: NotetypeKind::Normal as i32,
            sort_field_idx: 0,
            css: DEFAULT_CSS.to_string(),
            latex_pre: DEFAULT_LATEX_HEADER.to_string(),
            latex_post: DEFAULT_LATEX_FOOTER.to_string(),
            latex_svg: false,
            reqs: vec![],
            original_stock_kind: 1,
            target_deck_id_unused: 0,
            original_id: None,
            other: vec![],
        },
    }
}

fn stable_field(ord: u32, name: &str, id: i64) -> NoteField {
    NoteField {
        ord: Some(ord),
        name: name.to_string(),
        config: NoteFieldConfig {
            id: Some(id),
            sticky: false,
            rtl: false,
            plain_text: false,
            font_name: "Arial".to_string(),
            font_size: 20,
            description: String::new(),
            collapsed: false,
            exclude_from_search: false,
            tag: None,
            prevent_deletion: false,
            other: vec![],
        },
    }
}
