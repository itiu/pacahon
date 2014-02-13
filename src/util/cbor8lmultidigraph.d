module util.cbor8lmultidigraph;

import std.outbuffer, std.stdio;

import util.cbor;
import util.lmultidigraph;

/*
struct Element
{
    MajorType type;
    TAG       tag = TAG.NONE;
    string    str;
    size_t    resource_idx;
}
*/
string dummy;

private static int read_element(LabeledMultiDigraph lmg, ubyte[] src, out string _key, size_t subject_idx = NONE,
                                size_t predicate_idx = NONE)
{
    int           pos;
    ElementHeader header;

    pos = read_header(src[ pos..$ ], &header);
//    writeln ("read_element:[", cast(string)src[0..pos+header.len], "],[", src[0..pos+header.len], "]");

//    writeln ("pos +-> ", pos);

    if (header.type == MajorType.MAP)
    {
//        writeln("IS MAP, length=", header.len, ", pos=", pos);
        size_t new_subject_idx = NONE;
        string key;
        pos += read_element(lmg, src[ pos..$ ], key);

        string val;
        pos += read_element(lmg, src[ pos..$ ], val);

        if (key == "@")
            new_subject_idx = lmg.addResource(val);

        foreach (i; 1 .. header.len)
        {
            pos += read_element(lmg, src[ pos..$ ], key);

            size_t new_predicate_idx = lmg.addResource(key);

            pos += read_element(lmg, src[ pos..$ ], dummy, new_subject_idx, new_predicate_idx);
        }
    }
    else if (header.type == MajorType.TEXT_STRING)
    {
//	writeln ("IS STRING, length=", header.len, ", pos=", pos);
        int    ep = cast(int)(pos + header.len);

        string str = cast(string)src[ pos..ep ].dup;
        _key = str;

        if (subject_idx != NONE && predicate_idx != NONE)
        {
//        	writeln ("*1");
            lmg.addEdge(subject_idx, predicate_idx, str);
//        	writeln ("*2");
        }    

        pos = ep;
    }
    else if (header.type == MajorType.ARRAY)
    {
//	writeln ("IS ARRAY, length=", header.len, ", pos=", pos);
        foreach (i; 0 .. header.len)
        {
            pos += read_element(lmg, src[ pos..$ ], dummy, subject_idx, predicate_idx);
        }
    }
    return pos;
}

/////////////////////////////////////////////////////////////////////////////////////
public void add_cbor_to_lmultidigraph(LabeledMultiDigraph lmg, string in_str)
{
    read_element(lmg, cast(ubyte[])in_str, dummy);
}

