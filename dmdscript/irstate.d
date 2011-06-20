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

// The state of the interpreter machine as seen by the code generator, not
// the interpreter.

struct IRstate
{
    OutBuffer      codebuf;             // accumulate code here
    Statement      breakTarget;         // current statement that 'break' applies to
    Statement      continueTarget;      // current statement that 'continue' applies to
    ScopeStatement scopeContext;        // current ScopeStatement we're inside
    uint[]         fixups;

    //void next();	// close out current Block, and start a new one

    uint locali = 1;            // leave location 0 as our "null"
    uint nlocals = 1;

    void ctor()
    {
        codebuf = new OutBuffer();
    }

    void validate()
    {
        assert(codebuf.offset <= codebuf.data.length);
        if(codebuf.data.length > codebuf.data.capacity)
            printf("ptr %p, length %d, capacity %d\n", codebuf.data.ptr, codebuf.data.length, core.memory.GC.sizeOf(codebuf.data.ptr));
        assert(codebuf.data.length <= codebuf.data.capacity);
        for(uint u = 0; u < codebuf.offset; )
        {
            IR* code = cast(IR*)(codebuf.data.ptr + u);
            assert(code.opcode < IRMAX);
            u += IR.size(code.opcode) * 4;
        }
    }

    /**********************************
     * Allocate a block of local variables, and return an
     * index to them.
     */

    uint alloc(uint nlocals)
    {
        uint n;

        n = locali;
        locali += nlocals;
        if(locali > this.nlocals)
            this.nlocals = locali;
        assert(n);
        return n * INDEX_FACTOR;
    }

    /****************************************
     * Release this block of n locals starting at local.
     */

    void release(uint local, uint n)
    {
        /+
            local /= INDEX_FACTOR;
            if (local + n == locali)
                locali = local;
         +/
    }

    uint mark()
    {
        return locali;
    }

    void release(uint i)
    {
        //locali = i;
    }

    static uint combine(uint loc, uint opcode)
    {
        return (loc << 16) | opcode;
    }

    /***************************************
     * Generate code.
     */

    void gen0(Loc loc, uint opcode)
    {
        codebuf.write(combine(loc, opcode));
    }

    void gen1(Loc loc, uint opcode, uint arg)
    {
        codebuf.reserve(2 * uint.sizeof);
        version(all)
        {
            // Inline ourselves for speed (compiler doesn't do a good job)
            uint *data = cast(uint *)(codebuf.data.ptr + codebuf.offset);
            codebuf.offset += 2 * uint.sizeof;
            data[0] = combine(loc, opcode);
            data[1] = arg;
        }
        else
        {
            codebuf.write4n(combine(loc, opcode));
            codebuf.write4n(arg);
        }
    }

    void gen2(Loc loc, uint opcode, uint arg1, uint arg2)
    {
        codebuf.reserve(3 * uint.sizeof);
        version(all)
        {
            // Inline ourselves for speed (compiler doesn't do a good job)
            uint *data = cast(uint *)(codebuf.data.ptr + codebuf.offset);
            codebuf.offset += 3 * uint.sizeof;
            data[0] = combine(loc, opcode);
            data[1] = arg1;
            data[2] = arg2;
        }
        else
        {
            codebuf.write4n(combine(loc, opcode));
            codebuf.write4n(arg1);
            codebuf.write4n(arg2);
        }
    }

    void gen3(Loc loc, uint opcode, uint arg1, uint arg2, uint arg3)
    {
        codebuf.reserve(4 * uint.sizeof);
        version(all)
        {
            // Inline ourselves for speed (compiler doesn't do a good job)
            uint *data = cast(uint *)(codebuf.data.ptr + codebuf.offset);
            codebuf.offset += 4 * uint.sizeof;
            data[0] = combine(loc, opcode);
            data[1] = arg1;
            data[2] = arg2;
            data[3] = arg3;
        }
        else
        {
            codebuf.write4n(combine(loc, opcode));
            codebuf.write4n(arg1);
            codebuf.write4n(arg2);
            codebuf.write4n(arg3);
        }
    }

