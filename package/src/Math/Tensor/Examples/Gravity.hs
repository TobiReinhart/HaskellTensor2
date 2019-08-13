{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}

module Math.Tensor.Examples.Gravity (
    flatInter, interArea, interEqn5, flatArea, interEqn3, interEqn4, interEqn2, invEta,
    generic4Ansatz, generic5Ansatz, generic6Ansatz,
    generic8Ansatz, generic9Ansatz, generic10_1Ansatz, generic10_2Ansatz, generic11Ansatz, generic12_1Ansatz,
    randArea, randFlatArea, randAreaDerivative1, randAreaDerivative2, delta20, delta9, delta3,
    lorentzJ1, lorentzJ2, lorentzJ3, lorentzK1, lorentzK2, lorentzK3, etaA, randMetric,
    interMetric, interI2, randAxon, eta, interJ2,
    interIArea, interJArea, epsilonInv, epsilon, flatInterMetric,
    interEqn5Metric, interEqn4Metric, interEqn3Metric, interEqn2Metric
) where

import System.Random.TF.Instances (randomRs)
import System.Random.TF.Init (newTFGen)

import qualified Data.Map.Strict as M
import qualified Data.IntMap.Strict as I

import Data.List (permutations, nub, sort)

import Math.Tensor

--start with deltas

delta20 :: ATens 1 1 0 0 0 0 (SField Rational)
delta20 = fromListT6' $ zip [( [Ind20 i],[Ind20 i], [], [], [], []) | i <- [0..20]] (repeat $ SField 1)

delta9 :: ATens 0 0 1 1 0 0 (SField Rational)
delta9 = fromListT6' $ zip [([], [], [Ind9 i],[Ind9 i], [], []) | i <- [0..9]] (repeat $ SField 1)

delta3 :: ATens 0 0 0 0 1 1 (SField Rational)
delta3 = fromListT6' $ zip [([], [], [], [], [Ind3 i],[Ind3 i]) | i <- [0..3]] (repeat $ SField 1)

--eta and inverse eta (numerical)

eta :: ATens 0 0 0 0 0 2 (SField Rational)
eta =  fromListT6' l
            where
                l = map (\(x,y,z) -> (([],[],[],[],[],(:) (Ind3 x) $ (:) (Ind3 y) []),SField z)) [(0,0,-1),(1,1,1),(2,2,1),(3,3,1)]

invEta :: ATens 0 0 0 0 2 0 (SField Rational)
invEta =  fromListT6' l
            where
                l = map (\(x,y,z) -> (([],[],[],[],(:) (Ind3 x) $ (:) (Ind3 y) [],[]),SField z)) [(0,0,-1),(1,1,1),(2,2,1),(3,3,1)]

etaA :: ATens 0 0 0 1 0 0 (SField Rational)
etaA = fromListT6' l
            where
                l = map (\(x,y) -> (([], [], [], [Ind9 x], [], []),SField y)) [(0,-1),(4,1),(7,1),(9,1)]

--epsilon and inverse epsilon (numerical)

epsilon :: ATens 0 0 0 0 0 4 (SField Rational)
epsilon = fromListT6' $ map (\([i,j,k,l],v) -> (([], [], [], [], [], (:) (Ind3 i) $ (:) (Ind3 j) $ (:) (Ind3 k) [Ind3 l]),SField v)) epsL
                where
                   epsSign [i,j,k,l] = (-1) ^ length (filter (==True) [j>i,k>i,l>i,k>j,l>j,l>k])
                   epsL = map (\x -> (x, epsSign x)) $ permutations [0,1,2,3]

epsilonInv :: ATens 0 0 0 0 4 0 (SField Rational)
epsilonInv = fromListT6' $ map (\([i,j,k,l],v) -> (([], [], [], [], (:) (Ind3 i) $ (:) (Ind3 j) $ (:) (Ind3 k) [Ind3 l], []),SField v)) epsL
                where
                   epsSign [i,j,k,l] = (-1) ^ length (filter (==True) [j>i,k>i,l>i,k>j,l>j,l>k])
                   epsL = map (\x -> (x, epsSign x)) $ permutations [0,1,2,3]

--now the Area metric tesnors

trianMap2 :: M.Map ([Ind3]) ([Ind9])
trianMap2 = M.fromList $ zip [ (:) (Ind3 a) $ [Ind3 b] | a <- [0..3], b <- [a..3] ] $ map ((: []). Ind9) [0..]

