# Haskell Code Patterns

Conventions derived from the YonedaAI Research Collective codebase.

## Module Structure

```haskell
{-|
Module      : TopicName.ModuleName
Description : Brief description of the module
Copyright   : (c) Matthew Long, 2026
License     : MIT
Maintainer  : matthew@yonedaai.com
Stability   : experimental

Detailed description of the module's purpose and its relationship
to the research paper.
-}
module TopicName.ModuleName
  ( -- * Core Types
    TypeA(..)
  , TypeB
    -- * Key Functions
  , functionA
  , functionB
    -- * Demonstrations
  , demo
  ) where

import Data.Map (Map)
import qualified Data.Map as Map
```

## Main.hs Pattern

```haskell
module Main where

import TopicName.Module1
import TopicName.Module2

main :: IO ()
main = do
  putStrLn "=== Topic Name: Formal Verification ==="
  putStrLn ""

  putStrLn "--- Demonstration 1: [Name] ---"
  demo1

  putStrLn ""
  putStrLn "--- Demonstration 2: [Name] ---"
  demo2

  putStrLn ""
  putStrLn "All demonstrations completed successfully."
```

## Type Patterns

### Category Theory Types
```haskell
-- | A category with objects and morphisms
data Category obj mor = Category
  { objects    :: [obj]
  , morphisms  :: [(obj, obj, mor)]
  , identity   :: obj -> mor
  , compose    :: mor -> mor -> Maybe mor
  }

-- | A functor between categories
data Functor' c d = Functor'
  { objectMap   :: Object c -> Object d
  , morphismMap :: Morphism c -> Morphism d
  }

-- | Natural transformation between functors
data NatTrans f g = NatTrans
  { component :: forall a. f a -> g a
  }
```

### Quantum/Physics Types
```haskell
-- | Hilbert space element
newtype HilbertSpace a = HS { getVector :: [Complex Double] }
  deriving (Show, Eq)

-- | Observable (Hermitian operator)
newtype Observable = Observable { getMatrix :: [[Complex Double]] }
  deriving (Show)

-- | Measurement outcome
data Outcome a = Outcome
  { eigenvalue  :: Double
  , eigenstate  :: HilbertSpace a
  , probability :: Double
  } deriving (Show)
```

## Quality Standards

1. **Type signatures on ALL top-level bindings** — no exceptions
2. **Explicit export lists** — no bare `module Foo where`
3. **No incomplete pattern matches** — handle all cases or use `-Wall`
4. **Meaningful names** — avoid single-letter variables except in local lambdas/folds
5. **Haddock documentation** — at least module header and exported functions
6. **Compile with `-Wall`** — fix all warnings

## Compilation

```bash
# Single-file compilation
ghc -Wall -o test Main.hs

# Multi-file with module path
ghc -Wall -o test Main.hs -i.

# Clean build artifacts
rm -f *.o *.hi test
```

## Common Imports

```haskell
import Data.Complex (Complex(..), magnitude, conjugate)
import Data.Map (Map)
import qualified Data.Map as Map
import Data.List (intercalate, transpose, foldl')
import Control.Monad (forM_, when, unless)
import System.IO (hFlush, stdout)
```
