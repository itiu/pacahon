module onto.resource;

import onto.lang;

enum ResourceType : ubyte
{
    Uri      = 1,
    String   = 2,
    Integer  = 4,
    Datetime = 8,
    Float    = 16
}

enum ResourceOrigin : ubyte
{
    local    = 1,
    external = 2
}

alias Resource[] Resources;


struct Resource
{
    size_t         idx;
    ResourceType   type   = ResourceType.Uri;
    ResourceOrigin origin = ResourceOrigin.local;
    string         data;
    LANG           lang = LANG.NONE;

    this(string str, ResourceOrigin _origin)
    {
        data   = str;
        type   = ResourceType.Uri;
        origin = _origin;
    }

    this(ResourceType _type, string str, LANG _lang = LANG.NONE)
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

