// D import file generated from 'dmdscript/symbol.d'
module dmdscript.symbol;
import std.stdio;
import dmdscript.script;
import dmdscript.identifier;
import dmdscript.scopex;
import dmdscript.statement;
import dmdscript.irstate;
import dmdscript.opcodes;
import dmdscript.errmsgs;
class Symbol
{
    Identifier* ident;
    this()
{
}
    this(Identifier* ident)
{
this.ident = ident;
}
    override bool opEquals(Object o);

    override string toString()
{
return ident ? "__ident" : "__anonymous";
}

    void semantic(Scope* sc)
{
assert(0);
}
    Symbol search(Identifier* ident)
{
assert(0);
}
    void toBuffer(ref tchar[] buf)
{
buf ~= toString();
}
}
class ScopeSymbol : Symbol
{
    Symbol[] members;
    SymbolTable* symtab;
    this()
{
super();
}
    this(Identifier* id)
{
super(id);
}
    override Symbol search(Identifier* ident)
{
Symbol s;
s = symtab ? symtab.lookup(ident) : null;
if (s)
writef("\x09s = '%s.%s'\x0a",toString(),s.toString());
return s;
}

}
struct SymbolTable
{
    Symbol[Identifier*] members;
    Symbol lookup(Identifier* ident);
    Symbol insert(Symbol s);
    Symbol update(Symbol s)
{
members[s.ident] = s;
return s;
}
}
class FunctionSymbol : ScopeSymbol
{
    Loc loc;
    Identifier*[] parameters;
    TopStatement[] topstatements;
    SymbolTable labtab;
    IR* code;
    uint nlocals;
    this(Loc loc, Identifier* ident, Identifier*[] parameters, TopStatement[] topstatements)
{
super(ident);
this.loc = loc;
this.parameters = parameters;
this.topstatements = topstatements;
}
    override void semantic(Scope* sc)
{
}

}
class LabelSymbol : Symbol
{
    Loc loc;
    LabelStatement statement;
    this(Loc loc, Identifier* ident, LabelStatement statement)
{
super(ident);
this.loc = loc;
this.statement = statement;
}
}
