module util.cbor;

private 
{
import std.outbuffer;
import std.stdio;
import std.typetuple;
import std.datetime;
import std.conv;

import util.graph;
import util.container;
import util.utils;
}

enum : byte
{
    TYPE  = 1,
    LINKS = 2,
    ALL   = 4
}

/** The CBOR-encoded boolean <code>false</code> value (encoded as "simple value": {@link #MT_SIMPLE}). */
int FALSE = 0x14;
/** The CBOR-encoded boolean <code>true</code> value (encoded as "simple value": {@link #MT_SIMPLE}). */
int TRUE = 0x15;
/** The CBOR-encoded <code>null</code> value (encoded as "simple value": {@link #MT_SIMPLE}). */
int NULL = 0x16;
/** The CBOR-encoded "undefined" value (encoded as "simple value": {@link #MT_SIMPLE}). */
int UNDEFINED = 0x17;
/** Denotes a half-precision float (two-byte IEEE 754, see {@link #MT_FLOAT}). */
int HALF_PRECISION_FLOAT = 0x19;
/** Denotes a single-precision float (four-byte IEEE 754, see {@link #MT_FLOAT}). */
int SINGLE_PRECISION_FLOAT = 0x1a;
/** Denotes a double-precision float (eight-byte IEEE 754, see {@link #MT_FLOAT}). */
int DOUBLE_PRECISION_FLOAT = 0x1b;
/** The CBOR-encoded "break" stop code for unlimited arrays/maps. */
int BREAK = 0x1f;

/** Semantic tag value describing date/time values in the standard format (UTF8 string, RFC3339). */
int TAG_STANDARD_DATE_TIME = 0;
/** Semantic tag value describing date/time values as Epoch timestamp (numeric, RFC3339). */
int TAG_EPOCH_DATE_TIME = 1;
/** Semantic tag value describing a positive big integer value (byte string). */
int TAG_POSITIVE_BIGINT = 2;
/** Semantic tag value describing a negative big integer value (byte string). */
int TAG_NEGATIVE_BIGINT = 3;
/** Semantic tag value describing a decimal fraction value (two-element array, base 10). */
int TAG_DECIMAL_FRACTION = 4;
/** Semantic tag value describing a big decimal value (two-element array, base 2). */
int TAG_BIGDECIMAL = 5;
/** Semantic tag value describing an expected conversion to base64url encoding. */
int TAG_EXPECTED_BASE64_URL_ENCODED = 21;
/** Semantic tag value describing an expected conversion to base64 encoding. */
int TAG_EXPECTED_BASE64_ENCODED = 22;
/** Semantic tag value describing an expected conversion to base16 encoding. */
int TAG_EXPECTED_BASE16_ENCODED = 23;
/** Semantic tag value describing an encoded CBOR data item (byte string). */
int TAG_CBOR_ENCODED = 24;
/** Semantic tag value describing an URL (UTF8 string). */
int TAG_URI = 32;
/** Semantic tag value describing a base64url encoded string (UTF8 string). */
int TAG_BASE64_URL_ENCODED = 33;
/** Semantic tag value describing a base64 encoded string (UTF8 string). */
int TAG_BASE64_ENCODED = 34;
/** Semantic tag value describing a regular expression string (UTF8 string, PCRE). */
int TAG_REGEXP = 35;
/** Semantic tag value describing a MIME message (UTF8 string, RFC2045). */
int TAG_MIME_MESSAGE = 36;
/** Semantic tag value describing CBOR content. */
int TAG_CBOR_MARKER = 55799;

enum MajorType : ubyte
{
    /** Major type 0: unsigned integers. */
    UNSIGNED_INTEGER     = 0 << 5,
        /** Major type 1: negative integers. */
        NEGATIVE_INTEGER = 1 << 5,
        /** Major type 2: byte string. */
        BYTE_STRING      = 2 << 5,
        /** Major type 3: text/UTF8 string. */
        TEXT_STRING      = 3 << 5,
        /** Major type 4: array of items. */
        ARRAY            = 4 << 5,
        /** Major type 5: map of pairs. */
        MAP              = 5 << 5,
        /** Major type 6: semantic tags. */
        TAG              = 6 << 5,
        /** Major type 7: floating point, simple data types. */
        FLOAT_SIMPLE     = 7 << 5
}

enum TAG : ubyte
{
	NONE	= 255,
	TEXT_RU = 42,
	TEXT_EN = 43
}	

struct ElementHeader
{
    MajorType type;
    ulong     len;
    TAG	  tag = TAG.NONE; 		
}

