{-# LANGUAGE ViewPatterns, TupleSections, RecordWildCards, ScopedTypeVariables #-}

module Output.Names(writeNames, searchNames) where

import Control.Applicative
import System.IO.Extra
import System.FilePath
import Data.List.Extra
import Data.Maybe
import Data.Tuple.Extra
import qualified Data.ByteString.Char8 as BS

import Input.Type
import General.Util


writeNames :: Database -> [(Maybe Id, Item)] -> IO ()
writeNames (Database file) xs = writeFileBinary (file <.> "names") $ unlines
    [show i ++ " " ++ [' ' | isUName name] ++ lower name | (Just i, x) <- xs, name <- toName x]

toName :: Item -> [String]
toName (IKeyword x) = [x]
toName (IPackage x) = [x]
toName (IModule x) = [last $ splitOn "." x]
toName (IDecl x) = declNames x

searchNames :: Database -> Bool -> [String] -> IO [(Score, Id)]
searchNames (Database file) exact xs = do
    src <- BS.lines <$> BS.readFile (file <.> "names")
    return $ mapMaybe (match exact xs) src

match :: Bool -> [String] -> BS.ByteString -> Maybe (Score, Id)
match exact xs = \line ->
    let (ident, str) = second (BS.drop 1) $ BS.break (== ' ') line
        ident2 = read $ BS.unpack ident
    in fmap (,ident2) $ case () of
        _ | BS.length str < mn -> Nothing
          | not $ all (`BS.isInfixOf` str) xsMatch -> Nothing
          | any (== str) xsPerfect -> Just 0
          | exact -> Nothing
          | any (== str) xsGood -> Just 1
          | any (`BS.isPrefixOf` str) xsPerfect -> Just 2
          | any (`BS.isPrefixOf` str) xsGood -> Just 3
          | otherwise -> Just 4
    where
        mn = sum $ map BS.length xsMatch
        xsMatch = map (BS.pack . lower) xs
        xsPerfect = [BS.pack $ [' ' | isUName x] ++ lower x | x <- xs]
        xsGood = [BS.pack $ [' ' | not $ isUName x] ++ lower x | x <- xs]