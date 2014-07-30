module onto.resource;

import std.conv, std.stdio;
import onto.lang;
import type;

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
    DataType   type   = DataType.Uri;
    ResourceOrigin origin = ResourceOrigin.local;
    LANG lang = LANG.NONE;    

    private {
        void *[ 2 ] m_data;
        ref inout (T)getDataAs(T) () inout { static assert(T.sizeof <= m_data.sizeof); return *cast(inout (T) *)m_data.ptr; }
        @property ref inout (long)m_int() inout { return getDataAs!long (); }
        @property ref inout (decimal)m_decimal() inout { return getDataAs!decimal (); }
        @property ref inout (bool)m_bool() inout { return getDataAs!bool(); }
        @property ref inout (string)m_string() inout { return getDataAs!string(); }
    }
    ///////////////////////////////////////////

    @property inout (T)get(T) ()
    inout {
        static if (is (T == bool))
            return m_bool;
        else
            static if (is (T == decimal))
                return m_decimal;
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

    ///////////////////////////////////////////
    bool opEquals(bool v) const
    {
        return type == DataType.Boolean && m_bool == v;
    }
    bool opEquals(long v) const
    {
        return type == DataType.Integer && m_int == v;
    }
    bool opEquals(decimal v) const
    {
        return type == DataType.Decimal && m_decimal == v;
    }
    bool opEquals(string v) const
    {
        return (type == DataType.String || type == DataType.Uri) && m_string == v;
    }
    
    ///////////////////////////////////////////
    bool opAssign(bool v)
    {
        type = DataType.Boolean; m_bool = v; return v;
    }
    int opAssign(int v)
    {
        type = DataType.Integer; m_int = v; return v;
    }
    long opAssign(long v)
    {
        type = DataType.Integer; m_int = v; return v;
    }
    decimal opAssign(decimal v)
    {
        type = DataType.Decimal; m_decimal = v; return v;
    }
    string opAssign(string v)
    {
        type = DataType.String; m_string = v; return v;
    }
    
    ///////////////////////////////////////////
    this(string str, ResourceOrigin _origin)
    {
        this   = str;
        type   = DataType.Uri;
        origin = _origin;
    }

    this(DataType _type, string str, LANG _lang = LANG.NONE)
    {
    	if (_type == DataType.Integer)
    	{
    		try
    		{
    			this = parse!long (str);
    			type = _type;
    		}
    		catch (Exception ex)
    		{
    			writeln ("Ex!: ", __FUNCTION__, ":", text(__LINE__), ", ", ex.msg);
    		}
    	}
    	else
    	{
    		this = str;
    		type = _type;
    		lang = _lang;
        }
    }

    this(string str, LANG _lang = LANG.NONE)
    {
        this = str;
        type = DataType.String;
        lang = _lang;
    }

    this(bool val)
    {
        this = val;
        type = DataType.Boolean;
    }

    this(decimal val)
    {
        this = val;
        type = DataType.Decimal;
    }
    
    this(ulong val)    
    {
        this = cast(long)val;
        type = DataType.Integer;
    }
    
    this(DataType _type, ulong val)
    {
        this = cast(long)val;
        type = _type;    	
    }    
    
    void toString(scope void delegate(const(char)[]) sink) const
    {
    	if (type == DataType.Uri || type == DataType.String)
    		sink(get!string());
    	else if (type == DataType.Boolean)
    		sink(text (get!bool()));
    	else if (type == DataType.Datetime)
    		sink(get!string());    		    		
    	else if (type == DataType.Decimal)
    		sink(text (get!decimal()));    		    		
    	else if (type == DataType.Integer)
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
        if (type == DataType.Uri)
            return m_string;
        else
            return null;
    }

    void set_uri(string uri)
    {
        type     = DataType.Uri;
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

