module Cli (
  optParser,
  optParserIO,
  optToFunc,
) where

import Data.ByteString.Char8 qualified as B
import Data.Map qualified as M
import Data.Text qualified as T
import Lib
import Options.Applicative (Parser, command, customExecParser, hsubparser, idm, info, prefs, showHelpOnEmpty)
import Text.Pandoc

data MarkdownToAnkiOpt = ToAnki | ToRenderedAst | ToAstWithGUID

optToFunc :: MarkdownToAnkiOpt -> M.Map T.Text T.Text -> Pandoc -> B.ByteString
optToFunc ToAnki = pandocToAnkiNotesJSON
optToFunc ToRenderedAst = pandocToRenderedAstJSON
optToFunc ToAstWithGUID = pandocToAstWithGUIDJSON

optParser :: Parser MarkdownToAnkiOpt
optParser =
  hsubparser
    ( command "lock" (info (pure ToAstWithGUID) idm)
        <> command "anki" (info (pure ToAnki) idm)
        <> command "render" (info (pure ToRenderedAst) idm)
    )

optParserIO :: IO MarkdownToAnkiOpt
optParserIO = customExecParser (prefs showHelpOnEmpty) (info optParser idm)
