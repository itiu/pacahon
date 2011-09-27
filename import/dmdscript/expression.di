// D import file generated from 'dmdscript/expression.d'
module dmdscript.expression;
import std.string;
import std.algorithm;
import std.string;
import std.range;
import std.exception;
import std.stdio;
import dmdscript.script;
import dmdscript.lexer;
import dmdscript.scopex;
import dmdscript.text;
import dmdscript.errmsgs;
import dmdscript.functiondefinition;
import dmdscript.irstate;
import dmdscript.ir;
import dmdscript.opcodes;
import dmdscript.identifier;
class Expression
{
    const uint EXPRESSION_SIGNATURE = 989011519;

    uint signature = EXPRESSION_SIGNATURE;
    Loc loc;
    TOK op;
    this(Loc loc, TOK op)
{
this.loc = loc;
this.op = op;
signature = EXPRESSION_SIGNATURE;
}
        Expression semantic(Scope* sc)
{
return this;
}
    override d_string toString()
{
char[] buf;
toBuffer(buf);
return assumeUnique(buf);
}

    void toBuffer(ref char[] buf)
{
buf ~= toString();
}
    void checkLvalue(Scope* sc);
    int match(Expression e)
{
return false;
}
    int isBooleanResult()
{
return false;
}
    void toIR(IRstate* irs, uint ret)
{
writef("Expression::toIR('%s')\x0a",toString());
}
    void toLvalue(IRstate* irs, out uint base, IR* property, out int opoff)
{
base = irs.alloc(1);
toIR(irs,base);
property.index = 0;
opoff = 3;
}
}
class RealExpression : Expression
{
    real_t value;
    this(Loc loc, real_t value)
{
super(loc,TOKreal);
this.value = value;
}
    override d_string toString()
{
d_string buf;
long i;
i = cast(long)value;
if (i == value)
buf = std.string.format("%d",i);
else
buf = std.string.format("%g",value);
return buf;
}

    override void toBuffer(ref tchar[] buf)
{
buf ~= std.string.format("%g",value);
}

    override void toIR(IRstate* irs, uint ret);

}
class IdentifierExpression : Expression
{
    Identifier* ident;
    this(Loc loc, Identifier* ident)
{
super(loc,TOKidentifier);
this.ident = ident;
}
    override Expression semantic(Scope* sc)
{
return this;
}

    override d_string toString()
{
return ident.toString();
}

    override void checkLvalue(Scope* sc)
{
}

    override int match(Expression e);

    override void toIR(IRstate* irs, uint ret)
{
Identifier* id = ident;
assert(id.sizeof == (uint).sizeof);
if (ret)
irs.gen2(loc,IRgetscope,ret,cast(uint)id);
else
irs.gen1(loc,IRcheckref,cast(uint)id);
}

    override void toLvalue(IRstate* irs, out uint base, IR* property, out int opoff)
{
property.id = ident;
opoff = 2;
base = ~0u;
}

}
class ThisExpression : Expression
{
    this(Loc loc)
{
super(loc,TOKthis);
}
    override d_string toString()
{
return TEXT_this;
}

    override Expression semantic(Scope* sc)
{
return this;
}

    override void toIR(IRstate* irs, uint ret)
{
if (ret)
irs.gen1(loc,IRthis,ret);
}

}
class NullExpression : Expression
{
    this(Loc loc)
{
super(loc,TOKnull);
}
    override d_string toString()
{
return TEXT_null;
}

    override void toIR(IRstate* irs, uint ret)
{
if (ret)
irs.gen1(loc,IRnull,ret);
}

}
class StringExpression : Expression
{
    d_string string;
    this(Loc loc, d_string string)
{
super(loc,TOKstring);
this.string = string;
}
    override void toBuffer(ref tchar[] buf);

    override void toIR(IRstate* irs, uint ret);

}
class RegExpLiteral : Expression
{
    d_string string;
    this(Loc loc, d_string string)
{
super(loc,TOKregexp);
this.string = string;
}
    override void toBuffer(ref tchar[] buf)
{
buf ~= string;
}

    override void toIR(IRstate* irs, uint ret);

}
class BooleanExpression : Expression
{
    int boolean;
    this(Loc loc, int boolean)
{
super(loc,TOKboolean);
this.boolean = boolean;
}
    override d_string toString()
{
return boolean ? "true" : "false";
}

