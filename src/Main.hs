{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Exception (assert)
import Data.Foldable (find)
import qualified Data.Map as M
import Data.Maybe (catMaybes, fromMaybe, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Text.Pandoc.Generic (bottomUp)
import Text.Pandoc.JSON

type Dict = M.Map Text Text

nameMap =
  M.fromList
    [ ("theorem", "Theorem")
    , ("example", "Example")
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
  , theoremName :: [Inline]
  , theoremContent :: [Block]
  }

pickTheorem :: Dict -> Block -> Maybe Theorem
pickTheorem nameMap x = do
  (id, cls, dict, blocks) <- case x of Div (id, cls, dict) blocks -> Just (id, cls, dict, blocks); _ -> Nothing
  (theoremNameCandidate, theoremContent) <- if length blocks > 1 then Just (head blocks, tail blocks) else Nothing
  theoremName <- case theoremNameCandidate of Para x -> Just x; _ -> Nothing
  if any (`M.member` nameMap) cls then Just $ Theorem (id, cls, dict) theoremName theoremContent else Nothing

pickTheorems nameMap = mapMaybe (pickTheorem nameMap)

-- checkTheorem :: Theorem -> Bool
-- checkTheorem (Theorem attr theoremName theoremContent) = 
--   let
--     res = do
--       theoremNameCls <- case theoremName of Div attr blocks 
--   any (`M.member` nameMap) cls 
--     && "theorem-name" `elem` theoremNameCls
--     && "theorem-content" `elem` theoremContent
--   where
--     theoremNameCls = case theoremName 
    

-- pickTheorems :: Dict -> [Block] -> [(Block, Block)]
-- pickTheorems

renderTheorem nameMap (Div attr blocks) =
  let (_, cls, dict) = attr
   in if "theorem-name" `elem` cls
        then
          let theoremName = pickPara (head blocks)
              theoremType = fromMaybe (error "no such theorem type") ("theorem-type" `M.lookup` M.fromList dict)
              theoremTypeRendered = fromMaybe (error "no such theorem type") (theoremType `M.lookup` nameMap)
              theoremNameRendered = Para ([Strong [Str theoremTypeRendered], Space, Str "("] ++ theoremName ++ [Str ")"])
           in Div attr [theoremNameRendered]
        else Div attr blocks
renderTheorem _ x = x

main = toJSONFilter (bottomUp (renderTheorem nameMap) . bottomUp (transformTheorem nameMap) :: Pandoc -> Pandoc)
