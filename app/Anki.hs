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
  addNote,
) where

import Data.Aeson (Value, object, (.:), (.=))
import Data.Aeson qualified as A
import Data.Aeson.Types qualified as A
import Data.Default (Default, def)
import Data.Function ((&))
import Data.Map qualified as M
import Data.Proxy (Proxy (..))
import Data.Text qualified as T
import Network.HTTP.Req qualified as R

type family AnkiConnectResult param
class AnkiConnectParam param where
  operationName :: Proxy param -> String

ankiConnect :: forall p. (A.ToJSON p, AnkiConnectParam p, A.FromJSON (AnkiConnectResult p)) => AnkiConnectAddress -> p -> IO (Either Value (AnkiConnectResult p))
ankiConnect address param = do
  let
    payload =
      object
        [ "action" .= operationName (Proxy :: Proxy p)
        , "params" .= param
        , "version" .= (6 :: Int)
        ]
  r <-
    R.runReq R.defaultHttpConfig $
      R.req
        R.POST
        (R.http (T.pack address.ip))
        (R.ReqBodyJson payload)
        R.jsonResponse
        (R.port address.port)
  let
    v = R.responseBody r :: A.Object
    parser =
      do
        maybeErr :: Maybe Value <- v .: "error"
        case maybeErr of
          Just err -> return (Left err)
          Nothing -> do
            val :: r <- v .: "result"
            return (Right val)
    res = A.parseEither (const parser) () & either error id
  return res

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

data AddNoteParam a = AddNoteParam
  { note :: a
  , deckName :: String
  , tags :: [String]
  }
type instance AnkiConnectResult (AddNoteParam a) = Int

instance AnkiConnectParam (AddNoteParam a) where
  operationName = const "addNote"

addNote :: (AnkiNote a) => AnkiConnectAddress -> AddNoteParam a -> IO (Either Value Int)
addNote = ankiConnect

data BasicNote = BasicNote
  { front :: String
  , back :: String
  }

instance AnkiNote BasicNote where
  ankiModel = const "Basic"
  ankiFields x = M.fromList [("Front", x.front), ("Back", x.back)]
  ankiMedia _ = def
