mod config;
mod export;
mod pandoc;

use std::path::PathBuf;

use anyhow::Result;
use clap::Parser;

#[derive(Debug, Parser)]
#[command(author, version, about)]
struct Cli {
    /// Config JSON path.
    #[arg(short, long, default_value = "config.json")]
    config: PathBuf,

    /// Destination .apkg path.
    #[arg(short, long)]
    output: PathBuf,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    let config = config::Config::from_path(cli.config)?;
    let notes = config.load_notes()?;
    export::write_apkg(cli.output, &config.deck, &notes)
}
