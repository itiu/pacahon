// D import file generated from 'dmdscript/parse.d'
module dmdscript.parse;
import dmdscript.script;
import dmdscript.lexer;
import dmdscript.functiondefinition;
import dmdscript.expression;
import dmdscript.statement;
import dmdscript.identifier;
import dmdscript.ir;
import dmdscript.errmsgs;
class Parser : Lexer
{
    uint flags;
    enum 
{
normal = 0,
initial = 1,
allowIn = 0,
noIn = 2,
inForHeader = 4,
}
    FunctionDefinition lastnamedfunc;
    this(d_string sourcename, d_string base, int useStringtable)
{
super(sourcename,base,useStringtable);
nextToken();
}
    ~this()
{
lastnamedfunc = null;
}
    static int parseFunctionDefinition(out FunctionDefinition pfd, immutable(char)[] params, immutable(char)[] bdy, out ErrInfo perrinfo);

    int parseProgram(out TopStatement[] topstatements, ErrInfo* perrinfo)
{
topstatements = parseTopStatements();
check(TOKeof);
*perrinfo = errinfo;
return errinfo.message != null;
}
    TopStatement[] parseTopStatements();
    TopStatement parseFunction(int flag);
    Statement parseStatement();
    Expression parseOptionalExpression(uint flags = 0)
{
Expression e;
if (token.value == TOKsemicolon || token.value == TOKrparen)
e = null;
else
e = parseExpression(flags);
return e;
}
    void parseOptionalSemi()
{
if (token.value != TOKeof && token.value != TOKrbrace && !(token.sawLineTerminator && (flags & inForHeader) == 0))
check(TOKsemicolon);
}
    int check(TOK value);
    Expression parseParenExp()
{
Expression e;
check(TOKlparen);
e = parseExpression();
check(TOKrparen);
return e;
}
    Expression parsePrimaryExp(int innew);
    Expression[] parseArguments();
    Expression parseArrayLiteral();
    Expression parseObjectLiteral();
    Expression parseFunctionLiteral()
{
FunctionDefinition f;
Loc loc;
loc = currentline;
f = cast(FunctionDefinition)parseFunction(1);
return new FunctionLiteral(loc,f);
}
    Expression parsePostExp(Expression e, int innew);
    Expression parseUnaryExp();
    Expression parseMulExp();
    Expression parseAddExp();
    Expression parseShiftExp();
    Expression parseRelExp();
    Expression parseEqualExp();
    Expression parseAndExp();
    Expression parseXorExp();
    Expression parseOrExp();
    Expression parseAndAndExp();
    Expression parseOrOrExp();
    Expression parseCondExp();
    Expression parseAssignExp();
    Expression parseExpression(uint flags = 0);
}
