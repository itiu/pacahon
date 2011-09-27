// D import file generated from 'dmdscript/protoerror.d'
module dmdscript.protoerror;
import dmdscript.script;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.threadcontext;
import dmdscript.text;
import dmdscript.dfunction;
import dmdscript.property;
int foo;
class D0_constructor : Dfunction
{
    d_string text_d1;
    Dobject function(d_string) newD0;
    this(d_string text_d1, Dobject function(d_string) newD0)
{
super(1,Dfunction_prototype);
this.text_d1 = text_d1;
this.newD0 = newD0;
}
    void* Construct(CallContext* cc, Value* ret, Value[] arglist)
{
Value* m;
Dobject o;
d_string s;
m = arglist.length ? &arglist[0] : &vundefined;
if (m.isUndefined())
s = text_d1;
else
s = m.toString();
o = (*newD0)(s);
ret.putVobject(o);
return null;
}
    void* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return Construct(cc,ret,arglist);
}
}
template proto(alias TEXT_D1)
{
class D0_prototype : D0
{
    this()
{
super(Derror_prototype);
d_string s;
Put(TEXT_constructor,ctorTable[TEXT_D1],DontEnum);
Put(TEXT_name,TEXT_D1,0);
s = TEXT_D1 ~ ".prototype.message";
Put(TEXT_message,s,0);
Put(TEXT_description,s,0);
Put(TEXT_number,cast(d_number)0,0);
}
}
class D0 : Dobject
{
    ErrInfo errinfo;
    this(Dobject prototype)
{
super(prototype);
classname = TEXT_Error;
}
    this(d_string m)
{
this(D0.getPrototype());
Put(TEXT_message,m,0);
Put(TEXT_description,m,0);
Put(TEXT_number,cast(d_number)0,0);
errinfo.message = m;
}
    this(ErrInfo* perrinfo)
{
this(perrinfo.message);
errinfo = *perrinfo;
Put(TEXT_number,cast(d_number)perrinfo.code,0);
}
    void getErrInfo(ErrInfo* perrinfo, int linnum)
{
if (linnum && errinfo.linnum == 0)
errinfo.linnum = linnum;
if (perrinfo)
*perrinfo = errinfo;
}
    static Dfunction getConstructor()
{
return ctorTable[TEXT_D1];
}

    static Dobject getPrototype()
{
return protoTable[TEXT_D1];
}

    static Dobject newD0(d_string s)
{
return new D0(s);
}

    static void init()
{
Dfunction constructor = new D0_constructor(TEXT_D1,&newD0);
ctorTable[TEXT_D1] = constructor;
Dobject prototype = new D0_prototype;
protoTable[TEXT_D1] = prototype;
constructor.Put(TEXT_prototype,prototype,DontEnum | DontDelete | ReadOnly);
}

}
}
alias proto!(TEXT_SyntaxError) syntaxerror;
alias proto!(TEXT_EvalError) evalerror;
alias proto!(TEXT_ReferenceError) referenceerror;
alias proto!(TEXT_RangeError) rangeerror;
alias proto!(TEXT_TypeError) typeerror;
alias proto!(TEXT_URIError) urierror;
static this();
