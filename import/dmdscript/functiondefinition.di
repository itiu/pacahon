// D import file generated from 'dmdscript/functiondefinition.d'
module dmdscript.functiondefinition;
import std.stdio;
import dmdscript.script;
import dmdscript.identifier;
import dmdscript.statement;
import dmdscript.dfunction;
import dmdscript.scopex;
import dmdscript.irstate;
import dmdscript.opcodes;
import dmdscript.ddeclaredfunction;
import dmdscript.symbol;
import dmdscript.dobject;
import dmdscript.ir;
import dmdscript.errmsgs;
import dmdscript.value;
import dmdscript.property;
class FunctionDefinition : TopStatement
{
    int isglobal;
    int isliteral;
    int iseval;
    Identifier* name;
    Identifier*[] parameters;
    TopStatement[] topstatements;
    Identifier*[] varnames;
    FunctionDefinition[] functiondefinitions;
    FunctionDefinition enclosingFunction;
    int nestDepth;
    int withdepth;
    SymbolTable* labtab;
    IR* code;
    uint nlocals;
    this(TopStatement[] topstatements)
{
super(0);
st = FUNCTIONDEFINITION;
this.isglobal = 1;
this.topstatements = topstatements;
}
    this(Loc loc, int isglobal, Identifier* name, Identifier*[] parameters, TopStatement[] topstatements)
{
super(loc);
st = FUNCTIONDEFINITION;
this.isglobal = isglobal;
this.name = name;
this.parameters = parameters;
this.topstatements = topstatements;
}
    int isAnonymous()
{
return name is null;
}
    override Statement semantic(Scope* sc);

    override void toBuffer(ref tchar[] buf);

    override void toIR(IRstate* ignore);

    void instantiate(Dobject[] scopex, Dobject actobj, uint attributes);
}
