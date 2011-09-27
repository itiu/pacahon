// D import file generated from 'dmdscript/statement.d'
module dmdscript.statement;
import std.stdio;
import std.string;
import std.math;
import dmdscript.script;
import dmdscript.value;
import dmdscript.scopex;
import dmdscript.expression;
import dmdscript.irstate;
import dmdscript.symbol;
import dmdscript.identifier;
import dmdscript.ir;
import dmdscript.lexer;
import dmdscript.errmsgs;
import dmdscript.functiondefinition;
import dmdscript.opcodes;
enum 
{
TOPSTATEMENT,
FUNCTIONDEFINITION,
EXPSTATEMENT,
VARSTATEMENT,
}
class TopStatement
{
    const uint TOPSTATEMENT_SIGNATURE = -1170218509u;

    uint signature = TOPSTATEMENT_SIGNATURE;
    Loc loc;
    int done;
    int st;
    this(Loc loc)
{
this.loc = loc;
this.done = 0;
this.st = TOPSTATEMENT;
}
        void toBuffer(ref tchar[] buf)
{
buf ~= "TopStatement.toBuffer()\x0a";
}
    Statement semantic(Scope* sc)
{
writefln("TopStatement.semantic(%p)",this);
return null;
}
    void toIR(IRstate* irs)
{
writefln("TopStatement.toIR(%p)",this);
}
    void error(Scope* sc, int msgnum)
{
error(sc,errmsgtbl[msgnum]);
}
    void error(Scope* sc,...);
    TopStatement ImpliedReturn()
{
return this;
}
}
class Statement : TopStatement
{
    LabelSymbol* label;
    this(Loc loc)
{
super(loc);
this.loc = loc;
}
    override void toBuffer(ref tchar[] buf)
{
buf ~= "Statement.toBuffer()\x0a";
}

    override Statement semantic(Scope* sc)
{
writef("Statement.semantic(%p)\x0a",this);
return this;
}

    override void toIR(IRstate* irs)
{
writef("Statement.toIR(%p)\x0a",this);
}

    uint getBreak()
{
assert(0);
}
    uint getContinue()
{
assert(0);
}
    uint getGoto()
{
assert(0);
}
    uint getTarget()
{
assert(0);
}
    ScopeStatement getScope()
{
return null;
}
}
class EmptyStatement : Statement
{
    this(Loc loc)
{
super(loc);
this.loc = loc;
}
    override void toBuffer(ref tchar[] buf)
{
buf ~= ";\x0a";
}

    override Statement semantic(Scope* sc)
{
return this;
}

    override void toIR(IRstate* irs)
{
}

}
class ExpStatement : Statement
{
    Expression exp;
    this(Loc loc, Expression exp)
{
super(loc);
st = EXPSTATEMENT;
this.exp = exp;
}
    override void toBuffer(ref tchar[] buf)
{
if (exp)
exp.toBuffer(buf);
buf ~= ";\x0a";
}

    override Statement semantic(Scope* sc)
{
if (exp)
exp = exp.semantic(sc);
return this;
}

    override TopStatement ImpliedReturn()
{
return new ImpliedReturnStatement(loc,exp);
}

    override void toIR(IRstate* irs);

}
class VarDeclaration
{
    Loc loc;
    Identifier* name;
    Expression init;
    this(Loc loc, Identifier* name, Expression init)
{
this.loc = loc;
this.init = init;
this.name = name;
}
}
class VarStatement : Statement
{
    VarDeclaration[] vardecls;
    this(Loc loc)
{
super(loc);
st = VARSTATEMENT;
}
    override Statement semantic(Scope* sc);

    override void toBuffer(ref tchar[] buf);

    override void toIR(IRstate* irs);

}
class BlockStatement : Statement
{
    TopStatement[] statements;
    this(Loc loc)
{
super(loc);
}
    override Statement semantic(Scope* sc);

    override TopStatement ImpliedReturn();

    override void toBuffer(ref tchar[] buf);

    override void toIR(IRstate* irs);

}
class LabelStatement : Statement
{
    Identifier* ident;
    Statement statement;
    uint gotoIP;
    uint breakIP;
    ScopeStatement scopeContext;
    Scope whichScope;
    this(Loc loc, Identifier* ident, Statement statement)
{
super(loc);
this.ident = ident;
this.statement = statement;
gotoIP = ~0u;
breakIP = ~0u;
scopeContext = null;
}
    override Statement semantic(Scope* sc);

    override TopStatement ImpliedReturn()
{
if (statement)
statement = cast(Statement)statement.ImpliedReturn();
return this;
}

