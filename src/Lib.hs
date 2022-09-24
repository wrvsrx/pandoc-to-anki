{-# LANGUAGE OverloadedStrings #-}

module Lib (
  renderFilter,
  nameMap,
  pandocToAnkiNotesJSON,
  pandocToAstWithGUIDJSON,
  pandocToRenderedAstJSON,
) where

import Codec.Binary.UTF8.String as U8
import Control.Exception (assert)
import Data.Aeson ((.=))
import qualified Data.Aeson as A
import Data.Bifunctor (Bifunctor (first))
import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy as BL
import Data.Either (fromRight)
import Data.Foldable (find)
import Data.Function ((&))
import Data.Functor ((<&>))
import qualified Data.Map as M
import Data.Maybe (catMaybes, fromMaybe, isNothing, mapMaybe)
import qualified Data.Maybe as UUID
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as T
import qualified Data.UUID as UUID
import qualified Data.UUID.V5 as UUID
import Text.Pandoc
import qualified Text.Pandoc as M
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

blocksToText x = fromRight (error "fail render block") (runPure $ writeHtml5String def (Pandoc (Meta M.empty) x))

theoremToAnkiNote :: Dict -> Theorem -> Anki
theoremToAnkiNote nameMap t =
  let Div (did, cls, dict) [theoremHead, theoremContent] = renderTheorem nameMap t
      theoremKind' = theoremKind t
      [question, answer] = map blocksToText [[theoremHead], [theoremContent]]
      (tags, guid) = computeAnkiTagsAndGuid dict question
   in Anki guid tags question answer

pickAnkiTagsAndGuid :: [(Text, Text)] -> ([Text], Maybe Text)
pickAnkiTagsAndGuid dict =
  let dict' = M.fromList dict
      tags = maybe [] T.words ("tags" `M.lookup` dict')
      guid = "guid" `M.lookup` dict'
   in (tags, guid)

computeGuid = UUID.toText . UUID.generateNamed UUID.namespaceOID . U8.encode . T.unpack

computeAnkiTagsAndGuid :: [(Text, Text)] -> Text -> ([Text], Text)
computeAnkiTagsAndGuid dict question =
  let (tags, guidMaybe) = pickAnkiTagsAndGuid dict
      guid = fromMaybe (computeGuid question) guidMaybe
   in (tags, guid)

pandocToAnkiNotes :: Dict -> [Block] -> [Anki]
pandocToAnkiNotes nameMap = map (theoremToAnkiNote nameMap) . mapMaybe (pickTheorem nameMap)

pickDiv :: Block -> Maybe (Attr, [Block])
pickDiv (Div attr bs) = Just (attr, bs)
pickDiv _ = Nothing

pickAnki :: Block -> Maybe Anki
pickAnki x = do
  ((did, cls, dict), blocks) <- pickDiv x
  (fb, sb) <- if "anki-note" `elem` cls then assert (length blocks == 2) Just (head blocks, head (tail blocks)) else Nothing
  ((_, fcls, _), fbs) <- pickDiv fb
  ((_, scls, _), sbs) <- pickDiv sb
  if "anki-question" `elem` fcls && "anki-answer" `elem` scls
    then
      let [question, answer] = map blocksToText [fbs, sbs]
          (tags, guid) = computeAnkiTagsAndGuid dict question
       in Just (Anki guid tags question answer)
    else Nothing

attachGUIDToTheorem :: Dict -> Block -> Block
attachGUIDToTheorem nameMap x = fromMaybe x $ do
  ((did, cls, dict), bs) <- pickDiv x
  t <- pickTheorem nameMap x
  let a = theoremToAnkiNote nameMap t
  if isNothing ((snd . pickAnkiTagsAndGuid) dict) then Just (Div (did, cls, dict <> [("guid", guid a)]) bs) else Nothing

pandocToAstWithGUIDJSON :: Dict -> Pandoc -> B.ByteString
pandocToAstWithGUIDJSON nameMap = T.encodeUtf8 . fromRight (error "fail to convert to json") . runPure . writeJSON def . topDown (attachGUIDToTheorem nameMap)

pandocToAnkiNotesJSON nameMap (Pandoc m bs) = (BL.toStrict . A.encode . pandocToAnkiNotes nameMap) bs

pandocToRenderedAstJSON :: Dict -> Pandoc -> B.ByteString
pandocToRenderedAstJSON nameMap = T.encodeUtf8 . fromRight (error "fail to convert to json") . runPure . writeJSON def . topDown (renderFilter nameMap)
