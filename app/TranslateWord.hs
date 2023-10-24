module TranslateWord (
  translateWordsFromStdin,
  translateWordsIncrementally,
) where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT (..), runExceptT, throwE)
import Data.Aeson qualified as A
import Data.ByteString.Lazy qualified as BL
import Data.Function ((&))
import Data.Functor ((<&>))
import Data.Map qualified as M
import Data.Maybe (fromJust)
import System.Process (readProcessWithExitCode)
import Words (TranslatedWord (..))
import Prelude hiding (words)

translateWord :: String -> ExceptT String IO String
translateWord word = do
  (_, res, err) <- liftIO $ readProcessWithExitCode "trans" ["-no-ansi", ":zh", word] ""
  case err of
    "" -> return res
    x -> throwE x

translateWordsFromStdin :: IO ()
translateWordsFromStdin = do
  cnt <- BL.getContents
  let
    words = cnt & A.decode & fromJust :: [String]
  translatedWords <-
    mapM
      ( \word -> do
          translatedWord <- runExceptT (translateWord word) <&> either error id
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
      ( \word -> do
          s <- case M.lookup word translatedWords of
            Just chn -> return $ TranslatedWord{eng = word, chn = chn}
            Nothing -> do
              translatedResult <- runExceptT (translateWord word)
              case translatedResult of
                Left err -> error $ "fail to translate word: " <> word <> "\nerror message: " <> err
                Right x -> return $ TranslatedWord{eng = word, chn = x}
          putStrLn $ "finish translate " <> word
          return s
      )
      words
  BL.writeFile translatedFile (A.encode translatedWordsNew)
