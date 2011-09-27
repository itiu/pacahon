// D import file generated from 'dmdscript/program.d'
module dmdscript.program;
import std.stdio;
import std.c.stdlib;
import dmdscript.script;
import dmdscript.dobject;
import dmdscript.dglobal;
import dmdscript.functiondefinition;
import dmdscript.statement;
import dmdscript.threadcontext;
import dmdscript.value;
import dmdscript.opcodes;
import dmdscript.darray;
import dmdscript.parse;
import dmdscript.scopex;
import dmdscript.text;
import dmdscript.property;
class Program
{
    uint errors;
    CallContext* callcontext;
    FunctionDefinition globalfunction;
    static Program program;

    uint lcid;
    d_string slist;
    this()
{
initContext();
}
    void initContext();
    void compile(d_string progIdentifier, d_string srctext, FunctionDefinition* pfd);
    void execute(d_string[] args);
    void toBuffer(ref tchar[] buf)
{
if (globalfunction)
globalfunction.toBuffer(buf);
}
    static Program getProgram()
{
return program;
}

    static void setProgram(Program p)
{
program = p;
}

}