trianMapArea :: M.Map ([Ind3]) ([Ind20])
trianMapArea = M.fromList $ zip [ (:) (Ind3 a) $ (:) (Ind3 b) $ (:) (Ind3 c) $ [Ind3 d] | a <- [0..2], b <- [a+1..3], c <- [a..2], d <- [c+1..3], not $ a == c && b > d ] $ map ((: []). Ind20) [0..]

jMult2 :: (Eq a) => [a] -> Rational
jMult2 ((:) a ((:) b []))
        | a == b = 1
        | otherwise = 1/2

jMult3 :: (Eq a) => [a] -> Rational
jMult3 ((:) a ((:) b ((:) c [])))
        | i == 1 = 1
        | i == 2 = 1/3
        | otherwise = 1/6
         where
            i = length $ nub [a,b,c]

jMultArea :: (Eq a) => [a] -> Rational
jMultArea ((:) a ((:) b ((:) c ((:) d []))))
            | a == c && b == d = 1/4
            | otherwise = 1/8

isZeroArea :: (Eq a) => [a] -> Bool
isZeroArea ((:) a ((:) b ((:) c ((:) d [])))) = a == b || c == d

areaSign :: (Eq a, Ord a) => [a] -> Rational
areaSign ((:) a ((:) b ((:) c ((:) d [])))) = s1 * s2
             where
                s1 = pairSign a b
                s2 = pairSign c d
                pairSign x y = if x < y then 1 else -1

canonicalizeArea :: (Eq a, Ord a) =>  [a] -> ([a], Rational)
canonicalizeArea ((:) a ((:) b ((:) c ((:) d [])))) = ((:) a' ((:) b' ((:) c' ((:) d' []))),s)
        where
            s = areaSign ((:) a ((:) b ((:) c ((:) d []))))
            [[a',b'],[c',d']] = sort $ map sort [[a,b],[c,d]]

interI2 :: ATens 0 0 1 0 0 2 (SField Rational)
interI2 = fromListT6' $ fmap (fmap SField) $ filter (\(i,k) -> k /= 0) $ map (\x -> (x,f x)) inds
        where
            trian2 = trianMap2
            inds = [ ([], [], [Ind9 a], [], [], (:) (Ind3 b) $ [Ind3 c]) | a <- [0..9], b <- [0..3], c <- [0..3]]
            f (_, _, ind1, _, _, ind2)
                | ind1 == (M.!) trian2 (sort ind2) = 1
                | otherwise = 0

interJ2 :: ATens 0 0 0 1 2 0 (SField Rational)
interJ2 = fromListT6' $ fmap (fmap SField) $ filter (\(i,k) -> k /= 0) $ map (\x -> (x,f x)) inds
        where
            trian2 = trianMap2
            inds = [ ([], [], [], [Ind9 a], (:) (Ind3 b) $ [Ind3 c], []) | a <- [0..9], b <- [0..3], c <- [0..3]]
            f (_, _, _, ind1, ind2, _)
                | ind1 == (M.!) trian2 (sort ind2) = jMult2 ind2
                | otherwise = 0


interIArea :: ATens 1 0 0 0 0 4  (SField Rational)
interIArea = fromListT6' $ fmap (fmap SField) $ filter (\(i,k) -> k /= 0) $ map (\x -> (x,f x)) inds
        where
            trianArea = trianMapArea
            inds = [ ([Ind20 a], [], [], [], [], (:) (Ind3 b) $ (:) (Ind3 c) $ (:) (Ind3 d) $ [Ind3 e]) | a <- [0..20], b <- [0..3], c <- [0..3], d <- [0..3], e <- [0..3], not (b == c || d == e)]
            f (ind1, _, _, _, _, ind2)
                | ind1 == (M.!) trianArea indArea = s
                | otherwise = 0
                    where
                        (indArea, s) = canonicalizeArea ind2

interJArea :: ATens 0 1 0 0 4 0 (SField Rational)
interJArea = fromListT6' $ fmap (fmap SField) $ filter (\(i,k) -> k /= 0) $ map (\x -> (x,f x)) inds
        where
            trianArea = trianMapArea
            inds = [  ([], [Ind20 a], [], [], (:) (Ind3 b) $ (:) (Ind3 c) $ (:) (Ind3 d) $ [Ind3 e], []) | a <- [0..20], b <- [0..3], c <- [0..3], d <- [0..3], e <- [0..3], not (b == c || d == e)]
            f (_, ind1, _, _, ind2, _)
                | ind1 == (M.!) trianArea indArea = s * jMultArea indArea
                | otherwise = 0
                    where
                        (indArea, s) = canonicalizeArea ind2


