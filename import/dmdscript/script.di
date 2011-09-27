// D import file generated from 'dmdscript/script.d'
module dmdscript.script;
import std.ctype;
import std.string;
import std.c.stdlib;
import std.c.stdarg;
const uint MAJOR_VERSION = 5;

const uint MINOR_VERSION = 5;

const uint BUILD_VERSION = 1;

const uint JSCRIPT_CATCH_BUG = 1;

const uint JSCRIPT_ESCAPEV_BUG = 0;

alias char tchar;
alias ulong number_t;
alias double real_t;
alias uint Loc;
struct ErrInfo
{
    d_string message;
    d_string srcline;
    uint linnum;
    int charpos;
    int code;
}
class ScriptException : Exception
{
    ErrInfo ei;
    this(d_string msg)
{
ei.message = msg;
super(msg);
}
    this(ErrInfo* pei)
{
ei = *pei;
super(ei.message);
}
}
int logflag;
alias uint d_boolean;
alias double d_number;
alias int d_int32;
alias uint d_uint32;
alias ushort d_uint16;
alias immutable(char)[] d_string;
import dmdscript.value;
import dmdscript.dobject;
import dmdscript.program;
import dmdscript.text;
import dmdscript.functiondefinition;
struct CallContext
{
    Dobject[] scopex;
    Dobject variable;
    Dobject global;
    uint scoperoot;
    uint globalroot;
    void* lastnamedfunc;
    Program prog;
    Dobject callerothis;
    Dobject caller;
    FunctionDefinition callerf;
    Value value;
    uint linnum;
    int Interrupt;
}
struct Global
{
    string copyright = "Copyright (c) 1999-2010 by Digital Mars";
    string written = "by Walter Bright";
}
Global global;
string banner()
{
return std.string.format("DMDSsript-2 v0.1rc1\x0a","Compiled by Digital Mars DMD D compiler\x0ahttp://www.digitalmars.com\x0a","Fork of the original DMDScript 1.16\x0a",global.written,"\x0a",global.copyright);
}
int isStrWhiteSpaceChar(dchar c);
int StringToIndex(d_string name, out d_uint32 index);
d_number StringNumericLiteral(d_string string, out size_t endidx, int parsefloat);
int localeCompare(CallContext* cc, d_string s1, d_string s2)
{
return std.string.cmp(s1,s2);
}
