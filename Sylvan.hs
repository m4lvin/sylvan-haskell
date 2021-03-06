module Sylvan where

import Foreign.C.Types
import Foreign.Ptr
import Foreign.Marshal.Array
import Data.Word
import Data.Bits
import Control.Monad.Primitive

--Lace
foreign import ccall safe "lace_init"
    c_laceInit :: CInt -> CInt -> IO ()

laceInit :: PrimMonad m => Int -> Int -> m ()
laceInit workers deque = unsafePrimToPrim $ c_laceInit (fromIntegral workers) (fromIntegral deque)

foreign import ccall safe "lace_startup"
    c_laceStartup :: CInt -> Ptr () -> Ptr () -> IO ()

laceStartup :: PrimMonad m => m ()
laceStartup = unsafePrimToPrim $ c_laceStartup 0 nullPtr nullPtr

--Sylvan
type    CBDD    = CLLong
newtype BDD     = BDD CBDD deriving (Eq, Show)
type    CBDDVar = CUInt
type    BDDVar  = Word32
type    CBDDMap = CLLong
newtype BDDMap  = BDDMap CBDDMap deriving (Show)

c_sylvanComplement :: CLLong
c_sylvanComplement =  0x8000000000000000
c_sylvanFalse      :: CLLong
c_sylvanFalse      =  0x0000000000000000
c_sylvanTrue       :: CLLong
c_sylvanTrue       =  c_sylvanFalse .|. c_sylvanComplement

sylvanFalse :: BDD
sylvanFalse = BDD c_sylvanFalse

sylvanTrue :: BDD
sylvanTrue  = BDD c_sylvanTrue

foreign import ccall safe "sylvan_init_mtbdd"
    c_sylvanInit :: IO ()

sylvanInit :: PrimMonad m => m ()
sylvanInit = unsafePrimToPrim c_sylvanInit

foreign import ccall safe "sylvan_init_package"
    c_sylvanInitPackage :: CInt -> CInt -> CInt -> CInt -> IO ()

sylvanInitPackage :: PrimMonad m => Int -> Int -> Int -> Int -> m ()
sylvanInitPackage tableSize maxSize cacheSize maxCacheSize =
  unsafePrimToPrim $ c_sylvanInitPackage tS mS cS mcS where
    [tS,mS,cS,mcS] = map fromIntegral [tableSize, maxSize, cacheSize, maxCacheSize]

foreign import ccall safe "sylvan_quit"
    c_sylvanQuit :: IO ()

sylvanQuit :: PrimMonad m => m ()
sylvanQuit = unsafePrimToPrim c_sylvanQuit

foreign import ccall safe "sylvan_ithvar"
    c_ithVar :: CBDDVar -> IO CBDD

ithVar :: PrimMonad m => BDDVar -> m BDD
ithVar var = fmap BDD $ unsafePrimToPrim $ c_ithVar (fromIntegral var)

nithVar :: PrimMonad m => BDDVar -> m BDD
nithVar var = fmap (BDD . xor c_sylvanComplement) $ unsafePrimToPrim $ c_ithVar (fromIntegral var)

foreign import ccall safe "mtbdd_ref"
    c_ref :: CBDD -> IO CBDD

ref :: PrimMonad m => BDD -> m BDD
ref (BDD bdd) = fmap BDD $ unsafePrimToPrim $ c_ref bdd

refMap :: PrimMonad m => BDDMap -> m BDDMap
refMap (BDDMap bdd) = fmap BDDMap $ unsafePrimToPrim $ c_ref bdd

foreign import ccall safe "mtbdd_deref"
    c_deref :: CBDD -> IO ()

deref :: PrimMonad m => BDD -> m ()
deref (BDD bdd) = unsafePrimToPrim $ c_deref bdd

derefMap :: PrimMonad m => BDDMap -> m ()
derefMap (BDDMap bdd) = unsafePrimToPrim $ c_deref bdd

foreign import ccall safe "sylvan_gc_stub"
    c_gc :: IO ()

gc :: PrimMonad m => m ()
gc = unsafePrimToPrim c_gc

foreign import ccall safe "sylvan_gc_enable"
    c_gcEnable :: IO ()

gcEnable :: PrimMonad m => m ()
gcEnable = unsafePrimToPrim c_gcEnable

foreign import ccall safe "sylvan_gc_disable"
    c_gcDisable :: IO ()

gcDisable :: PrimMonad m => m ()
gcDisable = unsafePrimToPrim c_gcDisable

neg :: BDD -> BDD
neg (BDD x) = BDD $ xor c_sylvanComplement x

foreign import ccall safe "sylvan_ite_stub"
    c_ite :: CBDD -> CBDD -> CBDD -> IO CBDD

ite :: PrimMonad m => BDD -> BDD -> BDD -> m BDD
ite (BDD a) (BDD b) (BDD c) = fmap BDD $ unsafePrimToPrim $ c_ite a b c

foreign import ccall safe "sylvan_xor_stub"
    c_xor :: CBDD -> CBDD -> IO CBDD

bxor :: PrimMonad m => BDD -> BDD -> m BDD
bxor (BDD a) (BDD b) = fmap BDD $ unsafePrimToPrim $ c_xor a b

