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

pickClass :: Dict -> [Text] -> Text
pickClass nameMap = fromMaybe (error "no such class") . find (`M.member` nameMap)

renderClassName :: Dict -> [Text] -> Text
renderClassName nameMap = head . mapMaybe (`M.lookup` nameMap)

pickPara (Para x) = x
pickPara _ = error "not a paragraph"

transformTheorem nameMap (Div attr blocks)
  | let (_, cls, _) = attr in any (`M.member` nameMap) cls =
    let theoremName = head blocks
        theoremContent = tail blocks
        (id, cls, dict) = attr
        theoremKind = pickClass nameMap cls
     in Div (id, cls ++ ["theorem-mark"], dict) [Div ("", ["theorem-name"], [("theorem-type", theoremKind)]) [theoremName], Div ("", ["theorem-content"], []) theoremContent]
transformTheorem _ x = x

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
  { guid :: UUID.UUID
  , tags :: [Text]
  , question :: Text
  , answer :: Text
  }

instance A.ToJSON Anki where
  toJSON (Anki guid tags question answer) =
    A.object ["guid" .= guid, "tags" .= tags, "question" .= question, "answer" .= answer]

theoremToAnkiNote :: Dict -> Meta -> Theorem -> Anki
theoremToAnkiNote nameMap m t =
  let Div (did, cls, dict) [theoremHead, theoremContent] = renderTheorem nameMap t
      theoremKind' = theoremKind t
      tags = maybe [] (T.words . snd) (find (\(x, y) -> "tags" == x) dict) :: [Text]
      question = fromRight (error "fail rendering question") (runPure $ writeHtml5String def (Pandoc m [theoremHead]))
      answer = fromRight (error "fail rendering question") (runPure $ writeHtml5String def (Pandoc m [theoremContent]))
      guid = UUID.generateNamed UUID.namespaceOID (U8.encode (T.unpack question))
   in Anki guid tags question answer

pandocToAnkiNotes :: Dict -> Pandoc -> [Anki]
pandocToAnkiNotes nameMap (Pandoc m bs) =
  bs
    & mapMaybe (pickTheorem nameMap)
    & map (theoremToAnkiNote nameMap m)

pandocToAnkiNotesString nameMap = A.encode . pandocToAnkiNotes nameMap
