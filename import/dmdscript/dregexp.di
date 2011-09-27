// D import file generated from 'dmdscript/dregexp.d'
module dmdscript.dregexp;
private import dmdscript.regexp;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.protoerror;
import dmdscript.text;
import dmdscript.darray;
import dmdscript.threadcontext;
import dmdscript.dfunction;
import dmdscript.property;
import dmdscript.errmsgs;
import dmdscript.dnative;
enum 
{
EXEC_STRING,
EXEC_ARRAY,
EXEC_BOOLEAN,
EXEC_INDEX,
}
class DregexpConstructor : Dfunction
{
    Value* input;
    Value* multiline;
    Value* lastMatch;
    Value* lastParen;
    Value* leftContext;
    Value* rightContext;
    Value*[10] dollar;
    Value* index;
    Value* lastIndex;
    this();
    override void* Construct(CallContext* cc, Value* ret, Value[] arglist);

    override void* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist);

    const Value* Get(d_string PropertyName)
{
return Dfunction.Get(perlAlias(PropertyName));
}
    Value* Put(d_string PropertyName, Value* value, uint attributes)
{
return Dfunction.Put(perlAlias(PropertyName),value,attributes);
}
    Value* Put(d_string PropertyName, Dobject o, uint attributes)
{
return Dfunction.Put(perlAlias(PropertyName),o,attributes);
}
    Value* Put(d_string PropertyName, d_number n, uint attributes)
{
return Dfunction.Put(perlAlias(PropertyName),n,attributes);
}
    int CanPut(d_string PropertyName)
{
return Dfunction.CanPut(perlAlias(PropertyName));
}
    int HasProperty(d_string PropertyName)
{
return Dfunction.HasProperty(perlAlias(PropertyName));
}
    int Delete(d_string PropertyName)
{
return Dfunction.Delete(perlAlias(PropertyName));
}
    static d_string perlAlias(d_string s);

}
void* Dregexp_prototype_toString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dregexp_prototype_test(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return Dregexp.exec(othis,ret,arglist,EXEC_BOOLEAN);
}
void* Dregexp_prototype_exec(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return Dregexp.exec(othis,ret,arglist,EXEC_ARRAY);
}
void* Dregexp_prototype_compile(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
class DregexpPrototype : Dregexp
{
    this()
{
super(Dobject_prototype);
classname = TEXT_Object;
uint attributes = ReadOnly | DontDelete | DontEnum;
Dobject f = Dfunction_prototype;
Put(TEXT_constructor,Dregexp_constructor,attributes);
static enum NativeFunctionData[] nfd = [{TEXT_toString,&Dregexp_prototype_toString,0},{TEXT_compile,&Dregexp_prototype_compile,2},{TEXT_exec,&Dregexp_prototype_exec,1},{TEXT_test,&Dregexp_prototype_test,1}];
DnativeFunction.init(this,nfd,attributes);
}
}
class Dregexp : Dobject
{
    Value* global;
    Value* ignoreCase;
    Value* multiline;
    Value* lastIndex;
    Value* source;
    RegExp re;
    void* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
    this(d_string pattern, d_string attributes);
    this(Dobject prototype)
{
super(prototype);
Value v;
v.putVstring(null);
Value vb;
vb.putVboolean(false);
classname = TEXT_RegExp;
Put(TEXT_source,&v,ReadOnly | DontDelete | DontEnum);
Put(TEXT_global,&vb,ReadOnly | DontDelete | DontEnum);
Put(TEXT_ignoreCase,&vb,ReadOnly | DontDelete | DontEnum);
Put(TEXT_multiline,&vb,ReadOnly | DontDelete | DontEnum);
Put(TEXT_lastIndex,0,DontDelete | DontEnum);
source = Get(TEXT_source);
global = Get(TEXT_global);
ignoreCase = Get(TEXT_ignoreCase);
multiline = Get(TEXT_multiline);
lastIndex = Get(TEXT_lastIndex);
re = new RegExp(null,null);
}
    override void* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
Value* v;
v = Get(TEXT_exec);
return v.toObject().Call(cc,this,ret,arglist);
}

    static Dregexp isRegExp(Value* v);

    static void* exec(Dobject othis, Value* ret, Value[] arglist, int rettype);

    static Dfunction getConstructor()
{
return Dregexp_constructor;
}

    static Dobject getPrototype()
{
return Dregexp_prototype;
}

    static void init();

}
