--improved version of perturbationTree




module PerturbationTree5 (
    AnsatzForest(..), AnsatzNode(..), mkEtaList, mkEpsilonList, Symmetry, reduceAnsatzEta, reduceAnsatzEps, getEtaInds, getEpsilonInds, mkAllVars, symAnsatzForestEta, symAnsatzForestEps, mkForestFromAscList, getEtaForest, getEpsForest, flattenForest, relabelAnsatzForest, getForestLabels, printAnsatz, showAnsatzNode, mapNodes, addForests, isZeroVar, addVars

) where

    import qualified Data.IntMap.Strict as I
    import qualified Data.Map.Strict as M
    import Data.Foldable
    import Data.List 
    import Data.Maybe
    import Data.List
    import BinaryTree

    --getAllInds might be better with S.Seq

    getAllIndsEta :: [Int] -> [[Int]]
    getAllIndsEta [a,b] = [[a,b]]
    getAllIndsEta (x:xs) = res
            where
                l = map (\y -> ([x,y],delete y xs)) xs 
                res = concat $ map (\(a,b) -> (++) a <$> (getAllIndsEta b)) l
    getAllInds x = error "wrong list length"

    getIndsEpsilon :: Int -> [[Int]]
    getIndsEpsilon i = [ [a,b,c,d] | a <- [1..i-3], b <- [a+1..i-2], c <- [b+1..i-1], d <- [c+1..i] ]

    getAllIndsEpsilon :: [Int] -> [[Int]]
    getAllIndsEpsilon l = l3
            where
                s = length l
                l2 = getIndsEpsilon s
                l3 = concat $ map (\x -> (++) x <$> (getAllIndsEta (foldr delete l x))) l2

    filter1Sym :: [Int] -> (Int,Int) -> Bool 
    filter1Sym l (i,j)   
            | first == i = True
            | otherwise = False  
             where
               first = fromJust $ find (\x -> x == i || x == j) l

    filterSym :: [Int] -> [(Int,Int)] -> Bool
    filterSym l inds = and boolList 
            where
               boolList = map (filter1Sym l) inds 

    getEtaInds :: [Int] -> [(Int,Int)] -> [[Int]]
    getEtaInds l sym = filter (\x -> filterSym x sym) $ getAllIndsEta l

    getEpsilonInds :: [Int] -> [(Int,Int)] -> [[Int]]
    getEpsilonInds l sym = filter (\x -> filterSym x sym) $ getAllIndsEpsilon l

    data AnsatzNode a = Epsilon a a a a | Eta a a | Var Rational Int  deriving (Show, Eq, Ord)

    mkAllVars :: Int -> [AnsatzNode a] 
    mkAllVars i = map (Var 1) [i..]

    --or use standard Data.List sort ?

    sortList :: Ord a => [a] -> [a]
    sortList [] = [] 
    sortList (x:xs) = insert x $ sortList xs 

    sortAnsatzNode :: Ord a => AnsatzNode a ->  AnsatzNode a 
    sortAnsatzNode (Eta x y) = (Eta (min x y) (max x y))
    sortAnsatzNode (Epsilon i j k l) = ( Epsilon i' j' k' l')
            where
                [i',j',k',l'] = sortList [i,j,k,l]
    sortAnsatzNode (Var x y) = (Var x y)

    isEpsilon :: AnsatzNode a -> Bool
    isEpsilon (Epsilon i j k l) = True
    isEpsilon x = False

    getEpsSign :: Ord a => AnsatzNode a -> Rational 
    getEpsSign (Epsilon i j k l) = (-1)^(length $  filter (==True) [j>i,k>i,l>i,k>j,l>j,l>k])
    getEpsSign x = error "should only be called for Epsilon"

    
    addVars :: AnsatzNode a -> AnsatzNode a -> Maybe (AnsatzNode a) 
    addVars (Var x y) (Var x' y') 
            | rightVars && val == 0 = Nothing
            | rightVars = Just $ Var val y
                where
                    rightVars = (y == y')
                    val = x + x'

    multVar :: Rational -> AnsatzNode a -> AnsatzNode a
    multVar x (Var x' y) = Var (x * x') y
    multVar x y = y 

    isZeroVar :: AnsatzNode a -> Bool
    isZeroVar (Var 0 x) = True
    isZeroVar x = False 
   
    data AnsatzForest a = Forest (BiTree a (AnsatzForest a))| FLeaf a | EmptyForest  deriving (Show, Eq)

    forestMap :: AnsatzForest a -> BiTree a (AnsatzForest a)
    forestMap (Forest m) = m
    forestMap x = error "Forest is Leaf or Empty"

    --does not resorting

    mapNodes :: (a -> a) -> AnsatzForest a -> AnsatzForest a
    mapNodes f EmptyForest = EmptyForest
    mapNodes f (FLeaf var) = FLeaf (f var)
    mapNodes f (Forest m) = Forest $ (mapKeysTree f).(fmap (mapNodes f)) $ m


    --add 2 sorted forests (are all zeros removed ?)

    addForestsM :: Ord a => (a -> a -> Maybe a) -> AnsatzForest a -> AnsatzForest a -> Maybe (AnsatzForest a)
    addForestsM f ans EmptyForest = Just ans
    addForestsM f EmptyForest ans = Just ans 
    addForestsM f (FLeaf var1) (FLeaf var2) 
            | isJust newLeafVal = Just $ FLeaf $ fromJust newLeafVal
            | otherwise = Nothing
            where
                newLeafVal = (f var1 var2)
    addForestsM f (Forest m1) (Forest m2) 
            | EmptyTree == newMap = Nothing
            | otherwise = Just $ Forest newMap
             where
                newMap = filterTree (/= EmptyForest) $ unionTreeWithMaybe (addForestsM f) m1 m2

    addForests :: Ord a => (a -> a -> Maybe a) -> AnsatzForest a -> AnsatzForest a -> AnsatzForest a
    addForests f m1 m2 = fromMaybe EmptyForest $ addForestsM f m1 m2

    --flatten Forest to AscList Branches
    
    flattenForest :: Ord a => AnsatzForest a -> [[a]]
    flattenForest EmptyForest = [[]]
    flattenForest (FLeaf var) = [[var]]
    flattenForest (Forest m) = concat l 
            where
                mPairs = toAscList m 
                l = fmap (\(k,v) ->  fmap (insert k) $ flattenForest v) mPairs  
                
    mkForestFromAscList :: Ord a => [a] -> AnsatzForest a 
    mkForestFromAscList [] = EmptyForest
    mkForestFromAscList [x] = FLeaf x
    mkForestFromAscList (x:xs) = Forest $ fromAscListWithLength 1 [(x, mkForestFromAscList xs)]
    
    sortForest :: Ord a => (a -> a -> Maybe a) -> AnsatzForest a -> AnsatzForest a
    sortForest addFs f = foldr (addForests addFs) EmptyForest fList 
                where
                    fList = map mkForestFromAscList $ flattenForest f

    swapLabelF :: Ord a =>  (a,a) -> a -> a 
    swapLabelF (x,y) z
            | x == z = y
            | y == z = x
            | otherwise = z 

    --there is a problem        

    swapBlockLabelMap :: Ord a => ([a],[a]) -> M.Map a a
    swapBlockLabelMap (x,y) = swapF 
            where
                swapF = M.fromList $ (zip x y)++(zip y x)
            
    swapLabelNode :: Ord a => (a,a) -> AnsatzNode a -> AnsatzNode a
    swapLabelNode inds (Eta i j) = Eta (f i) (f j)
                where
                    f = swapLabelF inds
    swapLabelNode inds (Epsilon i j k l) = Epsilon (f i) (f j) (f k) (f l)
                where
                    f = swapLabelF inds
    swapLabelNode inds (Var x y) = Var x y


    swapBlockLabelNode :: Ord a => M.Map a a -> AnsatzNode a -> AnsatzNode a
    swapBlockLabelNode swapF (Eta i j) = Eta (f i) (f j)
                where
                    f = \z -> fromMaybe z $ M.lookup z swapF 
    swapBlockLabelNode swapF (Epsilon i j k l) = Epsilon (f i) (f j) (f k) (f l)
                where
                    f = \z -> fromMaybe z $ M.lookup z swapF 
    swapBlockLabelNode sapF (Var x y) = Var x y

    canonicalizeAnsatzEta :: Ord a => AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a)
    canonicalizeAnsatzEta  = mapNodes sortAnsatzNode

    canonicalizeAnsatzEpsilon :: Ord a => AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a)
    canonicalizeAnsatzEpsilon EmptyForest = EmptyForest
    canonicalizeAnsatzEpsilon (FLeaf var) = FLeaf var
    canonicalizeAnsatzEpsilon (Forest m) = Forest newMap
                where
                    newMap = mapKeysTree sortAnsatzNode $ mapElemsWithKeyTree (\ k v -> mapNodes ((multVar $ getEpsSign k).sortAnsatzNode) v ) m
            

    swapLabelEta :: Ord a => (a,a) -> AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a)
    swapLabelEta inds ans = (sortForest addVars).canonicalizeAnsatzEta $ swapAnsatz
            where
                f = swapLabelNode inds 
                swapAnsatz = mapNodes f ans

    swapLabelEps :: Ord a => (a,a) -> AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a)
    swapLabelEps inds ans = (sortForest addVars).canonicalizeAnsatzEpsilon $ swapAnsatz
            where
                f = swapLabelNode inds 
                swapAnsatz = mapNodes f ans           

    swapBlockLabelEta :: Ord a => M.Map a a -> AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a)
    swapBlockLabelEta swapF ans = (sortForest addVars).canonicalizeAnsatzEta $ swapAnsatz
            where
                f = swapBlockLabelNode swapF 
                swapAnsatz = mapNodes f ans

    swapBlockLabelEps :: Ord a => M.Map a a -> AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a)
    swapBlockLabelEps swapF ans = (sortForest addVars).canonicalizeAnsatzEpsilon $ swapAnsatz
            where
                f = swapBlockLabelNode swapF 
                swapAnsatz = mapNodes f ans
            

    pairSymForestEta :: (Ord a, Show a) => (a,a) -> AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a)
    pairSymForestEta inds ans = (addForests addVars) ans $ swapLabelEta inds ans 

    pairSymForestEps :: (Ord a, Show a) => (a,a) -> AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a)
    pairSymForestEps inds ans = (addForests addVars) ans $ swapLabelEps inds ans 

    pairASymForestEta :: (Ord a, Show a) => (a,a) -> AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a)
    pairASymForestEta inds ans = (addForests addVars) ans $ mapNodes (multVar (-1)) $ swapLabelEta inds ans 

    pairASymForestEps :: (Ord a, Show a) => (a,a) -> AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a)
    pairASymForestEps inds ans = (addForests addVars) ans $ mapNodes (multVar (-1)) $ swapLabelEps inds ans 

    pairBlockSymForestEta :: (Ord a, Show a) => M.Map a a -> AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a)
    pairBlockSymForestEta swapF ans = (addForests addVars) ans $ swapBlockLabelEta swapF ans 

    pairBlockSymForestEps :: (Ord a, Show a) => M.Map a a -> AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a)
    pairBlockSymForestEps swapF ans = (addForests addVars) ans $ swapBlockLabelEps swapF ans 

    pairBlockASymForestEta :: (Ord a, Show a) => M.Map a a -> AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a)
    pairBlockASymForestEta swapF ans = (addForests addVars) ans $ mapNodes (multVar (-1)) $ swapBlockLabelEta swapF ans

    pairBlockASymForestEps :: (Ord a, Show a) => M.Map a a -> AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a)
    pairBlockASymForestEps swapF ans = (addForests addVars) ans $ mapNodes (multVar (-1)) $ swapBlockLabelEps swapF ans

    --cyclic symmetrization does not work !!! -> There is a problem 
    
    cyclicSymForestEta :: (Ord a, Show a) => [a] -> AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a)
    cyclicSymForestEta inds ans = foldr (\y x -> (addForests addVars) x $ swapBlockLabelEta y ans ) ans perms
            where
                perms = map (\a -> M.fromList (zip inds a)) $ tail $ permutations inds 

    cyclicSymForestEps :: (Ord a, Show a) => [a] -> AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a)
    cyclicSymForestEps inds ans = foldr (\y x -> (addForests addVars) x $ swapBlockLabelEps y ans ) ans perms
            where
                perms = map (\a -> M.fromList (zip inds a)) $ tail $ permutations inds 


    cyclicBlockSymForestEta :: (Ord a, Show a) => [[a]] -> AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a)
    cyclicBlockSymForestEta inds ans = foldr (\y x -> (addForests addVars) x $ swapBlockLabelEta y ans ) ans perms
            where
                perms = map (\a -> M.fromList $ zip (concat inds) (concat a)) $ tail $ permutations inds 

    cyclicBlockSymForestEps :: (Ord a, Show a) => [[a]] -> AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a)
    cyclicBlockSymForestEps inds ans = foldr (\y x -> (addForests addVars) x $ swapBlockLabelEps y ans ) ans perms
            where
                perms = map (\a -> M.fromList $ zip (concat inds) (concat a)) $ tail $ permutations inds 

    type Symmetry a = ( [(a,a)] , [(a,a)] , [([a],[a])] , [[a]], [[[a]]] )

    symAnsatzForestEta :: (Ord a, Show a) => Symmetry a -> AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a) 
    symAnsatzForestEta (sym,asym,blocksym,cyclicsym,cyclicblocksym) ans =
        foldr cyclicBlockSymForestEta (
            foldr cyclicSymForestEta (
                foldr pairBlockSymForestEta (
                    foldr pairASymForestEta (
                        foldr pairSymForestEta ans sym
                    ) asym
                ) blockSymMap
            ) cyclicsym
        ) cyclicblocksym  
        where
            blockSymMap = map swapBlockLabelMap blocksym

    symAnsatzForestEps :: (Ord a, Show a) => Symmetry a -> AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a) 
    symAnsatzForestEps (sym,asym,blocksym,cyclicsym,cyclicblocksym) ans =
          foldr cyclicBlockSymForestEps (
              foldr cyclicSymForestEps (
                  foldr pairBlockSymForestEps (
                      foldr pairASymForestEps (
                          foldr pairSymForestEps ans sym
                      ) asym
                  ) blockSymMap
              ) cyclicsym
          ) cyclicblocksym  
          where
            blockSymMap = map swapBlockLabelMap blocksym


    --if symmetrizing an ansatz this way is too slow we can symmetrize by using a map and then insert in the big tree 
    
    mkEtaList :: AnsatzNode a -> [a] -> [AnsatzNode a]
    mkEtaList var [] = [var] 
    mkEtaList var x = (Eta a b) : (mkEtaList var rest) 
            where
                [a,b] = take 2 x
                rest = drop 2 x

    mkEpsilonList :: AnsatzNode a -> [a] -> [AnsatzNode a]
    mkEpsilonList var [] = [var]
    mkEpsilonList var x = (Epsilon i j k l) : (mkEtaList var rest) 
            where
                [i,j,k,l] = take 4 x
                rest = drop 4 x
    

    --look up a 1d Forest (obtained from the index list) in the given Forest

    isElem :: Ord a => [AnsatzNode a] -> AnsatzForest (AnsatzNode a) -> Bool
    isElem [] x = True
    isElem x (FLeaf y) = True
    isElem x EmptyForest = False 
    isElem  (x:xs) (Forest m) 
                | isJust mForest = isElem xs $ fromJust mForest
                | otherwise = False
                where
                    mForest = lookupTree x m

    reduceAnsatzEta :: (Ord a, Show a) => Symmetry a -> [[AnsatzNode a]] -> AnsatzForest (AnsatzNode a)
    reduceAnsatzEta sym [] = EmptyForest
    reduceAnsatzEta sym l = foldr addOrRem EmptyForest l
            where
                addOrRem = \ans f -> if (isElem ans f) then f else (addForests addVars) f (symAnsatzForestEta sym $ mkForestFromAscList ans)

    reduceAnsatzEps :: (Ord a, Show a) => Symmetry a -> [[AnsatzNode a]] -> AnsatzForest (AnsatzNode a)
    reduceAnsatzEps sym [] = EmptyForest
    reduceAnsatzEps sym l = foldr addOrRem EmptyForest l
            where
                addOrRem = \ans f -> if (isElem ans f) then f else (addForests addVars) f (symAnsatzForestEps sym $ mkForestFromAscList ans)


    getEtaForest :: [Int] -> [(Int,Int)] -> Int -> Symmetry Int -> AnsatzForest (AnsatzNode Int)
    getEtaForest inds filters label1 syms = reduceAnsatzEta syms allForests
                where
                    allInds = getEtaInds inds filters
                    allVars = mkAllVars label1 
                    allForests = zipWith mkEtaList allVars allInds

    getEpsForest :: [Int] -> [(Int,Int)] -> Int -> Symmetry Int -> AnsatzForest (AnsatzNode Int)
    getEpsForest inds filters label1 syms = reduceAnsatzEps syms allForests
                where
                    allInds = getEpsilonInds inds filters
                    allVars = mkAllVars label1 
                    allForests = zipWith mkEpsilonList allVars allInds

    getLeafVals :: AnsatzForest a -> [a]
    getLeafVals (FLeaf var) = [var]
    getLeafVals (Forest m) = rest
            where
                rest = concatMap getLeafVals $ map snd $ toAscList m

    getVarLabels :: AnsatzNode a -> Int
    getVarLabels (Var i j) = j
    getVarLabels x = error "only can get label of node"

    getForestLabels :: AnsatzForest (AnsatzNode a) -> [Int]
    getForestLabels ans = nub $ map getVarLabels $ getLeafVals ans

    relabelVar :: (Int -> Int) -> AnsatzNode a -> AnsatzNode a
    relabelVar f (Var i j) = Var i (f j)
    relabelVar f x = x

    relabelAnsatzForest :: Ord a => AnsatzForest (AnsatzNode a) -> AnsatzForest (AnsatzNode a)
    relabelAnsatzForest ans = mapNodes update ans
            where
                vars = getForestLabels ans 
                relabMap = I.fromList $ zip vars [1..]
                update = relabelVar ((I.!) relabMap) 

    showAnsatzNode :: Show a => AnsatzNode a -> String 
    showAnsatzNode (Var i j) = (show i) ++ "*" ++ "x" ++ (show j)
    showAnsatzNode (Eta i b) = show (i,b)
    showAnsatzNode (Epsilon i j k l) = show (i,j,k,l)
    

    shiftAnsatzForest :: AnsatzForest String -> AnsatzForest String
    shiftAnsatzForest EmptyForest = EmptyForest
    shiftAnsatzForest (FLeaf var) = FLeaf var 
    shiftAnsatzForest (Forest m) = Forest $ fmap shiftAnsatzForest shiftedForestMap
            where
                mapElems f (Forest m) =  Forest $ mapKeysTree f m
                mapElems f (FLeaf var) = FLeaf (f var)
                shiftedForestMap = fmap (\f -> mapElems (\x -> "     " ++ x) f) m

    printAnsatz ::  AnsatzForest String -> [String]
    printAnsatz (FLeaf var) = [var] 
    printAnsatz (Forest m) = map (init.unlines) subForests
            where
                shiftedForest = shiftAnsatzForest (Forest m)
                pairs = toAscList $ forestMap shiftedForest
                subForests = map (\(k,v) -> k : (printAnsatz v)) pairs
                