{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NoFieldSelectors #-}

module Main (main) where

import Anki
import AnkiNote
import qualified Data.ByteString.Char8 as B
import Data.Default (def)
import Data.Either (fromRight)
import qualified Data.Map as M
import qualified Data.Text as T
import qualified Data.Text.IO as T
import Lib
import Options.Applicative (command, customExecParser, hsubparser, idm, info, prefs, showHelpOnEmpty)
import Text.Pandoc

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
  res <-
    ankiConnect
      (AnkiConnectAddress{ip = "127.0.0.1", port = 8765})
      ( UpdateNoteFieldParam
          { id = 1693366003448
          , note =
              BasicNote
                { front = "front"
                , back = "back"
                }
          }
      )
  print res
  return ()
