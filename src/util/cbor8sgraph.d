module util.cbor8sgraph;

import std.outbuffer;
import util.cbor;
import onto.lang;
import onto.sgraph;
import pacahon.define;

struct Element
{
    MajorType type;
    TAG       tag = TAG.NONE;
    DataType  dest_type;
    union
    {
        string    str;
        bool      bl;
        Predicate pp;
        Subject   subject;
    }
}

private void write_subject(Subject ss, ref OutBuffer ou)
{
    ulong     map_len = ss.length + 1;
    MajorType type    = MajorType.MAP;

    write_header(type, map_len, ou);
    write_string("@", ou);
    write_string(ss.subject, ou);

    foreach (pp; ss)
    {
        write_predicate(pp, ou);
    }
}

private void write_predicate(Predicate vv, ref OutBuffer ou)
{
    write_string(vv.predicate, ou);
    if (vv.length > 1)
        write_header(MajorType.ARRAY, vv.length, ou);
    foreach (value; vv)
    {
        if (value.type == DataType.LinkSubject)
        {
            write_subject(value.subject, ou);
        }
        else if (value.type == DataType.Uri)
        {
            write_header(MajorType.TAG, TAG.URI, ou);
            write_string(value.literal, ou);
        }
        else if (value.type == DataType.Bool)
        {
            write_bool(value.literal, ou);
        }
        else
        {
            if (value.lang != LANG.NONE)
                write_header(MajorType.TAG, value.lang + 41, ou);
            write_string(value.literal, ou);
        }
    }
}

private static int read_element(ubyte[] src, Element *el, byte fields, Subject parent_subject)
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
//        writeln("IS MAP, length=", header.len, ", pos=", pos);
        foreach (i; 0 .. header.len)
        {
            Element key;
            pos += read_element(src[ pos..$ ], &key, fields, res1);
            Element val;
            pos += read_element(src[ pos..$ ], &val, fields, res1);
//            writeln ("*** key=", key.str, ", pos=", pos);
//            writeln ("*** val.type=", val.type);

            if (key.type == MajorType.TEXT_STRING)
            {
                if (key.str == "@")
                {
                    res1.subject = val.str;
                }
                else
                {
                    if (val.type == MajorType.ARRAY)
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
                    else if (val.type == MajorType.MAP)
                    {
                        res1.addPredicate(key.str, val.subject);
                    }
                    else if (val.type == MajorType.TEXT_STRING && val.str.length > 0)
                    {
                        if (fields == ALL || (fields == LINKS && is_link_on_subject(val.str) == true))
                        {
                            //writeln ("[", val.str, "], lang=", val.lang);
                            if (val.tag == TAG.NONE)
                            {
//                      writeln ("add as string:", key.str, " : ", val.str);
                                res1.addPredicate(key.str, val.str);
                            }
                            else if (val.tag == TAG.TEXT_RU || val.tag == TAG.TEXT_EN)
                                res1.addPredicate(key.str, val.str, cast(LANG)(el.tag - 41));
                            else if (val.tag == TAG.URI)
                            {
//                      writeln ("add as resource:", key.str, " : ", val.str);
                                res1.addResource(key.str, val.str);
                            }
                        }
                    }
                    else if (val.type == MajorType.FLOAT_SIMPLE && val.dest_type == DataType.Bool)
                    {
                        if (val.bl == true)
                            res1.addPredicate(key.str, "1", DataType.Bool);
                        else
                            res1.addPredicate(key.str, "0", DataType.Bool);
                    }
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
        el.tag = header.tag;

        pos = ep;
    }
    else if (header.type == MajorType.FLOAT_SIMPLE)
    {
        if (header.len == TRUE)
        {
            el.bl        = true;
            el.dest_type = DataType.Bool;
        }
        else if (header.len == FALSE)
        {
            el.bl        = false;
            el.dest_type = DataType.Bool;
        }
        else
        {
        }
    }
    else if (header.type == MajorType.ARRAY)
    {
//	writeln ("IS ARRAY, length=", header.len, ", pos=", pos);
        Predicate vals;
        foreach (i; 0 .. header.len)
        {
            Element arr_el;
            pos += read_element(src[ pos..$ ], &arr_el, fields, parent_subject);

            if (arr_el.type == MajorType.FLOAT_SIMPLE && arr_el.dest_type == DataType.Bool)
            {
                if (arr_el.bl == true)
                    vals.addLiteral("1", DataType.Bool);
                else
                    vals.addLiteral("0", DataType.Bool);
            }
            else if (arr_el.type == MajorType.TEXT_STRING)
            {
                if (fields == ALL || (fields == LINKS && is_link_on_subject(arr_el.str) == true))
                {
                    if (vals is null)
                        vals = new Predicate();

                    if (arr_el.tag == TAG.NONE)
                        vals.addLiteral(arr_el.str);
                    else if (arr_el.tag == TAG.TEXT_RU || arr_el.tag == TAG.TEXT_EN)
                        vals.addLiteral(arr_el.str, cast(LANG)(arr_el.tag - 41));
                    else if (arr_el.tag == TAG.URI)
                    {
//                      writeln ("#2 add as resource: ", arr_el.str);
                        vals.addLiteral(arr_el.str, DataType.String);
                    }
                }
            }
            else if (arr_el.type == MajorType.MAP)
            {
                if (vals is null)
                    vals = new Predicate();
                vals.addSubject(arr_el.subject);
            }
        }
        el.pp = vals;
    }
    return pos;
}

/////////////////////////////////////////////////////////////////////////////////////
public string subject2cbor(Subject in_obj)
{
//    writeln("encode_cbor #1, subject:", in_obj);
    OutBuffer ou = new OutBuffer();

    write_subject(in_obj, ou);

//	writeln ("encode_cbor #2 : ou:[", ou, "]");
    return ou.toString();
}


public Subject cbor2subject(string in_str, byte fields = ALL)
{
//    StopWatch sw;
//    sw.start();

    Element res;

    read_element(cast(ubyte[])in_str, &res, fields, null);

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

