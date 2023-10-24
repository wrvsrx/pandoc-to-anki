{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NoFieldSelectors #-}

module Main (main) where

import Cli (optParserIO, optToFunc)
import Data.ByteString.Char8 qualified as B
import Data.Default (def)
import Data.Either (fromRight)
import Data.Text.IO qualified as T
import Lib
import Text.Pandoc (readJSON, runPure)

main :: IO ()
main = do
  opt <- optParserIO
  cnt <- T.getContents
  let p = fromRight (error "can't parse json") (runPure (readJSON def cnt))
      out = optToFunc opt nameMap p
  B.putStrLn out
