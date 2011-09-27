// D import file generated from 'dmdscript/lexer.d'
module dmdscript.lexer;
import std.range;
import std.algorithm;
import std.stdio;
import std.string;
import std.utf;
import std.outbuffer;
import std.ctype;
import std.c.stdlib;
import dmdscript.script;
import dmdscript.text;
import dmdscript.identifier;
import dmdscript.scopex;
import dmdscript.errmsgs;
alias int TOK;
enum 
{
TOKreserved,
TOKlparen,
TOKrparen,
TOKlbracket,
TOKrbracket,
TOKlbrace,
TOKrbrace,
TOKcolon,
TOKneg,
TOKpos,
TOKsemicolon,
TOKeof,
TOKarray,
TOKcall,
TOKarraylit,
TOKobjectlit,
TOKcomma,
TOKassert,
TOKless,
TOKgreater,
TOKlessequal,
TOKgreaterequal,
TOKequal,
TOKnotequal,
TOKidentity,
TOKnonidentity,
TOKshiftleft,
TOKshiftright,
TOKshiftleftass,
TOKshiftrightass,
TOKushiftright,
TOKushiftrightass,
TOKplus,
TOKminus,
TOKplusass,
TOKminusass,
TOKmultiply,
TOKdivide,
TOKpercent,
TOKmultiplyass,
TOKdivideass,
TOKpercentass,
TOKand,
TOKor,
TOKxor,
TOKandass,
TOKorass,
TOKxorass,
TOKassign,
TOKnot,
TOKtilde,
TOKplusplus,
TOKminusminus,
TOKdot,
TOKquestion,
TOKandand,
TOKoror,
TOKnumber,
TOKidentifier,
TOKstring,
TOKregexp,
TOKreal,
TOKbreak,
TOKcase,
TOKcontinue,
TOKdefault,
TOKdelete,
TOKdo,
TOKelse,
TOKexport,
TOKfalse,
TOKfor,
TOKfunction,
TOKif,
TOKimport,
TOKin,
TOKnew,
TOKnull,
TOKreturn,
TOKswitch,
TOKthis,
TOKtrue,
TOKtypeof,
TOKvar,
TOKvoid,
TOKwhile,
TOKwith,
TOKcatch,
TOKclass,
TOKconst,
TOKdebugger,
TOKenum,
TOKextends,
TOKfinally,
TOKsuper,
TOKthrow,
TOKtry,
TOKabstract,
TOKboolean,
TOKbyte,
TOKchar,
TOKdouble,
TOKfinal,
TOKfloat,
TOKgoto,
TOKimplements,
TOKinstanceof,
TOKint,
TOKinterface,
TOKlong,
TOKnative,
TOKpackage,
TOKprivate,
TOKprotected,
TOKpublic,
TOKshort,
TOKstatic,
TOKsynchronized,
TOKthrows,
TOKtransient,
TOKmax,
}
int isoctal(dchar c)
{
return '0' <= c && c <= '7';
}
int isasciidigit(dchar c)
{
return '0' <= c && c <= '9';
}
int isasciilower(dchar c)
{
return 'a' <= c && c <= 'z';
}
int isasciiupper(dchar c)
{
return 'A' <= c && c <= 'Z';
}
int ishex(dchar c)
{
return '0' <= c && c <= '9' || 'a' <= c && c <= 'f' || 'A' <= c && c <= 'F';
}
struct Token
{
    Token* next;
    immutable(tchar)* ptr;
    uint linnum;
    TOK value;
    immutable(tchar)* sawLineTerminator;
    union
{
number_t intvalue;
real_t realvalue;
d_string string;
Identifier* ident;
}
    static d_string[TOKmax] tochars;

    static Token* alloc(Lexer* lex);

    void print()
{
writefln(toString());
}
    d_string toString();
    static d_string toString(TOK value)
{
d_string p;
p = tochars[value];
if (!p)
p = std.string.format("TOK%d",value);
return p;
}

}
class Lexer
{
    Identifier[d_string] stringtable;
    Token* freelist;
    d_string sourcename;
    d_string base;
    immutable(char)* end;
    immutable(char)* p;
    uint currentline;
    Token token;
    OutBuffer stringbuffer;
    int useStringtable;
    ErrInfo errinfo;
    static bool inited;

    this(d_string sourcename, d_string base, int useStringtable)
{
if (!inited)
init();
std.c.string.memset(&token,0,token.sizeof);
this.useStringtable = useStringtable;
this.sourcename = sourcename;
if (!base.length || base[$ - 1] != 0 && base[$ - 1] != 26)
base ~= cast(tchar)26;
this.base = base;
this.end = base.ptr + base.length;
p = base.ptr;
currentline = 1;
freelist = null;
}
    ~this()
{
freelist = null;
sourcename = null;
base = null;
end = null;
p = null;
}
    dchar get(immutable(tchar)* p)
{
size_t idx = p - base.ptr;
return std.utf.decode(base,idx);
}
    immutable(tchar)* inc(immutable(tchar)* p)
{
size_t idx = p - base.ptr;
std.utf.decode(base,idx);
return base.ptr + idx;
}
    void error(int msgnum)
{
error(errmsgtbl[msgnum]);
}
    void error(...);
    static d_string locToSrcline(immutable(char)* src, Loc loc);

    TOK nextToken();
    Token* peek(Token* ct);
    void insertSemicolon(immutable(tchar)* loc)
{
Token* t;
t = Token.alloc(&this);
*t = token;
token.next = t;
token.value = TOKsemicolon;
token.ptr = loc;
token.sawLineTerminator = null;
}
    void rescan()
{
token.next = null;
p = token.ptr + 1;
}
    void scan(Token* t);
    dchar escapeSequence();
    d_string string(tchar quote);
    d_string regexp();
    dchar unicode();
    TOK number(Token* t);
    static TOK isKeyword(const(tchar)[] s);

}
struct Keyword
{
    string name;
    TOK value;
}
static Keyword[] keywords = [{"break",TOKbreak},{"case",TOKcase},{"continue",TOKcontinue},{"default",TOKdefault},{"delete",TOKdelete},{"do",TOKdo},{"else",TOKelse},{"export",TOKexport},{"false",TOKfalse},{"for",TOKfor},{"function",TOKfunction},{"if",TOKif},{"import",TOKimport},{"in",TOKin},{"new",TOKnew},{"null",TOKnull},{"return",TOKreturn},{"switch",TOKswitch},{"this",TOKthis},{"true",TOKtrue},{"typeof",TOKtypeof},{"var",TOKvar},{"void",TOKvoid},{"while",TOKwhile},{"with",TOKwith},{"catch",TOKcatch},{"class",TOKclass},{"const",TOKconst},{"debugger",TOKdebugger},{"enum",TOKenum},{"extends",TOKextends},{"finally",TOKfinally},{"super",TOKsuper},{"throw",TOKthrow},{"try",TOKtry},{"abstract",TOKabstract},{"boolean",TOKboolean},{"byte",TOKbyte},{"char",TOKchar},{"double",TOKdouble},{"final",TOKfinal},{"float",TOKfloat},{"goto",TOKgoto},{"implements",TOKimplements},{"instanceof",TOKinstanceof},{"int",TOKint},{"interface",TOKinterface},{"long",TOKlong},{"native",TOKnative},{"package",TOKpackage},{"private",TOKprivate},{"protected",TOKprotected},{"public",TOKpublic},{"short",TOKshort},{"static",TOKstatic},{"synchronized",TOKsynchronized},{"throws",TOKthrows},{"transient",TOKtransient}];

void init();
