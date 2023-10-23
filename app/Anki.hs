{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE NoFieldSelectors #-}

module Anki (
  AnkiNote (..),
  AddNoteParam (..),
  AnkiConnectAddress (..),
  BasicNote (..),
  BasicReverseNote (..),
  UpdateNoteFieldParam (..),
  FindNotesParam (..),
  ankiConnect,
) where

import Data.Aeson (Value, object, (.:), (.=))
import Data.Aeson qualified as A
import Data.Default (Default, def)
import Data.Functor ((<&>))
import Data.Map qualified as M
import Data.Proxy (Proxy (..))
import Data.Text qualified as T
import Network.HTTP.Req qualified as R

type family AnkiConnectResult param
class AnkiConnectParam param where
  operationName :: Proxy param -> String

newtype AnkiConnectResultWrapper r = AnkiConnectResultWrapper {unwrapped :: Either Value r}
instance (A.FromJSON r) => A.FromJSON (AnkiConnectResultWrapper r) where
  parseJSON = A.withObject "AnkiConnectResult" $ \v -> do
    maybeErr :: Maybe Value <- v .: "error"
    case maybeErr of
      Just err -> return (AnkiConnectResultWrapper (Left err))
      Nothing -> (v .: "result") <&> Right <&> AnkiConnectResultWrapper

ankiConnect :: forall p. (A.ToJSON p, AnkiConnectParam p, A.FromJSON (AnkiConnectResult p)) => AnkiConnectAddress -> p -> IO (Either Value (AnkiConnectResult p))
ankiConnect address param = do
  let
    payload =
      object
        [ "action" .= operationName (Proxy :: Proxy p)
        , "params" .= param
        , "version" .= (6 :: Int)
        ]
  r :: AnkiConnectResultWrapper r <-
    R.runReq R.defaultHttpConfig $
      R.req
        R.POST
        (R.http (T.pack address.ip))
        (R.ReqBodyJson payload)
        R.jsonResponse
        (R.port address.port)
        <&> R.responseBody
  return r.unwrapped

data AnkiMedia = AnkiMedia
  { audio :: [FilePath]
  , video :: [FilePath]
  , picture :: [FilePath]
  }

instance Default AnkiMedia where
  def = AnkiMedia{audio = [], video = [], picture = []}

-- anki note 由什么构成？
-- model
-- fields
-- medias
class AnkiNote a where
  ankiModel :: Proxy a -> String
  ankiFields :: a -> M.Map String String
  ankiMedia :: a -> AnkiMedia

data AnkiConnectAddress = AnkiConnectAddress
  { ip :: String
  , port :: Int
  }

data AddNoteParam a = AddNoteParam
  { note :: a
  , deckName :: String
  , tags :: [String]
  }
type instance AnkiConnectResult (AddNoteParam a) = Int
instance AnkiConnectParam (AddNoteParam a) where
  operationName = const "addNote"
instance (AnkiNote a) => A.ToJSON (AddNoteParam a) where
  toJSON (AddNoteParam note deckName tags) =
    object
      [ "note"
          .= object
            [ "deckName" .= deckName
            , "modelName" .= ankiModel (Proxy :: Proxy a)
            , "fields" .= ankiFields note
            , "tags" .= tags
            ]
      ]

data BasicNote = BasicNote
  { front :: String
  , back :: String
  }
instance AnkiNote BasicNote where
  ankiModel = const "Basic"
  ankiFields x = M.fromList [("Front", x.front), ("Back", x.back)]
  ankiMedia _ = def

newtype BasicReverseNote = BasicReverseNote BasicNote
instance AnkiNote BasicReverseNote where
  ankiModel = const "Basic (and reversed card)"
  ankiFields (BasicReverseNote x) = ankiFields x
  ankiMedia (BasicReverseNote x) = ankiMedia x

data UpdateNoteFieldParam a = UpdateNoteFieldParam
  { note :: a
  , id :: Int
  }
type instance AnkiConnectResult (UpdateNoteFieldParam a) = ()
instance AnkiConnectParam (UpdateNoteFieldParam a) where
  operationName = const "updateNoteFields"
instance (AnkiNote a) => A.ToJSON (UpdateNoteFieldParam a) where
  toJSON (UpdateNoteFieldParam note id_) =
    object
      [ "note"
          .= object
            [ "id" .= id_
            , "fields" .= ankiFields note
            ]
      ]

newtype FindNotesParam = FindNotesParam {query :: String}
type instance AnkiConnectResult FindNotesParam = [Int]
instance AnkiConnectParam FindNotesParam where
  operationName = const "findNotes"
instance A.ToJSON FindNotesParam where
  toJSON (FindNotesParam query) = object ["query" .= query]
