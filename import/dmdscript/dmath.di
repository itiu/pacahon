// D import file generated from 'dmdscript/dmath.d'
module dmdscript.dmath;
import std.math;
import std.random;
import dmdscript.script;
import dmdscript.value;
import dmdscript.dobject;
import dmdscript.dnative;
import dmdscript.threadcontext;
import dmdscript.text;
import dmdscript.property;
d_number math_helper(Value[] arglist)
{
Value* v;
v = arglist.length ? &arglist[0] : &vundefined;
return v.toNumber();
}
void* Dmath_abs(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_number result;
result = fabs(math_helper(arglist));
ret.putVnumber(result);
return null;
}
void* Dmath_acos(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_number result;
result = acos(math_helper(arglist));
ret.putVnumber(result);
return null;
}
void* Dmath_asin(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_number result;
result = asin(math_helper(arglist));
ret.putVnumber(result);
return null;
}
void* Dmath_atan(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_number result;
result = atan(math_helper(arglist));
ret.putVnumber(result);
return null;
}
void* Dmath_atan2(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_number n1;
Value* v2;
d_number result;
n1 = math_helper(arglist);
v2 = arglist.length >= 2 ? &arglist[1] : &vundefined;
result = atan2(n1,v2.toNumber());
ret.putVnumber(result);
return null;
}
void* Dmath_ceil(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_number result;
result = ceil(math_helper(arglist));
ret.putVnumber(result);
return null;
}
void* Dmath_cos(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_number result;
result = cos(math_helper(arglist));
ret.putVnumber(result);
return null;
}
void* Dmath_exp(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_number result;
result = std.math.exp(math_helper(arglist));
ret.putVnumber(result);
return null;
}
void* Dmath_floor(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_number result;
result = std.math.floor(math_helper(arglist));
ret.putVnumber(result);
return null;
}
void* Dmath_log(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_number result;
result = log(math_helper(arglist));
ret.putVnumber(result);
return null;
}
void* Dmath_max(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dmath_min(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dmath_pow(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_number n1;
Value* v2;
d_number result;
n1 = math_helper(arglist);
v2 = arglist.length >= 2 ? &arglist[1] : &vundefined;
result = pow(n1,v2.toNumber());
ret.putVnumber(result);
return null;
}
void* Dmath_random(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dmath_round(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_number result;
result = math_helper(arglist);
if (!isnan(result))
result = copysign(std.math.floor(result + 0.5),result);
ret.putVnumber(result);
return null;
}
void* Dmath_sin(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_number result;
result = sin(math_helper(arglist));
ret.putVnumber(result);
return null;
}
void* Dmath_sqrt(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_number result;
result = sqrt(math_helper(arglist));
ret.putVnumber(result);
return null;
}
void* Dmath_tan(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_number result;
result = tan(math_helper(arglist));
ret.putVnumber(result);
return null;
}
class Dmath : Dobject
{
    this();
    static void init()
{
Dmath_object = new Dmath;
}

}
