module Main (main) where

import qualified Data.ByteString.Char8 as B
import Data.Either (fromRight)
import qualified Data.Map as M
import qualified Data.Text as T
import qualified Data.Text.IO as T
import Lib
import Options.Applicative
import Text.Pandoc

data MarkdownToAnkiOpt = ToAnki | ToRenderedAst | ToAstWithGUID

optToFunc :: MarkdownToAnkiOpt -> M.Map T.Text T.Text -> Pandoc -> B.ByteString
optToFunc ToAnki = pandocToAnkiNotesJSON
optToFunc ToRenderedAst = pandocToRenderedAstJSON
optToFunc ToAstWithGUID = pandocToAstWithGUIDJSON

toAnkiOpt = flag' ToAnki (long "anki" <> short 'a' <> help "render pandoc ast to anki json")

toRenderedJSONOpt = flag' ToRenderedAst (long "rendered" <> short 'r' <> help "render theorems in pandoc ast")

toAstWithGUID = flag' ToAstWithGUID (long "guid" <> short 'g' <> help "attach theorems in pandoc ast with guid")

optParser = toAnkiOpt <|> toRenderedJSONOpt <|> toAstWithGUID

main = do
  opt <- execParser optParserWithHelp
  cnt <- T.getContents
  let p = fromRight (error "can't parse json") (runPure (readJSON def cnt))
      out = optToFunc opt nameMap p
  B.putStrLn out
 where
  optParserWithHelp =
    info
      (optParser <**> helper)
      fullDesc