    override void toBuffer(ref tchar[] buf)
{
buf ~= ident.toString();
buf ~= ": ";
if (statement)
statement.toBuffer(buf);
else
buf ~= '\x0a';
}

    override void toIR(IRstate* irs)
{
gotoIP = irs.getIP();
statement.toIR(irs);
breakIP = irs.getIP();
}

    override uint getGoto()
{
return gotoIP;
}

    override uint getBreak()
{
return breakIP;
}

    override uint getContinue()
{
return statement.getContinue();
}

    override ScopeStatement getScope()
{
return scopeContext;
}

}
class IfStatement : Statement
{
    Expression condition;
    Statement ifbody;
    Statement elsebody;
    this(Loc loc, Expression condition, Statement ifbody, Statement elsebody)
{
super(loc);
this.condition = condition;
this.ifbody = ifbody;
this.elsebody = elsebody;
}
    override Statement semantic(Scope* sc)
{
assert(condition);
condition = condition.semantic(sc);
ifbody = ifbody.semantic(sc);
if (elsebody)
elsebody = elsebody.semantic(sc);
return this;
}

    override TopStatement ImpliedReturn()
{
assert(condition);
ifbody = cast(Statement)ifbody.ImpliedReturn();
if (elsebody)
elsebody = cast(Statement)elsebody.ImpliedReturn();
return this;
}

    override void toIR(IRstate* irs);

}
class SwitchStatement : Statement
{
    Expression condition;
    Statement bdy;
    uint breakIP;
    ScopeStatement scopeContext;
    DefaultStatement swdefault;
    CaseStatement[] cases;
    this(Loc loc, Expression c, Statement b)
{
super(loc);
condition = c;
bdy = b;
breakIP = ~0u;
scopeContext = null;
swdefault = null;
cases = null;
}
    override Statement semantic(Scope* sc)
{
condition = condition.semantic(sc);
SwitchStatement switchSave = sc.switchTarget;
Statement breakSave = sc.breakTarget;
scopeContext = sc.scopeContext;
sc.switchTarget = this;
sc.breakTarget = this;
bdy = bdy.semantic(sc);
sc.switchTarget = switchSave;
sc.breakTarget = breakSave;
return this;
}

    override void toIR(IRstate* irs);

    override uint getBreak()
{
return breakIP;
}

    override ScopeStatement getScope()
{
return scopeContext;
}

}
class CaseStatement : Statement
{
    Expression exp;
    uint caseIP;
    uint patchIP;
    this(Loc loc, Expression exp)
{
super(loc);
this.exp = exp;
caseIP = ~0u;
patchIP = ~0u;
}
    override Statement semantic(Scope* sc);

    override void toIR(IRstate* irs)
{
caseIP = irs.getIP();
}

}
class DefaultStatement : Statement
{
    uint defaultIP;
    this(Loc loc)
{
super(loc);
defaultIP = ~0u;
}
    override Statement semantic(Scope* sc);

    override void toIR(IRstate* irs)
{
defaultIP = irs.getIP();
}

}
class DoStatement : Statement
{
    Statement bdy;
    Expression condition;
    uint breakIP;
    uint continueIP;
    ScopeStatement scopeContext;
    this(Loc loc, Statement b, Expression c)
{
super(loc);
bdy = b;
condition = c;
breakIP = ~0u;
continueIP = ~0u;
scopeContext = null;
}
    override Statement semantic(Scope* sc)
{
Statement continueSave = sc.continueTarget;
Statement breakSave = sc.breakTarget;
scopeContext = sc.scopeContext;
sc.continueTarget = this;
sc.breakTarget = this;
bdy = bdy.semantic(sc);
condition = condition.semantic(sc);
sc.continueTarget = continueSave;
sc.breakTarget = breakSave;
return this;
}

    override TopStatement ImpliedReturn()
{
if (bdy)
bdy = cast(Statement)bdy.ImpliedReturn();
return this;
}

    override void toIR(IRstate* irs)
{
uint c;
uint u1;
Statement continueSave = irs.continueTarget;
Statement breakSave = irs.breakTarget;
uint marksave;
irs.continueTarget = this;
irs.breakTarget = this;
marksave = irs.mark();
u1 = irs.getIP();
bdy.toIR(irs);
c = irs.alloc(1);
continueIP = irs.getIP();
condition.toIR(irs,c);
irs.gen2(loc,condition.isBooleanResult() ? IRjtb : IRjt,u1 - irs.getIP(),c);
breakIP = irs.getIP();
irs.release(marksave);
irs.continueTarget = continueSave;
irs.breakTarget = breakSave;
condition = null;
bdy = null;
}

    override uint getBreak()
{
return breakIP;
}

    override uint getContinue()
{
return continueIP;
}

