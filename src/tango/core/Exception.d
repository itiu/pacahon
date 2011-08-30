/**
 * The exception module defines all system-level exceptions and provides a
 * mechanism to alter system-level error handling.
 *
 * Copyright: Copyright (C) 2005-2006 Sean Kelly, Kris Bell.  All rights reserved.
 * License:   BSD style: $(LICENSE)
 * Authors:   Sean Kelly, Kris Bell
 */
module tango.core.Exception;

/**
 * Thrown when an illegal argument is encountered.
 */
class IllegalArgumentException : Exception
{
    this( char[] msg )
    {
        super( cast (string) msg );
    }
    this( string msg )
    {
        super( msg );
    }
}
