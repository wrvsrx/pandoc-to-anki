{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module Lib (
  renderFilter,
  nameMap,
  pandocToAnkiNotesJSON,
  pandocToAstWithGUIDJSON,
  pandocToRenderedAstJSON,
  hashToInt32,
) where

import Codec.Binary.UTF8.String as U8
import Control.Exception (assert)
import Crypto.Hash.SHA256 (hash)
import Data.Aeson ((.=))
import qualified Data.Aeson as A
import Data.Bits (shift)
import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.UTF8 as BU
import Data.Either (fromRight)
import qualified Data.Map as M
import Data.Maybe (fromMaybe, isNothing, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as T
import qualified Data.UUID as UUID
import qualified Data.UUID.V5 as UUID
import Text.Pandoc
import Text.Pandoc.Shared (stringify)

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

data AnkiDeck = AnkiDeck
  { deckTitle :: Text
  , deckId :: Int
  , notes :: [Anki]
  }

instance A.ToJSON AnkiDeck where toJSON (AnkiDeck t i n) = A.object ["deckTitle" .= t, "deckId" .= i, "notes" .= n]

blocksToText x = fromRight (error "fail render block") (runPure $ writeHtml5String (def{writerHTMLMathMethod = MathJax defaultMathJaxURL}) (Pandoc (Meta M.empty) x))

theoremToAnkiNote :: Dict -> Theorem -> Anki
theoremToAnkiNote nameMap t =
  let Div (did, cls, dict) [theoremHead, theoremContent] = renderTheorem nameMap t
      theoremKind' = theoremKind t
      theoremKindTag = fromMaybe (error "no such theorem type") (theoremKind' `M.lookup` nameMap)
      [question, answer] = map blocksToText [[theoremHead], [theoremContent]]
      (tags, guid) = computeAnkiTagsAndGuid dict question
   in Anki guid (theoremKindTag : tags) question answer

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

blocksToAnkiNotes :: Dict -> [Block] -> [Anki]
blocksToAnkiNotes nameMap = map (theoremToAnkiNote nameMap) . mapMaybe (pickTheorem nameMap)

metaInlinesToText :: [Inline] -> Text
metaInlinesToText = T.concat . map stringify

hashToInt32 :: Text -> Int
hashToInt32 = flip shift (-1) . foldl (\x y -> shift x 8 + (fromIntegral y :: Int)) 0 . B.unpack . B.take 4 . hash . BU.fromString . T.unpack

pickDeckTitleFromMeta :: M.Map Text MetaValue -> (Text, Int)
pickDeckTitleFromMeta m =
  let deckTitleMeta = take "anki-deck-title"
      docTitleMeta = take "title"
      deckTitle = case deckTitleMeta of
        Just x -> x
        Nothing -> case docTitleMeta of
          Just x -> x
          Nothing -> error "there's no deck title"
      deckUUID = maybe (hashToInt32 deckTitle) (read . T.unpack :: Text -> Int) (take "deck-id")
   in (deckTitle, deckUUID)
 where
  take key = do
    val <- key `M.lookup` m
    Just $ metaInlinesToText $ ensureMetaInlines val

ensureMetaInlines = \case (MetaInlines x) -> x; _ -> error "val must be a MetaInlines"

pandocToAnkiDeck nameMap (Pandoc (Meta m) bs) =
  let globalTags = fromMaybe [] $ do
        a <- "anki-tags" `M.lookup` m
        ms <- case a of MetaList m -> Just m; _ -> Nothing
        Just $ map ((\s -> if ' ' `T.elem` s then error "no space are allowed in tag" else s) . metaInlinesToText . ensureMetaInlines) ms
      (deckTitle, deckUUID) = pickDeckTitleFromMeta m
      ankiNotes = map (\anki -> anki{tags = tags anki <> globalTags}) (blocksToAnkiNotes nameMap bs)
      ankiDeck = AnkiDeck deckTitle deckUUID ankiNotes
   in ankiDeck

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

rawTexToRawMarkdown :: Block -> Block
rawTexToRawMarkdown (RawBlock "tex" x) = RawBlock "markdown" x
rawTexToRawMarkdown x = x

attachDeckIdToMeta :: Meta -> Meta
attachDeckIdToMeta (Meta m) =
  let (_, did) = pickDeckTitleFromMeta m
      metaWithDeckId = M.insert "deck-id" ((MetaString . T.pack . show) did) m
   in Meta metaWithDeckId

-- FIXME: think a method to avoid convert all raw tex blocks to markdown
pandocToAstWithGUIDJSON :: Dict -> Pandoc -> B.ByteString
pandocToAstWithGUIDJSON nameMap = T.encodeUtf8 . fromRight (error "fail to convert to json") . runPure . writeJSON def . (\(Pandoc m bs) -> Pandoc (attachDeckIdToMeta m) (map (rawTexToRawMarkdown . attachGUIDToTheorem nameMap) bs))

pandocToAnkiNotesJSON nameMap = BL.toStrict . A.encode . pandocToAnkiDeck nameMap

pandocToRenderedAstJSON :: Dict -> Pandoc -> B.ByteString
pandocToRenderedAstJSON nameMap = T.encodeUtf8 . fromRight (error "fail to convert to json") . runPure . writeJSON def . topDown (renderFilter nameMap)