    override void toBuffer(ref tchar[] buf)
{
buf ~= toString();
}

    override int isBooleanResult()
{
return true;
}

    override void toIR(IRstate* irs, uint ret)
{
if (ret)
irs.gen2(loc,IRboolean,ret,boolean);
}

}
class ArrayLiteral : Expression
{
    Expression[] elements;
    this(Loc loc, Expression[] elements)
{
super(loc,TOKarraylit);
this.elements = elements;
}
    override Expression semantic(Scope* sc);

    override void toBuffer(ref tchar[] buf);

    override void toIR(IRstate* irs, uint ret);

}
class Field
{
    Identifier* ident;
    Expression exp;
    this(Identifier* ident, Expression exp)
{
this.ident = ident;
this.exp = exp;
}
}
class ObjectLiteral : Expression
{
    Field[] fields;
    this(Loc loc, Field[] fields)
{
super(loc,TOKobjectlit);
this.fields = fields;
}
    override Expression semantic(Scope* sc);

    override void toBuffer(ref tchar[] buf);

    override void toIR(IRstate* irs, uint ret);

}
class FunctionLiteral : Expression
{
    FunctionDefinition func;
    this(Loc loc, FunctionDefinition func)
{
super(loc,TOKobjectlit);
this.func = func;
}
    override Expression semantic(Scope* sc)
{
func = cast(FunctionDefinition)func.semantic(sc);
return this;
}

    override void toBuffer(ref tchar[] buf)
{
func.toBuffer(buf);
}

    override void toIR(IRstate* irs, uint ret)
{
func.toIR(null);
irs.gen2(loc,IRobject,ret,cast(uint)cast(void*)func);
}

}
class UnaExp : Expression
{
    Expression e1;
    this(Loc loc, TOK op, Expression e1)
{
super(loc,op);
this.e1 = e1;
}
    override Expression semantic(Scope* sc)
{
e1 = e1.semantic(sc);
return this;
}

    override void toBuffer(ref tchar[] buf)
{
buf ~= Token.toString(op);
buf ~= ' ';
e1.toBuffer(buf);
}

}
class BinExp : Expression
{
    Expression e1;
    Expression e2;
    this(Loc loc, TOK op, Expression e1, Expression e2)
{
super(loc,op);
this.e1 = e1;
this.e2 = e2;
}
    override Expression semantic(Scope* sc)
{
e1 = e1.semantic(sc);
e2 = e2.semantic(sc);
return this;
}

    override void toBuffer(ref tchar[] buf)
{
e1.toBuffer(buf);
buf ~= ' ';
buf ~= Token.toString(op);
buf ~= ' ';
e2.toBuffer(buf);
}

    void binIR(IRstate* irs, uint ret, uint ircode);
}
class PreExp : UnaExp
{
    uint ircode;
    this(Loc loc, uint ircode, Expression e)
{
super(loc,TOKplusplus,e);
this.ircode = ircode;
}
    override Expression semantic(Scope* sc)
{
super.semantic(sc);
e1.checkLvalue(sc);
return this;
}

    override void toBuffer(ref tchar[] buf)
{
e1.toBuffer(buf);
buf ~= Token.toString(op);
}

    override void toIR(IRstate* irs, uint ret);

}
class PostIncExp : UnaExp
{
    this(Loc loc, Expression e)
{
super(loc,TOKplusplus,e);
}
    override Expression semantic(Scope* sc)
{
super.semantic(sc);
e1.checkLvalue(sc);
return this;
}

    override void toBuffer(ref tchar[] buf)
{
e1.toBuffer(buf);
buf ~= Token.toString(op);
}

    override void toIR(IRstate* irs, uint ret);

}
class PostDecExp : UnaExp
{
    this(Loc loc, Expression e)
{
super(loc,TOKplusplus,e);
}
    override Expression semantic(Scope* sc)
{
super.semantic(sc);
e1.checkLvalue(sc);
return this;
}

    override void toBuffer(ref tchar[] buf)
{
e1.toBuffer(buf);
buf ~= Token.toString(op);
}

