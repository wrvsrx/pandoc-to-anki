import Lib
import Text.Pandoc.JSON

main = toJSONFilter (renderFilter nameMap)
