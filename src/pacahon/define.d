module pacahon.define;

import util.container;
import std.concurrency;

enum CNAME : byte
{
    COUNT_MESSAGE = 0,
    COUNT_COMMAND = 1,
    WORKED_TIME   = 2,
	LAST_UPDATE_TIME = 3,
	KEY2SLOT = 4
}

alias immutable(int)[]  const_int_array;
alias immutable(long)[] const_long_array;
alias Tid[string] Tid2Name;
alias immutable Tid2Name Tids;

const byte              asObject = 0;
const byte              asArray  = 1;
const byte              asString = 2;

interface Outer
{
	void put (string data); 
}

enum Type : ubyte
{
    Uri      = 1,
    String   = 2,
    Integer  = 4,
    Datetime = 8,
    Float    = 16
}