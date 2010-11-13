/**
 * D header file for POSIX.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 *
 *          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.posix.setjmp;

private import core.sys.posix.config;
private import core.sys.posix.signal; // for sigset_t

extern (C):

//
// Required
//
/*
jmp_buf

int  setjmp(jmp_buf);
void longjmp(jmp_buf, int);
*/

version( linux )
{
    version( X86_64 )
    {
        //enum JB_BX      = 0;
        //enum JB_BP      = 1;
        //enum JB_12      = 2;
        //enum JB_13      = 3;
        //enum JB_14      = 4;
        //enum JB_15      = 5;
        //enum JB_SP      = 6;
        //enum JB_PC      = 7;
        //enum JB_SIZE    = 64;

        alias long[8] __jmp_buf;
    }
    else version( X86 )
    {
        //enum JB_BX      = 0;
        //enum JB_SI      = 1;
        //enum JB_DI      = 2;
        //enum JB_BP      = 3;
        //enum JB_SP      = 4;
        //enum JB_PC      = 5;
        //enum JB_SIZE    = 24;

        alias int[6] __jmp_buf;
    }
    else version ( SPARC )
    {
        alias int[3] __jmp_buf;
    }

    struct __jmp_buf_tag
    {
        __jmp_buf   __jmpbuf;
        int         __mask_was_saved;
        sigset_t    __saved_mask;
    }

    alias __jmp_buf_tag[1] jmp_buf;

    alias _setjmp setjmp; // see XOpen block
    void longjmp(jmp_buf, int);
}

//
// C Extension (CX)
//
/*
sigjmp_buf

int  sigsetjmp(sigjmp_buf, int);
void siglongjmp(sigjmp_buf, int);
*/

version( linux )
{
    alias jmp_buf sigjmp_buf;

    int __sigsetjmp(sigjmp_buf, int);
    alias __sigsetjmp sigsetjmp;
    void siglongjmp(sigjmp_buf, int);
}

//
// XOpen (XSI)
//
/*
int  _setjmp(jmp_buf);
void _longjmp(jmp_buf, int);
*/

version( linux )
{
    int  _setjmp(ref jmp_buf);
    void _longjmp(jmp_buf, int);
}
