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

main :: IO ()
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
  optParser =
    flag' ToAnki (long "anki" <> short 'a' <> help "render pandoc ast to anki json")
      <|> flag' ToRenderedAst (long "rendered" <> short 'r' <> help "render theorems in pandoc ast")
      <|> flag' ToAstWithGUID (long "guid" <> short 'g' <> help "attach theorems in pandoc ast with guid")
