// D import file generated from 'dmdscript/RandAA.d'
module dmdscript.RandAA;
import std.traits;
import core.memory;
import core.exception;
import std.algorithm;
import std.conv;
import std.exception;
import std.math;
class KeyError : Exception
{
    this(string msg)
{
super(msg);
}
}
private enum 
{
EMPTY,
USED,
REMOVED,
}

private template shouldStoreHash(K)
{
enum bool shouldStoreHash = !isFloatingPoint!(K) && !isIntegral!(K);
}

private template missing_key(K)
{
void missing_key(K key)
{
throw new KeyError(text("missing or invalid key ",key));
}
}

template aard(K,V,bool useRandom = false)
{
struct aard
{
    alias RandAA!(K,V,shouldStoreHash!(K),useRandom) HashMapClass;
    HashMapClass imp_;
    V opIndex(K key)
{
if (imp_ !is null)
return imp_.opIndex(key);
missing_key(key);
assert(0);
}
    V* opIn_r(K k)
{
if (imp_ is null)
return null;
return imp_.opIn_r(k);
}
    void opIndexAssign(V value, K k)
{
if (imp_ is null)
imp_ = new HashMapClass;
imp_.assignNoRehashCheck(k,value);
imp_.rehash();
}
    void clear()
{
if (imp_ !is null)
imp_.free();
}
    void detach()
{
imp_ = null;
}
    bool remove(K k)
{
if (imp_ is null)
return false;
V val;
return imp_.remove(k,val);
}
    bool remove(K k, ref V value)
{
if (imp_ is null)
return false;
return imp_.remove(k,value);
}
    @property K[] keys()
{
if (imp_ is null)
return null;
return imp_.keys();
}

    @property aard allocate()
{
aard newAA;
newAA.imp_ = new HashMapClass;
return newAA;
}

    @property void loadRatio(double cap)
{
}

    @property void capacity(size_t cap)
{
}

    @property V[] values()
{
if (imp_ is null)
return null;
return imp_.values();
}

    V get(K k)
{
V* p = opIn_r(k);
if (p !is null)
{
return *p;
}
return V.init;
}
    bool get(K k, ref V val)
{
if (imp_ !is null)
{
V* p = opIn_r(k);
if (p !is null)
{
val = *p;
return true;
}
}
val = V.init;
return false;
}
    @property size_t length()
{
if (imp_ is null)
return 0;
return imp_._length;
}

    public int opApply(int delegate(ref V value) dg)
{
return imp_ !is null ? imp_.opApply(dg) : 0;
}

    public int opApply(int delegate(ref K key, ref V value) dg)
{
return imp_ !is null ? imp_.opApply(dg) : 0;
}

}
}
final template RandAA(K,V,bool storeHash = shouldStoreHash!(K),bool useRandom = false)
{
class RandAA
{
    private 
{
    K* _keys;
    V* vals;
    ubyte* flags;
    static if(storeHash)
{
    hash_t* hashes;
}
    size_t mask;
    size_t clock;
    size_t _length;
    size_t space;
    size_t nDead;
    enum : size_t
{
mul = 1103515245u,
add = 12345u,
}
    enum : size_t
{
PERTURB_SHIFT = 32,
}
    const hash_t getHash(K key)
{
static if(is(K : long) && K.sizeof <= hash_t.sizeof)
{
hash_t hash = cast(hash_t)key;
}
else
{
static if(is(typeof(key.toHash())))
{
hash_t hash = key.toHash();
}
else
{
hash_t hash = typeid(K).getHash(cast(const(void)*)&key);
}

}

return hash;
}
    static if(storeHash)
{
    const size_t findExisting(ref K key)
{
immutable hashFull = getHash(key);
size_t pos = hashFull & mask;
static if(useRandom)
{
size_t rand = hashFull + 1;
}
else
{
size_t perturb = hashFull;
size_t i = pos;
}

uint flag = void;
while (true)
{
flag = flags[pos];
if (flag == EMPTY || hashFull == hashes[pos] && key == _keys[pos] && flag != EMPTY)
{
break;
}
static if(useRandom)
{
rand = rand * mul + add;
pos = rand + hashFull & mask;
}
else
{
i = i * 5 + perturb + 1;
perturb /= PERTURB_SHIFT;
pos = i & mask;
}

}
return flag == USED ? pos : size_t.max;
}
    size_t findForInsert(ref K key, immutable hash_t hashFull)
{
size_t pos = hashFull & mask;
static if(useRandom)
{
size_t rand = hashFull + 1;
}
else
{
size_t perturb = hashFull;
size_t i = pos;
}

while (true)
{
if (flags[pos] != USED || hashes[pos] == hashFull && _keys[pos] == key)
{
break;
}
static if(useRandom)
{
rand = rand * mul + add;
pos = rand + hashFull & mask;
}
else
{
i = i * 5 + perturb + 1;
perturb /= PERTURB_SHIFT;
pos = i & mask;
}

}
hashes[pos] = hashFull;
return pos;
}
}
else
{
    const size_t findExisting(ref K key)
{
immutable hashFull = getHash(key);
size_t pos = hashFull & mask;
static if(useRandom)
{
size_t rand = hashFull + 1;
}
else
{
size_t perturb = hashFull;
size_t i = pos;
}

uint flag = void;
while (true)
{
flag = flags[pos];
if (flag == EMPTY || _keys[pos] == key && flag != EMPTY)
{
break;
}
static if(useRandom)
{
rand = rand * mul + add;
pos = rand + hashFull & mask;
}
else
{
i = i * 5 + perturb + 1;
perturb /= PERTURB_SHIFT;
pos = i & mask;
}

}
return flag == USED ? pos : size_t.max;
}
    const size_t findForInsert(ref K key, immutable hash_t hashFull)
{
size_t pos = hashFull & mask;
static if(useRandom)
{
size_t rand = hashFull + 1;
}
else
{
size_t perturb = hashFull;
size_t i = pos;
}

while (flags[pos] == USED && _keys[pos] != key)
{
static if(useRandom)
{
rand = rand * mul + add;
pos = rand + hashFull & mask;
}
else
{
i = i * 5 + perturb + 1;
perturb /= PERTURB_SHIFT;
pos = i & mask;
}

}
return pos;
}
}
    void assignNoRehashCheck(ref K key, ref V val, hash_t hashFull)
{
size_t i = findForInsert(key,hashFull);
vals[i] = val;
immutable uint flag = flags[i];
if (flag != USED)
{
if (flag == REMOVED)
{
nDead--;
}
_length++;
flags[i] = USED;
_keys[i] = key;
}
}
    void assignNoRehashCheck(ref K key, ref V val)
{
hash_t hashFull = getHash(key);
size_t i = findForInsert(key,hashFull);
vals[i] = val;
immutable uint flag = flags[i];
if (flag != USED)
{
if (flag == REMOVED)
{
nDead--;
}
_length++;
flags[i] = USED;
_keys[i] = key;
}
}
    this(bool dummy)
{
}
    public 
{
    static size_t getNextP2(size_t n)
{
size_t result = 16;
while (n >= result)
{
result *= 2;
}
return result;
}

    this(size_t initSize = 10)
{
space = getNextP2(initSize);
mask = space - 1;
_keys = (new K[](space)).ptr;
vals = (new V[](space)).ptr;
static if(storeHash)
{
hashes = (new hash_t[](space)).ptr;
}

flags = (new ubyte[](space)).ptr;
}
    void rehash()
{
if (cast(float)(_length + nDead) / space < 0.7)
{
return ;
}
reserve(space + 1);
}
    private void reserve(size_t newSize)
{
scope typeof(this) newTable = new typeof(this)(newSize);
foreach (i; 0 .. space)
{
if (flags[i] == USED)
{
static if(storeHash)
{
newTable.assignNoRehashCheck(_keys[i],vals[i],hashes[i]);
}
else
{
newTable.assignNoRehashCheck(_keys[i],vals[i]);
}

}
}
GC.free(cast(void*)this._keys);
GC.free(cast(void*)this.flags);
GC.free(cast(void*)this.vals);
static if(storeHash)
{
GC.free(cast(void*)this.hashes);
}

foreach (ti, elem; newTable.tupleof)
{
this.tupleof[ti] = elem;
}
}

    ref V opIndex(K index)
{
size_t i = findExisting(index);
if (i == size_t.max)
{
throw new KeyError("Could not find key " ~ to!(string)(index));
}
else
{
return vals[i];
}
}

    V* findExistingAlt(ref K key, hash_t hashFull)
{
size_t pos = hashFull & mask;
static if(useRandom)
{
size_t rand = hashFull + 1;
}
else
{
size_t perturb = hashFull;
size_t i = pos;
}

uint flag = void;
while (true)
{
flag = flags[pos];
if (flag == EMPTY || hashFull == hashes[pos] && key == _keys[pos] && flag != EMPTY)
{
break;
}
static if(useRandom)
{
rand = rand * mul + add;
pos = rand + hashFull & mask;
}
else
{
i = i * 5 + perturb + 1;
perturb /= PERTURB_SHIFT;
pos = i & mask;
}

}
return flag == USED ? &vals[pos] : null;
}
    void insertAlt(ref K key, ref V val, hash_t hashFull)
{
assignNoRehashCheck(key,val,hashFull);
rehash();
}
    void opIndexAssign(V val, K index)
{
assignNoRehashCheck(index,val);
rehash();
}
    template KeyValRange(K,V,bool storeHash,bool vals)
{
struct KeyValRange
{
    private 
{
    static if(vals)
{
    alias V T;
}
else
{
    alias K T;
}
    size_t index = 0;
    RandAA aa;
    public 
{
    this(RandAA aa)
{
this.aa = aa;
while (aa.flags[index] != USED && index < aa.space)
{
index++;
}
}
    T front()
{
static if(vals)
{
return aa.vals[index];
}
else
{
return aa._keys[index];
}

}
    void popFront()
{
index++;
while (aa.flags[index] != USED && index < aa.space)
{
index++;
}
}
    bool empty()
{
return index == aa.space;
}
    string toString()
{
char[] ret = "[".dup;
auto copy = this;
foreach (elem; copy)
{
ret ~= to!(string)(elem);
ret ~= ", ";
}
ret[$ - 2] = ']';
ret = ret[0..$ - 1];
auto retImmutable = assumeUnique(ret);
return retImmutable;
}
}
}
}
}
    alias KeyValRange!(K,V,storeHash,false) key_range;
    alias KeyValRange!(K,V,storeHash,true) value_range;
    key_range keyRange()
{
return key_range(this);
}
    value_range valueRange()
{
return value_range(this);
}
    V remove(K index)
{
size_t i = findExisting(index);
if (i == size_t.max)
{
throw new KeyError("Could not find key " ~ to!(string)(index));
}
else
{
_length--;
nDead++;
flags[i] = REMOVED;
return vals[i];
}
}
    V[] values()
{
size_t i = 0;
V[] result = new V[](this._length);
foreach (k, v; this)
{
result[i++] = v;
}
return result;
}
    K[] keys()
{
size_t i = 0;
K[] result = new K[](this._length);
foreach (k, v; this)
{
result[i++] = k;
}
return result;
}
    bool remove(K index, ref V value)
{
size_t i = findExisting(index);
if (i == size_t.max)
{
return false;
}
else
{
_length--;
nDead++;
flags[i] = REMOVED;
value = vals[i];
return true;
}
}
    V* opIn_r(K index)
{
size_t i = findExisting(index);
if (i == size_t.max)
{
return null;
}
else
{
return vals + i;
}
}
    int opApply(int delegate(ref K, ref V) dg)
{
int result;
foreach (i, k; _keys[0..space])
{
if (flags[i] == USED)
{
result = dg(k,vals[i]);
if (result)
{
break;
}
}
}
return result;
}
    private template DeconstArrayType(T)
{
static if(isStaticArray!(T))
{
    alias typeof(T.init[0])[] type;
}
else
{
    alias T type;
}
}

    alias DeconstArrayType!(K).type K_;
    alias DeconstArrayType!(V).type V_;
    public int opApply(int delegate(ref V_ value) dg)
{
return opApply(delegate (ref K_ k, ref V_ v)
{
return dg(v);
}
);
}

    void clear()
{
free();
}
    void free()
{
GC.free(cast(void*)this._keys);
GC.free(cast(void*)this.vals);
GC.free(cast(void*)this.flags);
static if(storeHash)
{
GC.free(cast(void*)this.hashes);
}

}
    size_t length()
{
return _length;
}
}
}
}
}

import std.random;
import std.exception;
import std.stdio;
