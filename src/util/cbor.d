module util.cbor;

private
{
    import std.outbuffer;
    import std.stdio;
    import std.typetuple;
    import std.datetime;
    import std.conv;

    import util.container;
 //   import util.utils;
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
    NONE                        = 255,

    TEXT_RU                     = 42,

    TEXT_EN                     = 43,
/** date/time values in the standard format (UTF8 string, RFC3339). */
    STANDARD_DATE_TIME          = 0,
/** date/time values as Epoch timestamp (numeric, RFC3339). */
    EPOCH_DATE_TIME             = 1,
/** positive big integer value (byte string). */
    POSITIVE_BIGINT             = 2,
/** negative big integer value (byte string). */
    NEGATIVE_BIGINT             = 3,
/** decimal fraction value (two-element array, base 10). */
    DECIMAL_FRACTION            = 4,
/** big decimal value (two-element array, base 2). */
    BIGDECIMAL                  = 5,
/** base64url encoding. */
    EXPECTED_BASE64_URL_ENCODED = 21,
/** base64 encoding. */
    EXPECTED_BASE64_ENCODED     = 22,
/** base16 encoding. */
    EXPECTED_BASE16_ENCODED     = 23,
/** encoded CBOR data item (byte string). */
    CBOR_ENCODED                = 24,
/** URL (UTF8 string). */
    URI                         = 32,
/** base64url encoded string (UTF8 string). */
    BASE64_URL_ENCODED          = 33,
/** base64 encoded string (UTF8 string). */
    BASE64_ENCODED              = 34,
/** regular expression string (UTF8 string, PCRE). */
    REGEXP                      = 35,
/** MIME message (UTF8 string, RFC2045). */
    MIME_MESSAGE                = 36
}

struct ElementHeader
{
    MajorType type;
    ulong     len;
    TAG       tag = TAG.NONE;
}


string toString(ElementHeader *el)
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


public void write_string(string vv, ref OutBuffer ou)
{
    write_header(MajorType.TEXT_STRING, vv.length, ou);
    ou.write(vv);
}

//public void write(T) (T[] arr, ref OutBuffer ou)
//{
//    write_header(MajorType.ARRAY, arr.length, ou);
//    foreach (value; arr)
//    {
//        write(value, ou);
//    }
//}

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


public int read_header(ubyte[] src, ElementHeader *header)
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
        d_pos      += read_header(src[ d_pos..$ ], &main_type_header);
        header.tag  = cast(TAG)ld;
        header.len  = main_type_header.len;
        header.type = main_type_header.type;
//      writeln ("HEADER:", header.toString());
    }
    else
    {
        if (ld > src.length)
        {
            writeln("%%%%%%%%%%%%%%%%%%%%%%%% ld=", ld);
            ld = src.length;
        }
        header.len  = ld;
        header.type = type;
    }
//    writeln ("type=", type, ", length=", ld, ", d_pos=", d_pos, ", src.length=", src.length);

    return d_pos;
}



