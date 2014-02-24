module onto.resource;

enum LANG : ubyte
{
    NONE = 0,
    RU   = 1,
    EN   = 2
}

enum ResourceType : ubyte
{
    Uri,
    String,
    Integer,
    Datetime,
    Float
}

alias Resource[] Resources;


struct Resource
{
    size_t           idx;
    ResourceType     type = ResourceType.Uri;
    string           data;
    LANG             lang = LANG.NONE;

    this (string str, ResourceType _type=ResourceType.Uri, LANG _lang=LANG.NONE)
    {
    	data = str;
    	type = _type;
    	lang = _lang;
    }

    @property string uri()
    {
        if (type == ResourceType.Uri)
            return data;
        else
            return null;
    }

    @property void uri(string uri)
    {
        type = ResourceType.Uri;
        data = uri;
    }
}

