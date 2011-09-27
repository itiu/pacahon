// D import file generated from 'dmdscript/dstring.d'
module dmdscript.dstring;
import dmdscript.regexp;
import std.utf;
import std.c.stdlib;
import std.c.string;
import std.exception;
import std.algorithm;
import std.range;
import std.stdio;
import dmdscript.script;
import dmdscript.dobject;
import dmdscript.dregexp;
import dmdscript.darray;
import dmdscript.value;
import dmdscript.threadcontext;
import dmdscript.dfunction;
import dmdscript.text;
import dmdscript.property;
import dmdscript.errmsgs;
import dmdscript.dnative;
void* Dstring_fromCharCode(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
class DstringConstructor : Dfunction
{
    this()
{
super(1,Dfunction_prototype);
name = "String";
static enum NativeFunctionData[] nfd = [{TEXT_fromCharCode,&Dstring_fromCharCode,1}];
DnativeFunction.init(this,nfd,0);
}
    void* Construct(CallContext* cc, Value* ret, Value[] arglist)
{
d_string s;
Dobject o;
s = arglist.length ? arglist[0].toString() : TEXT_;
o = new Dstring(s);
ret.putVobject(o);
return null;
}
    void* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_string s;
s = arglist.length ? arglist[0].toString() : TEXT_;
ret.putVstring(s);
return null;
}
}
void* Dstring_prototype_toString(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dstring_prototype_valueOf(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dstring_prototype_charAt(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dstring_prototype_charCodeAt(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dstring_prototype_concat(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dstring_prototype_indexOf(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dstring_prototype_lastIndexOf(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dstring_prototype_localeCompare(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
d_string s1;
d_string s2;
d_number n;
Value* v;
v = &othis.value;
s1 = v.toString();
s2 = arglist.length ? arglist[0].toString() : vundefined.toString();
n = localeCompare(cc,s1,s2);
ret.putVnumber(n);
return null;
}
void* Dstring_prototype_match(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dstring_prototype_replace(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dstring_prototype_search(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dstring_prototype_slice(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dstring_prototype_split(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* dstring_substring(d_string s, size_t sUCSdim, d_number start, d_number end, Value* ret);
void* Dstring_prototype_substr(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
void* Dstring_prototype_substring(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist);
enum CASE 
{
Lower,
Upper,
LocaleLower,
LocaleUpper,
}
void* tocase(Dobject othis, Value* ret, CASE caseflag);
void* Dstring_prototype_toLowerCase(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return tocase(othis,ret,CASE.Lower);
}
void* Dstring_prototype_toLocaleLowerCase(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return tocase(othis,ret,CASE.LocaleLower);
}
void* Dstring_prototype_toUpperCase(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return tocase(othis,ret,CASE.Upper);
}
void* Dstring_prototype_toLocaleUpperCase(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return tocase(othis,ret,CASE.LocaleUpper);
}
void* dstring_anchor(Dobject othis, Value* ret, d_string tag, d_string name, Value[] arglist)
{
d_string foo = othis.value.toString();
Value* va = arglist.length ? &arglist[0] : &vundefined;
d_string bar = va.toString();
d_string s;
s = "<" ~ tag ~ " " ~ name ~ "=\"" ~ bar ~ "\">" ~ foo ~ "</" ~ tag ~ ">";
ret.putVstring(s);
return null;
}
void* Dstring_prototype_anchor(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return dstring_anchor(othis,ret,"A","NAME",arglist);
}
void* Dstring_prototype_fontcolor(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return dstring_anchor(othis,ret,"FONT","COLOR",arglist);
}
void* Dstring_prototype_fontsize(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return dstring_anchor(othis,ret,"FONT","SIZE",arglist);
}
void* Dstring_prototype_link(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return dstring_anchor(othis,ret,"A","HREF",arglist);
}
void* dstring_bracket(Dobject othis, Value* ret, d_string tag)
{
d_string foo = othis.value.toString();
d_string s;
s = "<" ~ tag ~ ">" ~ foo ~ "</" ~ tag ~ ">";
ret.putVstring(s);
return null;
}
void* Dstring_prototype_big(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return dstring_bracket(othis,ret,"BIG");
}
void* Dstring_prototype_blink(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return dstring_bracket(othis,ret,"BLINK");
}
void* Dstring_prototype_bold(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return dstring_bracket(othis,ret,"B");
}
void* Dstring_prototype_fixed(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return dstring_bracket(othis,ret,"TT");
}
void* Dstring_prototype_italics(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return dstring_bracket(othis,ret,"I");
}
void* Dstring_prototype_small(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return dstring_bracket(othis,ret,"SMALL");
}
void* Dstring_prototype_strike(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return dstring_bracket(othis,ret,"STRIKE");
}
void* Dstring_prototype_sub(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return dstring_bracket(othis,ret,"SUB");
}
void* Dstring_prototype_sup(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return dstring_bracket(othis,ret,"SUP");
}
class DstringPrototype : Dstring
{
    this()
{
super(Dobject_prototype);
Put(TEXT_constructor,Dstring_constructor,DontEnum);
static enum NativeFunctionData[] nfd = [{TEXT_toString,&Dstring_prototype_toString,0},{TEXT_valueOf,&Dstring_prototype_valueOf,0},{TEXT_charAt,&Dstring_prototype_charAt,1},{TEXT_charCodeAt,&Dstring_prototype_charCodeAt,1},{TEXT_concat,&Dstring_prototype_concat,1},{TEXT_indexOf,&Dstring_prototype_indexOf,1},{TEXT_lastIndexOf,&Dstring_prototype_lastIndexOf,1},{TEXT_localeCompare,&Dstring_prototype_localeCompare,1},{TEXT_match,&Dstring_prototype_match,1},{TEXT_replace,&Dstring_prototype_replace,2},{TEXT_search,&Dstring_prototype_search,1},{TEXT_slice,&Dstring_prototype_slice,2},{TEXT_split,&Dstring_prototype_split,2},{TEXT_substr,&Dstring_prototype_substr,2},{TEXT_substring,&Dstring_prototype_substring,2},{TEXT_toLowerCase,&Dstring_prototype_toLowerCase,0},{TEXT_toLocaleLowerCase,&Dstring_prototype_toLocaleLowerCase,0},{TEXT_toUpperCase,&Dstring_prototype_toUpperCase,0},{TEXT_toLocaleUpperCase,&Dstring_prototype_toLocaleUpperCase,0},{TEXT_anchor,&Dstring_prototype_anchor,1},{TEXT_fontcolor,&Dstring_prototype_fontcolor,1},{TEXT_fontsize,&Dstring_prototype_fontsize,1},{TEXT_link,&Dstring_prototype_link,1},{TEXT_big,&Dstring_prototype_big,0},{TEXT_blink,&Dstring_prototype_blink,0},{TEXT_bold,&Dstring_prototype_bold,0},{TEXT_fixed,&Dstring_prototype_fixed,0},{TEXT_italics,&Dstring_prototype_italics,0},{TEXT_small,&Dstring_prototype_small,0},{TEXT_strike,&Dstring_prototype_strike,0},{TEXT_sub,&Dstring_prototype_sub,0},{TEXT_sup,&Dstring_prototype_sup,0}];
DnativeFunction.init(this,nfd,DontEnum);
}
}
class Dstring : Dobject
{
    this(d_string s)
{
super(getPrototype());
classname = TEXT_String;
Put(TEXT_length,std.utf.toUCSindex(s,s.length),DontEnum | DontDelete | ReadOnly);
value.putVstring(s);
}
    this(Dobject prototype)
{
super(prototype);
classname = TEXT_String;
Put(TEXT_length,0,DontEnum | DontDelete | ReadOnly);
value.putVstring(null);
}
    static void init()
{
Dstring_constructor = new DstringConstructor;
Dstring_prototype = new DstringPrototype;
Dstring_constructor.Put(TEXT_prototype,Dstring_prototype,DontEnum | DontDelete | ReadOnly);
}

    static Dfunction getConstructor()
{
return Dstring_constructor;
}

    static Dobject getPrototype()
{
return Dstring_prototype;
}

}