interMetric :: ATens 0 0 1 1 1 1 (SField Rational)
interMetric = (SField $ -2) &. contrATens3 (0,0) (interI2 &* interJ2)

interArea :: ATens 1 1 0 0 1 1 (SField Rational)
interArea = (SField $ -4) &. contrATens3 (1,1) (contrATens3 (2,2) $ contrATens3 (3,3) $ interIArea &* interJArea)

interEqn2 :: ATens 1 1 0 0 2 2 (SField Rational)
interEqn2 = int1 &- int2
        where
            int1 = interArea &* delta3
            int2 = tensorTrans6 (0,1) (delta3 &* delta3) &* delta20

interEqn2Metric :: ATens 0 0 1 1 2 2 (SField Rational)
interEqn2Metric = int1 &- int2
        where
            int1 = interMetric &* delta3
            int2 = tensorTrans6 (0,1) (delta3 &* delta3) &* delta9

interEqn3 :: ATens 1 1 1 1 1 1 (SField Rational)
interEqn3 = int1 &+ int2
        where
            int1 = interArea &* delta9
            int2 = interMetric &* delta20

interEqn3Metric :: ATens 0 0 2 2 1 1 (SField Rational)
interEqn3Metric = int1 &+ int2
        where
            int1 = interMetric &* delta9
            int2 = delta9 &* interMetric

interEqn4 :: ATens 1 1 0 1 3 1 (SField Rational)
interEqn4 = block1 &- block2
        where
            block1' = interJ2 &* interArea
            block1 = block1' &+ tensorTrans5 (1,2) block1'
            block2 = delta20 &* delta3 &* interJ2

interEqn4Metric :: ATens 0 0 1 2 3 1 (SField Rational)
interEqn4Metric = block1 &- block2
        where
            block1' = interJ2 &* interMetric
            block1 = block1' &+ tensorTrans5 (1,2) block1'
            block2 = delta3 &* interJ2 &* delta9

interEqn5 :: ATens 1 1 0 1 3 1 (SField Rational)
interEqn5 = cyclicSymATens5 [0,1,2] intA1
        where
            intA1 = interJ2 &* interArea

--derivative indices are left metric indices right !!

interEqn5Metric :: ATens 0 0 1 2 3 1 (SField Rational)
interEqn5Metric = cyclicSymATens5 [0,1,2] intA1
        where
            intA1 = interJ2 &* interMetric


--generic Ansätze up to prolongation order 2

--A
generic4Ansatz :: ATens 1 0 0 0 0 0 AnsVarR
generic4Ansatz = fromListT6' list
     where
         list = [ let varMap = AnsVar $ I.singleton (dof a) (SField 1)
                  in (([Ind20 $ a-1], [], [], [], [], []), varMap)
                  | a <- [1..21] ]
         dof a = a

--Aa
generic5Ansatz :: ATens 1 0 0 0 1 0 AnsVarR
generic5Ansatz = fromListT6' list
      where
         list = [ let varMap = AnsVar $ I.singleton (dof a p) (SField 1)
                  in (([Ind20 $ a-1], [], [], [], [Ind3 $ p-1], []), varMap)
                  | a <- [1..21], p <- [1..4] ]
         dof a p = 1 + 21 + 4*(a-1) + (p-1)

--AI
generic6Ansatz :: ATens 1 0 1 0 0 0 AnsVarR
generic6Ansatz = fromListT6' list
     where
        list = [ let varMap = AnsVar $ I.singleton (dof a i) (SField 1)
                 in (([Ind20 $ a-1], [], [Ind9 $ i-1], [], [], []), varMap)
                 | a <- [1..21], i <- [1..10] ]
        dof a i = 1 + 21 + 84 + 10*(a-1) + (i-1)
--AB
generic8Ansatz :: ATens 2 0 0 0 0 0 AnsVarR
generic8Ansatz = fromListT6' list
     where
        list = [ let varMap = AnsVar $ I.singleton (dof a b) (SField 1)
                 in (((:) (Ind20 $ a-1) $ [Ind20 $ b-1], [], [], [], [], []), varMap)
                 | a <- [1..21], b <- [1..21] ]
        dof a b = let a' = min a b
                      b' = max a b
                  in trian M.! [a',b'] + 315
        trian = M.fromList $ zip j k
                  where
                      j = [ [a,b] | a <- [1..315], b <- [a..315] ]
                      k = [1..]