    void gen4(Loc loc, uint opcode, uint arg1, uint arg2, uint arg3, uint arg4)
    {
        codebuf.reserve(5 * uint.sizeof);
        version(all)
        {
            // Inline ourselves for speed (compiler doesn't do a good job)
            uint *data = cast(uint *)(codebuf.data.ptr + codebuf.offset);
            codebuf.offset += 5 * uint.sizeof;
            data[0] = combine(loc, opcode);
            data[1] = arg1;
            data[2] = arg2;
            data[3] = arg3;
            data[4] = arg4;
        }
        else
        {
            codebuf.write4n(combine(loc, opcode));
            codebuf.write4n(arg1);
            codebuf.write4n(arg2);
            codebuf.write4n(arg3);
            codebuf.write4n(arg4);
        }
    }

    void gen(Loc loc, uint opcode, uint argc, ...)
    {
        codebuf.reserve((1 + argc) * uint.sizeof);
        codebuf.write(combine(loc, opcode));
        for(uint i = 1; i <= argc; i++)
        {
            codebuf.write(va_arg!(uint)(_argptr));
        }
    }

    void pops(uint npops)
    {
        while(npops--)
            gen0(0, IRpop);
    }

    /******************************
     * Get the current "instruction pointer"
     */

    uint getIP()
    {
        if(!codebuf)
            return 0;
        return codebuf.offset / 4;
    }

    /******************************
     * Patch a value into the existing codebuf.
     */

    void patchJmp(uint index, uint value)
    {
        assert((index + 1) * 4 < codebuf.offset);
        (cast(uint *)(codebuf.data))[index + 1] = value - index;
    }

    /*******************************
     * Add this IP to list of jump instructions to patch.
     */

    void addFixup(uint index)
    {
        fixups ~= index;
    }

    /*******************************
     * Go through the list of fixups and patch them.
     */

    void doFixups()
    {
        uint i;
        uint index;
        uint value;
        Statement s;

        for(i = 0; i < fixups.length; i++)
        {
            index = fixups[i];
            assert((index + 1) * 4 < codebuf.offset);
            s = (cast(Statement *)codebuf.data)[index + 1];
            value = s.getTarget();
            patchJmp(index, value);
        }
    }


