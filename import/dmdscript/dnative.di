// D import file generated from 'dmdscript/dnative.d'
module dmdscript.dnative;
import dmdscript.script;
import dmdscript.dobject;
import dmdscript.dfunction;
import dmdscript.value;
alias void* function(Dobject pthis, CallContext* cc, Dobject othis, Value* ret, Value[] arglist) PCall;
struct NativeFunctionData
{
    d_string string;
    PCall pcall;
    d_uint32 length;
}
class DnativeFunction : Dfunction
{
    PCall pcall;
    this(PCall func, d_string name, d_uint32 length)
{
super(length);
this.name = name;
pcall = func;
}
    this(PCall func, d_string name, d_uint32 length, Dobject o)
{
super(length,o);
this.name = name;
pcall = func;
}
    override void* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist)
{
return (*pcall)(this,cc,othis,ret,arglist);
}

    static void init(Dobject o, NativeFunctionData[] nfd, uint attributes);

}
