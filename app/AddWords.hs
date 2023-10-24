{-# LANGUAGE ImportQualifiedPost #-}

module AddWords (addWordsFromStdin) where

import Anki (AnkiConnectAddress (..))
import Control.Monad.Trans.Except (runExceptT)
import Data.Aeson qualified as A
import Data.ByteString.Lazy qualified as BL
import Data.Functor ((<&>))
import Data.Maybe (fromJust)
import Words (TranslatedWord (..), addOrUpdateWord)

addWordsFromStdin :: IO ()
addWordsFromStdin = do
  translatedWords :: [TranslatedWord] <- BL.getContents <&> A.decode <&> fromJust
  let
    address = AnkiConnectAddress{ip = "127.0.0.1", port = 8765}
  res <-
    runExceptT $
      mapM_
        ( \x -> do
            addOrUpdateWord address "Paper Words" [] x
        )
        translatedWords
  case res of
    Left err -> error err
    Right () -> return ()