    void optimize()
    {
        // Determine the length of the code array
        IR *c;
        IR *c2;
        IR *code;
        uint length;
        uint i;

        code = cast(IR *)codebuf.data;
        for(c = code; c.opcode != IRend; c += IR.size(c.opcode))
        {
        }
        length = c - code + 1;

        // Allocate a bit vector for the array
        byte[] b = new byte[length]; //TODO: that was a bit array, maybe should use std.container

        // Set bit for each target of a jump
        for(c = code; c.opcode != IRend; c += IR.size(c.opcode))
        {
            switch(c.opcode)
            {
            case IRjf:
            case IRjt:
            case IRjfb:
            case IRjtb:
            case IRjmp:
            case IRjlt:
            case IRjle:
            case IRjltc:
            case IRjlec:
            case IRtrycatch:
            case IRtryfinally:
            case IRnextscope:
            case IRnext:
            case IRnexts:
                //writefln("set %d", (c - code) + (c + 1).offset);
                b[(c - code) + (c + 1).offset] = true;
                break;
            default:
                break;
            }
        }

        // Allocate array of IR contents for locals.
        IR*[] local;
        IR*[] p1 = null;

        // Allocate on stack for smaller arrays
        IR** plocals;
        if(nlocals < 128)
            plocals = cast(IR * *)alloca(nlocals * local[0].sizeof);

        if(plocals)
        {
            local = plocals[0 .. nlocals];
            local[] = null;
        }
        else
        {
            p1 = new IR *[nlocals];
            local = p1;
        }

        // Optimize
        for(c = code; c.opcode != IRend; c += IR.size(c.opcode))
        {
            uint offset = (c - code);

            if(b[offset])       // if target of jump
            {
                // Reset contents of locals
                local[] = null;
            }

            switch(c.opcode)
            {
            case IRnop:
                break;

            case IRnumber:
            case IRstring:
            case IRboolean:
                local[(c + 1).index / INDEX_FACTOR] = c;
                break;

            case IRadd:
            case IRsub:
            case IRcle:
                local[(c + 1).index / INDEX_FACTOR] = c;
                break;

            case IRputthis:
                local[(c + 1).index / INDEX_FACTOR] = c;
                goto Lreset;

            case IRputscope:
                local[(c + 1).index / INDEX_FACTOR] = c;
                break;

            case IRgetscope:
            {
                Identifier* cs = (c + 2).id;
                IR *cimax = null;
                for(i = nlocals; i--; )
                {
                    IR *ci = local[i];
                    if(ci &&
                       (ci.opcode == IRgetscope || ci.opcode == IRputscope) &&
                       (ci + 2).id.value.string == cs.value.string
                       )
                    {
                        if(cimax)
                        {
                            if(cimax < ci)
                                cimax = ci;     // select most recent instruction
                        }
                        else
                            cimax = ci;
                    }
                }
                if(1 && cimax)
                {
                    //writef("IRgetscope . IRmov %d, %d\n", (c + 1).index, (cimax + 1).index);
                    c.opcode = IRmov;
                    (c + 2).index = (cimax + 1).index;
                    local[(c + 1).index / INDEX_FACTOR] = cimax;
                }
                else
                    local[(c + 1).index / INDEX_FACTOR] = c;
                break;
            }

            case IRnew:
                local[(c + 1).index / INDEX_FACTOR] = c;
                goto Lreset;

            case IRcallscope:
            case IRputcall:
            case IRputcalls:
            case IRputcallscope:
            case IRputcallv:
            case IRcallv:
                local[(c + 1).index / INDEX_FACTOR] = c;
                goto Lreset;

            case IRmov:
                local[(c + 1).index / INDEX_FACTOR] = local[(c + 2).index / INDEX_FACTOR];
                break;

            case IRput:
            case IRpostincscope:
            case IRaddassscope:
                goto Lreset;

            case IRjf:
            case IRjfb:
            case IRjtb:
            case IRjmp:
            case IRjt:
            case IRret:
            case IRjlt:
            case IRjle:
            case IRjltc:
            case IRjlec:
                break;

            default:
                Lreset:
                // Reset contents of locals
                local[] = null;
                break;
            }
        }

        delete p1;

        //return;
        // Remove all IRnop's
        for(c = code; c.opcode != IRend; )
        {
            uint offset;
            uint o;
            uint c2off;

            if(c.opcode == IRnop)
            {
                offset = (c - code);
                for(c2 = code; c2.opcode != IRend; c2 += IR.size(c2.opcode))
                {
                    switch(c2.opcode)
                    {
                    case IRjf:
                    case IRjt:
                    case IRjfb:
                    case IRjtb:
                    case IRjmp:
                    case IRjlt:
                    case IRjle:
                    case IRjltc:
                    case IRjlec:
                    case IRnextscope:
                    case IRtryfinally:
                    case IRtrycatch:
                        c2off = c2 - code;
                        o = c2off + (c2 + 1).offset;
                        if(c2off <= offset && offset < o)
                            (c2 + 1).offset--;
                        else if(c2off > offset && o <= offset)
                            (c2 + 1).offset++;
                        break;
                    /+
                                        case IRtrycatch:
                                            o = (c2 + 1).offset;
                                            if (offset < o)
                                                (c2 + 1).offset--;
                                            break;
                     +/
                    default:
                        continue;
                    }
                }

                length--;
                memmove(c, c + 1, (length - offset) * uint.sizeof);
            }
            else
                c += IR.size(c.opcode);
        }
    }
}
