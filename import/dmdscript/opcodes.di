// D import file generated from 'dmdscript/opcodes.d'
module dmdscript.opcodes;
import std.stdio;
import core.stdc.string;
import std.string;
import std.conv;
import dmdscript.script;
import dmdscript.dobject;
import dmdscript.statement;
import dmdscript.functiondefinition;
import dmdscript.value;
import dmdscript.iterator;
import dmdscript.scopex;
import dmdscript.identifier;
import dmdscript.ir;
import dmdscript.errmsgs;
import dmdscript.property;
import dmdscript.ddeclaredfunction;
import dmdscript.dfunction;
version = SCOPECACHING;
class Catch : Dobject
{
    override const Value* Get(d_string PropertyName)
{
return null;
}

    override const Value* Get(d_string PropertyName, uint hash)
{
return null;
}

    override d_string getTypeof()
{
return null;
}

    uint offset;
    d_string name;
    this(uint offset, d_string name)
{
super(null);
this.offset = offset;
this.name = name;
}
    override const int isCatch()
{
return true;
}

}
class Finally : Dobject
{
    override const Value* Get(d_string PropertyName)
{
return null;
}

    override const Value* Get(d_string PropertyName, uint hash)
{
return null;
}

    override d_string getTypeof()
{
return null;
}

    IR* finallyblock;
    this(IR* finallyblock)
{
super(null);
this.finallyblock = finallyblock;
}
    override const int isFinally()
{
return true;
}

}
Value* scope_get(Dobject[] scopex, Identifier* id, Dobject* pthis);
Value* scope_get_lambda(Dobject[] scopex, Identifier* id, Dobject* pthis);
Value* scope_get(Dobject[] scopex, Identifier* id);
Dobject scope_tos(Dobject[] scopex);
void PutValue(CallContext* cc, d_string s, Value* a);
void PutValue(CallContext* cc, Identifier* id, Value* a);
Value* cannotConvert(Value* b, int linnum);
const uint INDEX_FACTOR = 16;

struct IR
{
    union
{
struct
{
version (LittleEndian)
{
    ubyte opcode;
    ubyte padding;
    ushort linnum;
}
else
{
    ushort linnum;
    ubyte padding;
    ubyte opcode;
}
}
IR* code;
Value* value;
uint index;
uint hash;
int offset;
Identifier* id;
d_boolean boolean;
Statement target;
Dobject object;
void* ptr;
}
    static void* call(CallContext* cc, Dobject othis, IR* code, Value* ret, Value* locals);

    static void print(uint address, IR* code);

    static uint size(uint opcode);

    static void printfunc(IR* code);

    static uint verify(uint linnum, IR* codestart);

}
