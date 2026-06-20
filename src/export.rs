use std::path::Path;

use anki::collection::CollectionBuilder;
use anki::import_export::package::ExportAnkiPackageOptions;
use anki::notetype::{
    CardTemplate, CardTemplateConfig, NoteField, NoteFieldConfig, Notetype, NotetypeConfig,
    NotetypeId, NotetypeKind,
};
use anki::prelude::{TimestampSecs, Usn};
use anyhow::{bail, Context, Result};
use serde::Deserialize;
use tempfile::Builder;

const BASIC_MODEL_JSON: &str = include_str!("../models/basic-v1.json");
const DEFAULT_CSS: &str = include_str!("../externals/anki/rslib/src/notetype/styling.css");
const DEFAULT_LATEX_HEADER: &str = include_str!("../externals/anki/rslib/src/notetype/header.tex");
const DEFAULT_LATEX_FOOTER: &str = "\\end{document}";

#[derive(Debug, Deserialize)]
struct ModelSchema {
    id: i64,
    name: String,
    fields: Vec<FieldSchema>,
    templates: Vec<TemplateSchema>,
}

#[derive(Debug, Deserialize)]
struct FieldSchema {
    ord: u32,
    name: String,
    id: i64,
}

#[derive(Debug, Deserialize)]
struct TemplateSchema {
    ord: u32,
    name: String,
    id: i64,
    q_format: String,
    a_format: String,
}

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

    let mut stable_basic = stable_basic_notetype()?;
    let stable_model_id = stable_basic.id;
    collection
        .add_or_update_notetype_with_existing_id(&mut stable_basic, true)
        .context("failed to add stable Basic note type")?;
    for notetype in collection
        .get_all_notetypes()
        .context("failed to list note types")?
    {
        if notetype.id != stable_model_id {
            collection
                .remove_notetype(notetype.id)
                .with_context(|| format!("failed to remove unused note type {}", notetype.name))?;
        }
    }
    let notetype = collection
        .get_notetype(stable_model_id)
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

fn stable_basic_notetype() -> Result<Notetype> {
    let schema: ModelSchema =
        serde_json::from_str(BASIC_MODEL_JSON).context("failed to parse basic model schema")?;
    validate_basic_model_schema(&schema)?;

    Ok(Notetype {
        id: NotetypeId(schema.id),
        name: schema.name,
        mtime_secs: TimestampSecs(0),
        usn: Usn(0),
        fields: schema
            .fields
            .into_iter()
            .map(stable_field)
            .collect::<Vec<_>>(),
        templates: schema
            .templates
            .into_iter()
            .map(stable_template)
            .collect::<Vec<_>>(),
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
    })
}

fn validate_basic_model_schema(schema: &ModelSchema) -> Result<()> {
    if schema.fields.len() != 2 {
        bail!(
            "basic model schema must define exactly 2 fields for the current renderer, got {}",
            schema.fields.len()
        );
    }
    if schema.fields[0].ord != 0 || schema.fields[0].name != "Front" {
        bail!("basic model field 0 must be named Front");
    }
    if schema.fields[1].ord != 1 || schema.fields[1].name != "Back" {
        bail!("basic model field 1 must be named Back");
    }
    if schema.templates.len() != 1 {
        bail!(
            "basic model schema must define exactly 1 template, got {}",
            schema.templates.len()
        );
    }
    if schema.templates[0].ord != 0 {
        bail!("basic model template must have ord 0");
    }
    Ok(())
}

fn stable_field(field: FieldSchema) -> NoteField {
    NoteField {
        ord: Some(field.ord),
        name: field.name,
        config: NoteFieldConfig {
            id: Some(field.id),
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

fn stable_template(template: TemplateSchema) -> CardTemplate {
    CardTemplate {
        ord: Some(template.ord),
        mtime_secs: TimestampSecs(0),
        usn: Usn(0),
        name: template.name,
        config: CardTemplateConfig {
            id: Some(template.id),
            q_format: template.q_format,
            a_format: template.a_format,
            q_format_browser: String::new(),
            a_format_browser: String::new(),
            target_deck_id: 0,
            browser_font_name: String::new(),
            browser_font_size: 0,
            other: vec![],
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn loads_basic_model_schema() {
        let notetype = stable_basic_notetype().unwrap();

        assert_eq!(notetype.id, NotetypeId(1_781_974_503_754));
        assert_eq!(notetype.name, "Pandoc Basic");
        assert_eq!(notetype.fields.len(), 2);
        assert_eq!(notetype.fields[0].name, "Front");
        assert_eq!(notetype.fields[0].config.id, Some(1_781_974_503_755));
        assert_eq!(notetype.fields[1].name, "Back");
        assert_eq!(notetype.fields[1].config.id, Some(1_781_974_503_756));
        assert_eq!(notetype.templates.len(), 1);
        assert_eq!(notetype.templates[0].name, "Forward");
        assert_eq!(notetype.templates[0].config.id, Some(1_781_974_503_757));
    }
}
