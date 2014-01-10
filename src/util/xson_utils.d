module util.xson_utils;

private
{
    import std.stdio;
    import std.outbuffer;
    
    import util.container;	
    import util.utils;
    
    import pacahon.know_predicates;    
}

public string BSON_2_json(string bson, byte fields = ALL)
{
	OutBuffer outbuff = new OutBuffer;
	outbuff.write ("\n{");
    prepare_bson_element_for_json(bson, outbuff, 4, 0, 0, fields);
	outbuff.write ("\n}");
    return outbuff.toString;
}

private static int prepare_bson_element_for_json(string bson, ref OutBuffer outbuff, int pos, byte parent_type, int level, byte fields)
{
//	send_request_on_find = 0;

    //writeln ("fromBSON #1 bson.len=", bson.length);
    while (pos < bson.length)
    {
        byte type = bson[ pos ];
			//writeln ("fromBSON:type=", type);
        pos++;

        if (type == 0x02 || type == 0x03 || type == 0x04)
        {        	
            int bp = pos;
            while (bson[ pos ] != 0)
                pos++;

            string key = bson[ bp..pos ];
            //writeln ("key=`", bson[bp..pos], "`");
            
           	if (key != "0" && outbuff.data.length > 10)
           		outbuff.write (", ");

            pos++;

            bp = pos;
            int len = int_from_buff(bson, pos);
            //writeln ("LEN:", len);

            if (len > bson.length)
            {
                writeln("!@!#!@#!@%#$@!&% len > bson.length, len=", len, ", bson.length=", bson.length);
            }


            if (type == 0x03)
            {
                //writeln ("*1:key=", key);
                pos += 4;

				outbuff.write ("\n{\"");
				outbuff.write (key);
				outbuff.write ("\" : {");

                //writeln ("		!!!!!!!!! read subject of metadata, len=", len, ", pos=", pos, ", bson.len=", bson.length);
                pos += prepare_bson_element_for_json(bson[ pos..pos + len ], outbuff, 4, type, level + 1, fields);
               	outbuff.write ('}');
                //writeln ("		!!!!!!!! ok, len=", len);
            }
            else
            if (type == 0x02)
            {
                bp = pos + 4;
                if (bp + len > bson.length)
                    len = cast(int)bson.length - bp;

                //writeln ("LEN2:", len);
                string val  = bson[ bp..bp + len - 1];

//						print_dump (bp+len, bson);
               	LANG   lang = LANG.NONE;

                if (parent_type != 0x04)
                {
						outbuff.write ("\n\"");
						outbuff.write (key);
						outbuff.write ("\" : ");                	
                }                

                if (parent_type != 0x03)
                {
					//	writeln ("#0 level:", level, ", ooz=", ooz);
                    if (fields == ALL ||
                        (fields == LINKS && (key == "@" || is_link_on_subject(val))) ||
                        fields == TYPE)
                    {
                    	lang = cast(LANG)bson[ bp + len - 1];
//                    	writeln ("lang:", cast(byte)bson[bp+len-1]);
                    	
//                        if (level == 0)
//                        {
//                            ooz = new Set!string;
//                            ooz.resize(1);
//                        }

//                        *ooz ~= val;
						outbuff.write ('"');
						outbuff.write (val);
						
						if (lang == LANG.RU)
							outbuff.write ("@ru");						
						if (lang == LANG.EN)
							outbuff.write ("@en");
												
						outbuff.write ('"');
						
//                        if (level == 0)
//                        {
					//writeln ("val:", val);
//                            res[ key ] = ooz;
//                        }    
                    }
                }
                
                //writeln (bson[bp..bp+len]);
                pos = bp + len + 1;
            }
            else if (type == 0x04)
            {
                pos += 4;

				outbuff.write ("\n\"");
				outbuff.write (key);
				outbuff.write ("\" : ");
               	outbuff.write ('[');
               	
                pos += prepare_bson_element_for_json(bson[ pos..pos + len ], outbuff, 0, type, level + 1, fields);
//                if ((*inner_ooz).size > 0)
 //                   res[ key ] = inner_ooz;
               	outbuff.write (']');

                if (level == 0 && fields == TYPE && key == rdf__type)
                    return 0;
            }
                        
        }
    }

    return pos;
}


