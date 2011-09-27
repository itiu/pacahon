// D import file generated from 'dmdscript/dfunction.d'
module dmdscript.dfunction;
import std.string;
import std.c.stdlib;
import dmdscript.script;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.protoerror;
import dmdscript.threadcontext;
import dmdscript.text;
import dmdscript.errmsgs;
import dmdscript.property;
import dmdscript.scopex;
import dmdscript.dnative;
import dmdscript.functiondefinition;
import dmdscript.parse;
import dmdscript.ddeclaredfunction;
class DfunctionConstructor : Dfunction
{
    this()
{
super(1,Dfunction_prototype);
}
    void* Construct(CallContext* cc, Value* ret, Value[] arglist);
    void* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return Construct(cc,ret,arglist);
}
}
void* Dfunction_prototype_toString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dfunction_prototype_apply(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dfunction_prototype_call(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
class DfunctionPrototype : Dfunction
{
    this()
{
super(0,Dobject_prototype);
uint attributes = DontEnum;
classname = TEXT_Function;
name = "prototype";
Put(TEXT_constructor,Dfunction_constructor,attributes);
static enum NativeFunctionData[] nfd = [{TEXT_toString,&Dfunction_prototype_toString,0},{TEXT_apply,&Dfunction_prototype_apply,2},{TEXT_call,&Dfunction_prototype_call,1}];
DnativeFunction.init(this,nfd,attributes);
}
    void* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
ret.putVundefined();
return null;
}
}
class Dfunction : Dobject
{
    const(char)[] name;
    Dobject[] scopex;
    this(d_uint32 length)
{
this(length,Dfunction.getPrototype());
}
    this(d_uint32 length, Dobject prototype)
{
super(prototype);
classname = TEXT_Function;
name = TEXT_Function;
Put(TEXT_length,length,DontDelete | DontEnum | ReadOnly);
Put(TEXT_arity,length,DontDelete | DontEnum | ReadOnly);
}
    override immutable(char)[] getTypeof()
{
return TEXT_function;
}

    override string toString()
{
immutable(char)[] s;
s = std.string.format("function %s() { [native code] }",name);
return s;
}

    override void* HasInstance(Value* ret, Value* v);

    static Dfunction isFunction(Value* v);

    static Dfunction getConstructor()
{
return Dfunction_constructor;
}

    static Dobject getPrototype()
{
return Dfunction_prototype;
}

    static void init()
{
Dfunction_constructor = new DfunctionConstructor;
Dfunction_prototype = new DfunctionPrototype;
Dfunction_constructor.Put(TEXT_prototype,Dfunction_prototype,DontEnum | DontDelete | ReadOnly);
Dfunction_constructor.internal_prototype = Dfunction_prototype;
Dfunction_constructor.proptable.previous = Dfunction_prototype.proptable;
}

}