    override ScopeStatement getScope()
{
return scopeContext;
}

}
class WhileStatement : Statement
{
    Expression condition;
    Statement bdy;
    uint breakIP;
    uint continueIP;
    ScopeStatement scopeContext;
    this(Loc loc, Expression c, Statement b)
{
super(loc);
condition = c;
bdy = b;
breakIP = ~0u;
continueIP = ~0u;
scopeContext = null;
}
    override Statement semantic(Scope* sc)
{
Statement continueSave = sc.continueTarget;
Statement breakSave = sc.breakTarget;
scopeContext = sc.scopeContext;
sc.continueTarget = this;
sc.breakTarget = this;
condition = condition.semantic(sc);
bdy = bdy.semantic(sc);
sc.continueTarget = continueSave;
sc.breakTarget = breakSave;
return this;
}

    override TopStatement ImpliedReturn()
{
if (bdy)
bdy = cast(Statement)bdy.ImpliedReturn();
return this;
}

    override void toIR(IRstate* irs)
{
uint c;
uint u1;
uint u2;
Statement continueSave = irs.continueTarget;
Statement breakSave = irs.breakTarget;
uint marksave = irs.mark();
irs.continueTarget = this;
irs.breakTarget = this;
u1 = irs.getIP();
continueIP = u1;
c = irs.alloc(1);
condition.toIR(irs,c);
u2 = irs.getIP();
irs.gen2(loc,condition.isBooleanResult() ? IRjfb : IRjf,0,c);
bdy.toIR(irs);
irs.gen1(loc,IRjmp,u1 - irs.getIP());
irs.patchJmp(u2,irs.getIP());
breakIP = irs.getIP();
irs.release(marksave);
irs.continueTarget = continueSave;
irs.breakTarget = breakSave;
condition = null;
bdy = null;
}

    override uint getBreak()
{
return breakIP;
}

    override uint getContinue()
{
return continueIP;
}

    override ScopeStatement getScope()
{
return scopeContext;
}

}
class ForStatement : Statement
{
    Statement init;
    Expression condition;
    Expression increment;
    Statement bdy;
    uint breakIP;
    uint continueIP;
    ScopeStatement scopeContext;
    this(Loc loc, Statement init, Expression condition, Expression increment, Statement bdy)
{
super(loc);
this.init = init;
this.condition = condition;
this.increment = increment;
this.bdy = bdy;
breakIP = ~0u;
continueIP = ~0u;
scopeContext = null;
}
    override Statement semantic(Scope* sc)
{
Statement continueSave = sc.continueTarget;
Statement breakSave = sc.breakTarget;
if (init)
init = init.semantic(sc);
if (condition)
condition = condition.semantic(sc);
if (increment)
increment = increment.semantic(sc);
scopeContext = sc.scopeContext;
sc.continueTarget = this;
sc.breakTarget = this;
bdy = bdy.semantic(sc);
sc.continueTarget = continueSave;
sc.breakTarget = breakSave;
return this;
}

    override TopStatement ImpliedReturn()
{
if (bdy)
bdy = cast(Statement)bdy.ImpliedReturn();
return this;
}

    override void toIR(IRstate* irs);

    override uint getBreak()
{
return breakIP;
}

    override uint getContinue()
{
return continueIP;
}

    override ScopeStatement getScope()
{
return scopeContext;
}

}
class ForInStatement : Statement
{
    Statement init;
    Expression inexp;
    Statement bdy;
    uint breakIP;
    uint continueIP;
    ScopeStatement scopeContext;
    this(Loc loc, Statement init, Expression inexp, Statement bdy)
{
super(loc);
this.init = init;
this.inexp = inexp;
this.bdy = bdy;
breakIP = ~0u;
continueIP = ~0u;
scopeContext = null;
}
    override Statement semantic(Scope* sc);

    override TopStatement ImpliedReturn()
{
bdy = cast(Statement)bdy.ImpliedReturn();
return this;
}

    override void toIR(IRstate* irs);

    override uint getBreak()
{
return breakIP;
}

    override uint getContinue()
{
return continueIP;
}

    override ScopeStatement getScope()
{
return scopeContext;
}

}
class ScopeStatement : Statement
{
    ScopeStatement enclosingScope;
    int depth;
    int npops;
    this(Loc loc)
{
super(loc);
enclosingScope = null;
depth = 1;
npops = 1;
}
}
class WithStatement : ScopeStatement
{
    Expression exp;
    Statement bdy;
    this(Loc loc, Expression exp, Statement bdy)
{
super(loc);
this.exp = exp;
this.bdy = bdy;
}
    override Statement semantic(Scope* sc)
{
exp = exp.semantic(sc);
enclosingScope = sc.scopeContext;
sc.scopeContext = this;
if (enclosingScope)
depth = enclosingScope.depth + 1;
if (depth > sc.funcdef.withdepth)
sc.funcdef.withdepth = depth;
sc.nestDepth++;
bdy = bdy.semantic(sc);
sc.nestDepth--;
sc.scopeContext = enclosingScope;
return this;
}

