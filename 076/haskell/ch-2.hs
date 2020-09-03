{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}
import Options.Generic
import Data.List ( find, findIndex, span, insert
            ,inits, tails, isPrefixOf, unfoldr )
import Data.Char ( toLower )
import System.IO
import System.Exit (die)
import Control.Exception

{- tested with:
 runhaskell ch-2.hs --grid ../data/grid.txt --dict ../data/tinyDict.txt
 # or this will use `/usr/share/dict/british-english' by default
-}

{- comment:
I try to learn how `data' works in Haskell
probably I could have used `nub` for duplicated words
and use `readFile' to get simply a list of words in a dictionary
but try to do more investigation about this interesting language
-}

-- solution:
-- 1. read Grid and generate all possile (and useful) indices
-- 2. save all words accoring to the indcies found above into tree
-- 3. read Dictionary
-- 4. compare one by one
---   all data is sorted so we can easily compare between two.

-- not-efficient tree with multiple child nodes
data WordTree = Root [WordTree] | Node Char [WordTree]
  deriving (Show, Read, Eq, Ord)

wordTreeNodeVal  (Node a _)        = a
wordTreeNodeVal  (Root   _)        = '\NUL'
wordTreeChildren (Root   children) = children
wordTreeChildren (Node _ children) = children

findChild a wtree = find ((a ==).(wordTreeNodeVal)) (wordTreeChildren wtree)
spanChildren c children = span ((<c).(wordTreeNodeVal)) children

newChild        a = Node a [] -- with char
newChildren   str
  | length str == 1  = newChild (head str)
  | otherwise = foldr (\x acc -> Node x [acc]) (newChild (last str)) (init str)

wordTreeSaveWord :: WordTree -> String -> WordTree
wordTreeSaveWord (Root children) str@(c:cs) =
  let (leChildren, riChildren) = spanChildren c children
      foundChild = head riChildren
  in
    if (null riChildren) || ((wordTreeNodeVal.head) riChildren /= c)
    then Root (insert (newChildren str) children)
    else if null cs then Root children -- already saved: skip
      else Root$leChildren ++ (wordTreeSaveWord foundChild cs):(tail riChildren)

wordTreeSaveWord (Node a children) str@(c:cs) =
  let (leChildren, riChildren) = spanChildren c children
      foundChild = head riChildren
  in
    if (null riChildren) || ((wordTreeNodeVal.head) riChildren /= c)
    then Node a (insert (newChildren str) children)
    else if null cs then Node a children -- already saved: skip
      else Node a $ leChildren
                  ++ (wordTreeSaveWord foundChild cs):(tail riChildren)

wordTreeGetAllWords :: WordTree -> [String]
wordTreeGetAllWords (Root children) =
  ((foldr (++) []).(map wordTreeGetAllWords)) children

wordTreeGetAllWords (Node nv children) =
  [[nv]] ++ ((foldr (++) [])
              .(map (\wtree -> [ nv:str | str <-(wordTreeGetAllWords wtree)] )))
  children

-- find out all indices
allColumnIndices (maxPos, llen) =
  map (\c ->  takeWhile (<=maxPos) $
             map ((c+).(llen*)) [ 0 .. (maxPos `div` llen) ] )
  [ 0.. (llen -1) ]

allRowIndices (maxPos, llen) =
  map (\c -> takeWhile (<=maxPos) $
            map (c+) [ 0 .. (llen -1) ] )
  [ 0, llen .. maxPos ]

allTopLeftToBottomRightIndices (maxPos, llen) =
  map (\c -> [c] ++ ( takeWhile
            (\x -> x <= maxPos
              && (rem c llen) < (rem x llen) ) $
            map (c+) [ (llen+1), (llen+llen+2) .. ] ) ) $
  [ 0 .. (llen-1) ] ++ [ llen, llen + llen .. maxPos ]

allTopRightToBottomLeftIndices (maxPos, llen) =
  map (\c -> [c] ++ ( takeWhile
            (\x -> x <= maxPos
              && (rem x llen) < (rem c llen) )
            $ map (c+) [ (llen-1), (llen+llen-2) .. ] ) )
  $ [ 0 .. (llen-1) ] ++ [ llen+llen-1, llen+llen+llen-1 .. maxPos ]

allIndices (maxPos, llen) = let idxArgs = (maxPos, llen) in
                              (allColumnIndices idxArgs)
                              ++ (allRowIndices idxArgs)
                              ++ (allTopLeftToBottomRightIndices idxArgs)
                              ++ (allTopRightToBottomLeftIndices idxArgs)

flatOnce = foldr (++) []

bothDirectAllIndices = flatOnce.(map obverseAndReverse).allIndices where
    obverseAndReverse a
      | length a == 1 = [ a ] -- rerversing is not useful
      | otherwise     = [ a, reverse a ]

