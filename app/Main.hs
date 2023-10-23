{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NoFieldSelectors #-}

module Main (main) where

import Anki
import AnkiNote
import Control.Monad.Trans.Except (runExceptT)
import Data.ByteString.Char8 qualified as B
import Data.Default (def)
import Data.Either (fromRight)
import qualified Data.Map as M
import qualified Data.Text as T
import qualified Data.Text.IO as T
import Lib
import Options.Applicative (command, customExecParser, hsubparser, idm, info, prefs, showHelpOnEmpty)
import Text.Pandoc
import AddWords (addWordsFromStdin)

data MarkdownToAnkiOpt = ToAnki | ToRenderedAst | ToAstWithGUID

optToFunc :: MarkdownToAnkiOpt -> M.Map T.Text T.Text -> Pandoc -> B.ByteString
optToFunc ToAnki = pandocToAnkiNotesJSON
optToFunc ToRenderedAst = pandocToRenderedAstJSON
optToFunc ToAstWithGUID = pandocToAstWithGUIDJSON

main :: IO ()
main = do
  --  opt <- optParserIO
  --  cnt <- T.getContents
  --  let p = fromRight (error "can't parse json") (runPure (readJSON def cnt))
  --      out = optToFunc opt nameMap p
  --  B.putStrLn out
  -- where
  --  optParserIO = customExecParser (prefs showHelpOnEmpty) (info optParser idm)
  --  optParser =
  --    hsubparser
  --      ( command "lock" (info (pure ToAstWithGUID) idm)
  --          <> command "anki" (info (pure ToAnki) idm)
  --          <> command "render" (info (pure ToRenderedAst) idm)
  --      )
  
  addWordsFromStdin
