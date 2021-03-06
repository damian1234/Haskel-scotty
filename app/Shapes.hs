{-# LANGUAGE OverloadedStrings #-}


module Shapes(
  Shape, Point, Vector(..), Transform, Drawing, Boarder,
  point, getX, getY,
  empty, Shapes.circle, square,boarder,
  identity, Shapes.translate, Shapes.myRotate, Shapes.scale, (<+>),
  inside,bldSvg)  where

import Ansi
import Text.Blaze (toMarkup)
import Text.Blaze.Svg  hiding (title, matrix)
import Text.Blaze.Svg11 as SV11 hiding (title, matrix)
import Text.Blaze.Svg11.Attributes as SV11A hiding (title, matrix)
import Text.Blaze.Internal as I hiding (matrix, Empty)


-- Utilities

data Vector = Vector Double Double
              deriving (Show, Read)
vector = Vector

cross :: Vector -> Vector -> Double
cross (Vector a b) (Vector a' b') = a * a' + b * b'

mult :: Matrix -> Vector -> Vector
mult (Matrix r0 r1) v = Vector (cross r0 v) (cross r1 v)

invert :: Matrix -> Matrix
invert (Matrix (Vector a b) (Vector c d)) = matrix (d / k) (-b / k) (-c / k) (a / k)
  where k = a * d - b * c
        
-- 2x2 square matrices are all we need.
data Matrix = Matrix Vector Vector
              deriving (Show, Read)

matrix :: Double -> Double -> Double -> Double -> Matrix
matrix a b c d = Matrix (Vector a b) (Vector c d)

getX (Vector x y) = x
getY (Vector x y) = y

-- Shapes

type Point  = Vector

point :: Double -> Double -> Point
point = vector


data Shape = Empty 
           | Circle 
           | Square
             deriving (Show, Read)

empty, circle, square :: Shape

empty = Empty
circle = Circle
square = Square

-- Transformations

data Transform = Identity
           | Translate Vector
           | Scale Vector
           | Compose Transform Transform
           | Rotate Matrix
           | MyRotate Double
             deriving (Show, Read)



identity = Identity
translate = Translate
scale = Scale
rotate angle = Rotate $ matrix (cos angle) (-sin angle) (sin angle) (cos angle)
t0 <+> t1 = Compose t0 t1

transform :: Transform -> Point -> Point
transform Identity                   x = id x
transform (Translate (Vector tx ty)) (Vector px py)  = Vector (px - tx) (py - ty)
transform (Scale (Vector tx ty))     (Vector px py)  = Vector (px / tx)  (py / ty)
transform (Rotate m)                 p = (invert m) `mult` p
transform (Compose t1 t2)            p = Shapes.transform t2 $ Shapes.transform t1 p


------------------- my code starts here ----------------------

--boarder is apart of style. this describes the size and colour of the boarder for the described shape

data Boarder = Boarder Colour Double
               deriving (Show,Read)
boarder :: Colour-> Double -> Boarder
boarder = Boarder

--the style of the shape is the details of it's boarder and then the colour of the shape itself

type Style = (Colour, Boarder)


--ShapeDesc Shape in question, size(radius of cirlce or side of a square, x and y coordinates follow

type ShapeDesc = (Shape, Double,Double,Double)
--drawWrapper f (x:xs) = (mappend (f x) (drawWrapper xs))

type Drawing = [(Transform,ShapeDesc,Style)]
--
bldSvg :: [Drawing] -> Svg
bldSvg xs = svg! width "1000"! height "1000" $ (sequence_ (bldLst xs))

--buld list of svg's, this can take 1 or multiple drawing descriptions and return an Svg


bldLst :: [Drawing] -> [Svg]
bldLst xs = map svgdesc xs

--svgdesc takes a drawing and builds an svg using my interpretation function.

svgdesc :: Drawing -> Svg
svgdesc [(t,s,(c,b))] = myShape s ! stroke (boarderColour b) ! strokeWidth (boarderSize b)! fill (myColour c) !SV11A.transform(myTransform t)
--SV11A.transform(myTransform t)
-- convert takes a numerical value converts it to a String so it can be returned as an AttributeValue for the Svg being built

convert :: (Show a) => a -> SV11.AttributeValue
convert x = (I.stringValue (show x))

-- my version of rotate without matrix parameter, this was needed as the original rotate passed a matrix as the rotate parameter 
myRotate ang = MyRotate ang

-- takes a boarder description to return the size of the boarder as an AttributeValue
boarderSize :: Boarder -> SV11.AttributeValue
boarderSize (Boarder _ s) = toValue s

-- returns the colour of the boarder as an attributeValue
boarderColour :: Boarder -> SV11.AttributeValue
boarderColour (Boarder c _) = myColour c

-- interpretation functions for my transformations
-- these will the take the transformation and return the Svg interpretation for the given transformation
myTransform :: Shapes.Transform -> SV11.AttributeValue
myTransform (Scale (Vector x y)) = SV11.scale x y
myTransform (Translate (Vector x y)) = SV11.translate x y
myTransform (MyRotate ang) = SV11.rotate ang
myTransform (Compose t1 t2) = (mappend (myTransform t1) (myTransform t2))


-- interpretations for a shape. returns the shapes with default start coordinates and the size for the shape
-- circle takes a radius and square will also take 1 param for size  since each side is the same size
myShape :: ShapeDesc -> Svg
myShape (Circle, rad, x, y) = SV11.circle! cx "50"! cy "50"! r (convert rad)  
myShape (Square, s, x, y) = SV11.rect! cx "50"! cy "50" ! width (convert s)! height (convert s)

---------------colour interpretation-----------------
-- interpretation for colour that take an Ansi colour and returns an AttributeValues of the colour
myColour :: Colour -> SV11.AttributeValue
myColour Blue = "blue"
myColour Black = "black"
myColour Red = "red"
myColour Green = "green"
myColour Yellow = "yellow"
myColour Magenta = "magenta"
myColour Cyan = "cyan"
myColour White = "white"


-----------------my code ends here -------------------
-----------------------------------------------------
-- interpretation function for drawings
inside :: Point -> Drawing -> Bool
inside p d = or $ map (inside1 p) d

inside1 :: Point -> (Transform, ShapeDesc,Style) -> Bool
inside1 p (t,(s,_,_,_),_) = insides (Shapes.transform t p) s

insides :: Point -> Shape -> Bool
p `insides` Empty = False
p `insides` Circle = distance p <= 1
p `insides` Square = maxnorm  p <= 1


distance :: Point -> Double
distance (Vector x y ) = sqrt ( x**2 + y**2 )

maxnorm :: Point -> Double
maxnorm (Vector x y ) = max (abs x) (abs y)
