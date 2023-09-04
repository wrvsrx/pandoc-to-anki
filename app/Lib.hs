{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoFieldSelectors #-}

module Lib (
  ) where

import Anki (BasicNote (..))
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
import Text.Pandoc hiding (Example)
import Text.Pandoc.Shared (stringify)

newtype PandocIDToAnkiNID = PandocIDToAnkiNID {unwrapped :: M.Map Text Int}

-- read json
-- pandoc ast -> [pandoc node]
-- pandoc node -> Note + Pandoc ID
-- Note + Pandoc ID -> Note + Maybe (Anki ID)
-- Note + Just (Anki ID) -> UpdateNoteField
-- Note + Nothing -> AddNote

-- nameMap :: M.Map Text Text
-- nameMap =
--   M.fromList
--     [ ("theorem", "Theorem")
--     , ("example", "Example")
--     , ("remark", "Remark")
--     ]

data TheoremLike = TheoremLike
  { kind :: Text
  , attr :: Attr
  , name :: [Inline]
  , content :: [Block]
  }

data ParseTheoremLikeFailure = BlockIsNotDiv | DivIsNotTheoremKind | DivIsEmpty | TooManyTheoremClassInDiv | NameIsNotPara

pickTheorem :: M.Map Text Text -> Block -> Either ParseTheoremLikeFailure TheoremLike
pickTheorem m b = do
  (pid, cls, dict, blocks) <- case b of
    Div (pid, cls, dict) blocks -> Right (pid, cls, dict, blocks)
    _ -> Left BlockIsNotDiv
  kind <- case filter (`M.member` m) cls of
    [] -> Left DivIsNotTheoremKind
    [x] -> Right x
    _ -> Left TooManyTheoremClassInDiv
  (nameToParse, content) <- case blocks of
    x : xs -> Right (x, xs)
    [] -> Left DivIsEmpty
  name <- case nameToParse of
    Para x -> Right x
    _ -> Left NameIsNotPara
  Right $ TheoremLike kind (pid, cls, dict) name content

theoremLikeToAnki :: M.Map Text Text -> TheoremLike -> BasicNote
theoremLikeToAnki = undefined

addMarkdownToAnki :: M.Map Text Text -> ()
addMarkdownToAnki = undefined

-- renderTheorem :: M.Map Text Text -> TheoremLike -> Block
-- renderTheorem m theorem =
--   let renderedKind = fromMaybe (error "no such theorem type") (theorem.kind `M.lookup` m)
--       renderedName = Para [Strong [Str renderedKind], Space, Str "(", Span ("", ["theorem-name"], []) theorem.name, Str ")"]
--    in Div
--         theorem.attr
--         [ Div ("", ["theorem-head"], []) [renderedName]
--         , Div ("", ["theorem-content"], []) theorem.content
--         ]

--
-- renderFilter :: Dict -> Block -> Block
-- renderFilter nameMap x =
--   fromMaybe x (pickTheorem nameMap x >>= Just . renderTheorem nameMap)
--
-- data Anki = Anki
--   { guid :: Text
--   , tags :: [Text]
--   , question :: Text
--   , answer :: Text
--   }
--
-- instance A.ToJSON Anki where
--   toJSON (Anki guid tags question answer) = A.object ["guid" .= guid, "tags" .= tags, "question" .= question, "answer" .= answer]
--
-- data AnkiDeck = AnkiDeck
--   { deckTitle :: Text
--   , deckId :: Int
--   , notes :: [Anki]
--   }
--
-- instance A.ToJSON AnkiDeck where toJSON (AnkiDeck t i n) = A.object ["deckTitle" .= t, "deckId" .= i, "notes" .= n]
--
-- blocksToText x = fromRight (error "fail render block") (runPure $ writeHtml5String (def{writerHTMLMathMethod = MathJax defaultMathJaxURL}) (Pandoc (Meta M.empty) x))
--
-- theoremToAnkiNote :: Dict -> Theorem -> Anki
-- theoremToAnkiNote nameMap t =
--   let Div (did, cls, dict) [theoremHead, theoremContent] = renderTheorem nameMap t
--       theoremKind' = theoremKind t
--       theoremKindTag = fromMaybe (error "no such theorem type") (theoremKind' `M.lookup` nameMap)
--       [question, answer] = map blocksToText [[theoremHead], [theoremContent]]
--       (tags, guid) = computeAnkiTagsAndGuid dict question
--    in Anki guid (theoremKindTag : tags) question answer
--
-- pickAnkiTagsAndGuid :: [(Text, Text)] -> ([Text], Maybe Text)
-- pickAnkiTagsAndGuid dict =
--   let dict' = M.fromList dict
--       tags = maybe [] T.words ("tags" `M.lookup` dict')
--       guid = "guid" `M.lookup` dict'
--    in (tags, guid)
--
-- computeGuid = UUID.toText . UUID.generateNamed UUID.namespaceOID . U8.encode . T.unpack
--
-- computeAnkiTagsAndGuid :: [(Text, Text)] -> Text -> ([Text], Text)
-- computeAnkiTagsAndGuid dict question =
--   let (tags, guidMaybe) = pickAnkiTagsAndGuid dict
--       guid = fromMaybe (computeGuid question) guidMaybe
--    in (tags, guid)
--
-- blocksToAnkiNotes :: Dict -> [Block] -> [Anki]
-- blocksToAnkiNotes nameMap = map (theoremToAnkiNote nameMap) . mapMaybe (pickTheorem nameMap)
--
-- metaInlinesToText :: [Inline] -> Text
-- metaInlinesToText = T.concat . map stringify
--
-- hashToInt32 :: Text -> Int
-- hashToInt32 = flip shift (-1) . foldl (\x y -> shift x 8 + (fromIntegral y :: Int)) 0 . B.unpack . B.take 4 . hash . BU.fromString . T.unpack
--
-- pickDeckTitleFromMeta :: M.Map Text MetaValue -> (Text, Int)
-- pickDeckTitleFromMeta m =
--   let deckTitleMeta = take "anki-deck-title"
--       docTitleMeta = take "title"
--       deckTitle = case deckTitleMeta of
--         Just x -> x
--         Nothing -> case docTitleMeta of
--           Just x -> x
--           Nothing -> error "there's no deck title"
--       deckUUID = maybe (hashToInt32 deckTitle) (read . T.unpack :: Text -> Int) (take "deck-id")
--    in (deckTitle, deckUUID)
--  where
--   take key = do
--     val <- key `M.lookup` m
--     Just $ metaInlinesToText $ ensureMetaInlines val
--
-- ensureMetaInlines = \case (MetaInlines x) -> x; _ -> error "val must be a MetaInlines"
--
-- pandocToAnkiDeck nameMap (Pandoc (Meta m) bs) =
--   let globalTags = fromMaybe [] $ do
--         a <- "anki-tags" `M.lookup` m
--         ms <- case a of MetaList m -> Just m; _ -> Nothing
--         Just $ map ((\s -> if ' ' `T.elem` s then error "no space are allowed in tag" else s) . metaInlinesToText . ensureMetaInlines) ms
--       (deckTitle, deckUUID) = pickDeckTitleFromMeta m
--       ankiNotes = map (\anki -> anki{tags = tags anki <> globalTags}) (blocksToAnkiNotes nameMap bs)
--       ankiDeck = AnkiDeck deckTitle deckUUID ankiNotes
--    in ankiDeck
--
-- pickDiv :: Block -> Maybe (Attr, [Block])
-- pickDiv (Div attr bs) = Just (attr, bs)
-- pickDiv _ = Nothing
--
-- pickAnki :: Block -> Maybe Anki
-- pickAnki x = do
--   ((did, cls, dict), blocks) <- pickDiv x
--   (fb, sb) <- if "anki-note" `elem` cls then assert (length blocks == 2) Just (head blocks, head (tail blocks)) else Nothing
--   ((_, fcls, _), fbs) <- pickDiv fb
--   ((_, scls, _), sbs) <- pickDiv sb
--   if "anki-question" `elem` fcls && "anki-answer" `elem` scls
--     then
--       let [question, answer] = map blocksToText [fbs, sbs]
--           (tags, guid) = computeAnkiTagsAndGuid dict question
--        in Just (Anki guid tags question answer)
--     else Nothing
--
-- attachGUIDToTheorem :: Dict -> Block -> Block
-- attachGUIDToTheorem nameMap x = fromMaybe x $ do
--   ((did, cls, dict), bs) <- pickDiv x
--   t <- pickTheorem nameMap x
--   let a = theoremToAnkiNote nameMap t
--   if isNothing ((snd . pickAnkiTagsAndGuid) dict) then Just (Div (did, cls, dict <> [("guid", guid a)]) bs) else Nothing
--
-- rawTexToRawMarkdown :: Block -> Block
-- rawTexToRawMarkdown (RawBlock "tex" x) = RawBlock "markdown" x
-- rawTexToRawMarkdown x = x
--
-- attachDeckIdToMeta :: Meta -> Meta
-- attachDeckIdToMeta (Meta m) =
--   let (_, did) = pickDeckTitleFromMeta m
--       metaWithDeckId = M.insert "deck-id" ((MetaString . T.pack . show) did) m
--    in Meta metaWithDeckId
--
-- -- FIXME: think a method to avoid convert all raw tex blocks to markdown
-- pandocToAstWithGUIDJSON :: Dict -> Pandoc -> B.ByteString
-- pandocToAstWithGUIDJSON nameMap = T.encodeUtf8 . fromRight (error "fail to convert to json") . runPure . writeJSON def . (\(Pandoc m bs) -> Pandoc (attachDeckIdToMeta m) (map (rawTexToRawMarkdown . attachGUIDToTheorem nameMap) bs))
--
-- pandocToAnkiNotesJSON nameMap = BL.toStrict . A.encode . pandocToAnkiDeck nameMap
--
-- pandocToRenderedAstJSON :: Dict -> Pandoc -> B.ByteString
-- pandocToRenderedAstJSON nameMap = T.encodeUtf8 . fromRight (error "fail to convert to json") . runPure . writeJSON def . topDown (renderFilter nameMap)