struct Element
{
    MajorType type;
    union
    {
        string    str;
        Predicate pp;
        Subject   subject;
    }
    LANG lang;
}

string toString (ElementHeader *el)
{
	return "type=" ~ text(el.type) ~ ", len=" ~ text(el.len) ~ ", tag=" ~ text(el.tag); 
}

///////////////////////////////////////////////////////////////////////////

public void write_header(MajorType type, ulong len, ref OutBuffer ou)
{
//    writeln ("@1 type=", type, ", len=", len);
    ubyte element_header;
    ulong add_info;

   	add_info = len;

    if (add_info < 24)
    {
        ubyte ll = cast(ubyte)add_info;
        element_header = type | ll;
        ou.write(element_header);

//	writeln ("element_header=",element_header);
//	writeln ("@1 element_header=", element_header, ", len=", len);
    }
    else
    {
        if ((add_info & 0xff00000000000000) > 0)
        {
            element_header = type | 27;
            ou.write(element_header);
            ou.write(add_info);
        }
        else if ((add_info & 0xff000000) > 0)
        {
            element_header = type | 26;
            ou.write(element_header);
            ou.write(cast(uint)add_info);
        }
        else if ((add_info & 0xff00) > 0)
        {
            element_header = type | 25;
            ou.write(element_header);
            ou.write(cast(ushort)add_info);
        }
        else if ((add_info & 0xff) > 0)
        {
            element_header = type | 24;
            ou.write(element_header);
//	writeln ("element_header=",element_header);
            ou.write(cast(ubyte)add_info);
//	writeln ("len=",cast(ubyte)len);
        }
    }
}

public void write_predicate(Predicate vv, ref OutBuffer ou)
{
    write_string(vv.predicate, ou);
    if (vv.length > 1)
        write_header(MajorType.ARRAY, vv.length, ou);
    foreach (value; vv)
    {
        write_string(value.literal, ou, value.lang);
    }
}

public void write_string(string vv, ref OutBuffer ou, LANG lang = LANG.NONE)
{
	if (lang == LANG.NONE)
	{
		write_header(MajorType.TEXT_STRING, vv.length, ou);
    }
	else
	{
		write_header(MajorType.TAG, lang + 41, ou);
		write_header(MajorType.TEXT_STRING, vv.length, ou);
	}
    ou.write(vv);
}

public void write(T) (T[] arr, ref OutBuffer ou)
{
    write_header(MajorType.ARRAY, arr.length, ou);
    foreach (value; arr)
    {
        write(value, ou);
    }
}

private short short_from_buff(ubyte[] buff, int pos)
{
    short res = buff[ pos + 0 ] + ((cast(short)buff[ pos + 1 ]) << 8);

    return res;
}

private int int_from_buff(ubyte[] buff, int pos)
{
    int res = buff[ pos + 0 ] + ((cast(uint)buff[ pos + 1 ]) << 8) + ((cast(uint)buff[ pos + 2 ]) << 16) + ((cast(uint)buff[ pos + 3 ]) << 24);

    return res;
}

private long long_from_buff(ubyte[] buff, int pos)
{
    long res = buff[ pos + 0 ] + ((cast(uint)buff[ pos + 1 ]) << 8) + ((cast(uint)buff[ pos + 2 ]) << 16) + ((cast(uint)buff[ pos + 3 ]) << 24);

    return res;
}

