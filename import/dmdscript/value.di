// D import file generated from 'dmdscript/value.d'
module dmdscript.value;
import std.math;
import std.string;
import std.stdio;
import std.c.string;
import std.date;
import dmdscript.script;
import dmdscript.dobject;
import dmdscript.iterator;
import dmdscript.identifier;
import dmdscript.errmsgs;
import dmdscript.text;
import dmdscript.program;
import dmdscript.dstring;
import dmdscript.dnumber;
import dmdscript.dboolean;
version (DigitalMars)
{
    version (D_InlineAsm)
{
    version = UseAsm;
}
}
enum 
{
V_REF_ERROR = 0,
V_UNDEFINED = 1,
V_NULL = 2,
V_BOOLEAN = 3,
V_NUMBER = 4,
V_STRING = 5,
V_OBJECT = 6,
V_ITER = 7,
}
struct Value
{
    ubyte vtype = V_UNDEFINED;
    uint hash;
    union
{
d_boolean dbool;
d_number number;
d_string string;
Dobject object;
d_int32 int32;
d_uint32 uint32;
d_uint16 uint16;
Iterator* iter;
}
    void checkReference()
{
if (vtype == V_REF_ERROR)
throwRefError();
}
    const void throwRefError();
    void putSignalingUndefined(d_string id)
{
vtype = V_REF_ERROR;
string = id;
}
    void putVundefined()
{
vtype = V_UNDEFINED;
hash = 0;
string = null;
}
    void putVnull()
{
vtype = V_NULL;
}
    void putVboolean(d_boolean b)
in
{
assert(b == 1 || b == 0);
}
body
{
vtype = V_BOOLEAN;
dbool = b;
}
    void putVnumber(d_number n)
{
vtype = V_NUMBER;
number = n;
}
    void putVtime(d_time n)
{
vtype = V_NUMBER;
number = n == d_time_nan ? d_number.nan : n;
}
    void putVstring(d_string s)
{
vtype = V_STRING;
hash = 0;
string = s;
}
    void putVstring(d_string s, uint hash)
{
vtype = V_STRING;
this.hash = hash;
this.string = s;
}
    void putVobject(Dobject o)
{
vtype = V_OBJECT;
object = o;
}
    void putViterator(Iterator* i)
{
vtype = V_ITER;
iter = i;
}
        static void copy(Value* to, Value* from);

    void* toPrimitive(Value* v, d_string PreferredType);
    d_boolean toBoolean();
    d_number toNumber();
    d_time toDtime()
{
return cast(d_time)toNumber();
}
    d_number toInteger();
    d_int32 toInt32();
    d_uint32 toUint32();
    d_uint16 toUint16();
    d_string toString();
    d_string toLocaleString()
{
return toString();
}
    d_string toString(int radix);
    d_string toSource();
    Dobject toObject();
    const bool opEquals(ref const(Value) v)
{
return opCmp(v) == 0;
}

    static int stringcmp(d_string s1, d_string s2);

    const int opCmp(const(Value) v);
    void copyTo(Value* v)
{
copy(&this,v);
}
    d_string getType();
    d_string getTypeof();
    int isUndefined()
{
return vtype == V_UNDEFINED;
}
    int isNull()
{
return vtype == V_NULL;
}
    int isBoolean()
{
return vtype == V_BOOLEAN;
}
    int isNumber()
{
return vtype == V_NUMBER;
}
    int isString()
{
return vtype == V_STRING;
}
    int isObject()
{
return vtype == V_OBJECT;
}
    int isIterator()
{
return vtype == V_ITER;
}
    int isUndefinedOrNull()
{
return vtype == V_UNDEFINED || vtype == V_NULL;
}
    int isPrimitive()
{
return vtype != V_OBJECT;
}
    int isArrayIndex(out d_uint32 index);
    static uint calcHash(uint u)
{
return u ^ 1431655765;
}

    static uint calcHash(double d)
{
return calcHash(cast(uint)d);
}

    static uint calcHash(d_string s);

    uint toHash();
    Value* Put(d_string PropertyName, Value* value);
    Value* Put(d_uint32 index, Value* vindex, Value* value);
    Value* Get(d_string PropertyName);
    Value* Get(d_uint32 index);
    Value* Get(Identifier* id);
    void* Construct(CallContext* cc, Value* ret, Value[] arglist);
    void* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
    Value* putIterator(Value* v);
    void getErrInfo(ErrInfo* perrinfo, int linnum);
    void dump()
{
uint* v = cast(uint*)&this;
writef("v[%x] = %8x, %8x, %8x, %8x\x0a",cast(uint)v,v[0],v[1],v[2],v[3]);
}
}
static assert(Value.sizeof == 16);
Value vundefined = {V_UNDEFINED};
Value vnull = {V_NULL};
string TypeUndefined = "Undefined";
string TypeNull = "Null";
string TypeBoolean = "Boolean";
string TypeNumber = "Number";
string TypeString = "String";
string TypeObject = "Object";
string TypeIterator = "Iterator";
Value* signalingUndefined(string id)
{
Value* p;
p = new Value;
p.putSignalingUndefined(id);
return p;
}
