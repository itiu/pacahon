// D import file generated from 'dmdscript/ddate.d'
module dmdscript.ddate;
import std.math;
debug (1)
{
    import std.stdio;
}
import std.date;
import dmdscript.script;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.threadcontext;
import dmdscript.dfunction;
import dmdscript.dnative;
import dmdscript.property;
import dmdscript.text;
import dmdscript.errmsgs;
version = DATETOSTRING;
enum TIMEFORMAT 
{
String,
DateString,
TimeString,
LocaleString,
LocaleDateString,
LocaleTimeString,
UTCString,
}
d_time parseDateString(CallContext* cc, string s)
{
return std.date.parse(s);
}
string dateToString(CallContext* cc, d_time t, TIMEFORMAT tf);
void* Ddate_parse(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_UTC(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
class DdateConstructor : Dfunction
{
    this()
{
super(7,Dfunction_prototype);
name = "Date";
static enum NativeFunctionData[] nfd = [{TEXT_parse,&Ddate_parse,1},{TEXT_UTC,&Ddate_UTC,7}];
DnativeFunction.init(this,nfd,DontEnum);
}
    void* Construct(CallContext* cc, Value* ret, Value[] arglist);
    void* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
}
void* checkdate(Value* ret, d_string name, Dobject othis)
{
ret.putVundefined();
ErrInfo errinfo;
return Dobject.RuntimeError(&errinfo,errmsgtbl[ERR_FUNCTION_WANTS_DATE],name,othis.classname);
}
int getThisTime(Value* ret, Dobject othis, out d_time n)
{
d_number x;
n = cast(d_time)othis.value.number;
ret.putVtime(n);
return n == d_time_nan ? 1 : 0;
}
int getThisLocalTime(Value* ret, Dobject othis, out d_time n);
void* Ddate_prototype_toString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_toDateString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_toTimeString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_valueOf(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_getTime(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_getYear(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_getFullYear(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_getUTCFullYear(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_getMonth(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_getUTCMonth(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_getDate(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_getUTCDate(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_getDay(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_getUTCDay(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_getHours(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_getUTCHours(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_getMinutes(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_getUTCMinutes(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_getSeconds(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_getUTCSeconds(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_getMilliseconds(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_getUTCMilliseconds(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_getTimezoneOffset(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_setTime(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_setMilliseconds(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_setUTCMilliseconds(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_setSeconds(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_setUTCSeconds(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_setMinutes(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_setUTCMinutes(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_setHours(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_setUTCHours(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_setDate(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_setUTCDate(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_setMonth(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_setUTCMonth(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_setFullYear(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_setUTCFullYear(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_setYear(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_toLocaleString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_toLocaleDateString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_toLocaleTimeString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Ddate_prototype_toUTCString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
class DdatePrototype : Ddate
{
    this()
{
super(Dobject_prototype);
Dobject f = Dfunction_prototype;
Put(TEXT_constructor,Ddate_constructor,DontEnum);
static enum NativeFunctionData[] nfd = [{TEXT_toString,&Ddate_prototype_toString,0},{TEXT_toDateString,&Ddate_prototype_toDateString,0},{TEXT_toTimeString,&Ddate_prototype_toTimeString,0},{TEXT_valueOf,&Ddate_prototype_valueOf,0},{TEXT_getTime,&Ddate_prototype_getTime,0},{TEXT_getYear,&Ddate_prototype_getYear,0},{TEXT_getFullYear,&Ddate_prototype_getFullYear,0},{TEXT_getUTCFullYear,&Ddate_prototype_getUTCFullYear,0},{TEXT_getMonth,&Ddate_prototype_getMonth,0},{TEXT_getUTCMonth,&Ddate_prototype_getUTCMonth,0},{TEXT_getDate,&Ddate_prototype_getDate,0},{TEXT_getUTCDate,&Ddate_prototype_getUTCDate,0},{TEXT_getDay,&Ddate_prototype_getDay,0},{TEXT_getUTCDay,&Ddate_prototype_getUTCDay,0},{TEXT_getHours,&Ddate_prototype_getHours,0},{TEXT_getUTCHours,&Ddate_prototype_getUTCHours,0},{TEXT_getMinutes,&Ddate_prototype_getMinutes,0},{TEXT_getUTCMinutes,&Ddate_prototype_getUTCMinutes,0},{TEXT_getSeconds,&Ddate_prototype_getSeconds,0},{TEXT_getUTCSeconds,&Ddate_prototype_getUTCSeconds,0},{TEXT_getMilliseconds,&Ddate_prototype_getMilliseconds,0},{TEXT_getUTCMilliseconds,&Ddate_prototype_getUTCMilliseconds,0},{TEXT_getTimezoneOffset,&Ddate_prototype_getTimezoneOffset,0},{TEXT_setTime,&Ddate_prototype_setTime,1},{TEXT_setMilliseconds,&Ddate_prototype_setMilliseconds,1},{TEXT_setUTCMilliseconds,&Ddate_prototype_setUTCMilliseconds,1},{TEXT_setSeconds,&Ddate_prototype_setSeconds,2},{TEXT_setUTCSeconds,&Ddate_prototype_setUTCSeconds,2},{TEXT_setMinutes,&Ddate_prototype_setMinutes,3},{TEXT_setUTCMinutes,&Ddate_prototype_setUTCMinutes,3},{TEXT_setHours,&Ddate_prototype_setHours,4},{TEXT_setUTCHours,&Ddate_prototype_setUTCHours,4},{TEXT_setDate,&Ddate_prototype_setDate,1},{TEXT_setUTCDate,&Ddate_prototype_setUTCDate,1},{TEXT_setMonth,&Ddate_prototype_setMonth,2},{TEXT_setUTCMonth,&Ddate_prototype_setUTCMonth,2},{TEXT_setFullYear,&Ddate_prototype_setFullYear,3},{TEXT_setUTCFullYear,&Ddate_prototype_setUTCFullYear,3},{TEXT_setYear,&Ddate_prototype_setYear,1},{TEXT_toLocaleString,&Ddate_prototype_toLocaleString,0},{TEXT_toLocaleDateString,&Ddate_prototype_toLocaleDateString,0},{TEXT_toLocaleTimeString,&Ddate_prototype_toLocaleTimeString,0},{TEXT_toUTCString,&Ddate_prototype_toUTCString,0},{TEXT_toGMTString,&Ddate_prototype_toUTCString,0}];
DnativeFunction.init(this,nfd,DontEnum);
assert(proptable.get("toString",Value.calcHash("toString")));
}
}
class Ddate : Dobject
{
    this(d_number n)
{
super(Ddate.getPrototype());
classname = TEXT_Date;
value.putVnumber(n);
}
    this(d_time n)
{
super(Ddate.getPrototype());
classname = TEXT_Date;
value.putVtime(n);
}
    this(Dobject prototype)
{
super(prototype);
classname = TEXT_Date;
value.putVnumber(d_number.nan);
}
    static void init()
{
Ddate_constructor = new DdateConstructor;
Ddate_prototype = new DdatePrototype;
Ddate_constructor.Put(TEXT_prototype,Ddate_prototype,DontEnum | DontDelete | ReadOnly);
assert(Ddate_prototype.proptable.table.length != 0);
}

    static Dfunction getConstructor()
{
return Ddate_constructor;
}

    static Dobject getPrototype()
{
return Ddate_prototype;
}

}
