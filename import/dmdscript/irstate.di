// D import file generated from 'dmdscript/irstate.d'
module dmdscript.irstate;
import std.c.stdarg;
import std.c.stdlib;
import std.c.string;
import dmdscript.outbuffer;
import core.memory;
import core.stdc.stdio;
import std.stdio;
import dmdscript.script;
import dmdscript.statement;
import dmdscript.opcodes;
import dmdscript.ir;
import dmdscript.identifier;
struct IRstate
{
    OutBuffer codebuf;
    Statement breakTarget;
    Statement continueTarget;
    ScopeStatement scopeContext;
    uint[] fixups;
    uint locali = 1;
    uint nlocals = 1;
    void ctor()
{
codebuf = new OutBuffer;
}
    void validate();
    uint alloc(uint nlocals)
{
uint n;
n = locali;
locali += nlocals;
if (locali > this.nlocals)
this.nlocals = locali;
assert(n);
return n * INDEX_FACTOR;
}
    void release(uint local, uint n)
{
}
    uint mark()
{
return locali;
}
    void release(uint i)
{
}
    static uint combine(uint loc, uint opcode)
{
return loc << 16 | opcode;
}

    void gen0(Loc loc, uint opcode)
{
codebuf.write(combine(loc,opcode));
}
    void gen1(Loc loc, uint opcode, uint arg);
    void gen2(Loc loc, uint opcode, uint arg1, uint arg2);
    void gen3(Loc loc, uint opcode, uint arg1, uint arg2, uint arg3);
    void gen4(Loc loc, uint opcode, uint arg1, uint arg2, uint arg3, uint arg4);
    void gen(Loc loc, uint opcode, uint argc,...);
    void pops(uint npops);
    uint getIP();
    void patchJmp(uint index, uint value)
{
assert((index + 1) * 4 < codebuf.offset);
(cast(uint*)codebuf.data)[index + 1] = value - index;
}
    void addFixup(uint index)
{
fixups ~= index;
}
    void doFixups();
    void optimize();
}