-- final result of indices
allUsefulCombinationIndices = usefulInits.usefulTails.bothDirectAllIndices where
  -- note: a character might be not useful to compare: disgarded
  -- another possible approach might be (not checked)
  -- (filter ((2<).length).subsequences)
  usefulInits = flatOnce.map (drop 2. inits)
  usefulTails = flatOnce.map
                ((\ls -> let len = length ls in take (len-2) ls).tails)

data GridData = GridData { gridMaxPos       :: Int
                         , gridLineLength   :: Int
                         , gridContents     :: String       } deriving (Show)

-- grid data
gridDataFromString gridString =
  let noSpaceContents = filter (' '/=) gridString
      lineLen = case (findIndex ('\n'==) noSpaceContents) of
                  Nothing -> 1 -- maybe a wrong formated file: assume one
                  Just ln -> ln
      contents = (map toLower.filter ('\n'/=)) noSpaceContents
      maxPos   = (pred.length) contents
  in GridData { gridLineLength = lineLen
             , gridMaxPos = maxPos
             , gridContents = contents }

allUsefulWordsFromGridData g = (map (map (contents!!))) idcsList
  where
    lineLengh = gridLineLength g
    maxPos    = gridMaxPos     g
    contents  = gridContents   g
    idcsList  = allUsefulCombinationIndices (maxPos, lineLengh)

wordTreeFromGridData =
  (foldr (flip wordTreeSaveWord) (Root [])).allUsefulWordsFromGridData

-- comparison
{- If we create a list from a dictionary by using `readFile'
we can easily get the result by `intersect'
but I tried to go little bit further in order to study Haskell
which is not easy when it comes with unfamiliar context `Monad'...
-}
nextDictWord :: Handle -> IO (Maybe String)
nextDictWord dictFh = do
  eof <- hIsEOF dictFh
  if eof then return Nothing
    else do
    word <- hGetLine dictFh
    return (Just word)

-- there is no standard unfoldM and mapM doesn't look efficient in this case,
-- and have to reset the reading position via (hTell, hSeek) ...
-- so I decided to make own (recursive) function
grepMatchedWord dictFh gridWords =
  impli Nothing gridWords [] where
  impli :: Maybe String -> [String] -> [String]  -> IO [String]
  impli _ [] matchedWords = return matchedWords
  impli lastDictWord gWords@(gridWord:gridRestWords) matchedWords =
    case lastDictWord of
      Nothing -> do
        res <- nextDictWord dictFh
        case res of
          Nothing        -> return matchedWords -- dictionary finised first
          Just newDWord  -> impli (Just newDWord) gWords matchedWords
      Just lastDWord     ->
        let last_dword = map toLower lastDWord in
          case (compare last_dword gridWord) of
            LT -> impli Nothing gWords matchedWords
            EQ -> impli Nothing gridRestWords (matchedWords ++ [gridWord])
            GT -> impli lastDictWord gridRestWords matchedWords

defaultGridFile   = "../data/grid.txt"
--defaultDictionary = "../tinyDict.txt"
defaultDictionary = "/usr/share/dict/british-english"
-- via `words' package in Arch Linux

tryOpenDict :: FilePath -> IO (Maybe Handle)
tryOpenDict dpath =
  (do
      fh <- openFile dpath ReadMode
      return (Just fh)) `catch` openDictHandler

openDictHandler :: IOError -> IO (Maybe Handle)
openDictHandler e = do
  putStrLn $ "[ERR] Could not open given dictionary: " ++ (show e)
  if isPrefixOf (defaultDictionary++":") (show e) then return Nothing -- give up
  else do
    putStrLn $ "[INF] Trying to open default dictionary: " ++ defaultDictionary
    (tryOpenDict defaultDictionary) `catch` openDictHandler


-- testing ...
data Sample = Sample { grid :: Maybe FilePath, dict :: Maybe FilePath }
  deriving (Generic, Show)
instance ParseRecord Sample

main = do
  args <- getRecord "Challennge #076 - Task #2"
  let sample = args :: Sample
      gridPath = case (grid sample) of
                   Nothing -> "grid.txt"
                   Just gp -> gp
      dictPath = case (dict sample) of
                   Nothing -> defaultDictionary
                   Just dp -> dp
    in do
    rawData <- readFile gridPath
    putStrLn $ "Grid Contents:\n" ++ rawData
    let gridWords = (wordTreeGetAllWords
                    .wordTreeFromGridData
                    .gridDataFromString) rawData
      in do
      maybeDictFh <- tryOpenDict dictPath
      case maybeDictFh of
        Nothing -> do
          putStrLn "[WRN] Dictionary not available: could not match anytying."
        Just dictFh -> do
          matchedWords <- grepMatchedWord dictFh gridWords
          print matchedWords
          putStrLn $ "\nTotal "
            ++ (show (length matchedWords)) ++ " word(s) found."
          hClose dictFh

-- ok...
