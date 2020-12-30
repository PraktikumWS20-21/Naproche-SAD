{-
Authors: Andrei Paskevich (2001 - 2008), Steffen Frerix (2017 - 2018)

Main text reading functions.
-}

{-# OPTIONS_GHC -fno-warn-incomplete-patterns #-}
{-# LANGUAGE OverloadedStrings #-}

module SAD.Import.Reader (readInit, readProofText) where

import Data.Maybe
import Control.Monad
import System.IO.Error
import Control.Exception
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as Text

import SAD.Data.Text.Block
import SAD.Data.Instr as Instr
    ( Argument(Text, ReadTex, File, Read),
      Instr(GetArgument),
      Pos,
      position )
import SAD.ForTheL.Base
import SAD.ForTheL.Structure
import SAD.Parser.Base
import SAD.ForTheL.Instruction
import SAD.Core.SourcePos
import SAD.Parser.Token
import SAD.Parser.Combinators
import SAD.Parser.Primitives
import SAD.Parser.Error
import qualified SAD.Core.Message as Message
import qualified Isabelle.File as File


-- Init file parsing

readInit :: Text -> IO [(Pos, Instr)]
readInit "" = return []
readInit file = do
  input <- catch (File.read (Text.unpack file)) $ Message.errorParser (fileOnlyPos file) . ioeGetErrorString
  let tokens = filter isProperToken $ tokenize TexDisabled (filePos file) $ Text.pack input
      initialParserState = State (initFS Nothing) tokens NonTex noSourcePos
  fst <$> launchParser instructionFile initialParserState

instructionFile :: FTL [(Pos, Instr)]
instructionFile = after (optLL1 [] $ chainLL1 instr) eof


-- Reader loop

-- | @readProofText startWithTex pathToLibrary text0@ takes:
-- @startWithTex@, a boolean indicating whether to execute the next file instruction using the tex parser,
-- @pathToLibrary@, a path to where the read instruction should look for files and
-- @text0@, containing some configuration.
readProofText :: Bool -> Text -> [ProofText] -> IO [ProofText]
readProofText startWithTex pathToLibrary text0 = do
  pide <- Message.pideContext
  let initialParserKind = if startWithTex then Tex else NonTex
  (text, reports) <- reader pathToLibrary [] [State (initFS pide) noTokens NonTex noSourcePos] text0 (Just initialParserKind)
  when (isJust pide) $ Message.reports reports
  return text

reader :: Text -> [Text] -> [State FState] -> [ProofText] -> Maybe ParserKind -> IO ([ProofText], [Message.Report])
reader pathToLibrary doneFiles = go
  where
    go stateList [ProofTextInstr pos (GetArgument Read file)] _ = if ".." `Text.isInfixOf` file
      then Message.errorParser (Instr.position pos) ("Illegal \"..\" in file name: " ++ show file)
      else go stateList [ProofTextInstr pos $ GetArgument File $ pathToLibrary <> "/" <> file] (Just NonTex)
    
    go stateList [ProofTextInstr pos (GetArgument ReadTex file)] _ = if ".." `Text.isInfixOf` file
      then Message.errorParser (Instr.position pos) ("Illegal \"..\" in file name: " ++ show file)
      else go stateList [ProofTextInstr pos $ GetArgument File $ pathToLibrary <> "/" <> file] (Just Tex)

    go (pState:states) [ProofTextInstr pos (GetArgument File file)] parserKind'
      | file `elem` doneFiles = do
          when (Just (parserKind pState) /= parserKind')
            (Message.errorParser (Instr.position pos) "Trying to read a file once in Tex format and once in NonTex format.")
          Message.outputMain Message.WARNING (Instr.position pos)
            ("Skipping already read file: " ++ show file)
          (newProofText, newState) <- chooseParser pState
          go (newState:states) newProofText Nothing

    go (pState:states) [ProofTextInstr _ (GetArgument File file)] parserKind = do
      text <-
        catch (if Text.null file then getContents else File.read $ Text.unpack file)
          (Message.errorParser (fileOnlyPos file) . ioeGetErrorString)
      let parserKind' = fromMaybe (error "this shouldn't ever happen") parserKind
      (newProofText, newState) <- reader0 (filePos file) (Text.pack text) (pState {parserKind = parserKind'})
      -- state from before reading is still here!!
      reader pathToLibrary (file:doneFiles) (newState:pState:states) newProofText parserKind

    -- We read text instructions with NonTex parser!!!
    go (pState:states) [ProofTextInstr _ (GetArgument Text text)] _ = do
      (newProofText, newState) <- reader0 startPos text (pState {parserKind = NonTex})
      go (newState:pState:states) newProofText Nothing -- state from before reading is still here!!

    -- This sais that we are only really processing the last instruction in a [ProofText].
    go stateList (t:restProofText) parserKind = do
      (ts, ls) <- go stateList restProofText parserKind
      return (t:ts, ls)

    go (pState:oldState:rest) [] _ = do
      Message.outputParser Message.TRACING
        (if null doneFiles then noSourcePos else fileOnlyPos $ head doneFiles) "parsing successful"
      let resetState = oldState {
            stUser = (stUser pState) {tvrExpr = tvrExpr $ stUser oldState}}
      -- Continue running a parser after eg. a read instruction was evaluated.
      (newProofText, newState) <- chooseParser resetState
      go (newState:rest) newProofText Nothing

    go (state:_) [] _ = return ([], reports $ stUser state)

reader0 :: SourcePos -> Text -> State FState -> IO ([ProofText], State FState)
reader0 pos text pState = do
  let tokens0 = chooseTokenizer pState pos text
  Message.reports $ mapMaybe reportComments tokens0
  let tokens = filter isProperToken tokens0
      st = State ((stUser pState) { tvrExpr = [] }) tokens (parserKind pState) noSourcePos
  chooseParser st


chooseParser :: State FState -> IO ([ProofText], State FState)
chooseParser st = case parserKind st of
  Tex -> launchParser texForthel st
  NonTex -> launchParser forthel st

chooseTokenizer :: State FState -> SourcePos -> Text -> [Token]
chooseTokenizer st | parserKind st == Tex = tokenize OutsideForthelEnv
chooseTokenizer st | parserKind st == NonTex = tokenize TexDisabled

-- launch a parser in the IO monad
launchParser :: Parser st a -> State st -> IO (a, State st)
launchParser parser state =
  case runP parser state of
    Error err -> Message.errorParser (errorPos err) (show err)
    Ok [PR a st] -> return (a, st)
