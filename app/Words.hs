{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}

module Words (
  addOrUpdateWord,
  TranslatedWord (..),
) where

import Anki (
  AddNoteParam (..),
  AnkiConnectAddress,
  FindNotesParam (..),
  UpdateNoteFieldParam (..),
  ankiConnect,
 )
import AnkiNote
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, throwE)
import Data.Aeson qualified as A
import GHC.Generics (Generic)
import Text.Printf (printf)

data TranslatedWord = TranslatedWord
  { eng :: String
  , chn :: String
  }
  deriving (Generic)

instance A.FromJSON TranslatedWord
instance A.ToJSON TranslatedWord

addOrUpdateWord :: AnkiConnectAddress -> String -> [String] -> TranslatedWord -> ExceptT String IO ()
addOrUpdateWord address deckName tags word = do
  let
    queryString :: String = printf "deck:\"%s\" front:\"%s\"" deckName word.eng
  let
    note = BasicNote{front = word.eng, back = word.chn}
  noteIds <- ankiConnect address (FindNotesParam{query = queryString})
  case noteIds of
    [] -> do
      liftIO $ putStrLn ("adding a note: " <> word.eng)
      _ <-
        ankiConnect
          address
          ( AddNoteParam
              { note = note
              , deckName = deckName
              , tags = tags
              }
          )
      return ()
    [idNote] -> do
      liftIO $ putStrLn "updating a note"
      ankiConnect
        address
        ( UpdateNoteFieldParam
            { note = note
            , id = idNote
            }
        )
    _ -> do
      throwE "addOrUpdateWord: too much search result"
