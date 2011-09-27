// D import file generated from 'dmdscript/extending.d'
module dmdscript.extending;
import dmdscript.script;
import dmdscript.value;
import dmdscript.dobject;
import dmdscript.dfunction;
import dmdscript.dnative;
import dmdscript.program;
import dmdscript.property;
import dmdscript.threadcontext;
import std.typecons;
import std.traits;
import std.typetuple;
import std.file;
template convert(T)
{
T convert(Value* v)
{
static if(is(T == int))
{
return v.toInt32();
}
else
{
static if(isSomeString!(T))
{
return v.toString();
}
else
{
assert(0);
}

}

}
}
template convertPut(T)
{
void convertPut(ref T what, Value* v)
{
static if(isIntegral!(T) || isFloatingPoint!(T))
{
v.putVnumber(what);
}

}
}
template extendGlobal(alias fn) if (isCallable!(fn))
{
void extendGlobal(Program pg, string name)
{
alias ParameterTypeTuple!(fn) Args;
alias ReturnType!(fn) R;
alias staticMap!(Unqual,Args) Uargs;
static void* embedded(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
Tuple!(Uargs) tup = convertAll!(Uargs)(arglist);
if (arglist.length < tup.length)
{
auto len = arglist.length;
arglist.length = tup.length;
arglist[len..$] = vundefined;
}
arglist = arglist[0..tup.length];
static if(is(R == void))
{
fn(tup.expand);
}
else
{
R r = fn(tup.expand);
convertPut(r,ret);
}

return null;
}
NativeFunctionData[] nfd = [{name,&embedded,staticLength!(Args)}];
DnativeFunction.init(pg.callcontext.global,nfd,DontEnum);
}
}
template fitArray(T...)
{
void fitArray(ref Value[] arglist)
{
enum staticLen = staticLength!(T);
if (arglist.length < staticLen)
{
auto len = arglist.length;
arglist.length = staticLen;
arglist[len..$] = vundefined;
}
arglist = arglist[0..staticLen];
}
}
template extendMethod(T,alias fn) if (is(T == class) && isCallable!(fn))
{
void extendMethod(Dobject obj, string name)
{
alias ParameterTypeTuple!(fn) Args;
alias ReturnType!(fn) R;
alias staticMap!(Unqual,Args) Uargs;
static void* embedded(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
static if(staticLength!(Uargs))
{
Tuple!(Uargs) tup = convertAll!(Uargs)(arglist);
fitArray(arglist);
}

assert(cast(T)othis,"Wrong this pointer in external func ");
static if(staticLength!(Uargs))
{
auto dg = delegate ()
{
mixin("(cast(T)othis).wrapped." ~ (&fn).stringof[2..$] ~ "(tup.expand);");
}
;
}
else
{
auto dg = delegate ()
{
mixin("(cast(T)othis).wrapped." ~ (&fn).stringof[2..$] ~ "();");
}
;
}

static if(is(R == void))
{
dg();
}
else
{
R r = dg();
convertPut(r,ret);
}

return null;
}
NativeFunctionData[] nfd = [{name,&embedded,staticLength!(Args)}];
DnativeFunction.init(obj,nfd,DontEnum);
}
}
template Wrap(Which,string ClassName,Base = Dobject)
{
class Wrap : Base
{
    Which wrapped;
    static Wrap _prototype;

    static Constructor _constructor;

    static class Constructor : Dfunction
{
    this()
{
super(staticLength!(ConstructorArgs),Dfunction_prototype);
name = ClassName;
}
    void* Construct(CallContext* cc, Value* ret, Value[] arglist)
{
fitArray!(ConstructorArgs)(arglist);
Dobject o = new Wrap(convertAll!(UConstructorArgs)(arglist).expand);
ret.putVobject(o);
return null;
}
    void* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return Construct(cc,ret,arglist);
}
}

    static void init()
{
_prototype = new Wrap(Base.getPrototype());
_constructor = new Constructor;
_prototype.Put("constructor",_constructor,DontEnum);
_constructor.Put("prototype",_prototype,DontEnum | DontDelete | ReadOnly);
ctorTable[ClassName] = _constructor;
}

    static this();
    private this(Dobject prototype)
{
super(prototype);
classname = ClassName;
}

    alias ParameterTypeTuple!(Which.__ctor) ConstructorArgs;
    alias staticMap!(Unqual,ConstructorArgs) UConstructorArgs;
    this(ConstructorArgs args)
{
super(_prototype);
static if(is(Which == struct))
{
wrapped = Which(args);
}

}
    static template methods(Methods...)
{
void methods()
{
static if(staticLength!(Methods) >= 1)
{
extendMethod!(Wrap,Methods[0])(_prototype,(&Methods[0]).stringof[2..$]);
methods!(Methods[1 .. __dollar])();
}

}
}

}
}
template convertAll(Args...)
{
auto  convertAll(Value[] dest)
{
static if(staticLength!(Args) > 1)
{
return tuple(convert!(Args[0])(&dest[0]),convertAll!(Args[1 .. __dollar])(dest[1..$]).expand);
}
else
{
return tuple(convert!(Args[0])(&dest[0]));
}

}
}
