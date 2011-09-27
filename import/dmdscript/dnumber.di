// D import file generated from 'dmdscript/dnumber.d'
module dmdscript.dnumber;
import std.math;
import std.c.stdlib;
import std.exception;
import dmdscript.script;
import dmdscript.dobject;
import dmdscript.dfunction;
import dmdscript.value;
import dmdscript.threadcontext;
import dmdscript.text;
import dmdscript.property;
import dmdscript.errmsgs;
import dmdscript.dnative;
class DnumberConstructor : Dfunction
{
    this()
{
super(1,Dfunction_prototype);
uint attributes = DontEnum | DontDelete | ReadOnly;
name = TEXT_Number;
Put(TEXT_MAX_VALUE,d_number.max,attributes);
Put(TEXT_MIN_VALUE,d_number.min_normal * d_number.epsilon,attributes);
Put(TEXT_NaN,d_number.nan,attributes);
Put(TEXT_NEGATIVE_INFINITY,-d_number.infinity,attributes);
Put(TEXT_POSITIVE_INFINITY,d_number.infinity,attributes);
}
    override void* Construct(CallContext* cc, Value* ret, Value[] arglist)
{
d_number n;
Dobject o;
n = arglist.length ? arglist[0].toNumber() : 0;
o = new Dnumber(n);
ret.putVobject(o);
return null;
}

    override void* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_number n;
n = arglist.length ? arglist[0].toNumber() : 0;
ret.putVnumber(n);
return null;
}

}
void* Dnumber_prototype_toString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dnumber_prototype_toLocaleString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dnumber_prototype_valueOf(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
const int FIXED_DIGITS = 20;

static d_number[FIXED_DIGITS + 1] tens = [1,10,100,1000,10000,100000,1e+06,1e+07,1e+08,1e+09,1e+10,1e+11,1e+12,1e+13,1e+14,1e+15,1e+16,1e+17,1e+18,1e+19,1e+20];

number_t deconstruct_real(d_number x, int f, out int pe)
{
number_t n;
int e;
int i;
e = cast(int)log10(x);
i = e - f;
if (i >= 0 && i < tens.length)
n = cast(number_t)(x / tens[i] + 0.5);
else
n = cast(number_t)(x / std.math.pow(cast(real)10,i) + 0.5);
pe = e;
return n;
}
void* Dnumber_prototype_toFixed(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dnumber_prototype_toExponential(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dnumber_prototype_toPrecision(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
class DnumberPrototype : Dnumber
{
    this()
{
super(Dobject_prototype);
uint attributes = DontEnum;
Dobject f = Dfunction_prototype;
Put(TEXT_constructor,Dnumber_constructor,attributes);
static enum NativeFunctionData[] nfd = [{TEXT_toString,&Dnumber_prototype_toString,1},{TEXT_toLocaleString,&Dnumber_prototype_toLocaleString,1},{TEXT_valueOf,&Dnumber_prototype_valueOf,0},{TEXT_toFixed,&Dnumber_prototype_toFixed,1},{TEXT_toExponential,&Dnumber_prototype_toExponential,1},{TEXT_toPrecision,&Dnumber_prototype_toPrecision,1}];
DnativeFunction.init(this,nfd,attributes);
}
}
class Dnumber : Dobject
{
    this(d_number n)
{
super(getPrototype());
classname = TEXT_Number;
value.putVnumber(n);
}
    this(Dobject prototype)
{
super(prototype);
classname = TEXT_Number;
value.putVnumber(0);
}
    static Dfunction getConstructor()
{
return Dnumber_constructor;
}

    static Dobject getPrototype()
{
return Dnumber_prototype;
}

    static void init()
{
Dnumber_constructor = new DnumberConstructor;
Dnumber_prototype = new DnumberPrototype;
Dnumber_constructor.Put(TEXT_prototype,Dnumber_prototype,DontEnum | DontDelete | ReadOnly);
}

}
