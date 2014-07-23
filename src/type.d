module type;

import std.math, std.stdio, std.conv, std.string;

enum DataType : ubyte
{
    Uri         = 1,
    String      = 2,
    Integer     = 4,
    Datetime    = 8,
    Decimal     = 32,
    Boolean     = 64
}

struct decimal
{
	long mantissa;
	long exponent;
	
	this (long m, long e)
	{
		mantissa = m;
		exponent = e;
	}
	
	this (string num)
	{
		string[] ff = split (num, ".");		
		
		if (ff.length == 2)
		{
			long a = to!long(ff[0]);
			long b = to!long(ff[1]);
			
			int sfp = cast (int)log10 (b);
			
			mantissa = a * pow (10, sfp);
			exponent = - sfp; 
		}
	}
	
	this (double x)
	{
		byte count;
		while (true)
		{
			x *= 10;
			if (cast(long)(x) % 10 == 0)
				break;
			++count;
		}		
		mantissa = cast(long)x/10;
		exponent =  -count;
	}
	
	double toDouble ()
	{
		try
		{
			return mantissa * pow (10.0, exponent);
		}
		catch (Exception ex )
		{
			writeln ("EX! ", ex.msg);
			return 0;
		}
	}
		
}