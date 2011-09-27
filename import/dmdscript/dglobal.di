// D import file generated from 'dmdscript/dglobal.d'
module dmdscript.dglobal;
import std.uri;
import std.c.stdlib;
import std.c.string;
import std.stdio;
import std.algorithm;
import std.math;
import std.exception;
import dmdscript.script;
import dmdscript.protoerror;
import dmdscript.parse;
import dmdscript.text;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.statement;
import dmdscript.threadcontext;
import dmdscript.functiondefinition;
import dmdscript.scopex;
import dmdscript.opcodes;
import dmdscript.property;
import dmdscript.dstring;
import dmdscript.darray;
import dmdscript.dregexp;
import dmdscript.dnumber;
import dmdscript.dboolean;
import dmdscript.dfunction;
import dmdscript.dnative;
immutable(char)[] arg0string(Value[] arglist)
{
Value* v = arglist.length ? &arglist[0] : &vundefined;
return v.toString();
}
void* Dglobal_eval(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dglobal_parseInt(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dglobal_parseFloat(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_number n;
size_t endidx;
d_string string = arg0string(arglist);
n = StringNumericLiteral(string,endidx,1);
ret.putVnumber(n);
return null;
}
int ISURIALNUM(dchar c)
{
return c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9';
}
tchar[16 + 1] TOHEX = "0123456789ABCDEF";
void* Dglobal_escape(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dglobal_unescape(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dglobal_isNaN(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
Value* v;
d_number n;
d_boolean b;
if (arglist.length)
v = &arglist[0];
else
v = &vundefined;
n = v.toNumber();
b = isnan(n) ? true : false;
ret.putVboolean(b);
return null;
}
void* Dglobal_isFinite(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
Value* v;
d_number n;
d_boolean b;
if (arglist.length)
v = &arglist[0];
else
v = &vundefined;
n = v.toNumber();
b = isfinite(n) ? true : false;
ret.putVboolean(b);
return null;
}
void* URI_error(d_string s)
{
Dobject o = new urierror.D0(s ~ "() failure");
Value* v = new Value;
v.putVobject(o);
return v;
}
void* Dglobal_decodeURI(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dglobal_decodeURIComponent(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dglobal_encodeURI(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dglobal_encodeURIComponent(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
static void dglobal_print(CallContext* cc, Dobject othis, Value* ret, Value[] arglist);

void* Dglobal_print(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
dglobal_print(cc,othis,ret,arglist);
return null;
}
void* Dglobal_println(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
dglobal_print(cc,othis,ret,arglist);
writef("\x0a");
return null;
}
void* Dglobal_readln(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dglobal_getenv(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dglobal_ScriptEngine(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
ret.putVstring(TEXT_DMDScript);
return null;
}
void* Dglobal_ScriptEngineBuildVersion(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
ret.putVnumber(BUILD_VERSION);
return null;
}
void* Dglobal_ScriptEngineMajorVersion(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
ret.putVnumber(MAJOR_VERSION);
return null;
}
void* Dglobal_ScriptEngineMinorVersion(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
ret.putVnumber(MINOR_VERSION);
return null;
}
class Dglobal : Dobject
{
    this(tchar[][] argv);
}
