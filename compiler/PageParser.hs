module PageParser (parseProgFile) where

import PageSyntax
import Control.Applicative
import Control.Monad
import Data.Char
import Text.ParserCombinators.Parsec hiding (many, option, (<|>))
import Text.ParserCombinators.Parsec.Expr
import Text.ParserCombinators.Parsec.Language
import qualified Text.ParserCombinators.Parsec.Token as T
import qualified Data.Map as Map
  
page = T.makeTokenParser $ emptyDef
  { commentLine      = "--"
  , nestedComments   = False
  , identStart       = letter
  , identLetter      = alphaNum
  , opStart          = opLetter haskellStyle
  , opLetter         = oneOf "+-*/=<>;:|@.^~?"
  , reservedNames    = ["skip", "tick", "if", "then", "else", "halt",
                        "goto", "acquire", "release", "print", "while",
                        "inv", "declare", "in", "reg", "label", "fork",
                        "lock", "of", "fetch", "ram", "from", "to",
                        "data", "push", "pop", "top", "bits",
                        "end", "do", "return", "load", "rom", "opt",
                        "cond"
                       ]
  , caseSensitive    = True
  }
  
identifier = T.identifier page
reservedOp = T.reservedOp page
reserved = T.reserved page
natural = T.natural page
parens = T.parens page
semi = T.semi page
comma = T.comma page
braces = T.braces page
brackets = T.brackets page
symbol = T.symbol page
operator = T.operator page
charLiteral = T.charLiteral page
stringLiteral = T.stringLiteral page
lexeme = T.lexeme page
whitespace = T.whiteSpace page

-- Expressions

expBinOp op f assoc = Infix (reservedOp op >> return (Apply2 f)) assoc

expUnOp op f = Prefix (reservedOp op >> return (Apply1 f))
  
opTable =
  [ [ expUnOp "~" Inv ]
  , [ expBinOp "*" Mul AssocLeft, expBinOp "/" Div AssocLeft
    , expBinOp "&" And AssocLeft ]
  , [ expBinOp "+" Add AssocLeft, expBinOp "-" Sub AssocLeft
    , expBinOp "|" Or AssocLeft  ]
  , [ expBinOp "==" Eq AssocNone, expBinOp "/=" Neq AssocNone
    , expBinOp "<" Lt AssocNone , expBinOp "<=" Lte AssocNone
    , expBinOp ">" Gt AssocNone , expBinOp ">=" Gte AssocNone
    ]
  , [ Infix (reservedOp "." >> return Concat) AssocLeft ]
  ]

expr :: Parser Exp
expr = buildExpressionParser opTable expr'

expr' :: Parser Exp
expr' = pure (Lit Nothing) <*> natural
    <|> pure Var <*> var
    <|> pure Ptr <*> (reservedOp "^" *> var)
    <|> pure Lab <*> stmtLabel
    <|> (pure RamOutput <* reserved "data" <* reservedOp "(") <*>
          var <*> (reservedOp ":" *> ramPort <* reservedOp ")")
    <|> pure Select <*> (reserved "bits" *> nat)
                    <*> (reserved "to" *> nat)
                    <*> (reserved "of" *> expr)
    <|> pure Cond <*> (reserved "cond" *> reservedOp "(" *> expr)
                  <*> (reservedOp "," *> expr)
                  <*> (reservedOp "," *> expr <* reservedOp ")")
    <|> parens expr

var :: Parser Id
var =
  do v <- identifier
     if isLower (head v)
       then return v
       else unexpected (show v) <?> "variable"
 
stmtLabel :: Parser Id
stmtLabel = lexeme (return (:) `ap` char '#' `ap` identifier)

-- Statements

stmBinOp op f assoc = Infix (reservedOp op >> return f) assoc

stmtOpTable =
  [ [ stmBinOp "||" (\x y -> Par [x, y]) AssocLeft ]
  , [ stmBinOp ";" (:>) AssocLeft ]
  ]

stmt :: Parser Stm
stmt = buildExpressionParser stmtOpTable stmt'