    override void toIR(IRstate* irs, uint ret);

}
class DotExp : UnaExp
{
    Identifier* ident;
    this(Loc loc, Expression e, Identifier* ident)
{
super(loc,TOKdot,e);
this.ident = ident;
}
    override void checkLvalue(Scope* sc)
{
}

    override void toBuffer(ref tchar[] buf)
{
e1.toBuffer(buf);
buf ~= '.';
buf ~= ident.toString();
}

    override void toIR(IRstate* irs, uint ret);

    override void toLvalue(IRstate* irs, out uint base, IR* property, out int opoff)
{
base = irs.alloc(1);
e1.toIR(irs,base);
property.id = ident;
opoff = 1;
}

}
class CallExp : UnaExp
{
    Expression[] arguments;
    this(Loc loc, Expression e, Expression[] arguments)
{
super(loc,TOKcall,e);
this.arguments = arguments;
}
    override Expression semantic(Scope* sc);

    override void toBuffer(ref tchar[] buf);

    override void toIR(IRstate* irs, uint ret);

}
class AssertExp : UnaExp
{
    this(Loc loc, Expression e)
{
super(loc,TOKassert,e);
}
    override void toBuffer(ref tchar[] buf)
{
buf ~= "assert(";
e1.toBuffer(buf);
buf ~= ')';
}

    override void toIR(IRstate* irs, uint ret)
{
uint linnum;
uint u;
uint b;
b = ret ? ret : irs.alloc(1);
e1.toIR(irs,b);
u = irs.getIP();
irs.gen2(loc,IRjt,0,b);
linnum = cast(uint)loc;
irs.gen1(loc,IRassert,linnum);
irs.patchJmp(u,irs.getIP());
if (!ret)
irs.release(b,1);
}

}
class NewExp : UnaExp
{
    Expression[] arguments;
    this(Loc loc, Expression e, Expression[] arguments)
{
super(loc,TOKnew,e);
this.arguments = arguments;
}
    override Expression semantic(Scope* sc);

    override void toBuffer(ref tchar[] buf);

    override void toIR(IRstate* irs, uint ret);

}
class XUnaExp : UnaExp
{
    uint ircode;
    this(Loc loc, TOK op, uint ircode, Expression e)
{
super(loc,op,e);
this.ircode = ircode;
}
    override void toIR(IRstate* irs, uint ret)
{
e1.toIR(irs,ret);
if (ret)
irs.gen1(loc,ircode,ret);
}

}
class NotExp : XUnaExp
{
    this(Loc loc, Expression e)
{
super(loc,TOKnot,IRnot,e);
}
    override int isBooleanResult()
{
return true;
}

}
class DeleteExp : UnaExp
{
    bool lval;
    this(Loc loc, Expression e)
{
super(loc,TOKdelete,e);
}
    override Expression semantic(Scope* sc)
{
e1.checkLvalue(sc);
lval = sc.errinfo.message == null;
if (!lval)
sc.errinfo.message = null;
return this;
}

    override void toIR(IRstate* irs, uint ret);

}
class CommaExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
{
super(loc,TOKcomma,e1,e2);
}
    override void checkLvalue(Scope* sc)
{
e2.checkLvalue(sc);
}

    override void toIR(IRstate* irs, uint ret)
{
e1.toIR(irs,0);
e2.toIR(irs,ret);
}

}
class ArrayExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
{
super(loc,TOKarray,e1,e2);
}
    override Expression semantic(Scope* sc)
{
checkLvalue(sc);
return this;
}

    override void checkLvalue(Scope* sc)
{
}

    override void toBuffer(ref tchar[] buf)
{
e1.toBuffer(buf);
buf ~= '[';
e2.toBuffer(buf);
buf ~= ']';
}

    override void toIR(IRstate* irs, uint ret);

    override void toLvalue(IRstate* irs, out uint base, IR* property, out int opoff)
{
uint index;
base = irs.alloc(1);
e1.toIR(irs,base);
index = irs.alloc(1);
e2.toIR(irs,index);
property.index = index;
opoff = 0;
}

}
class AssignExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
{
super(loc,TOKassign,e1,e2);
}
    override Expression semantic(Scope* sc)
{
super.semantic(sc);
if (e1.op != TOKcall)
e1.checkLvalue(sc);
return this;
}

    override void toIR(IRstate* irs, uint ret);

}
class AddAssignExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
{
super(loc,TOKplusass,e1,e2);
}
    override Expression semantic(Scope* sc)
{
super.semantic(sc);
e1.checkLvalue(sc);
return this;
}

    override void toIR(IRstate* irs, uint ret);

}
class BinAssignExp : BinExp
{
    uint ircode = IRerror;
    this(Loc loc, TOK op, uint ircode, Expression e1, Expression e2)
{
super(loc,op,e1,e2);
this.ircode = ircode;
}
    override Expression semantic(Scope* sc)
{
super.semantic(sc);
e1.checkLvalue(sc);
return this;
}

