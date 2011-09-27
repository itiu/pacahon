// D import file generated from 'dmdscript/regexp.d'
module dmdscript.regexp;
private 
{
    import core.stdc.stdio;
    import core.stdc.stdlib;
    import core.stdc.string;
    import std.stdio;
    import std.string;
    import std.ctype;
    import std.outbuffer;
    import std.bitmanip;
    import std.utf;
    import std.algorithm;
    import std.array;
    import std.traits;
}
string email = "[a-zA-Z]([.]?([[a-zA-Z0-9_]-]+)*)?@([[a-zA-Z0-9_]\\-_]+\\.)+[a-zA-Z]{2,6}";
string url = "(([h|H][t|T]|[f|F])[t|T][p|P]([s|S]?)\\:\\/\\/|~/|/)?([\\w]+:\\w+@)?(([a-zA-Z]{1}([\\w\\-]+\\.)+([\\w]{2,5}))(:[\\d]{1,5})?)?((/?\\w+/)+|/?)(\\w+\\.[\\w]{3,4})?([,]\\w+)*((\\?\\w+=\\w+)?(&\\w+=\\w+)*([,]\\w*)*)?";
class RegExpException : Exception
{
    this(string msg)
{
super(msg);
}
}
struct regmatch_t
{
    sizediff_t rm_so;
    sizediff_t rm_eo;
}
private alias char rchar;

string sub(string s, string pattern, string format, string attributes = null)
{
auto r = new RegExp(pattern,attributes);
auto result = r.replace(s,format);
delete r;
return result;
}
string sub(string s, string pattern, string delegate(RegExp) dg, string attributes = null);
sizediff_t find(string s, RegExp pattern)
{
return pattern.test(s) ? pattern.pmatch[0].rm_so : -1;
}
sizediff_t find(string s, string pattern, string attributes = null);
sizediff_t rfind(string s, RegExp pattern);
sizediff_t rfind(string s, string pattern, string attributes = null);
string[] split(string s, RegExp pattern)
{
return pattern.split(s);
}
string[] split(string s, string pattern, string attributes = null)
{
auto r = new RegExp(pattern,attributes);
auto result = r.split(s);
delete r;
return result;
}
RegExp search(string s, string pattern, string attributes = null);
class RegExp
{
    public this(string pattern, string attributes = null)
{
pmatch = (&gmatch)[0..1];
compile(pattern,attributes);
}

    public static RegExp opCall(string pattern, string attributes = null)
{
return new RegExp(pattern,attributes);
}


        public RegExp search(string string)
{
input = string;
pmatch[0].rm_eo = 0;
return this;
}

    public int opApply(scope int delegate(ref RegExp) dg);

        public string opIndex(size_t n);

    public string match(size_t n)
{
return this[n];
}

    public string pre()
{
return input[0..pmatch[0].rm_so];
}

    public string post()
{
return input[pmatch[0].rm_eo..$];
}

    uint re_nsub;
    regmatch_t[] pmatch;
    string input;
    string pattern;
    string flags;
    int errors;
    uint attributes;
    enum REA 
{
global = 1,
ignoreCase = 2,
multiline = 4,
dotmatchlf = 8,
}
    private 
{
    size_t src;
    size_t src_start;
    size_t p;
    regmatch_t gmatch;
    const(ubyte)[] program;
    OutBuffer buf;
    enum : ubyte
{
REend,
REchar,
REichar,
REdchar,
REidchar,
REanychar,
REanystar,
REstring,
REistring,
REtestbit,
REbit,
REnotbit,
RErange,
REnotrange,
REor,
REplus,
REstar,
REquest,
REnm,
REnmq,
REbol,
REeol,
REparen,
REgoto,
REwordboundary,
REnotwordboundary,
REdigit,
REnotdigit,
REspace,
REnotspace,
REword,
REnotword,
REbackref,
}
    private int isword(dchar c)
{
return isalnum(c) || c == '_';
}

    private uint inf = ~0u;

    public void compile(string pattern, string attributes);

    public string[] split(string s);

        public int find(string string)
{
int i = test(string);
if (i)
i = pmatch[0].rm_so != 0;
else
i = -1;
return i;
}

        public string[] match(string s);

        public string replace(string s, string format);

        public string[] exec(string string);

    public string[] exec();

    public bool test(string s)
{
return test(s,0) != 0;
}

    public int test()
{
return test(input,pmatch[0].rm_eo);
}

    public int test(string s, size_t startindex);

    alias test opEquals;
        int chr(ref size_t si, rchar c);
    void printProgram(const(ubyte)[] prog);
    int trymatch(size_t pc, size_t pcend);
    int parseRegexp();
    int parsePiece();
    int parseAtom();
    private 
{
    class Range
{
    uint maxc;
    uint maxb;
    OutBuffer buf;
    ubyte* base;
    BitArray bits;
    this(OutBuffer buf)
{
this.buf = buf;
if (buf.data.length)
this.base = &buf.data[buf.offset];
}
    void setbitmax(uint u);
    void setbit2(uint u)
{
setbitmax(u + 1);
bits[u] = 1;
}
}
    int parseRange();
    void error(string msg);
    int escape();
    void optimize();
    int starrchars(Range r, const(ubyte)[] prog);
    public string replace(string format)
{
return replace3(format,input,pmatch[0..re_nsub + 1]);
}

    public static string replace3(string format, string input, regmatch_t[] pmatch);


    public string replaceOld(string format);

}
}
}
template Pattern(Char)
{
struct Pattern
{
    immutable(Char)[] pattern;
    this(immutable(Char)[] pattern)
{
this.pattern = pattern;
}
}
}
template pattern(Char)
{
Pattern!(Char) pattern(immutable(Char)[] pat)
{
return typeof(return)(pat);
}
}
template Splitter(Range)
{
struct Splitter
{
    Range _input;
    size_t _chunkLength;
    RegExp _rx;
    private Range search()
{
auto i = std.regexp.find(cast(string)_input,_rx);
return _input[i >= 0 ? i : _input.length.._input.length];
}

    private void advance()
{
_chunkLength += _rx[0].length;
}

    this(Range input, Pattern!(char) separator)
{
_input = input;
_rx = RegExp(separator.pattern);
_chunkLength = _input.length - search().length;
}
    auto ref  opSlice()
{
return this;
}
    Range front()
{
return _input[0.._chunkLength];
}
    bool empty()
{
return _input.empty;
}
    void popFront()
{
if (_chunkLength == _input.length)
{
_input = _input[_chunkLength.._input.length];
return ;
}
advance;
_input = _input[_chunkLength.._input.length];
_chunkLength = _input.length - search().length;
}
}
}
template splitter(Range)
{
Splitter!(Range) splitter(Range r, Pattern!(char) pat)
{
static assert(is(Unqual!(typeof(Range.init[0])) == char),Unqual!(typeof(Range.init[0])).stringof);
return typeof(return)(cast(string)r,pat);
}
}
