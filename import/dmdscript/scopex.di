// D import file generated from 'dmdscript/scopex.d'
module dmdscript.scopex;
import dmdscript.script;
import dmdscript.program;
import dmdscript.symbol;
import dmdscript.functiondefinition;
import dmdscript.identifier;
import dmdscript.statement;
struct Scope
{
    Scope* enclosing;
    d_string src;
    Program program;
    ScopeSymbol* scopesym;
    FunctionDefinition funcdef;
    SymbolTable** plabtab;
    uint nestDepth;
    ScopeStatement scopeContext;
    Statement continueTarget;
    Statement breakTarget;
    SwitchStatement switchTarget;
    ErrInfo errinfo;
    void zero()
{
enclosing = null;
src = null;
program = null;
scopesym = null;
funcdef = null;
plabtab = null;
nestDepth = 0;
scopeContext = null;
continueTarget = null;
breakTarget = null;
switchTarget = null;
}
    void ctor(Scope* enclosing)
{
zero();
this.program = enclosing.program;
this.funcdef = enclosing.funcdef;
this.plabtab = enclosing.plabtab;
this.nestDepth = enclosing.nestDepth;
this.enclosing = enclosing;
}
    void ctor(Program program, FunctionDefinition fd)
{
zero();
this.program = program;
this.funcdef = fd;
this.plabtab = &fd.labtab;
}
    void ctor(FunctionDefinition fd)
{
zero();
this.funcdef = fd;
this.plabtab = &fd.labtab;
}
    void dtor()
{
zero();
}
    Scope* push()
{
Scope* s;
s = new Scope;
s.ctor(&this);
return s;
}
    Scope* push(FunctionDefinition fd)
{
Scope* s;
s = push();
s.funcdef = fd;
s.plabtab = &fd.labtab;
return s;
}
    void pop()
{
if (enclosing && !enclosing.errinfo.message)
enclosing.errinfo = errinfo;
zero();
}
    Symbol search(Identifier* ident);
    Symbol insert(Symbol s)
{
if (!scopesym.symtab)
scopesym.symtab = new SymbolTable;
return scopesym.symtab.insert(s);
}
    LabelSymbol searchLabel(Identifier* ident);
    LabelSymbol insertLabel(LabelSymbol ls);
    d_string getSource();
}
