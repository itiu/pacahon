module pacahon.define;

enum : byte
{
	STORE = 1, 
	PUT = 1, 
	FOUND = 2, 
	GET = 2,
	EXAMINE = 4,
	AUTHORIZE = 8
}

enum : byte 
{
	COUNT_MESSAGE = 0,
	COUNT_COMMAND = 1,
	WORKED_TIME = 2
}

alias immutable(int)[]  const_int_array;
alias immutable(long)[]  const_long_array;

const byte asObject = 0;
const byte asArray = 1;
const byte asString = 2;
