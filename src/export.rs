use std::path::Path;

use anki::collection::CollectionBuilder;
use anki::import_export::package::ExportAnkiPackageOptions;
use anyhow::{Context, Result};
use tempfile::Builder;

const DEMO_DECK: &str = "Markdown To Anki Demo";
const DEMO_GUID: &str = "markdown-to-anki-demo-note-v1";
const DEMO_FRONT: &str = "<p>Demo question</p>";
const DEMO_BACK: &str = "<p>Demo answer</p>";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NoteInput {
    pub guid: String,
    pub front: String,
    pub back: String,
}

pub fn write_demo_apkg(output: impl AsRef<Path>) -> Result<()> {
    write_apkg(
        output,
        DEMO_DECK,
        &[NoteInput {
            guid: DEMO_GUID.to_string(),
            front: DEMO_FRONT.to_string(),
            back: DEMO_BACK.to_string(),
        }],
    )
}

pub fn write_apkg(output: impl AsRef<Path>, deck_name: &str, notes: &[NoteInput]) -> Result<()> {
    let output = output.as_ref();
    let temp_dir = Builder::new()
        .prefix("markdown-to-anki-")
        .tempdir()
        .context("failed to create temporary collection directory")?;
    let collection_path = temp_dir.path().join("demo.anki2");

    let mut collection = CollectionBuilder::new(&collection_path)
        .build()
        .context("failed to create Anki collection")?;

    let deck = collection
        .get_or_create_normal_deck(deck_name)
        .context("failed to create deck")?;

    let notetype = collection
        .get_notetype_by_name("Basic")
        .context("failed to look up Basic note type")?
        .context("Basic note type is missing from the new collection")?;

    for input in notes {
        let mut note = notetype.new_note();
        note.guid = input.guid.clone();
        note.tags = vec!["markdown-to-anki".to_string()];
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
