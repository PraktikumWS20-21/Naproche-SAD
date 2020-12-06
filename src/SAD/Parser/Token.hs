{-
Authors: Andrei Paskevich (2001 - 2008), Steffen Frerix (2017 - 2018)

Tokenization of input.
-}

{-# LANGUAGE NamedFieldPuns #-}

module SAD.Parser.Token
  ( Token (tokenPos, tokenText),
    tokenEndPos,
    tokensRange,
    showToken,
    properToken,
    tokenize,
    tokenReports,
    composeTokens,
    isEOF,
    noTokens)
  where

import Data.Char
import Data.List

import SAD.Core.SourcePos
import qualified SAD.Core.Message as Message
import qualified Isabelle.Markup as Markup


data Token =
  Token {
    tokenText :: String,
    tokenPos :: SourcePos,
    tokenWhiteSpace :: Bool,
    tokenProper :: Bool} |
  EOF {tokenPos :: SourcePos}

makeToken s pos ws proper =
  Token s (rangePos (pos, advancesPos pos s)) ws proper

tokenEndPos :: Token -> SourcePos
tokenEndPos tok@Token{} = advancesPos (tokenPos tok) (tokenText tok)
tokenEndPos tok@EOF {} = tokenPos tok

tokensRange :: [Token] -> SourceRange
tokensRange toks =
  if null toks then noRange
  else makeRange (tokenPos $ head toks, tokenEndPos $ last toks)

showToken :: Token -> String
showToken t@Token{} = tokenText t
showToken EOF{} = "end of input"

properToken :: Token -> Bool
properToken Token {tokenProper} = tokenProper
properToken EOF {} = True

noTokens :: [Token]
noTokens = [EOF noPos]


-- tokenize

tokenize :: SourcePos -> String -> [Token]
tokenize start = posToken start False
  where
    -- put LaTeX comments from % to end of line into a "False token"  
    posToken pos ws s@('%':_) =
      makeToken comment pos False False : posToken (advancesPos pos comment) ws rest
      where (comment, rest) = break (== '\n') s
   
   -- drop \section commands
    posToken pos ws s@('\\':'s':'e':'c':'t':'i':'o':'n':'{':_) =
      makeToken sec pos False False : posToken (advancesPos pos ('a':sec)) ws (tail rest)
      where (sec, rest) = break (== '}') s
         
    -- make alphanumeric tokens 
    posToken pos ws s
      | not (null lexem) =
          makeToken lexem pos ws True : posToken (advancesPos pos lexem) False rest
      where (lexem, rest) = span isLexem s
    
    -- make alphabetic tokens from LaTeX commands  
    posToken pos ws ('\\':s)
      | not (null alpha) =
          makeToken alpha pos ws True : posToken (advancesPos pos ('\\':alpha)) False rest
      where (alpha, rest) = span isAlpha s
    
    -- drop LaTeX "\\" line breaks  
    posToken pos ws ('\\':'\\':s) =
      posToken (advancesPos pos "\\\\") False s

    -- drop LaTeX "\ " spaces
    posToken pos ws ('\\':' ':s) =
      posToken (advancesPos pos "\\ ") False s

    -- drop whitespace
    posToken pos _ s
      | not (null white) = posToken (advancesPos pos white) True rest
      where (white, rest) = span isSpace s
    
    -- eliminate $-signs
    posToken pos ws ('$':cs) =
      posToken (advancePos pos '$') False cs
    
    -- eliminate other \-signs
    posToken pos ws ('\\':cs) =
      posToken (advancePos pos '\\') False cs

    -- put character being read into singleton token
    posToken pos ws (c:cs) =
      makeToken [c] pos ws True : posToken (advancePos pos c) False cs

    -- otherwise EOF
    posToken pos _ _ = [EOF pos]

isLexem :: Char -> Bool
isLexem c = isAscii c && isAlphaNum c


-- markup reports

tokenReports :: Token -> [Message.Report]
tokenReports Token {tokenPos = pos, tokenProper} =
  if tokenProper then []
  else [(pos, Markup.comment1)]
tokenReports _ = []


-- useful functions

composeTokens :: [Token] -> String
composeTokens [] = ""
composeTokens (t:ts) =
  let ws = if tokenWhiteSpace t then " " else ""
  in  ws ++ showToken t ++ composeTokens ts

isEOF :: Token -> Bool
isEOF EOF{} = True; isEOF _ = False




-- Show instances

instance Show Token where
  showsPrec _ (Token s p _ _) = showString s . shows p
  showsPrec _ _ = showString ""
