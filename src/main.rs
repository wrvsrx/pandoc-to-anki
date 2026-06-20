mod export;
mod pandoc;

use std::fs;
use std::io::{self, Read};
use std::path::PathBuf;

use anyhow::Result;
use clap::{Parser, Subcommand};

#[derive(Debug, Parser)]
#[command(author, version, about)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Generate an Anki package from a Pandoc JSON AST.
    Apkg {
        /// Pandoc JSON AST input path. Reads from stdin when omitted.
        #[arg(short, long)]
        input: Option<PathBuf>,

        /// Destination .apkg path.
        #[arg(short, long)]
        output: PathBuf,
    },

    /// Generate a fixed demo Anki package through Anki's official Rust exporter.
    Demo {
        /// Destination .apkg path.
        #[arg(short, long)]
        output: PathBuf,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Command::Apkg { input, output } => {
            let ast = read_input(input)?;
            let notes = pandoc::notes_from_json(&ast)?;
            export::write_apkg(output, "Markdown To Anki", &notes)
        }
        Command::Demo { output } => export::write_demo_apkg(output),
    }
}

fn read_input(input: Option<PathBuf>) -> Result<String> {
    match input {
        Some(path) => fs::read_to_string(path).map_err(Into::into),
        None => {
            let mut buffer = String::new();
            io::stdin().read_to_string(&mut buffer)?;
            Ok(buffer)
        }
    }
}