public Set!string *[ string ] get_subject_from_BSON(string bson, byte fields = ALL)
{
    Set!string *[ string ] out_set;
    Set!string * ooz = new Set!string;
    ooz.resize(1);
    prepare_bson_element_for_subject(bson, out_set, 4, ooz, 0, 0, fields);
    return out_set;
}

private static int prepare_bson_element_for_subject(string bson, ref Set!string *[ string ] res, int pos, Set!string *ooz, byte parent_type, int level, byte fields)
{
//	send_request_on_find = 0;

    //writeln ("fromBSON #1 bson.len=", bson.length);
    while (pos < bson.length)
    {
        byte type = bson[ pos ];
//			writeln ("fromBSON:type", type);
        pos++;

        if (type == 0x02 || type == 0x03 || type == 0x04)
        {
            int bp = pos;
            while (bson[ pos ] != 0)
                pos++;

            string key = bson[ bp..pos ];
            //writeln ("key=`", bson[bp..pos], "`");
            pos++;

            bp = pos;
            int len = int_from_buff(bson, pos);
            //writeln ("LEN:", len);

            if (len > bson.length)
            {
                writeln("!@!#!@#!@%#$@!&% len > bson.length, len=", len, ", bson.length=", bson.length);
            }


            if (type == 0x03)
            {
                //writeln ("*1:key=", key);
                pos += 4;

                //writeln ("		!!!!!!!!! read subject of metadata, len=", len, ", pos=", pos, ", bson.len=", bson.length);
                pos += prepare_bson_element_for_subject(bson[ pos..pos + len ], res, 4, ooz, type, level + 1, fields);
                //writeln ("		!!!!!!!! ok, len=", len);
            }
            else
            if (type == 0x02)
            {
                bp = pos + 4;
                if (bp + len > bson.length)
                    len = cast(int)bson.length - bp;

                //writeln ("LEN2:", len);
                string val  = bson[ bp..bp + len - 1];
                byte   lang = bson[ bp + len ];

//						print_dump (bp+len, bson);

//					writeln ("lang:", cast(byte)bson[bp+len+2]);

                if (parent_type != 0x03)
                {
					//	writeln ("#0 level:", level, ", ooz=", ooz);

                    if (fields == ALL ||
                        (fields == LINKS && (key == "@" || is_link_on_subject(val))) ||
                        fields == TYPE)
                    {
                        if (level == 0)
                        {
                            ooz = new Set!string;
                            ooz.resize(1);
                        }

                        *ooz ~= val;

                        if (level == 0)
                        {
					//writeln ("val:", val);
                            res[ key ] = ooz;
                        }    
                    }
                }

                //writeln (bson[bp..bp+len]);
                pos = bp + len + 1;
            }
            else if (type == 0x04)
            {
                pos                   += 4;
                Set!string * inner_ooz = new Set!string;
                inner_ooz.resize(4);

                pos += prepare_bson_element_for_subject(bson[ pos..pos + len ], res, 0, inner_ooz, type, level + 1, fields);
                if ((*inner_ooz).size > 0)
                    res[ key ] = inner_ooz;

                if (level == 0 && fields == TYPE && key == rdf__type)
                    return 0;
            }
        }
    }

    return pos;
}

public int int_from_buff(string buff, int pos)
{
    int res = buff[ pos + 0 ] + ((cast(uint)buff[ pos + 1 ]) << 8) + ((cast(uint)buff[ pos + 2 ]) << 16) + ((cast(uint)buff[ pos + 3 ]) << 24);

    return res;
}

public void int_to_buff(ref ubyte[] buff, int pos, int dd)
{
    ubyte *value_length_ptr = cast(ubyte *)&dd;

    buff[ pos + 0 ] = *(value_length_ptr + 0);
    buff[ pos + 1 ] = *(value_length_ptr + 1);
    buff[ pos + 2 ] = *(value_length_ptr + 2);
    buff[ pos + 3 ] = *(value_length_ptr + 3);
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

