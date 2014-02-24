module onto.resource;

enum LANG : ubyte
{
    NONE = 0,
    RU   = 1,
    EN   = 2
}

enum ResourceType : ubyte
{
    Individual,
    String,
    Integer,
    Datetime,
    Float
}

alias Resource[] Resources;

struct Resource
{
    size_t       idx;
    ResourceType type = ResourceType.Individual;
    string       name;
    LANG         lang = LANG.NONE;
}

