// D import file generated from 'dmdscript/derror.d'
module dmdscript.derror;
import dmdscript.script;
import dmdscript.dobject;
import dmdscript.dfunction;
import dmdscript.value;
import dmdscript.threadcontext;
import dmdscript.dnative;
import dmdscript.text;
import dmdscript.property;
const uint FACILITY = -2146828288u;

class DerrorConstructor : Dfunction
{
    this()
{
super(1,Dfunction_prototype);
}
    override void* Construct(CallContext* cc, Value* ret, Value[] arglist);

    void* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return Construct(cc,ret,arglist);
}
}
void* Derror_prototype_toString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
Value* v;
v = othis.Get(TEXT_message);
if (!v)
v = &vundefined;
ret.putVstring(othis.Get(TEXT_name).toString() ~ ": " ~ v.toString());
return null;
}
class DerrorPrototype : Derror
{
    this()
{
super(Dobject_prototype);
Dobject f = Dfunction_prototype;
Put(TEXT_constructor,Derror_constructor,DontEnum);
static enum NativeFunctionData[] nfd = [{TEXT_toString,&Derror_prototype_toString,0}];
DnativeFunction.init(this,nfd,0);
Put(TEXT_name,TEXT_Error,0);
Put(TEXT_message,TEXT_,0);
Put(TEXT_description,TEXT_,0);
Put(TEXT_number,cast(d_number)0,0);
}
}
class Derror : Dobject
{
    this(Value* m, Value* v2);
    this(Dobject prototype)
{
super(prototype);
classname = TEXT_Error;
}
    static Dfunction getConstructor()
{
return Derror_constructor;
}

    static Dobject getPrototype()
{
return Derror_prototype;
}

    static void init()
{
Derror_constructor = new DerrorConstructor;
Derror_prototype = new DerrorPrototype;
Derror_constructor.Put(TEXT_prototype,Derror_prototype,DontEnum | DontDelete | ReadOnly);
}

}