    override void toIR(IRstate* irs, uint ret)
{
uint b;
uint c;
uint r;
uint base;
IR property;
int opoff;
e1.toLvalue(irs,base,&property,opoff);
assert(opoff != 3);
b = irs.alloc(1);
if (opoff == 2)
irs.gen2(loc,IRgetscope,b,property.index);
else
irs.gen3(loc,IRget + opoff,b,base,property.index);
c = irs.alloc(1);
e2.toIR(irs,c);
r = ret ? ret : irs.alloc(1);
irs.gen3(loc,ircode,r,b,c);
if (opoff == 2)
irs.gen2(loc,IRputscope,r,property.index);
else
irs.gen3(loc,IRput + opoff,r,base,property.index);
if (!ret)
irs.release(r,1);
}

}
class AddExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
{
super(loc,TOKplus,e1,e2);
;
}
    override Expression semantic(Scope* sc)
{
return this;
}

    override void toIR(IRstate* irs, uint ret)
{
binIR(irs,ret,IRadd);
}

}
class XBinExp : BinExp
{
    uint ircode = IRerror;
    this(Loc loc, TOK op, uint ircode, Expression e1, Expression e2)
{
super(loc,op,e1,e2);
this.ircode = ircode;
}
    override void toIR(IRstate* irs, uint ret)
{
binIR(irs,ret,ircode);
}

}
class OrOrExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
{
super(loc,TOKoror,e1,e2);
}
    override void toIR(IRstate* irs, uint ret)
{
uint u;
uint b;
if (ret)
b = ret;
else
b = irs.alloc(1);
e1.toIR(irs,b);
u = irs.getIP();
irs.gen2(loc,IRjt,0,b);
e2.toIR(irs,ret);
irs.patchJmp(u,irs.getIP());
if (!ret)
irs.release(b,1);
}

}
class AndAndExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
{
super(loc,TOKandand,e1,e2);
}
    override void toIR(IRstate* irs, uint ret)
{
uint u;
uint b;
if (ret)
b = ret;
else
b = irs.alloc(1);
e1.toIR(irs,b);
u = irs.getIP();
irs.gen2(loc,IRjf,0,b);
e2.toIR(irs,ret);
irs.patchJmp(u,irs.getIP());
if (!ret)
irs.release(b,1);
}

}
class CmpExp : BinExp
{
    uint ircode = IRerror;
    this(Loc loc, TOK tok, uint ircode, Expression e1, Expression e2)
{
super(loc,tok,e1,e2);
this.ircode = ircode;
}
    override int isBooleanResult()
{
return true;
}

    override void toIR(IRstate* irs, uint ret)
{
binIR(irs,ret,ircode);
}

}
class InExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
{
super(loc,TOKin,e1,e2);
}
    override void toIR(IRstate* irs, uint ret)
{
binIR(irs,ret,IRin);
}

}
class CondExp : BinExp
{
    Expression econd;
    this(Loc loc, Expression econd, Expression e1, Expression e2)
{
super(loc,TOKquestion,e1,e2);
this.econd = econd;
}
    override void toIR(IRstate* irs, uint ret)
{
uint u1;
uint u2;
uint b;
if (ret)
b = ret;
else
b = irs.alloc(1);
econd.toIR(irs,b);
u1 = irs.getIP();
irs.gen2(loc,IRjf,0,b);
e1.toIR(irs,ret);
u2 = irs.getIP();
irs.gen1(loc,IRjmp,0);
irs.patchJmp(u1,irs.getIP());
e2.toIR(irs,ret);
irs.patchJmp(u2,irs.getIP());
if (!ret)
irs.release(b,1);
}

}