bequiv :: PrimMonad m => BDD -> BDD -> m BDD
bequiv a b = neg <$> bxor a b

foreign import ccall safe "sylvan_and_stub"
    c_and :: CBDD -> CBDD -> IO CBDD

band :: PrimMonad m => BDD -> BDD -> m BDD
band (BDD a) (BDD b) = fmap BDD $ unsafePrimToPrim $ c_and a b

bor :: PrimMonad m => BDD -> BDD -> m BDD
bor a b = neg <$> band (neg a) (neg b)

bnand :: PrimMonad m => BDD -> BDD -> m BDD
bnand a b = neg <$> band a b

bnor :: PrimMonad m => BDD -> BDD -> m BDD
bnor a b = neg <$> bor a b

bimp :: PrimMonad m => BDD -> BDD -> m BDD
bimp a b = neg <$> band a (neg b)

bimpinv :: PrimMonad m => BDD -> BDD -> m BDD
bimpinv a b = neg <$> band (neg a) b

biimp :: PrimMonad m => BDD -> BDD -> m BDD
biimp = bequiv

diff :: PrimMonad m => BDD -> BDD -> m BDD
diff a b = band a (neg b)

less :: PrimMonad m => BDD -> BDD -> m BDD
less a = band (neg a)

foreign import ccall safe "sylvan_exists_stub"
    c_exists :: CBDD -> CBDD -> IO CBDD

exists :: PrimMonad m => BDD -> BDD -> m BDD
exists (BDD a) (BDD variables) = fmap BDD $ unsafePrimToPrim $ c_exists a variables

forall :: PrimMonad m => BDD -> BDD -> m BDD
forall a variables = neg <$> exists (neg a) variables

foreign import ccall safe "sylvan_and_exists_stub"
    c_and_exists :: CBDD -> CBDD -> CBDD -> IO CBDD

andExists :: PrimMonad m => BDD -> BDD -> BDD -> m BDD
andExists (BDD a) (BDD b) (BDD vars) = fmap BDD $ unsafePrimToPrim $ c_and_exists a b vars

foreign import ccall safe "mtbdd_fromarray"
    c_setFromArray :: Ptr CBDDVar -> CSize -> IO CBDD

setFromArray :: PrimMonad m => [BDDVar] -> m BDD
setFromArray vars = fmap BDD $ unsafePrimToPrim $
    withArrayLen (map fromIntegral vars) $ \l p ->
        c_setFromArray p (fromIntegral l)

mapEmpty :: BDDMap
mapEmpty = BDDMap c_sylvanFalse

foreign import ccall safe "mtbdd_map_add"
    c_mapAdd :: CBDDMap -> CBDDVar -> CBDD -> IO CBDDMap

mapAdd :: PrimMonad m => BDDMap -> BDDVar -> BDD -> m BDDMap
mapAdd (BDDMap m) var (BDD x) = fmap BDDMap $ unsafePrimToPrim $ c_mapAdd m (fromIntegral var) x

foreign import ccall safe "sylvan_compose_stub"
    c_compose :: CBDD -> CBDDMap -> IO CBDD

compose :: PrimMonad m => BDD -> BDDMap -> m BDD
compose (BDD f) (BDDMap m) = fmap BDD $ unsafePrimToPrim $ c_compose f m

foreign import ccall safe "sylvan_restrict_stub"
    c_restrict :: CBDD -> CBDD -> IO CBDD

restrict :: PrimMonad m => BDD -> BDD -> m BDD
restrict (BDD f) (BDD c) = fmap BDD $ unsafePrimToPrim $ c_restrict f c

foreign import ccall safe "sylvan_stats_report"
    c_statsReport :: IO ()

statsReport :: PrimMonad m => m ()
statsReport = unsafePrimToPrim c_statsReport

-- foreign import ccall safe "sylvan_printDot_stub"
--    c_printDot :: CBDD -> IO ()

-- printDot :: PrimMonad m => BDD -> m ()
-- printDot (BDD x) = unsafePrimToPrim $ c_printDot x

----TODO: a macro
--foreign import ccall safe "sylvan_print_stub"
--    c_bddPrint :: CBDD -> IO ()
--
--bddPrint :: PrimMonad m => BDD -> m ()
--bddPrint (BDD x) = unsafePrimToPrim $ c_bddPrint x
--
----TODO: a macro
--foreign import ccall safe "sylvan_printsha"
--    c_printSHA :: CBDD -> IO ()
--
--printSHA :: BDD -> IO ()
--printSHA (BDD x) = unsafePrimToPrim $ c_printSHA x

foreign import ccall safe "sylvan_cube"
    c_cube :: CBDD -> Ptr CUChar -> IO CBDD

data Polarity =
      Negative
    | Positive
    | DontCare
    deriving (Show)

polarityToInt :: Integral i => Polarity -> i
polarityToInt Negative = 0
polarityToInt Positive = 1
polarityToInt DontCare = 2

cube :: PrimMonad m => BDD -> [Polarity] -> m BDD
cube (BDD vars) polarities = fmap BDD $ unsafePrimToPrim $
    withArrayLen (map polarityToInt polarities) $ \_ pp ->
        c_cube vars pp
