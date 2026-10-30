# Haskell Code Patterns

Conventions for Haskell formal verification code. Author details read from env vars at runtime.

## Module Structure

```haskell
{-|
Module      : TopicName.ModuleName
Description : Brief description of the module
Copyright   : (c) $RESEARCH_AUTHOR_NAME, [current year]
License     : MIT
Maintainer  : $RESEARCH_AUTHOR_EMAIL
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

## QuickCheck Properties Pattern

```haskell
module TopicName.Properties where

import Test.QuickCheck
import TopicName.Core

-- | Arbitrary instance for custom types
instance Arbitrary MyType where
  arbitrary = MyType <$> arbitrary <*> arbitrary

-- | Property corresponding to Theorem 3.1 in the paper
-- "For all x in the category, id . f = f"
prop_leftIdentity :: MyMorphism -> Property
prop_leftIdentity f = compose identity f === f

-- | Property corresponding to Proposition 4.2
-- "Functor preserves composition"
prop_functorComposition :: Morphism -> Morphism -> Property
prop_functorComposition f g =
  fmap' (compose g f) === compose (fmap' g) (fmap' f)

-- | Run all properties with verbose output
runAllProperties :: IO Bool
runAllProperties = do
  putStrLn "=== QuickCheck Property Verification ==="
  results <- sequence
    [ check "Theorem 3.1 (left identity)" prop_leftIdentity
    , check "Proposition 4.2 (functor composition)" prop_functorComposition
    ]
  let passed = length (filter id results)
      total = length results
  putStrLn $ show passed ++ "/" ++ show total ++ " properties passed"
  return (and results)
  where
    check name prop = do
      putStr $ "  " ++ name ++ "... "
      result <- quickCheckResult prop
      case result of
        Success{} -> putStrLn "OK" >> return True
        _         -> putStrLn "FAILED" >> return False
```

## Equational Reasoning Pattern

```haskell
module TopicName.Proofs where

-- | Equational proof: f (g x) = h x
--
-- Proof:
--   f (g x)
-- = { definition of g: g x = x + 1 }
--   f (x + 1)
-- = { definition of f: f y = y * 2 }
--   (x + 1) * 2
-- = { definition of h: h x = (x + 1) * 2 }
--   h x
-- QED

-- Executable check for the above proof
proofCheck_fgEqualsH :: Int -> Either String ()
proofCheck_fgEqualsH x
  | f (g x) == h x = Right ()
  | otherwise = Left $ "Failed at x=" ++ show x
    ++ ": f(g(" ++ show x ++ "))=" ++ show (f (g x))
    ++ " but h(" ++ show x ++ ")=" ++ show (h x)

-- | Run all proof checks
runAllProofs :: IO Bool
runAllProofs = do
  putStrLn "=== Equational Reasoning Proofs ==="
  let testValues = [-100..100]  -- concrete values to check
      results = map proofCheck_fgEqualsH testValues
      failures = [e | Left e <- results]
  if null failures
    then putStrLn "  All proofs verified" >> return True
    else do
      mapM_ (\e -> putStrLn $ "  FAIL: " ++ e) failures
      return False
```

## Liquid Haskell Annotations Pattern

```haskell
-- Refinement types (checked by Liquid Haskell if available)
{-@ type Probability = {v:Double | v >= 0.0 && v <= 1.0} @-}
{-@ type NonNeg = {v:Int | v >= 0} @-}
{-@ type Pos = {v:Int | v > 0} @-}
{-@ type NonEmpty a = {v:[a] | len v > 0} @-}

{-@ measure len @-}
{-@ len :: [a] -> Nat @-}
len :: [a] -> Int
len [] = 0
len (_:xs) = 1 + len xs

{-@ normalize :: [Double] -> {v:[Double] | len v > 0} @-}
{-@ bornRule :: Observable -> HilbertState -> Probability @-}
```

## Main.hs Pattern (with verification)

```haskell
module Main where

import TopicName.Core
import TopicName.Properties (runAllProperties)
import TopicName.Proofs (runAllProofs)
import System.Exit (exitFailure, exitSuccess)

main :: IO ()
main = do
  putStrLn "=== TopicName: Formal Verification ==="
  putStrLn ""

  -- Demonstrations
  putStrLn "--- Demonstrations ---"
  demo1
  demo2
  putStrLn ""

  -- QuickCheck properties
  propsOk <- runAllProperties
  putStrLn ""

  -- Equational proofs
  proofsOk <- runAllProofs
  putStrLn ""

  -- Summary
  if propsOk && proofsOk
    then putStrLn "All verifications passed." >> exitSuccess
    else putStrLn "VERIFICATION FAILURES DETECTED." >> exitFailure
```

## Required Module Structure

```
src/$TOPIC/
├── Main.hs          -- Entry point: demos + all verification
├── Core.hs          -- Core types and functions from the paper
├── Properties.hs    -- QuickCheck properties (one per theorem)
└── Proofs.hs        -- Equational reasoning proofs with executable checks
```

## Quality Standards

1. **Type signatures on ALL top-level bindings** — no exceptions
2. **Explicit export lists** — no bare `module Foo where`
3. **No incomplete pattern matches** — handle all cases
4. **Compile with `-Wall -Wextra -Werror`** — zero warnings
5. **QuickCheck property per major theorem** — minimum coverage
6. **Equational proof per key derivation** — cite paper theorem numbers
7. **Liquid Haskell annotations** on safety-critical functions (if LH available)
8. **Haddock documentation** — link to paper theorem numbers
9. **Main.hs exits non-zero on verification failure**

## Compilation

```bash
# Strict compilation
ghc -Wall -Wextra -Werror -o test Main.hs -i. -package QuickCheck

# Run verification (exits non-zero on failure)
./test

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
import System.Exit (exitFailure, exitSuccess)
import Test.QuickCheck
```
