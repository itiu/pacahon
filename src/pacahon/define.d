module pacahon.define;

enum : byte
{
	STORE = 0, 
	FOUND = 1, 
	EXAMINE = 2,
	GET = 1,
	PUT = 0 
}

enum : byte 
{
	COUNT_MESSAGE = 0,
	COUNT_COMMAND = 1,
	WORKED_TIME = 2
}

alias immutable(int)[]  const_int_array;
alias immutable(long)[]  const_long_array;
