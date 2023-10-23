module TranslateWord (
  translateWordsFromStdin,
  translateWordsIncrementally,
) where

import Data.Aeson qualified as A
import Data.ByteString.Lazy qualified as BL
import Data.Function ((&))
import Data.Functor ((<&>))
import Data.Map qualified as M
import Data.Maybe (fromJust)
import System.Process (readProcess)
import Words (TranslatedWord (..))
import Prelude hiding (words)

translateWord :: String -> IO String
translateWord word = readProcess "trans" [word] ""

translateWordsFromStdin :: IO ()
translateWordsFromStdin = do
  cnt <- BL.getContents
  let
    words = cnt & A.decode & fromJust :: [String]
  translatedWords <-
    mapM
      ( \word -> do
          translatedWord <- translateWord word
          return $ TranslatedWord{eng = word, chn = translatedWord}
      )
      words
  BL.putStr $ A.encode translatedWords

translateWordsIncrementally :: FilePath -> FilePath -> IO ()
translateWordsIncrementally wordsFile translatedFile = do
  words <- BL.readFile wordsFile <&> A.decode <&> fromJust :: IO [String]
  translatedWords :: M.Map String String <- BL.readFile translatedFile <&> A.decode <&> fromJust <&> map (\(x :: TranslatedWord) -> (x.eng, x.chn)) <&> M.fromList
  translatedWordsNew <-
    mapM
      ( \word ->
          case M.lookup word translatedWords of
            Just chn -> return $ TranslatedWord{eng = word, chn = chn}
            Nothing -> do
              translatedWord <- translateWord word
              return $ TranslatedWord{eng = word, chn = translatedWord}
      )
      words
  BL.putStr $ A.encode translatedWordsNew
