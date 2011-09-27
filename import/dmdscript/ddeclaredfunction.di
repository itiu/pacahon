// D import file generated from 'dmdscript/ddeclaredfunction.d'
module dmdscript.ddeclaredfunction;
import std.stdio;
import std.c.stdlib;
import std.exception;
import dmdscript.script;
import dmdscript.dobject;
import dmdscript.dfunction;
import dmdscript.darguments;
import dmdscript.opcodes;
import dmdscript.ir;
import dmdscript.identifier;
import dmdscript.value;
import dmdscript.functiondefinition;
import dmdscript.text;
import dmdscript.property;
class DdeclaredFunction : Dfunction
{
    FunctionDefinition fd;
    this(FunctionDefinition fd)
{
super(fd.parameters.length,Dfunction.getPrototype());
assert(Dfunction.getPrototype());
assert(internal_prototype);
this.fd = fd;
Dobject o;
o = new Dobject(Dobject.getPrototype());
Put(TEXT_prototype,o,DontEnum);
o.Put(TEXT_constructor,this,DontEnum);
}
    override void* Call(CallContext* cc, Dobject othis, Value* ret, Value[] arglist);

    override void* Construct(CallContext* cc, Value* ret, Value[] arglist);

    override string toString()
{
char[] s;
fd.toBuffer(s);
return assumeUnique(s);
}

}
