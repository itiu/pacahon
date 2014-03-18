module pacahon.define;

import util.container;
import std.concurrency;

enum CNAME : byte
{
    COUNT_MESSAGE    = 0,
    COUNT_COMMAND    = 1,
    WORKED_TIME      = 2,
    LAST_UPDATE_TIME = 3,
    KEY2SLOT         = 4
}

alias immutable(int)[]   const_int_array;
alias immutable(long)[]  const_long_array;
alias                    Tid[ string ] Tid2Name;
alias immutable Tid2Name Tids;

const byte               asObject = 0;
const byte               asArray  = 1;
const byte               asString = 2;

interface Outer
{
    void put(string data);
}

enum DataType : ubyte
{
    Uri      = 1,
    String   = 2,
    Integer  = 4,
    Datetime = 8,
    Float    = 16
}

enum EVENT : byte
{
    CREATE = 1,
    UPDATE = 2,
    REMOVE = 3,
    NONE   = 4,
    ERROR  = 5
}

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


const string individuals_db_path = "./data/lmdb-individuals";
const string tickets_db_path     = "./data/lmdb-tickets";
const string acl_indexes_db_path = "./data/acl-indexes";
