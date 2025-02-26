module Test.MySolutions where

import Prelude
import Control.Alt ((<|>))
import Data.Generic.Rep (class Generic)
import Data.Show.Generic (genericShow)
import Data.Function.Uncurried (Fn3)
import Data.Bifunctor (lmap)
import Data.Pair (Pair (..)) as NativePair
import Data.Maybe (Maybe (..))
import Data.Either (Either (..))
import Data.Int (trunc)
import Data.Map (Map)
import Data.Set (Set)
import Data.Tuple (Tuple (..))
import Data.Argonaut.Core (Json)
import Data.Argonaut.Parser (jsonParser)
import Data.Argonaut.Decode (class DecodeJson, decodeJson)
import Data.Argonaut.Decode.Generic (genericDecodeJson)
import Data.Argonaut.Decode.Decoders (decodeTuple, decodeInt, decodeNumber, decodeString)
import Data.Argonaut.Decode.Error (JsonDecodeError)
import Data.Argonaut.Encode (class EncodeJson, encodeJson)
import Data.Argonaut.Encode.Generic (genericEncodeJson)
import Data.Argonaut.Encode.Encoders (encodeInt, encodeString)
import Test.Examples (Quadratic, Complex, Undefined, isUndefined)

type Comp = { real :: Number
            , imag :: Number }

newtype Pair a = Pair (NativePair.Pair a)

toNativePair :: forall a. Pair a  -> NativePair.Pair a
toNativePair (Pair (NativePair.Pair x y)) = NativePair.Pair x y

instance DecodeJson a => DecodeJson (Pair a) where
  decodeJson :: Json -> Either JsonDecodeError (Pair a)
  decodeJson j = toPair <$> decodeTuple decodeJson decodeJson j where
        toPair :: Tuple a a -> Pair a
        toPair (Tuple x y) = Pair (NativePair.Pair x y)

foreign import volumeFn :: Fn3 Number Number Number Number
foreign import volumeArrow :: Number -> Number -> Number -> Number
foreign import cumulativeSumsComplex :: Array Comp -> Array Comp
foreign import quadraticRootsImpl :: forall a. (a -> a -> NativePair.Pair a) -> Quadratic -> NativePair.Pair Complex
foreign import toMaybeImpl :: forall a. (forall b. b -> Maybe b) -> (forall b. Maybe b) -> (Undefined a -> Boolean) -> Undefined a -> Maybe a
foreign import valuesOfMapJson :: Json -> Json
foreign import quadraticRootsSetJson :: Json -> Json

quadraticRoots :: Quadratic -> NativePair.Pair Complex
quadraticRoots = quadraticRootsImpl NativePair.Pair

toMaybe :: forall a. Undefined a -> Maybe a
toMaybe x = toMaybeImpl Just Nothing isUndefined x

-- maybeHead using toMaybe is better because it uses more purescript side code than javascript side code, and purescript have type signatures, so it's more constrained

passThrough :: forall a b. DecodeJson b => EncodeJson a => (Json -> Json) -> a -> Either JsonDecodeError b
passThrough fn = decodeJson <<< fn <<< encodeJson

valuesOfMap :: Map String Int -> Either JsonDecodeError (Set Int)
valuesOfMap = passThrough valuesOfMapJson

valuesOfMapGeneric :: forall k v. Ord k => Ord v => EncodeJson k => EncodeJson v => DecodeJson v => Map k v -> Either JsonDecodeError (Set v)
valuesOfMapGeneric = passThrough valuesOfMapJson

quadraticRootsSet :: Quadratic -> Either JsonDecodeError (Set Complex)
quadraticRootsSet = passThrough quadraticRootsSetJson

-- using the same FFI because sets of 2 and tuples have same rep on json
quadraticRootsSafe :: Quadratic -> Either JsonDecodeError (NativePair.Pair Complex)
quadraticRootsSafe q = toNativePair <$> passThrough quadraticRootsSetJson q

replaceLeft :: forall a b c. c -> Either a b -> Either c b
replaceLeft = lmap <<< const

parseAndDecodeArray2D :: String -> Either String (Array (Array Int))
parseAndDecodeArray2D s = do
  json <- jsonParser s
  replaceLeft s $ decodeJson json

data Tree a = Leaf a | Branch (Tree a) (Tree a)

derive instance Eq a => Eq (Tree a)
derive instance Generic (Tree a) _
instance Show a => Show (Tree a) where
  show c = genericShow c
instance DecodeJson a => DecodeJson (Tree a) where
  decodeJson c = genericDecodeJson c
instance EncodeJson a => EncodeJson (Tree a) where
  encodeJson c = genericEncodeJson c

data IntOrString = IntOrString_Int Int | IntOrString_String String
derive instance Eq IntOrString
derive instance Generic IntOrString _
instance Show IntOrString where
  show = genericShow
instance DecodeJson IntOrString where
  decodeJson j =     (IntOrString_Int <$> decodeJson j)
                 <|> (IntOrString_String <$> decodeJson j)
                 <|> genericDecodeJson j
instance EncodeJson IntOrString where
  encodeJson (IntOrString_Int i)    = encodeJson i
  encodeJson (IntOrString_String s) = encodeJson s
