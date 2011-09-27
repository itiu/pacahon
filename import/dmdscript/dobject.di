// D import file generated from 'dmdscript/dobject.d'
module dmdscript.dobject;
import std.string;
import std.c.stdarg;
import std.c.string;
import std.exception;
import dmdscript.script;
import dmdscript.value;
import dmdscript.dfunction;
import dmdscript.property;
import dmdscript.threadcontext;
import dmdscript.iterator;
import dmdscript.identifier;
import dmdscript.errmsgs;
import dmdscript.text;
import dmdscript.program;
import dmdscript.dboolean;
import dmdscript.dstring;
import dmdscript.dnumber;
import dmdscript.darray;
import dmdscript.dmath;
import dmdscript.ddate;
import dmdscript.dregexp;
import dmdscript.derror;
import dmdscript.dnative;
import dmdscript.protoerror;
enum int* pfoo = &dmdscript.protoerror.foo;
class ErrorValue : Exception
{
    Value value;
    this(Value* vptr)
{
super("DMDScript exception");
value = *vptr;
}
}
class DobjectConstructor : Dfunction
{
    this()
{
super(1,Dfunction_prototype);
if (Dobject_prototype)
Put(TEXT_prototype,Dobject_prototype,DontEnum | DontDelete | ReadOnly);
}
    override void* Construct(CallContext* cc, Value* ret, Value[] arglist);

