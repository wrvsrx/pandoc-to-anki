import Data.Either (fromRight)
import qualified Data.Text as T
import qualified Data.Text.IO as T
import qualified Data.ByteString.Lazy.Char8 as B
import Lib
import Text.Pandoc

main = do
  cnt <- T.getContents
  let p = fromRight (error "can't parse json") (runPure (readJSON def cnt))
  B.putStrLn (pandocToAnkiNotesString nameMap p)
