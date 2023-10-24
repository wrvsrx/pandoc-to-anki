module Cli (
  MarkdownToAnkiOpt (..),
  optParser,
  optParserIO,
) where

import Options.Applicative (
  Parser,
  command,
  customExecParser,
  hsubparser,
  idm,
  info,
  metavar,
  prefs,
  showHelpOnEmpty,
  strArgument,
 )

data MarkdownToAnkiOpt
  = ToAnki
  | ToRenderedAst
  | ToAstWithGUID
  | TranslateWord FilePath FilePath
  | TranslatedWordToAnki

optParser :: Parser MarkdownToAnkiOpt
optParser =
  hsubparser
    ( command "lock" (info (pure ToAstWithGUID) idm)
        <> command "anki" (info (pure ToAnki) idm)
        <> command "render" (info (pure ToRenderedAst) idm)
        <> command "words-to-anki" (info (pure TranslatedWordToAnki) idm)
        <> command
          "translate"
          ( info
              ( TranslateWord
                  <$> strArgument (metavar "words file")
                  <*> strArgument (metavar "translated file")
              )
              idm
          )
    )

optParserIO :: IO MarkdownToAnkiOpt
optParserIO = customExecParser (prefs showHelpOnEmpty) (info optParser idm)