private static int read_element(ubyte[] src, Element *el, byte fields)
{
    int           pos;
    ElementHeader header;

    pos = read_header(src[ pos..$ ], &header);
//    writeln ("read_element:[", cast(string)src[0..pos+header.len], "],[", src[0..pos+header.len], "]");

//    writeln ("pos +-> ", pos);

    el.type = header.type;
    if (header.type == MajorType.MAP)
    {
        Subject res1 = new Subject();
//	writeln ("IS MAP, length=", header.len, ", pos=", pos);
        foreach (i; 0 .. header.len)
        {
            Element key;
            pos += read_element(src[ pos..$ ], &key, fields);
//            writeln ("key=", key.val, ", pos=", pos);
            Element val;
            pos += read_element(src[ pos..$ ], &val, fields);
//            writeln ("val=", val.val, ", pos=", pos);

            if (key.str == "@")
            {
                res1.subject = val.str;
            }
            else if (key.type == MajorType.TEXT_STRING && val.type == MajorType.ARRAY)
            {
                if (val.pp !is null)
                {
                    val.pp.predicate = key.str;
                    if (val.pp.length > 0)
                    {
                        res1.addPredicate(val.pp);
                    }    
                }
            }
            else if (val.str.length > 0 && key.type == MajorType.TEXT_STRING && val.type == MajorType.TEXT_STRING)
            {
                if (fields == ALL || (fields == LINKS && is_link_on_subject(val.str) == true))
                {
                	//writeln ("[", val.str, "], lang=", val.lang);
                    res1.addPredicate(key.str, val.str, val.lang);
                }
            }
        }
        el.subject = res1;
    }
    else if (header.type == MajorType.TEXT_STRING)
    {
//	writeln ("IS STRING, length=", header.len, ", pos=", pos);
        int    ep = cast(int)(pos + header.len);

        string str = cast(string)src[ pos..ep ].dup;
        el.str = str;
        
       	if (header.tag == TAG.TEXT_RU || header.tag == TAG.TEXT_EN)
       	{
       		el.lang = cast (LANG)(header.tag - 41); 
//       		writeln ("TAGGED str=", str, ", lang=", el.lang);
       	}

        pos = ep;
    }
    else if (header.type == MajorType.ARRAY)
    {
//	writeln ("IS ARRAY, length=", header.len, ", pos=", pos);
        Predicate vals;
        foreach (i; 0 .. header.len)
        {
            Element arr_el;
            pos += read_element(src[ pos..$ ], &arr_el, fields);

            if (arr_el.type == MajorType.TEXT_STRING)
            {
                if (fields == ALL || (fields == LINKS && is_link_on_subject(arr_el.str) == true))
                {
                    if (vals is null)
                        vals = new Predicate();

                    vals.addLiteral (arr_el.str, arr_el.lang);
                }
            }
        }
        el.pp = vals;
    }
    return pos;
}

private int read_header(ubyte[] src, ElementHeader *header)
{
    ubyte hh = src[ 0 ];
//    writeln ("hh=", hh);
//    writeln ("hh & 0xe0=", hh & 0xe0);

    MajorType type  = cast(MajorType)(hh & 0xe0);
    ulong     ld    = hh & 0x1f;
    int       d_pos = 1;

    if (ld > 23)
    {
        d_pos += 1 << (ld - 24);
        if (ld == 24)
            ld = src[ 1 ];
        else if (ld == 25)
            ld = short_from_buff(src, 1);
        else if (ld == 26)
            ld = int_from_buff(src, 1);
        else if (ld == 27)
            ld = long_from_buff(src, 1);
    }
    
    if (type == MajorType.TAG)
    {
    	ElementHeader main_type_header;
    	d_pos += read_header(src[d_pos..$], &main_type_header);
    	header.tag = cast(TAG)ld;
    	header.len = main_type_header.len;
    	header.type = main_type_header.type;
 //   	writeln ("HEADER:", header.toString());
    }
    else
    {
    	if (ld > src.length)
    	{
    		writeln("%%%%%%%%%%%%%%%%%%%%%%%% ld=", ld);
    		ld = src.length;
    	}
    	header.len = ld;
    	header.type = type;    	
    }
//    writeln ("type=", type, ", length=", ld, ", d_pos=", d_pos, ", src.length=", src.length);

    return d_pos;
}


/////////////////////////////////////////////////////////////////////////////////////
public string encode_cbor(Subject in_obj)
{
//	writeln ("encode_cbor #1, subject:", in_obj);
    OutBuffer ou = new OutBuffer();

    ulong     map_len = in_obj.length + 1;
    MajorType type    = MajorType.MAP;

    write_header(type, map_len, ou);
    write_string("@", ou);
    write_string(in_obj.subject, ou);

    foreach (pp; in_obj)
    {
        write_predicate(pp, ou);
    }

//	writeln ("encode_cbor #2 : ou:[", ou, "]");
    return ou.toString();
}


public Subject decode_cbor(string in_str, byte fields = ALL)
{
//    StopWatch sw;
//    sw.start();

    Element res;

    read_element(cast(ubyte[])in_str, &res, fields);

//    sw.stop();
//    int t = cast(int)sw.peek().usecs;
//    writeln("time:", t);

    return res.subject;
}

private static bool is_link_on_subject(string val)
{
    if (val.length > 12)
    {
        if (val[ 0 ] == '#')
            return true;

        if (val[ 0 ] == 'z' && val[ 1 ] == 'd' && val[ 2 ] == 'b' && val[ 3 ] == ':' && val[ 4 ] == 'd' && val[ 5 ] == 'o')
            return true;
    }
    return false;
}

