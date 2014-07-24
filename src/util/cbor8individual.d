module util.cbor8individual;

private import std.outbuffer, std.stdio, std.string;
private import type;
private import onto.resource;
private import onto.individual;
private import onto.lang;
private import util.cbor;


string dummy;

private static int read_element(Individual *individual, ubyte[] src, out string _key, string subject_uri = null,
                                string predicate_uri = null)
{
    int           pos;
    ElementHeader header;

    pos = read_type_value(src[ 0..$ ], &header);
    //writeln ("read_element:[", cast(uint)src[0], " ", cast(uint)src[1], "]");
    //writeln ("#^read_element, header=", header); 
    //writeln ("read_element:[", cast(string)src[0..pos+header.len], "],[", src[0..pos+header.len], "]");

    if (header.type == MajorType.MAP)
    {
        //writeln("IS MAP, length=", header.len, ", pos=", pos);
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
            new_subject_uri = val;

            //writeln ("@ id:", val);
        }

        foreach (i; 1 .. header.v_long)
        {
            pos += read_element(individual, src[ pos..$ ], key);

            string new_predicate_uri = key;

            pos += read_element(individual, src[ pos..$ ], dummy, new_subject_uri, new_predicate_uri);
        }
    }
    else if (header.type == MajorType.TEXT_STRING)
    {
	//writeln ("IS STRING, length=", header.len, ", pos=", pos);
        int    ep = cast(int)(pos + header.v_long);

        string str = cast(string)src[ pos..ep ].dup;
        _key = str;

        //writeln ("[", str, "]");        
        
        if (subject_uri !is null && predicate_uri !is null)
        {
          //writeln ("*1");

            Resources resources = individual.resources.get(predicate_uri, Resources.init);

            if (header.tag == TAG.TEXT_RU)
                resources ~= Resource(DataType.String, str, LANG.RU);
            else if (header.tag == TAG.TEXT_EN)
                resources ~= Resource(DataType.String, str, LANG.EN);
            else if (header.tag == TAG.URI)
            {
                if (str.indexOf('/') > 0)
                    resources ~= Resource(str, ResourceOrigin.external);
                else
                    resources ~= Resource(str, ResourceOrigin.local);
            }
            else
                resources ~= Resource(DataType.String, str);

            individual.resources[ predicate_uri ] = resources;
        }

        pos = ep;
    }
    else if (header.type == MajorType.NEGATIVE_INTEGER)
    {
    	long value = header.v_long;
    	Resources resources = individual.resources.get(predicate_uri, Resources.init);
   		resources ~= Resource(value);
   		individual.resources[ predicate_uri ] = resources;
    }
    else if (header.type == MajorType.UNSIGNED_INTEGER)
    {
//   		writeln ("@p #read_element MajorType.UNSIGNED_INTEGER #0");	
    	long value = header.v_long;
    	Resources resources = individual.resources.get(predicate_uri, Resources.init);
    	
    	if (header.tag == TAG.EPOCH_DATE_TIME)
    	{
//    		writeln ("@p #read_element TAG.EPOCH_DATE_TIME value=", value);	
    		resources ~= Resource(DataType.Datetime, value);
    	}
    	else
    	{
    		resources ~= Resource(value);    		
    	}
        individual.resources[ predicate_uri ] = resources;
//   		writeln ("@p #read_element MajorType.UNSIGNED_INTEGER #end");	
    }
    else if (header.type == MajorType.FLOAT_SIMPLE)
    {
        Resources resources = individual.resources.get(predicate_uri, Resources.init);
        if (header.v_long == TRUE)
        {
            resources ~= Resource(true);
            individual.resources[ predicate_uri ] = resources;
        }
        else if (header.v_long == FALSE)
        {
            resources ~= Resource(false);
            individual.resources[ predicate_uri ] = resources;
        }
        else
        {        	
        }
    }
    else if (header.type == MajorType.ARRAY)
    {
    	
    	if (header.tag == TAG.DECIMAL_FRACTION)
    	{
    		Resources resources = individual.resources.get(predicate_uri, Resources.init);
    		
    		ElementHeader mantissa;
    		pos += read_type_value(src[ pos..$ ], &mantissa);
    		
    		ElementHeader exponent;    		
    		pos += read_type_value(src[ pos..$ ], &exponent);
    		    		    		    		
            resources ~= Resource(decimal (mantissa.v_long, exponent.v_long));
            individual.resources[ predicate_uri ] = resources;
    	}
    	else
    	{
    	    //writeln ("IS ARRAY, length=", header.len, ", pos=", pos);
			foreach (i; 0 .. header.v_long)
			{         
				pos += read_element(individual, src[ pos..$ ], dummy, subject_uri, predicate_uri);
			}
        }
    }
    else if (header.type == MajorType.TAG)
    {
	//writeln ("IS TAG, length=", header.len, ", pos=", pos);
    	
    }
    return pos;
}

private void write_individual(Individual *ii, ref OutBuffer ou)
{
    ulong     map_len = ii.resources.length + 1;
    MajorType type    = MajorType.MAP;

    write_type_value(type, map_len, ou);
    write_string("@", ou);
    write_string(ii.uri, ou);

    foreach (key, pp; ii.resources)
    {
        write_resources(key, pp, ou);
    }
}

private void write_resources(string uri, ref Resources vv, ref OutBuffer ou)
{
    write_string(uri, ou);
    if (vv.length > 1)
        write_type_value(MajorType.ARRAY, vv.length, ou);
    foreach (value; vv)
    {
        if (value.type == DataType.Uri)
        {
            write_type_value(MajorType.TAG, TAG.URI, ou);
            write_string(value.get!string, ou);
        }
        else if (value.type == DataType.Integer)
        {
            write_integer(value.get!long, ou);        	        	
        }
        else if (value.type == DataType.Datetime)
        {
            write_type_value(MajorType.TAG, TAG.EPOCH_DATE_TIME, ou);
            write_integer(value.get!long, ou);        	        	
        }
        else if (value.type == DataType.Decimal)
        {
            decimal x = value.get!decimal;
        	
            write_type_value(MajorType.TAG, TAG.DECIMAL_FRACTION, ou);
            write_type_value(MajorType.ARRAY, 2, ou);
            write_integer(x.mantissa, ou); 
            write_integer(x.exponent, ou);        	        	
        }
        else if (value.type == DataType.Boolean)
        {
            write_bool(value.get!bool, ou);
        }
        else
        {
            if (value.lang != LANG.NONE)
                write_type_value(MajorType.TAG, value.lang + 41, ou);
            write_string(value.get!string, ou);
        }
    }
}
/////////////////////////////////////////////////////////////////////////////////////
public void cbor2individual(Individual *individual, string in_str)
{
    read_element(individual, cast(ubyte[])in_str, dummy);
}

public string individual2cbor(Individual *in_obj)
{
    OutBuffer ou = new OutBuffer();

    write_individual(in_obj, ou);

    return ou.toString();
}
