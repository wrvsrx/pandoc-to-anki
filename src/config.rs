use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{anyhow, bail, Context, Result};
use serde::Deserialize;

use crate::export::NoteInput;
use crate::pandoc;

#[derive(Debug, Deserialize)]
pub struct Config {
    pub deck: String,
    pub entries: Vec<Entry>,
    #[serde(skip)]
    base_dir: PathBuf,
}

#[derive(Debug, Deserialize)]
pub struct Entry {
    pub namespace: String,
    pub path: PathBuf,
    pub command: Option<String>,
}

impl Config {
    pub fn from_path(path: impl AsRef<Path>) -> Result<Self> {
        let path = path.as_ref();
        let contents = fs::read_to_string(path)
            .with_context(|| format!("failed to read config {}", path.display()))?;
        let mut config: Config = serde_json::from_str(&contents)
            .with_context(|| format!("failed to parse config {}", path.display()))?;
        config.base_dir = path
            .parent()
            .unwrap_or_else(|| Path::new("."))
            .to_path_buf();
        config.validate()?;
        Ok(config)
    }

    pub fn load_notes(&self) -> Result<Vec<NoteInput>> {
        let mut notes = Vec::new();
        for entry in &self.entries {
            let ast = entry.load_pandoc_ast(&self.base_dir)?;
            notes.extend(
                pandoc::notes_from_json(&ast, &entry.namespace)
                    .with_context(|| format!("failed to convert entry {}", entry.namespace))?,
            );
        }
        reject_duplicate_guids(&notes)?;
        if notes.is_empty() {
            bail!("no notes found in config entries");
        }
        Ok(notes)
    }

    fn validate(&self) -> Result<()> {
        if self.deck.trim().is_empty() {
            bail!("config deck must not be empty");
        }
        if self.entries.is_empty() {
            bail!("config entries must not be empty");
        }
        for entry in &self.entries {
            entry.validate()?;
        }
        Ok(())
    }
}

impl Entry {
    fn validate(&self) -> Result<()> {
        if self.namespace.trim().is_empty() {
            bail!("entry namespace must not be empty");
        }
        if self.path.as_os_str().is_empty() {
            bail!("entry path must not be empty");
        }
        Ok(())
    }

    fn load_pandoc_ast(&self, base_dir: &Path) -> Result<String> {
        match &self.command {
            Some(command) => run_command(command, base_dir),
            None => {
                let path = base_dir.join(&self.path);
                fs::read_to_string(&path)
                    .with_context(|| format!("failed to read {}", path.display()))
            }
        }
    }
}

fn run_command(command: &str, base_dir: &Path) -> Result<String> {
    let output = Command::new("sh")
        .arg("-c")
        .arg(command)
        .current_dir(base_dir)
        .output()
        .with_context(|| format!("failed to run command `{command}`"))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow!(
            "command `{command}` failed with status {}: {}",
            output.status,
            stderr.trim()
        ));
    }

    String::from_utf8(output.stdout)
        .with_context(|| format!("command `{command}` did not produce UTF-8 output"))
}

fn reject_duplicate_guids(notes: &[NoteInput]) -> Result<()> {
    let mut seen = HashSet::new();
    for note in notes {
        if !seen.insert(&note.guid) {
            bail!("duplicate note guid `{}`", note.guid);
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use tempfile::tempdir;

    use super::*;

    #[test]
    fn loads_notes_from_pandoc_json_file() {
        let dir = tempdir().unwrap();
        let ast_path = dir.path().join("notes.json");
        fs::write(&ast_path, pandoc_json("card-1")).unwrap();
        let config = Config {
            deck: "Deck".to_string(),
            entries: vec![Entry {
                namespace: "entry".to_string(),
                path: PathBuf::from("notes.json"),
                command: None,
            }],
            base_dir: dir.path().to_path_buf(),
        };

        let notes = config.load_notes().unwrap();

        assert_eq!(notes.len(), 1);
        assert_eq!(notes[0].guid, "entry#card-1");
    }

    #[test]
    fn rejects_duplicate_guids() {
        let dir = tempdir().unwrap();
        let first = dir.path().join("first.json");
        let second = dir.path().join("second.json");
        fs::write(&first, pandoc_json("card-1")).unwrap();
        fs::write(&second, pandoc_json("card-1")).unwrap();
        let config = Config {
            deck: "Deck".to_string(),
            entries: vec![
                Entry {
                    namespace: "entry".to_string(),
                    path: PathBuf::from("first.json"),
                    command: None,
                },
                Entry {
                    namespace: "entry".to_string(),
                    path: PathBuf::from("second.json"),
                    command: None,
                },
            ],
            base_dir: dir.path().to_path_buf(),
        };

        let error = config.load_notes().unwrap_err();

        assert!(error.to_string().contains("duplicate note guid"));
    }

    fn pandoc_json(id: &str) -> String {
        format!(
            r#"{{
          "pandoc-api-version": [1, 23],
          "meta": {{}},
          "blocks": [
            {{
              "t": "Div",
              "c": [
                ["{id}", ["anki"], []],
                [
                  {{"t": "Para", "c": [{{"t": "Str", "c": "front"}}]}},
                  {{"t": "Para", "c": [{{"t": "Str", "c": "back"}}]}}
                ]
              ]
            }}
          ]
        }}"#
        )
    }
}
