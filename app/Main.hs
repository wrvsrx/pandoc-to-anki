{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NoFieldSelectors #-}

module Main (main) where

import AddWords (addWordsFromStdin)
import Cli (MarkdownToAnkiOpt (..), optParserIO)
import Data.ByteString.Char8 qualified as B
import Data.Default (def)
import Data.Either (fromRight)
import Data.Text qualified as T
import Data.Text.IO qualified as T
import Lib
import Text.Pandoc (Pandoc, readJSON, runPure)
import TranslateWord (translateWordsIncrementally)

parsePandocContent :: T.Text -> Pandoc
parsePandocContent cnt = fromRight (error "can't parse json") (runPure (readJSON def cnt))

main :: IO ()
main = do
  opt <- optParserIO
  case opt of
    ToAnki -> T.getContents >>= (B.putStr . pandocToAnkiNotesJSON nameMap) . parsePandocContent
    ToRenderedAst -> T.getContents >>= (B.putStr . pandocToRenderedAstJSON nameMap) . parsePandocContent
    ToAstWithGUID -> T.getContents >>= (B.putStr . pandocToAstWithGUIDJSON nameMap) . parsePandocContent
    TranslateWord w t -> translateWordsIncrementally w t
    TranslatedWordToAnki -> addWordsFromStdin
