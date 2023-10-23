{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE NoFieldSelectors #-}

module Words (
  addOrUpdateWord,
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
import System.Process (readProcess)
import Text.Printf (printf)

translateWord :: String -> IO String
translateWord word = readProcess "trans" [word] ""

addOrUpdateWord :: AnkiConnectAddress -> String -> [String] -> String -> ExceptT String IO ()
addOrUpdateWord address deckName tags word = do
  let
    queryString :: String = printf "deck:%s front:%s" deckName word
  translatedWord <- liftIO (translateWord word)
  let
    note = BasicReverseNote (BasicNote{front = word, back = translatedWord})
  noteIds <- ankiConnect address (FindNotesParam{query = queryString})
  case noteIds of
    [] -> do
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
      ankiConnect
        address
        ( UpdateNoteFieldParam
            { note = note
            , id = idNote
            }
        )
    _ -> do
      throwE "addOrUpdateWord: too much search result"
