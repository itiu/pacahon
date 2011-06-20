/* Digital Mars DMDScript source code.
 * Copyright (c) 2000-2002 by Chromium Communications
 * D version Copyright (c) 2004-2010 by Digital Mars
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
 * written by Walter Bright
 * http://www.digitalmars.com
 *
 * D2 port by Dmitry Olshansky 
 *
 * DMDScript is implemented in the D Programming Language,
 * http://www.digitalmars.com/d/
 *
 * For a C++ implementation of DMDScript, including COM support, see
 * http://www.digitalmars.com/dscript/cppscript.html
 */


// Opcodes for our Intermediate Representation (IR)

module dmdscript.ir;

enum
{
    IRerror,
    IRnop,                      // no operation
    IRend,                      // end of function
    IRstring,
    IRthisget,
    IRnumber,
    IRobject,
    IRthis,
    IRnull,
    IRundefined,
    IRboolean,
    IRcall,
    IRcalls = IRcall + 1,
    IRcallscope = IRcalls + 1,
    IRcallv = IRcallscope + 1,
    IRputcall,
    IRputcalls = IRputcall + 1,
    IRputcallscope = IRputcalls + 1,
    IRputcallv = IRputcallscope + 1,
    IRget,
    IRgets = IRget + 1,         // 's' versions must be original + 1
    IRgetscope = IRgets + 1,
    IRput,
    IRputs = IRput + 1,
    IRputscope = IRputs + 1,
    IRdel,
    IRdels = IRdel + 1,
    IRdelscope = IRdels + 1,
    IRnext,
    IRnexts = IRnext + 1,
    IRnextscope = IRnexts + 1,
    IRaddass,
    IRaddasss = IRaddass + 1,
    IRaddassscope = IRaddasss + 1,
    IRputthis,
    IRputdefault,
    IRmov,
    IRret,
    IRretexp,
    IRimpret,
    IRneg,
    IRpos,
    IRcom,
    IRnot,
    IRadd,
    IRsub,
    IRmul,
    IRdiv,
    IRmod,
    IRshl,
    IRshr,
    IRushr,
    IRand,
    IRor,
    IRxor,
	IRin,
    IRpreinc,
    IRpreincs = IRpreinc + 1,
    IRpreincscope = IRpreincs + 1,

    IRpredec,
    IRpredecs = IRpredec + 1,
    IRpredecscope = IRpredecs + 1,

    IRpostinc,
    IRpostincs = IRpostinc + 1,
    IRpostincscope = IRpostincs + 1,

    IRpostdec,
    IRpostdecs = IRpostdec + 1,
    IRpostdecscope = IRpostdecs + 1,

    IRnew,

    IRclt,
    IRcle,
    IRcgt,
    IRcge,
    IRceq,
    IRcne,
    IRcid,
    IRcnid,

    IRjt,
    IRjf,
    IRjtb,
    IRjfb,
    IRjmp,

    IRjlt,              // commonly appears as loop control
    IRjle,              // commonly appears as loop control

    IRjltc,             // commonly appears as loop control
    IRjlec,             // commonly appears as loop control

    IRtypeof,
    IRinstance,

    IRpush,
    IRpop,

    IRiter,
    IRassert,

    IRthrow,
    IRtrycatch,
    IRtryfinally,
    IRfinallyret,
    IRcheckref,//like scope get w/o target, occures mostly on (legal) programmer mistakes
    IRMAX
}


