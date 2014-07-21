module type;

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
}