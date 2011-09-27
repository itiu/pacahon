// D import file generated from 'dmdscript/dboolean.d'
module dmdscript.dboolean;
import dmdscript.script;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.threadcontext;
import dmdscript.dfunction;
import dmdscript.text;
import dmdscript.property;
import dmdscript.errmsgs;
import dmdscript.dnative;
class DbooleanConstructor : Dfunction
{
    this()
{
super(1,Dfunction_prototype);
name = "Boolean";
}
    void* Construct(CallContext* cc, Value* ret, Value[] arglist)
{
d_boolean b;
Dobject o;
b = arglist.length ? arglist[0].toBoolean() : false;
o = new Dboolean(b);
ret.putVobject(o);
return null;
}
    void* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_boolean b;
b = arglist.length ? arglist[0].toBoolean() : false;
ret.putVboolean(b);
return null;
}
}
void* Dboolean_prototype_toString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dboolean_prototype_valueOf(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
class DbooleanPrototype : Dboolean
{
    this()
{
super(Dobject_prototype);
Put(TEXT_constructor,Dboolean_constructor,DontEnum);
static enum NativeFunctionData[] nfd = [{TEXT_toString,&Dboolean_prototype_toString,0},{TEXT_valueOf,&Dboolean_prototype_valueOf,0}];
DnativeFunction.init(this,nfd,DontEnum);
}
}
class Dboolean : Dobject
{
    this(d_boolean b)
{
super(Dboolean.getPrototype());
value.putVboolean(b);
classname = TEXT_Boolean;
}
    this(Dobject prototype)
{
super(prototype);
value.putVboolean(false);
classname = TEXT_Boolean;
}
    static Dfunction getConstructor()
{
return Dboolean_constructor;
}

    static Dobject getPrototype()
{
return Dboolean_prototype;
}

    static void init()
{
Dboolean_constructor = new DbooleanConstructor;
Dboolean_prototype = new DbooleanPrototype;
Dboolean_constructor.Put(TEXT_prototype,Dboolean_prototype,DontEnum | DontDelete | ReadOnly);
}

}
