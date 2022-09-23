import qualified Data.ByteString.Lazy.Char8 as B
import Data.Either (fromRight)
import qualified Data.Text as T
import qualified Data.Text.IO as T
import Lib
import Text.Pandoc

main = do
  cnt <- T.getContents
  let Pandoc m bs = fromRight (error "can't parse json") (runPure (readJSON def cnt))
  B.putStrLn (pandocToAnkiNotesString nameMap bs)
