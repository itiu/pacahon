module type;

import std.math, std.stdio, std.conv, std.string;

enum Access : ubyte
{
    can_create  = 1,
    can_read    = 2,
    can_update  = 4,
    can_delete  = 8,
    cant_create = 16,
    cant_read   = 32,
    cant_update = 64,
    cant_delete = 128
}

Access[] access_list = [Access.can_create, Access.can_read, Access.can_update, Access.can_delete, Access.cant_create, 
Access.cant_read, Access.cant_update, Access.cant_delete];

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
//		writeln ("@p#1 num=", num);
		string[] ff = split (num, ".");		
		
		if (ff.length == 2)
		{
			long sfp = ff[1].length;
//			writeln ("@p#1 sfp=", sfp);
			
			mantissa = to!long (ff[0] ~ ff[1]);
			exponent = -sfp; 

//			writeln ("@p#1 mantissa=", mantissa);
//			writeln ("@p#1 exponent=", exponent);
		}
	}	
	
	this (double num)
	{
		byte sign = 1;
		
		if (num < 0)
		{				
			num = -num;
			sign = -1;
		}			
		
//		writeln ("@p#2 num=", num);

		byte count;
		double x = num;
		while (true)
		{
//			writeln ("@p#2 x=", x, ", d=", x - cast(long)(x), ", cast(long)(x)=", cast(long)(x));

			if (x - cast(long)(x) <= 0)
				break;

			x *= 10;
			++count;
		}		
		mantissa = cast(long)(num*pow (10, count))*sign;
		
		exponent =  -count;

//			writeln ("@p#2 mantissa=", mantissa);
//			writeln ("@p#2 exponent=", exponent);
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