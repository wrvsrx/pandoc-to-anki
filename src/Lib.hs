{-# LANGUAGE OverloadedStrings #-}

module Lib where

import Codec.Binary.UTF8.String as U8
import Control.Exception (assert)
import Data.Aeson ((.=))
import qualified Data.Aeson as A
import Data.Bifunctor (Bifunctor (first))
import Data.Either (fromRight)
import Data.Foldable (find)
import Data.Function ((&))
import qualified Data.Map as M
import Data.Maybe (catMaybes, fromMaybe, mapMaybe)
import qualified Data.Maybe as UUID
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.UUID as UUID
import qualified Data.UUID.V5 as UUID
import Text.Pandoc
import Text.Pandoc.Generic (bottomUp)
import Text.Pandoc.JSON

type Dict = M.Map Text Text

nameMap :: Dict
nameMap =
  M.fromList
    [ ("theorem", "Theorem")
    , ("example", "Example")
    , ("remark", "Remark")
    ]

data Theorem = Theorem
  { attr :: Attr
  , theoremKind :: Text
  , theoremName :: [Inline]
  , theoremContent :: [Block]
  }

pickTheoremKind nameMap cls = case filter (`M.member` nameMap) cls of
  [] -> Nothing
  [x] -> Just x
  _ -> error "too many theorem class in a div"

pickTheorem :: Dict -> Block -> Maybe Theorem
pickTheorem nameMap x = do
  (id, cls, dict, blocks) <- case x of Div (id, cls, dict) blocks -> Just (id, cls, dict, blocks); _ -> Nothing
  (theoremNameCandidate, theoremContent) <- if length blocks > 1 then Just (head blocks, tail blocks) else Nothing
  theoremName <- case theoremNameCandidate of Para x -> Just x; _ -> Nothing
  theoremKind <- pickTheoremKind nameMap cls
  Just $ Theorem (id, cls, dict) theoremKind theoremName theoremContent

renderTheorem :: Dict -> Theorem -> Block
renderTheorem nameMap (Theorem attr theoremKind theoremName theoremContent) =
  let theoremKindRendered = fromMaybe (error "no such theorem type") (theoremKind `M.lookup` nameMap)
      theoremNameRendered = Para [Strong [Str theoremKindRendered], Space, Str "(", Span ("", ["theorem-name"], []) theoremName, Str ")"]
   in Div
        attr
        [ Div ("", ["theorem-head"], []) [theoremNameRendered]
        , Div ("", ["theorem-content"], []) theoremContent
        ]

renderFilter :: Dict -> Block -> Block
renderFilter nameMap x =
  fromMaybe x (pickTheorem nameMap x >>= Just . renderTheorem nameMap)

data Anki = Anki
  { guid :: Text
  , tags :: [Text]
  , question :: Text
  , answer :: Text
  }

instance A.ToJSON Anki where
  toJSON (Anki guid tags question answer) = A.object ["guid" .= guid, "tags" .= tags, "question" .= question, "answer" .= answer]

theoremToAnkiNote :: Dict -> Theorem -> Anki
theoremToAnkiNote nameMap t =
  let Div (did, cls, dict) [theoremHead, theoremContent] = renderTheorem nameMap t
      theoremKind' = theoremKind t
      dict' = M.fromList dict
      tags = maybe [] T.words ("tags" `M.lookup` dict') :: [Text]
      question = fromRight (error "fail rendering question") (runPure $ writeHtml5String def (Pandoc (Meta M.empty) [theoremHead]))
      answer = fromRight (error "fail rendering answer") (runPure $ writeHtml5String def (Pandoc (Meta M.empty) [theoremContent]))
      guid =
        fromMaybe
          (UUID.toText $ UUID.generateNamed UUID.namespaceOID (U8.encode (T.unpack question)))
          ("guid" `M.lookup` dict')
   in Anki guid tags question answer

pandocToAnkiNotes :: Dict -> [Block] -> [Anki]
pandocToAnkiNotes nameMap = map (theoremToAnkiNote nameMap) . mapMaybe (pickTheorem nameMap)

pandocToAnkiNotesJSON nameMap = A.encode . pandocToAnkiNotes nameMap
