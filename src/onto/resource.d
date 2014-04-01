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

alias Resource[]            Resources;
alias immutable(Resource)[] iResources;
Resources                   _empty_Resources  = Resources.init;
iResources                  _empty_iResources = iResources.init;

struct Resource
{
    private size_t idx;
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

    string uri()
    {
        if (type == ResourceType.Uri)
            return data;
        else
            return null;
    }

    void set_uri(string uri)
    {
        type = ResourceType.Uri;
        data = uri;
    }

    public size_t get_idx()
    {
        return idx;
    }

    public void set_idx(size_t _idx)
    {
        idx = _idx;
    }
}

bool anyExist(Resources rss, string[] objects)
{
    foreach (rs; rss)
    {
        foreach (object; objects)
        {
            if (rs.data == object)
                return true;
        }
    }
    return false;
}

bool anyExist(Resources rss, string object)
{
    foreach (rs; rss)
    {
        if (rs.data == object)
            return true;
    }
    return false;
}

