{-# LANGUAGE ImportQualifiedPost #-}

module AddWords (addWordsFromStdin) where

import Anki (AnkiConnectAddress (..))
import Data.ByteString qualified as BL
import Words (addOrUpdateWord)

addWordsFromStdin :: IO ()
addWordsFromStdin = do
  cnt <- BL.getContents
  let
    address = AnkiConnectAddress{ip = "127.0.0.1", port = 8765}

  return ()