--ABb
generic9Ansatz :: ATens 2 0 0 0 1 0 AnsVarR
generic9Ansatz = fromListT6' list
    where
        list = [ let varMap = AnsVar $ I.singleton (dof a b p) (SField 1)
                in (((:) (Ind20 $ a-1) $ [Ind20 $ b-1], [], [], [], [Ind3 $ p-1], []), varMap)
                | a <- [1..21], b <- [1..21], p <- [1..4]]
        dof a b p = trian M.! [a,1 + 21 + 4*(b-1) + (p-1)] + 315
        trian = M.fromList $ zip j k
                where
                    j = [ [a,b] | a <- [1..315], b <- [a..315] ]
                    k = [1..]

--AaBb
generic10_1Ansatz :: ATens 2 0 0 0 2 0 AnsVarR
generic10_1Ansatz = fromListT6' list
    where
        list = [ let varMap = AnsVar $ I.singleton (dof a b p q) (SField 1)
                in (((:) (Ind20 $ a-1) $ [Ind20 $ b-1], [], [], [], (:) (Ind3 $ p-1) $ [Ind3 $ q-1], []), varMap)
                | a <- [1..21], b <- [1..21], p <- [1..4], q <- [1..4]]
        dof a b p q = let
                a' = min (1 + 21 + 4*(a-1) + (p-1)) (1 + 21 + 4*(b-1) + (q-1))
                b' = max (1 + 21 + 4*(a-1) + (p-1)) (1 + 21 + 4*(b-1) + (q-1))
                in trian M.! [a',b'] + 315
        trian = M.fromList $ zip j k
                where
                    j = [ [a,b] | a <- [1..315], b <- [a..315] ]
                    k = [1..]

--ABI
generic10_2Ansatz :: ATens 2 0 1 0 0 0 AnsVarR
generic10_2Ansatz = fromListT6' list
     where
         list = [ let varMap = AnsVar $ I.singleton (dof a b i) (SField 1)
                 in (((:) (Ind20 $ a-1) $ [Ind20 $ b-1], [], [Ind9 $ i-1], [], [], []), varMap)
                 | a <- [1..21], b <- [1..21], i <- [1..10]]
         dof a b i = trian M.! [a,1 + 105 + 10*(b-1) + (i-1)] + 315
         trian = M.fromList $ zip j k
                 where
                     j = [ [a,b] | a <- [1..315], b <- [a..315] ]
                     k = [1..]

--ApBI
generic11Ansatz :: ATens 2 0 1 0 1 0 AnsVarR
generic11Ansatz = fromListT6' list
     where
         list = [ let varMap = AnsVar $ I.singleton (dof a b i p) (SField 1)
                 in (((:) (Ind20 $ a-1) $ [Ind20 $ b-1], [], [Ind9 $ i-1], [], [Ind3 $ p-1], []), varMap)
                 | a <- [1..21], b <- [1..21], i <- [1..10], p <- [1..4]]
         dof a b i p = trian M.! [1 + 21 + 4*(a-1) + (p-1),1 + 105 + 10*(b-1) + (i-1)] + 315
         trian = M.fromList $ zip j k
                 where
                     j = [ [a,b] | a <- [1..315], b <- [a..315] ]
                     k = [1..]

--AIBJ
generic12_1Ansatz :: ATens 2 0 2 0 0 0 AnsVarR
generic12_1Ansatz = fromListT6' list
    where
        list = [ let varMap = AnsVar $ I.singleton (dof a b i j) (SField 1)
                in (((:) (Ind20 $ a-1) $ [Ind20 $ b-1], [], (:) (Ind9 $ i-1) $ [Ind9 $ j-1], [], [], []), varMap)
                | a <- [1..21], b <- [1..21], i <- [1..10], j <- [1..10]]
        dof a b i j = let
                a' =  min (1 + 105 + 10*(a-1) + (i-1)) (1 + 105 + 10*(b-1) + (j-1))
                b' =  max (1 + 105 + 10*(a-1) + (i-1)) (1 + 105 + 10*(b-1) + (j-1))
                in trian M.! [a',b'] + 315
        trian = M.fromList $ zip j k
                where
                    j = [ [a,b] | a <- [1..315], b <- [a..315] ]
                    k = [1..]

flatArea :: ATens 0 1 0 0 0 0 (SField Rational)
flatArea = fromListT6' $ map (\(i,v) -> ( ([], [Ind20 i], [], [], [], []), v)) [(0,-1),(5,-1),(6,-1),(9,1),(11,-1),(12,-1),(15,1),(18,1),(20,1)]

flatInter :: ATens 0 1 0 0 1 1 (SField Rational)
flatInter = contrATens1 (0,1) $ interArea &* flatArea

