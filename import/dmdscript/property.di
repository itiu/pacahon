// D import file generated from 'dmdscript/property.d'
module dmdscript.property;
import dmdscript.script;
import dmdscript.value;
import dmdscript.identifier;
import dmdscript.RandAA;
import std.c.string;
import std.stdio;
enum 
{
ReadOnly = 1,
DontEnum = 2,
DontDelete = 4,
Internal = 8,
Deleted = 16,
Locked = 32,
DontOverride = 64,
KeyWord = 128,
DebugFree = 256,
Instantiate = 512,
}
struct Property
{
    uint attributes;
    Value value;
}
extern (C) 
{
    struct Array
{
    int length;
    void* ptr;
}
    struct aaA
{
    aaA* left;
    aaA* right;
    hash_t hash;
}
    struct BB
{
    aaA*[] b;
    size_t nodes;
}
    struct AA
{
    BB* a;
    version (X86_64)
{
}
else
{
    int reserved;
}
}
    long _aaRehash(AA* paa, TypeInfo keyti);
    Property* _aaGetY(hash_t hash, Property[Value]* bb, Value* key);
    Property* _aaInY(hash_t hash, Property[Value] bb, Value* key);
}
struct PropTable
{
    RandAA!(Value,Property) table;
    PropTable* previous;
    int opApply(int delegate(ref Property) dg);
    int opApply(int delegate(ref Value, ref Property) dg);
    Property* getProperty(d_string name);
    Value* get(Value* key, hash_t hash);
    Value* get(d_uint32 index)
{
Value key;
key.putVnumber(index);
return get(&key,Value.calcHash(index));
}
    Value* get(Identifier* id)
{
return get(&id.value,id.value.hash);
}
    Value* get(d_string name, hash_t hash)
{
Value key;
key.putVstring(name);
return get(&key,hash);
}
    int hasownproperty(Value* key, int enumerable)
{
initialize();
Property* p;
p = *key in table;
return p && (!enumerable || !(p.attributes & DontEnum));
}
    int hasproperty(Value* key)
{
initialize();
return (*key in table) != null || previous && previous.hasproperty(key);
}
    int hasproperty(d_string name)
{
Value v;
v.putVstring(name);
return hasproperty(&v);
}
    Value* put(Value* key, hash_t hash, Value* value, uint attributes);
    Value* put(d_string name, Value* value, uint attributes)
{
Value key;
key.putVstring(name);
return put(&key,Value.calcHash(name),value,attributes);
}
    Value* put(d_uint32 index, Value* value, uint attributes)
{
Value key;
key.putVnumber(index);
return put(&key,Value.calcHash(index),value,attributes);
}
    Value* put(d_uint32 index, d_string string, uint attributes)
{
Value key;
Value value;
key.putVnumber(index);
value.putVstring(string);
return put(&key,Value.calcHash(index),&value,attributes);
}
    int canput(Value* key, hash_t hash);
    int canput(d_string name)
{
Value v;
v.putVstring(name);
return canput(&v,v.toHash());
}
    int del(Value* key);
    int del(d_string name)
{
Value v;
v.putVstring(name);
return del(&v);
}
    int del(d_uint32 index)
{
Value v;
v.putVnumber(index);
return del(&v);
}
    void initialize()
{
if (!table)
table = new RandAA!(Value,Property);
}
}
