module Test.MySolutions where

import Prelude

import Control.Apply (lift2, lift4)
import Data.AddressBook (Address, Person, PhoneNumber, address, person)
import Data.AddressBook.Validation (Errors, matches, nonEmpty, validateAddress, validatePhoneNumbers)
import Data.Foldable (class Foldable, foldMap, foldl, foldr)
import Data.Generic.Rep (class Generic)
import Data.Maybe (Maybe(..))
import Data.Show.Generic (genericShow)
import Data.String.Regex (Regex)
import Data.String.Regex.Flags (noFlags)
import Data.String.Regex.Unsafe (unsafeRegex)
import Data.Traversable (class Traversable, sequence, traverse)
import Data.Validation.Semigroup (V)

addMaybe :: Maybe Int -> Maybe Int -> Maybe Int
addMaybe = lift2 (+)

subMaybe :: Maybe Int -> Maybe Int -> Maybe Int
subMaybe = lift2 (-)

mulMaybe :: Maybe Int -> Maybe Int -> Maybe Int
mulMaybe = lift2 (*)

divMaybe :: Maybe Int -> Maybe Int -> Maybe Int
divMaybe = lift2 (/)

addApply :: forall f. Apply f => f Int -> f Int -> f Int
addApply = lift2 (+)

subApply :: forall f. Apply f => f Int -> f Int -> f Int
subApply = lift2 (-)

mulApply :: forall f. Apply f => f Int -> f Int -> f Int
mulApply = lift2 (*)

divApply :: forall f. Apply f => f Int -> f Int -> f Int
divApply = lift2 (/)

-- sequence :: forall a f. Applicative f => t (f a) -> f (t a)
-- combineList :: forall f a. Applicative f => List (f a) -> f (List a)
-- combineList (Cons x xs) = Cons <$> x <*> combineList xs

-- combineList 1:2:Nil
-- combineList (Cons (Just 1) (Just 2):Nil) = (Cons <$> (Just 1)) <*> combineList (Just 2):Nil)
-- combineList (Cons (Just 1) (Just 2):Nil) = Just (\t -> Cons 1 t) <*> combineList (Just 2):Nil)
-- combineList (Cons (Just 1) (Just 2):Nil) = Just (\t -> Cons 1 t) <*> ((Cons <$> Just 2) <*> combineList Nil)
-- combineList (Cons (Just 1) (Just 2):Nil) = Just (\t -> Cons 1 t) <*> ((Cons <$> Just 2) <*> Just Nil)
-- combineList (Cons (Just 1) (Just 2):Nil) = Just (\t -> Cons 1 t) <*> Just (\t' -> Cons 2 t') <*> Just Nil)
-- combineList (Cons (Just 1) (Just 2):Nil) = Just (\t -> Cons 1 t) <*> Just (Cons 2 Nil)
-- combineList (Cons (Just 1) (Just 2):Nil) = Just (Cons 1 (Cons 2 Nil))

combineMaybe :: forall a f. Applicative f => Maybe (f a) -> f (Maybe a)
combineMaybe Nothing = pure Nothing
combineMaybe (Just x) = Just <$> x

stateRegex :: Regex
stateRegex = unsafeRegex "^[a-zA-Z]{2}$" noFlags

nonEmptyRegex :: Regex
nonEmptyRegex = unsafeRegex "\\S" noFlags

validateAddressImproved :: Address -> V Errors Address
validateAddressImproved a =
    address <$> matches "Street" nonEmptyRegex a.street
            <*> matches "City" nonEmptyRegex a.city
            <*> matches "State" stateRegex a.state

data Tree a = Leaf | Branch (Tree a) a (Tree a)

leaf ∷ ∀ (a ∷ Type). a → Tree a
leaf x = Branch Leaf x Leaf

derive instance genericTree :: Generic (Tree a) _

instance showTree :: Show a => Show (Tree a) where
    show x = genericShow x

derive instance eqTree :: Eq a => Eq (Tree a)

derive instance functorTree :: Functor Tree

instance foldableTree :: Foldable Tree where
    foldMap _ (Leaf) = mempty
    foldMap f (Branch x y z) = foldMap f x <> f y <> foldMap f z

    foldl _ xs (Leaf) = xs
    foldl fn xs (Branch x y z) = foldl fn (fn (foldl fn xs x) y ) z

    foldr _ xs (Leaf) = xs
    foldr fn xs (Branch x y z) = foldr fn (fn y $ foldr fn xs z) x

instance traversableTree :: Traversable Tree where
    sequence   (Leaf)         = pure Leaf
    sequence   (Branch x y z) = pure Branch <*> sequence x <*> y <*> sequence z
    traverse _ (Leaf)         = pure Leaf
    traverse f (Branch x y z) = pure Branch <*> traverse f x <*> f y <*> traverse f z

traversePreOrder :: forall a m b. Applicative m => (a -> m b) -> Tree a -> m (Tree b)
traversePreOrder _ (Leaf) = pure Leaf
-- traversePreOrder f (Branch x y z) = pure ob <*> f y <*> traversePreOrder f x <*> traversePreOrder f z where
--     ob xs ys zs = Branch ys xs zs
traversePreOrder f (Branch x y z) = ado
    ys <- f y
    xs <- traversePreOrder f x
    zs <- traversePreOrder f z
    in Branch xs ys zs

traversePostOrder :: forall a m b. Applicative m => (a -> m b) -> Tree a -> m (Tree b)
traversePostOrder _ (Leaf) = pure Leaf
traversePostOrder f (Branch x y z) = ado
    xs <- traversePostOrder f x
    zs <- traversePostOrder f z
    ys <- f y
    in Branch xs ys zs

type PersonOptionalAddress = {
      firstName :: String
    , lastName :: String
    , homeAddress :: Maybe Address
    , phones :: Array PhoneNumber
}

validatePersonOptionalAddress :: PersonOptionalAddress -> V Errors PersonOptionalAddress
validatePersonOptionalAddress p = ado
  firstName   <- nonEmpty "First Name" p.firstName
  lastName    <- nonEmpty "Last Name" p.lastName
  homeAddress <- traverse validateAddress p.homeAddress
  phones      <- validatePhoneNumbers "Phone Numbers" p.phones
  in { firstName, lastName, homeAddress, phones }

sequenceUsingTraverse :: forall a f t. Traversable t => Applicative f => t (f a) -> f (t a)
sequenceUsingTraverse = traverse (\y -> y)

traverseUsingSequence :: forall c d m t. Traversable t => Applicative m => (c -> m d) -> t c -> m (t d)
traverseUsingSequence f xs = sequence (f <$> xs)