    void* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
}
void* Dobject_prototype_toString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_string s;
d_string string;
s = othis.classname;
string = std.string.format("[object %s]",s);
ret.putVstring(string);
return null;
}
void* Dobject_prototype_toLocaleString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dobject_prototype_valueOf(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
ret.putVobject(othis);
return null;
}
void* Dobject_prototype_toSource(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dobject_prototype_hasOwnProperty(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
Value* v;
v = arglist.length ? &arglist[0] : &vundefined;
ret.putVboolean(othis.proptable.hasownproperty(v,0));
return null;
}
void* Dobject_prototype_isPrototypeOf(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dobject_prototype_propertyIsEnumerable(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
Value* v;
v = arglist.length ? &arglist[0] : &vundefined;
ret.putVboolean(othis.proptable.hasownproperty(v,1));
return null;
}
class DobjectPrototype : Dobject
{
    this()
{
super(null);
}
}
class Dobject
{
    PropTable* proptable;
    Dobject internal_prototype;
    string classname;
    Value value;
    const uint DOBJECT_SIGNATURE = -1439568335u;

    uint signature;
        this(Dobject prototype)
{
proptable = new PropTable;
internal_prototype = prototype;
if (prototype)
proptable.previous = prototype.proptable;
classname = TEXT_Object;
value.putVobject(this);
signature = DOBJECT_SIGNATURE;
}
    Dobject Prototype()
{
return internal_prototype;
}
    Value* Get(d_string PropertyName)
{
return Get(PropertyName,Value.calcHash(PropertyName));
}
    Value* Get(Identifier* id)
{
Value* v;
v = proptable.get(&id.value,id.value.hash);
return v;
}
    Value* Get(d_string PropertyName, uint hash)
{
Value* v;
v = proptable.get(PropertyName,hash);
return v;
}
    Value* Get(d_uint32 index)
{
Value* v;
v = proptable.get(index);
return v;
}
    Value* Get(d_uint32 index, Value* vindex)
{
return proptable.get(vindex,Value.calcHash(index));
}
    Value* Put(d_string PropertyName, Value* value, uint attributes)
{
proptable.put(PropertyName,value,attributes);
return null;
}
    Value* Put(Identifier* key, Value* value, uint attributes)
{
proptable.put(&key.value,key.value.hash,value,attributes);
return null;
}
    Value* Put(d_string PropertyName, Dobject o, uint attributes)
{
Value v;
v.putVobject(o);
proptable.put(PropertyName,&v,attributes);
return null;
}
    Value* Put(d_string PropertyName, d_number n, uint attributes)
{
Value v;
v.putVnumber(n);
proptable.put(PropertyName,&v,attributes);
return null;
}
    Value* Put(d_string PropertyName, d_string s, uint attributes)
{
Value v;
v.putVstring(s);
proptable.put(PropertyName,&v,attributes);
return null;
}
    Value* Put(d_uint32 index, Value* vindex, Value* value, uint attributes)
{
proptable.put(vindex,Value.calcHash(index),value,attributes);
return null;
}
    Value* Put(d_uint32 index, Value* value, uint attributes)
{
proptable.put(index,value,attributes);
return null;
}
    Value* PutDefault(Value* value)
{
ErrInfo errinfo;
return RuntimeError(&errinfo,ERR_NO_DEFAULT_PUT);
}
    Value* put_Value(Value* ret, Value[] arglist)
{
ErrInfo errinfo;
return RuntimeError(&errinfo,ERR_FUNCTION_NOT_LVALUE);
}
    int CanPut(d_string PropertyName)
{
return proptable.canput(PropertyName);
}
    int HasProperty(d_string PropertyName)
{
return proptable.hasproperty(PropertyName);
}
    int Delete(d_string PropertyName)
{
return proptable.del(PropertyName);
}
    int Delete(d_uint32 index)
{
return proptable.del(index);
}
    int implementsDelete()
{
return true;
}
    void* DefaultValue(Value* ret, d_string Hint);
    void* Construct(CallContext* cc, Value* ret, Value[] arglist)
{
ErrInfo errinfo;
return RuntimeError(&errinfo,errmsgtbl[ERR_S_NO_CONSTRUCT],classname);
}
    void* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
ErrInfo errinfo;
return RuntimeError(&errinfo,errmsgtbl[ERR_S_NO_CALL],classname);
}
    void* HasInstance(Value* ret, Value* v)
{
ErrInfo errinfo;
return RuntimeError(&errinfo,errmsgtbl[ERR_S_NO_INSTANCE],classname);
}
    d_string getTypeof()
{
return TEXT_object;
}
    const int isClass(d_string classname)
{
return this.classname == classname;
}
    const int isDarray()
{
return isClass(TEXT_Array);
}
    const int isDdate()
{
return isClass(TEXT_Date);
}
    const int isDregexp()
{
return isClass(TEXT_RegExp);
}
    const int isDarguments()
{
return false;
}
    const int isCatch()
{
return false;
}
    const int isFinally()
{
return false;
}
    void getErrInfo(ErrInfo* perrinfo, int linnum)
{
ErrInfo errinfo;
Value v;
v.putVobject(this);
errinfo.message = v.toString();
if (perrinfo)
*perrinfo = errinfo;
}
    static Value* RuntimeError(ErrInfo* perrinfo, int msgnum)
{
return RuntimeError(perrinfo,errmsgtbl[msgnum]);
}

    static Value* RuntimeError(ErrInfo* perrinfo,...);

    static Value* ReferenceError(ErrInfo* perrinfo, int msgnum)
{
return ReferenceError(perrinfo,errmsgtbl[msgnum]);
}

    static Value* ReferenceError(...);

    static Value* RangeError(ErrInfo* perrinfo, int msgnum)
{
return RangeError(perrinfo,errmsgtbl[msgnum]);
}

    static Value* RangeError(ErrInfo* perrinfo,...);

    Value* putIterator(Value* v)
{
Iterator* i = new Iterator;
i.ctor(this);
v.putViterator(i);
return null;
}
    static Dfunction getConstructor()
{
return Dobject_constructor;
}

    static Dobject getPrototype()
{
return Dobject_prototype;
}

    static void init()
{
Dobject_prototype = new DobjectPrototype;
Dfunction.init();
Dobject_constructor = new DobjectConstructor;
Dobject op = Dobject_prototype;
Dobject f = Dfunction_prototype;
op.Put(TEXT_constructor,Dobject_constructor,DontEnum);
static enum NativeFunctionData[] nfd = [{TEXT_toString,&Dobject_prototype_toString,0},{TEXT_toLocaleString,&Dobject_prototype_toLocaleString,0},{TEXT_toSource,&Dobject_prototype_toSource,0},{TEXT_valueOf,&Dobject_prototype_valueOf,0},{TEXT_hasOwnProperty,&Dobject_prototype_hasOwnProperty,1},{TEXT_isPrototypeOf,&Dobject_prototype_isPrototypeOf,0},{TEXT_propertyIsEnumerable,&Dobject_prototype_propertyIsEnumerable,0}];
DnativeFunction.init(op,nfd,DontEnum);
}

}
void dobject_init();
