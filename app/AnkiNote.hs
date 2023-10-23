{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE NoFieldSelectors #-}

module AnkiNote (
  BasicNote (..),
  AnkiNote (..),
  BasicReverseNote (..),
) where

import Data.Default (Default, def)
import Data.Map qualified as M
import Data.Proxy (Proxy (..))

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