flatInterMetric :: ATens 0 0 0 1 1 1 (SField Rational)
flatInterMetric = contrATens2 (0,1) $ interMetric &* etaA

randRats :: IO [Rational]
randRats = do
            gen <- newTFGen
            let randList' = randomRs (-10000,10000) gen :: [Int]
            let randList = map fromIntegral randList'
            return randList

randArea :: IO (ATens 0 1 0 0 0 0 (SField Rational))
randArea = do gen <- newTFGen
              randList <- randRats
              let inds = map (\i -> ([], [Ind20 i], [], [], [], [])) [0..20]
              return $ fromListT6' $ zip inds $ map SField randList

randAxon :: IO (ATens 0 1 0 0 0 0 (SField Rational))
randAxon = do gen <- newTFGen
              randList <- randRats
              let inds = map (\i -> ([], [Ind20 i], [], [], [], [])) [5,9,12]
              let randInd = SField $ head randList
              let assocs = zip inds [-randInd, randInd, -randInd]
              let tens = fromListT6' assocs
              return tens

randFlatArea :: IO (ATens 0 1 0 0 0 0 (SField Rational))
randFlatArea = do gen <- newTFGen
                  randList <- randRats
                  let assocs = map (\(i,v) -> ( ([], [Ind20 i], [], [], [], []), SField v))
                         [(0, -1 * head randList),(5, randList !! 3),(6, -1 * randList !! 1),(9, -1 * randList !! 4),(11, -1 * randList !! 2),(12, randList !! 5),(15, head randList),(18, randList !! 1),(20, randList !! 2)]
                  let tens = fromListT6' assocs
                  return tens


randAreaDerivative1 :: IO (ATens 0 1 0 0 0 1 (SField Rational))
randAreaDerivative1 = do gen <- newTFGen
                         randList <- randRats
                         let inds = [ f a p | a <- [0..20], p <- [0..3]]
                         return $ fromListT6' $ zip inds $ map SField randList
                 where f a p = ([], [Ind20 a], [], [], [], [Ind3 p])


randAreaDerivative2 :: IO (ATens 0 1 0 1 0 0 (SField Rational))
randAreaDerivative2 = do gen <- newTFGen
                         randList <- randRats
                         let inds = [ f a i | a <- [0..20], i <- [0..9]]
                         return $ fromListT6' $ zip inds $ map SField randList
                 where f a i = ([], [Ind20 a], [], [Ind9 i], [], [])


--generators of the Lorentz group lie algebra (for flat metric eta)

lorentzJ1 :: ATens 0 0 0 0 1 1 (SField Rational)
lorentzJ1 = fromListT6' l
        where
            l = map (\(x,y,z) -> (([],[],[],[],[Ind3 x],[Ind3 y]),SField z)) [(3,2,1),(2,3,-1)]

lorentzJ2 :: ATens 0 0 0 0 1 1 (SField Rational)
lorentzJ2 = fromListT6' l
        where
            l = map (\(x,y,z) -> (([],[],[],[],[Ind3 x],[Ind3 y]),SField z)) [(3,1,-1),(1,3,1)]

lorentzJ3 :: ATens 0 0 0 0 1 1 (SField Rational)
lorentzJ3 = fromListT6' l
        where
            l = map (\(x,y,z) -> (([],[],[],[],[Ind3 x],[Ind3 y]),SField z)) [(2,1,1),(1,2,-1)]

lorentzK1 :: ATens 0 0 0 0 1 1 (SField Rational)
lorentzK1 = fromListT6' l
        where
            l = map (\(x,y,z) -> (([],[],[],[],[Ind3 x],[Ind3 y]),SField z)) [(0,1,1),(1,0,1)]

lorentzK2 :: ATens 0 0 0 0 1 1 (SField Rational)
lorentzK2 = fromListT6' l
        where
            l = map (\(x,y,z) -> (([],[],[],[],[Ind3 x],[Ind3 y]),SField z)) [(0,2,1),(2,0,1)]

lorentzK3 :: ATens 0 0 0 0 1 1 (SField Rational)
lorentzK3 = fromListT6' l
        where
            l = map (\(x,y,z) -> (([],[],[],[],[Ind3 x],[Ind3 y]),SField z)) [(0,3,1),(3,0,1)]


randMetric :: IO (ATens 0 0 0 1 0 0 (SField Rational))
randMetric = do gen <- newTFGen
                randList <- randRats
                let inds = map (\i -> ([], [], [], [Ind9 i], [], [])) [0..20]
                return $ fromListT6' $ zip inds $ map SField randList