#!/usr/bin/env runghc

import System.Process

main :: IO ()
main = do
  rawSystem "cabal-fmt" ["--inplace", "markdown-to-anki.cabal"]
  cnt <- readProcess "cabal2nix" ["."] ""
  writeFile "default.nix" cnt