    override TopStatement ImpliedReturn()
{
bdy = cast(Statement)bdy.ImpliedReturn();
return this;
}

    override void toIR(IRstate* irs)
{
uint c;
uint marksave = irs.mark();
irs.scopeContext = this;
c = irs.alloc(1);
exp.toIR(irs,c);
irs.gen1(loc,IRpush,c);
bdy.toIR(irs);
irs.gen0(loc,IRpop);
irs.scopeContext = enclosingScope;
irs.release(marksave);
exp = null;
bdy = null;
}

}
class ContinueStatement : Statement
{
    Identifier* ident;
    Statement target;
    this(Loc loc, Identifier* ident)
{
super(loc);
this.ident = ident;
target = null;
}
    override Statement semantic(Scope* sc);

    override void toIR(IRstate* irs);

    override uint getTarget()
{
assert(target);
return target.getContinue();
}

}
class BreakStatement : Statement
{
    Identifier* ident;
    Statement target;
    this(Loc loc, Identifier* ident)
{
super(loc);
this.ident = ident;
target = null;
}
    override Statement semantic(Scope* sc);

    override void toIR(IRstate* irs);

    override uint getTarget()
{
assert(target);
return target.getBreak();
}

}
class GotoStatement : Statement
{
    Identifier* ident;
    LabelSymbol label;
    this(Loc loc, Identifier* ident)
{
super(loc);
this.ident = ident;
label = null;
}
    override Statement semantic(Scope* sc);

    override void toIR(IRstate* irs);

    override uint getTarget()
{
return label.statement.getGoto();
}

}
class ReturnStatement : Statement
{
    Expression exp;
    this(Loc loc, Expression exp)
{
super(loc);
this.exp = exp;
}
    override Statement semantic(Scope* sc)
{
if (exp)
exp = exp.semantic(sc);
if (sc.funcdef.iseval || sc.funcdef.isglobal)
error(sc,ERR_MISPLACED_RETURN);
return this;
}

    override void toBuffer(ref tchar[] buf)
{
buf ~= "return ";
if (exp)
exp.toBuffer(buf);
buf ~= ";\x0a";
}

    override void toIR(IRstate* irs);

}
class ImpliedReturnStatement : Statement
{
    Expression exp;
    this(Loc loc, Expression exp)
{
super(loc);
this.exp = exp;
}
    override Statement semantic(Scope* sc)
{
if (exp)
exp = exp.semantic(sc);
return this;
}

    override void toBuffer(ref tchar[] buf)
{
if (exp)
exp.toBuffer(buf);
buf ~= ";\x0a";
}

    override void toIR(IRstate* irs);

}
class ThrowStatement : Statement
{
    Expression exp;
    this(Loc loc, Expression exp)
{
super(loc);
this.exp = exp;
}
    override Statement semantic(Scope* sc);

    override void toBuffer(ref tchar[] buf)
{
buf ~= "throw ";
if (exp)
exp.toBuffer(buf);
buf ~= ";\x0a";
}

    override void toIR(IRstate* irs)
{
uint e;
assert(exp);
e = irs.alloc(1);
exp.toIR(irs,e);
irs.gen1(loc,IRthrow,e);
irs.release(e,1);
exp = null;
}

}
class TryStatement : ScopeStatement
{
    Statement bdy;
    Identifier* catchident;
    Statement catchbdy;
    Statement finalbdy;
    this(Loc loc, Statement bdy, Identifier* catchident, Statement catchbdy, Statement finalbdy)
{
super(loc);
this.bdy = bdy;
this.catchident = catchident;
this.catchbdy = catchbdy;
this.finalbdy = finalbdy;
if (catchbdy && finalbdy)
npops = 2;
}
    override Statement semantic(Scope* sc)
{
enclosingScope = sc.scopeContext;
sc.scopeContext = this;
if (enclosingScope)
depth = enclosingScope.depth + 1;
if (depth > sc.funcdef.withdepth)
sc.funcdef.withdepth = depth;
bdy.semantic(sc);
if (catchbdy)
catchbdy.semantic(sc);
if (finalbdy)
finalbdy.semantic(sc);
sc.scopeContext = enclosingScope;
return this;
}

    override void toBuffer(ref tchar[] buf);

    override void toIR(IRstate* irs);

}
