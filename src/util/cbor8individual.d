module util.cbor8individual;

private import std.outbuffer, std.stdio, std.string;
private import onto.resource;
private import onto.individual;
private import util.cbor;
private import util.lmultidigraph;

string dummy;

private static int read_element(Individual *individual, ubyte[] src, out string _key, string subject_uri = null,
                                string predicate_uri = null)
{
    int           pos;
    ElementHeader header;

    pos = read_header(src[ pos..$ ], &header);
//    writeln ("read_element:[", cast(string)src[0..pos+header.len], "],[", src[0..pos+header.len], "]");

    if (header.type == MajorType.MAP)
    {
//        writeln("IS MAP, length=", header.len, ", pos=", pos);
        string new_subject_uri;
        string key;
        pos += read_element(individual, src[ pos..$ ], key);

        string val;
        pos += read_element(individual, src[ pos..$ ], val);

        if (key == "@")
        {
            if (subject_uri !is null)
            {
                Individual new_individual = Individual();
                individual = &new_individual;
            }
            individual.uri = val.dup;
//              new_subject_uri = lmg.addEdge(subject_uri, predicate_uri, val);
//             else
            new_subject_uri = val;

//            writeln ("@ id:", val, ", idx=", new_subject_idx);
        }

        foreach (i; 1 .. header.len)
        {
            pos += read_element(individual, src[ pos..$ ], key);

            string new_predicate_uri = key;

            pos += read_element(individual, src[ pos..$ ], dummy, new_subject_uri, new_predicate_uri);
        }
    }
    else if (header.type == MajorType.TEXT_STRING)
    {
//	writeln ("IS STRING, length=", header.len, ", pos=", pos);
        int    ep = cast(int)(pos + header.len);

        string str = cast(string)src[ pos..ep ].dup;
        _key = str;

        if (subject_uri !is null && predicate_uri !is null)
        {
//          writeln ("*1");

            Resources resources = individual.resources.get(predicate_uri, Resources.init);

            if (header.tag == TAG.TEXT_RU)
                resources ~= Resource(ResourceType.String, str, LANG.RU);
            else if (header.tag == TAG.TEXT_EN)
                resources ~= Resource(ResourceType.String, str, LANG.EN);
            else if (header.tag == TAG.URI)
            {
            	if (str.indexOf ('/') > 0)
            		resources ~= Resource(str, ResourceOrigin.external);
            	else
            		resources ~= Resource(str, ResourceOrigin.local);            		
            }    
            else
                resources ~= Resource(ResourceType.String, str);

            individual.resources[ predicate_uri ] = resources;
        }

        pos = ep;
    }
    else if (header.type == MajorType.ARRAY)
    {
//	writeln ("IS ARRAY, length=", header.len, ", pos=", pos);
        foreach (i; 0 .. header.len)
        {
            pos += read_element(individual, src[ pos..$ ], dummy, subject_uri, predicate_uri);
        }
    }
    return pos;
}

/////////////////////////////////////////////////////////////////////////////////////
public void cbor_to_individual(Individual *individual, string in_str)
{
    read_element(individual, cast(ubyte[])in_str, dummy);
}

