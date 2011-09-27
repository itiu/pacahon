// D import file generated from 'dmdscript/darray.d'
module dmdscript.darray;
version = SliceSpliceExtension;
import std.string;
import std.c.stdlib;
import std.math;
import dmdscript.script;
import dmdscript.value;
import dmdscript.dobject;
import dmdscript.threadcontext;
import dmdscript.identifier;
import dmdscript.dfunction;
import dmdscript.text;
import dmdscript.property;
import dmdscript.errmsgs;
import dmdscript.dnative;
import dmdscript.program;
class DarrayConstructor : Dfunction
{
    this()
{
super(1,Dfunction_prototype);
name = "Array";
}
    override void* Construct(CallContext* cc, Value* ret, Value[] arglist);

    override void* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return Construct(cc,ret,arglist);
}

}
void* Darray_prototype_toString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
array_join(othis,ret,null);
return null;
}
void* Darray_prototype_toLocaleString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Darray_prototype_concat(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Darray_prototype_join(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
array_join(othis,ret,arglist);
return null;
}
void array_join(Dobject othis, Value* ret, Value[] arglist);
void* Darray_prototype_toSource(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Darray_prototype_pop(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Darray_prototype_push(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Darray_prototype_reverse(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Darray_prototype_shift(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Darray_prototype_slice(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
static Dobject comparefn;

static CallContext* comparecc;

extern (C) int compare_value(const void* x, const void* y);

void* Darray_prototype_sort(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Darray_prototype_splice(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Darray_prototype_unshift(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
class DarrayPrototype : Darray
{
    this()
{
super(Dobject_prototype);
Dobject f = Dfunction_prototype;
Put(TEXT_constructor,Darray_constructor,DontEnum);
static enum NativeFunctionData[] nfd = [{TEXT_toString,&Darray_prototype_toString,0},{TEXT_toLocaleString,&Darray_prototype_toLocaleString,0},{TEXT_toSource,&Darray_prototype_toSource,0},{TEXT_concat,&Darray_prototype_concat,1},{TEXT_join,&Darray_prototype_join,1},{TEXT_pop,&Darray_prototype_pop,0},{TEXT_push,&Darray_prototype_push,1},{TEXT_reverse,&Darray_prototype_reverse,0},{TEXT_shift,&Darray_prototype_shift,0},{TEXT_slice,&Darray_prototype_slice,2},{TEXT_sort,&Darray_prototype_sort,1},{TEXT_splice,&Darray_prototype_splice,2},{TEXT_unshift,&Darray_prototype_unshift,1}];
DnativeFunction.init(this,nfd,DontEnum);
}
}
class Darray : Dobject
{
    Value length;
    d_uint32 ulength;
    this()
{
this(getPrototype());
}
    this(Dobject prototype)
{
super(prototype);
length.putVnumber(0);
ulength = 0;
classname = TEXT_Array;
}
    Value* Put(Identifier* key, Value* value, uint attributes)
{
Value* result = proptable.put(&key.value,key.value.hash,value,attributes);
if (!result)
Put(key.value.string,value,attributes);
return null;
}
    Value* Put(d_string name, Value* v, uint attributes);
    Value* Put(d_string name, Dobject o, uint attributes)
{
return Put(name,&o.value,attributes);
}
    Value* Put(d_string PropertyName, d_number n, uint attributes)
{
Value v;
v.putVnumber(n);
return Put(PropertyName,&v,attributes);
}
    Value* Put(d_string PropertyName, d_string string, uint attributes)
{
Value v;
v.putVstring(string);
return Put(PropertyName,&v,attributes);
}
    Value* Put(d_uint32 index, Value* vindex, Value* value, uint attributes)
{
if (index >= ulength)
ulength = index + 1;
proptable.put(vindex,index ^ 1431655765,value,attributes);
return null;
}
    Value* Put(d_uint32 index, Value* value, uint attributes);
    Value* Put(d_uint32 index, d_string string, uint attributes);
    Value* Get(Identifier* id);
    Value* Get(d_string PropertyName, uint hash);
    Value* Get(d_uint32 index)
{
Value* v;
v = proptable.get(index);
return v;
}
    Value* Get(d_uint32 index, Value* vindex)
{
Value* v;
v = proptable.get(vindex,index ^ 1431655765);
return v;
}
    int Delete(d_string PropertyName)
{
if (PropertyName == TEXT_length)
return 0;
else
return proptable.del(PropertyName);
}
    int Delete(d_uint32 index)
{
return proptable.del(index);
}
    static Dfunction getConstructor()
{
return Darray_constructor;
}

    static Dobject getPrototype()
{
return Darray_prototype;
}

    static void init()
{
Darray_constructor = new DarrayConstructor;
Darray_prototype = new DarrayPrototype;
Darray_constructor.Put(TEXT_prototype,Darray_prototype,DontEnum | ReadOnly);
}

}
