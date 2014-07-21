module onto.resource;

import std.conv;
import onto.lang;
import pacahon.define;

enum ResourceType : ubyte
{
    Uri      = DataType.Uri,
    String   = DataType.String,
    Integer  = DataType.Integer,
    Datetime = DataType.Datetime,
    Date     = DataType.Date,
    Float    = DataType.Float,
    Boolean  = DataType.Bool
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
        hrss[ rs.get!string ] = rs;
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
    ResourceType   type   = ResourceType.Uri;
    ResourceOrigin origin = ResourceOrigin.local;
    LANG lang = LANG.NONE;    

    private {
        void *[ 2 ] m_data;
        ref inout (T)getDataAs(T) () inout { static assert(T.sizeof <= m_data.sizeof); return *cast(inout (T) *)m_data.ptr; }
        @property ref inout (long)m_int() inout { return getDataAs!long (); }
        @property ref inout (double)m_float() inout { return getDataAs!double (); }
        @property ref inout (bool)m_bool() inout { return getDataAs!bool(); }
        @property ref inout (string)m_string() inout { return getDataAs!string(); }
    }

    @property inout (T)get(T) ()
    inout {
        static if (is (T == bool))
            return m_bool;
        else
            static if (is (T == double))
                return m_float;
            else
                static if (is (T == float))
                    return cast(T)m_float;
                else
                    static if (is (T == long))
                        return m_int;
                    else
                        static if (is (T == ulong))
                            return cast(ulong)m_int;
                        else
                            static if (is (T == string))
                                return m_string;
                            else
                                static assert("Resource can only be casted to (bool, long, double, string. Not " ~ T.stringof ~ ".");
    }

    bool opEquals(bool v) const
    {
        return type == ResourceType.Boolean && m_bool == v;
    }
    bool opEquals(long v) const
    {
        return type == ResourceType.Integer && m_int == v;
    }
    bool opEquals(double v) const
    {
        return type == ResourceType.Float && m_float == v;
    }
    bool opEquals(string v) const
    {
        return (type == ResourceType.String || type == ResourceType.Uri) && m_string == v;
    }

    bool opAssign(bool v)
    {
        type = ResourceType.Boolean; m_bool = v; return v;
    }
    int opAssign(int v)
    {double
        type = ResourceType.Integer; m_int = v; return v;
    }
    long opAssign(long v)
    {
        type = ResourceType.Integer; m_int = v; return v;
    }
    double opAssign(double v)
    {
        type = ResourceType.Float; m_float = v; return v;
    }
    string opAssign(string v)
    {
        type = ResourceType.String; m_string = v; return v;
    }

    this(string str, ResourceOrigin _origin)
    {
        this   = str;
        type   = ResourceType.Uri;
        origin = _origin;
    }

    this(ResourceType _type, string str, LANG _lang = LANG.NONE)
    {
        this = str;
        type = _type;
        lang = _lang;
    }

    this(string str, LANG _lang = LANG.NONE)
    {
        this = str;
        type = ResourceType.String;
        lang = _lang;
    }

    this(bool val)
    {
        this = val;
        type = ResourceType.Boolean;
    }

    this(double val)
    {
        this = val;
        type = ResourceType.Float;
    }
    
    this(ulong val)    
    {
        this = cast(long)val;
        type = ResourceType.Integer;
    }
    
    this(ResourceType _type, ulong val)
    {
        this = cast(long)val;
        type = _type;    	
    }    
    
    void toString(scope void delegate(const(char)[]) sink) const
    {
    	if (type == ResourceType.Uri || type == ResourceType.String)
    		sink(get!string());
    	else if (type == ResourceType.Boolean)
    		sink(text (get!bool()));
    	else if (type == ResourceType.Datetime)
    		sink(get!string());    		    		
    	else if (type == ResourceType.Float)
    		sink(text (get!double()));    		    		
    	else if (type == ResourceType.Integer)
    		sink(text (get!long()));    		    		
    }
    
    @property string data()
    {
        return get!string();
    }

    @property immutable string idata()
    {
        return get!string().idup;
    }

    @property void data(string str)
    {
        this = str;
    }

    string literal()
    {
        return get!string();
    }

    string uri()
    {
        if (type == ResourceType.Uri)
            return m_string;
        else
            return null;
    }

    void set_uri(string uri)
    {
        type     = ResourceType.Uri;
        m_string = uri;
    }
}

bool anyExist(Resources rss, string[] objects)
{
    foreach (rs; rss)
    {
        foreach (object; objects)
        {
            if (rs.m_string == object)
                return true;
        }
    }
    return false;
}

bool anyExist(T) (Resources rss, T object)
{
    foreach (rs; rss)
    {
        if (rs == object)
            return true;
    }
    return false;
}