stmt' :: Parser Stm
stmt'  = pure Skip <* reserved "skip"
     <|> pure Tick <* reserved "tick"
     <|> pure IndAssign <*> (reservedOp "^" *> var)
                        <*> (reservedOp ":=" *> expr)
     <|> assign
     <|> pure Ifte <*> (reserved "if" *> expr)
                   <*> (reserved "then" *> stmt)
                   <*> (reserved "else" *> stmt <* reserved "end")
     <|> pure While <*> (reserved "while" *> expr <* reserved "do")
                    <*> (stmt <* reserved "end")
     <|> pure (\l s -> Label l :> s) <*> (stmtLabel <* reservedOp ":")
                                     <*> stmt
     <|> goto
     <|> pure ForkJump <*> (reserved "fork" *> stmtLabel)
--   <|> pure Acquire <*> (reserved "acquire" *> var) <*> return Nothing
     <|> pure Release <*> (reserved "release" *> var)
     <|> pure Print <*> (reserved "print" *> var)
     <|> pure Fetch <*> (reserved "fetch" *> var)
                    <*> (reservedOp ":" *> ramPort)
                    <*> brackets expr
     <|> pure LoadRom <*> (reserved "load" *> var)
                      <*> (var <* reservedOp ":")
                      <*> var
                      <*> brackets expr
     <|> pure Push <*> (reserved "push" *> var) <*> many1 var
     <|> pure Pop <*> (reserved "pop" *> var) <*> many1 var
     <|> pure Halt <* reserved "halt"
     <|> parens stmt

goto =
  do reserved "goto"
     arg <- stmtLabel <|> var
     return (if head arg == '#' then Jump arg else IndJump arg)

assign =
  do v <- var
     m <- optionMaybe (reservedOp ":")
     case m of
       Nothing -> pure (v :=) <*> (reservedOp ":=" *> expr)
       Just _  -> pure (Store v) <*> ramPort <*>
                    brackets expr <*> (reservedOp ":=" *> expr)

ramPort = (string "A" *> return A) <|> (string "B" *> return B)

-- Declarations

decl :: Parser Decl
decl = pure Decl <*> (reserved "var" *> var <* reserved ":")
                 <*> typ <*> initial

initial :: Parser Init
initial =
  do m <- optionMaybe (reserved ":=")
     case m of
       Nothing -> return Uninit
       Just _  ->
            pure IntInit <*> natural
        <|> pure StrInit <*> stringLiteral

typ :: Parser Type
typ = pure TReg <*> (reserved "reg" *> nat)
  <|> pure (`TPtr` []) <*> (reserved "ptr" *> nat)
  <|> pure (TLab []) <* reserved "label"
  <|> pure TLock <* reserved "lock"
  <|> pure TRom <*> (reserved "rom" *> nat) <*> nat
  <|> do reserved "ram"
         m <- optionMaybe (reservedOp "<")
         case m of
           Nothing -> pure TRam <*> nat <*> nat
           Just _  -> do
             aw1 <- nat
             reservedOp "->"
             dw1 <- nat
             reservedOp ">"
             reservedOp "<"
             aw2 <- nat
             reservedOp "->"
             dw2 <- nat
             reservedOp ">"
             return (TMWRam aw1 dw1 aw2 dw2)

nat :: Parser Int
nat = pure fromIntegral <*> natural

log2 :: Integral a => a -> a
log2 n = if n == 1 then 0 else 1 + log2 (n `div` 2)
 
-- Parse a compiler option

compilerOpt :: Parser CompilerOpts
compilerOpt =
  do reserved "opt"
     key <- identifier
     reserved "="
     val <- natural
     return (Map.fromList [(key, val)])
   
-- Parse program prelude

prelude :: Parser (CompilerOpts, [Decl])
prelude =
  do items <- many preludeItem
     let (opts, decls) = unzip items
     return (Map.unions opts, concat decls)

preludeItem :: Parser (CompilerOpts, [Decl])
preludeItem =
      do { o <- compilerOpt ; return (o, []) }
  <|> do { d <- decl ; return (Map.empty, [d]) }

-- Programs

prog :: Parser Prog
prog =
  do whitespace
     (opts, ds) <- prelude
     s <- stmt
     return (Prog opts ds s)

parseProgFile :: SourceName -> IO Prog
parseProgFile f = parseFromFile (prog <* eof) f >>= \result ->
  case result of
    Left e  -> error . show $ e
    Right p -> return p
