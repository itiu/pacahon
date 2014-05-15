module onto.resource;

import onto.lang;
import pacahon.define;

enum ResourceType : ubyte
{
    Uri      = DataType.Uri,
    String   = DataType.String,
    Integer  = DataType.Integer,
    Datetime = DataType.Datetime,
    Date	 = DataType.Date,
    Float    = DataType.Float,
    Boolean	 = DataType.Bool    	
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

public void setMapResources(Resources rss, ref Resource[ string ] hrss)
{
    foreach (rs; rss)
        hrss[ rs.data ] = rs;
}

public bool anyExist(ref Resource[ string ] hrss, string object)
{
    if ((object in hrss) !is null)
        return true;
    else
        return false;
}

public bool anyExist(ref Resource[ string ] hrss, string[] objects)
{
    foreach (object; objects)
    {
        if ((object in hrss) !is null)
            return true;
    }
    return false;
}


struct Resource
{
    private size_t idx;
    ResourceType   type   = ResourceType.Uri;
    ResourceOrigin origin = ResourceOrigin.local;

    string         data;
//    bool		   bool_data;	
    
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

    this(ResourceType _type, bool val)
    {
    	if (val == true)
    		data = "1";
    	else	
    		data = "0";
        type = _type;
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

