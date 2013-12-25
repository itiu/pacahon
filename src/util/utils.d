module util.utils;

private
{
    import core.stdc.stdio;
    import std.file;
    import std.datetime;
    import std.json;
    import std.c.string;
    import std.c.linux.linux;
    import std.format;
    import std.stdio;
    import std.conv;
    import std.string;
    import std.outbuffer;
    import std.concurrency;
    import std.ascii;

    import util.container;
    import pacahon.know_predicates;
    import pacahon.context;
}


string getNowAsString()
{
    SysTime sysTime = Clock.currTime();

    return sysTime.toISOExtString();
}

string timeToString(long tm)
{
    SysTime sysTime = SysTime(tm);

    return sysTime.toISOExtString();
}

string timeToString(SysTime sysTime)
{
    return sysTime.toISOExtString();
}

long stringToTime(string str)
{
    try
    {
        if (str.length == 28)
        {
            str = str[ 0..23 ];
        }

        SysTime st = SysTime.fromISOExtString(str);
        return st.stdTime;
    }
    catch (Exception ex)
    {
        return 0;
    }
}

public JSONValue get_props(string file_name)
{
    JSONValue res;

    if (std.file.exists(file_name))
    {
        char[] buff = cast(char[])std.file.read(file_name);

        res = parseJSON(buff);
    }
    else
    {
        res.type = JSON_TYPE.OBJECT;

        JSONValue listeners;
        listeners.type = JSON_TYPE.ARRAY;

        JSONValue transport;
        transport.type = JSON_TYPE.OBJECT;        
        JSONValue point;
        point.str                   = "tcp://*:5559";
        transport.object[ "point" ] = point;
        JSONValue tt;
        tt.str                          = "zmq";
        transport.object[ "transport" ] = tt;
        listeners.array ~= transport;
        
        JSONValue transport1;
        transport1.type = JSON_TYPE.OBJECT;        
        JSONValue tt1;
        tt1.str                          = "file_reader";
        transport1.object[ "transport" ] = tt1;
        listeners.array ~= transport1;

        res.object[ "listeners" ] = listeners;

        string buff = toJSON(&res);

        std.file.write(file_name, buff);
    }

    return res;
}

string fromStringz(char *s)
{
    return cast(string)(s ? s[ 0 .. strlen(s) ] : null);
}

string fromStringz(char *s, int len)
{
    return cast(string)(s ? s[ 0 .. len ] : null);
}

public string generateMsgId()
{
    SysTime sysTime = Clock.currTime(UTC());
    long    tm      = sysTime.stdTime;

    return "msg:M" ~ text(tm);
}

// !!! stupid, but quickly
void formattedWrite(Writer, Char, A) (Writer w, in Char[] fmt, A[] args)
{
    if (args.length == 1)
    {
        std.format.formattedWrite(w, fmt, args[ 0 ]);
        return;
    }
    else if (args.length == 2)
    {
        std.format.formattedWrite(w, fmt, args[ 0 ], args[ 1 ]);
        return;
    }
    else if (args.length == 3)
    {
        std.format.formattedWrite(w, fmt, args[ 0 ], args[ 1 ], args[ 2 ]);
        return;
    }
    else if (args.length == 4)
    {
        std.format.formattedWrite(w, fmt, args[ 0 ], args[ 1 ], args[ 2 ], args[ 3 ]);
        return;
    }
    else if (args.length == 5)
    {
        std.format.formattedWrite(w, fmt, args[ 0 ], args[ 1 ], args[ 2 ], args[ 3 ], args[ 4 ]);
        return;
    }
    else if (args.length == 6)
    {
        std.format.formattedWrite(w, fmt, args[ 0 ], args[ 1 ], args[ 2 ], args[ 3 ], args[ 4 ], args[ 5 ]);
        return;
    }
    else if (args.length == 7)
    {
        std.format.formattedWrite(w, fmt, args[ 0 ], args[ 1 ], args[ 2 ], args[ 3 ], args[ 4 ], args[ 5 ], args[ 6 ]);
        return;
    }
    else if (args.length == 8)
    {
        std.format.formattedWrite(w, fmt, args[ 0 ], args[ 1 ], args[ 2 ], args[ 3 ], args[ 4 ], args[ 5 ], args[ 6 ], args[ 7 ]);
        return;
    }
    else if (args.length == 9)
    {
        std.format.formattedWrite(w, fmt, args[ 0 ], args[ 1 ], args[ 2 ], args[ 3 ], args[ 4 ], args[ 5 ], args[ 6 ], args[ 7 ], args[ 8 ]);
        return;
    }
    else if (args.length == 10)
    {
        std.format.formattedWrite(w, fmt, args[ 0 ], args[ 1 ], args[ 2 ], args[ 3 ], args[ 4 ], args[ 5 ], args[ 6 ], args[ 7 ], args[ 8 ],
                                  args[ 9 ]);
        return;
    }
    else if (args.length == 11)
    {
        std.format.formattedWrite(w, fmt, args[ 0 ], args[ 1 ], args[ 2 ], args[ 3 ], args[ 4 ], args[ 5 ], args[ 6 ], args[ 7 ], args[ 8 ],
                                  args[ 9 ], args[ 10 ]);
        return;
    }
    else if (args.length == 12)
    {
        std.format.formattedWrite(w, fmt, args[ 0 ], args[ 1 ], args[ 2 ], args[ 3 ], args[ 4 ], args[ 5 ], args[ 6 ], args[ 7 ], args[ 8 ],
                                  args[ 9 ], args[ 10 ], args[ 11 ]);
        return;
    }
    else if (args.length == 13)
    {
        std.format.formattedWrite(w, fmt, args[ 0 ], args[ 1 ], args[ 2 ], args[ 3 ], args[ 4 ], args[ 5 ], args[ 6 ], args[ 7 ], args[ 8 ],
                                  args[ 9 ], args[ 10 ], args[ 11 ], args[ 12 ]);
        return;
    }
    else if (args.length == 14)
    {
        std.format.formattedWrite(w, fmt, args[ 0 ], args[ 1 ], args[ 2 ], args[ 3 ], args[ 4 ], args[ 5 ], args[ 6 ], args[ 7 ], args[ 8 ],
                                  args[ 9 ], args[ 10 ], args[ 11 ], args[ 12 ], args[ 13 ]);
        return;
    }
    else if (args.length == 15)
    {
        std.format.formattedWrite(w, fmt, args[ 0 ], args[ 1 ], args[ 2 ], args[ 3 ], args[ 4 ], args[ 5 ], args[ 6 ], args[ 7 ], args[ 8 ],
                                  args[ 9 ], args[ 10 ], args[ 11 ], args[ 12 ], args[ 13 ], args[ 14 ]);
        return;
    }
    else if (args.length == 16)
    {
        std.format.formattedWrite(w, fmt, args[ 0 ], args[ 1 ], args[ 2 ], args[ 3 ], args[ 4 ], args[ 5 ], args[ 6 ], args[ 7 ], args[ 8 ],
                                  args[ 9 ], args[ 10 ], args[ 11 ], args[ 12 ], args[ 13 ], args[ 14 ], args[ 15 ]);
        return;
    }

    throw new Exception("util.formattedWrite (), count args > 16");
}

private static string[ dchar ] translit_table;

static this()
{
    translit_table =
    [
        '№':"N", ',':"_", '-':"_", ' ':"_", 'А':"A", 'Б':"B", 'В':"V", 'Г':"G", 'Д':"D", 'Е':"E", 'Ё':"E",
        'Ж':"ZH", 'З':"Z", 'И':"I", 'Й':"I", 'К':"K", 'Л':"L", 'М':"M", 'Н':"N", 'О':"O", 'П':"P", 'Р':"R",
        'С':"S", 'Т':"T", 'У':"U", 'Ф':"F", 'Х':"H", 'Ц':"C", 'Ч':"CH", 'Ш':"SH", 'Щ':"SH", 'Ъ':"'", 'Ы':"Y",
        'Ь':"'", 'Э':"E", 'Ю':"U", 'Я':"YA", 'а':"a", 'б':"b", 'в':"v", 'г':"g", 'д':"d", 'е':"e", 'ё':"e",
        'ж':"zh", 'з':"z", 'и':"i", 'й':"i", 'к':"k", 'л':"l", 'м':"m", 'н':"n", 'о':"o", 'п':"p", 'р':"r",
        'с':"s", 'т':"t", 'у':"u", 'ф':"f", 'х':"h", 'ц':"c", 'ч':"ch", 'ш':"sh", 'щ':"sh", 'ъ':"_", 'ы':"y",
        'ь':"_", 'э':"e", 'ю':"u", 'я':"ya"
    ];
}

/**
 * Переводит русский текст в транслит. В результирующей строке каждая
 * русская буква будет заменена на соответствующую английскую. Не русские
 * символы останутся прежними.
 *
 * @param text
 *            исходный текст с русскими символами
 * @return результат
 */
public static string toTranslit(string text)
{
    return translate(text, translit_table);
}

public JSONValue[] get_array(JSONValue jv, string field_name)
{
    if (field_name in jv.object)
    {
        return jv.object[ field_name ].array;
    }
    return null;
}

public string get_str(JSONValue jv, string field_name)
{
    if (field_name in jv.object)
    {
        return jv.object[ field_name ].str;
    }
    return null;
}

public long get_int(JSONValue jv, string field_name)
{
    if (field_name in jv.object)
    {
        return jv.object[ field_name ].integer;
    }
    return 0;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////

public tm *get_local_time()
{
    time_t rawtime;
    tm     *timeinfo;

    time(&rawtime);
    timeinfo = localtime(&rawtime);

    return timeinfo;
}

public string get_year(tm *timeinfo)
{
    return text(timeinfo.tm_year + 1900);
}

public string get_month(tm *timeinfo)
{
    if (timeinfo.tm_mon < 9)
        return "0" ~ text(timeinfo.tm_mon + 1);
    else
        return text(timeinfo.tm_mon + 1);
}

public string get_day(tm *timeinfo)
{
    if (timeinfo.tm_mday < 10)
        return "0" ~ text(timeinfo.tm_mday);
    else
        return text(timeinfo.tm_mday);
}

public int cmp_date_with_tm(string date, tm *timeinfo)
{
    string today_y = get_year(timeinfo);
    string today_m = get_month(timeinfo);
    string today_d = get_day(timeinfo);

    for (int i = 0; i < 4; i++)
    {
        if (date[ i + 6 ] > today_y[ i ])
        {
            return 1;
        }
        else if (date[ i + 6 ] < today_y[ i ])
        {
            return -1;
        }
    }

    for (int i = 0; i < 2; i++)
    {
        if (date[ i + 3 ] > today_m[ i ])
        {
            return 1;
        }
        else if (date[ i + 3 ] < today_m[ i ])
        {
            return -1;
        }
    }

    for (int i = 0; i < 2; i++)
    {
        if (date[ i ] > today_d[ i ])
        {
            return 1;
        }
        else if (date[ i ] < today_d[ i ])
        {
            return -1;
        }
    }

    return 0;
}

public bool is_today_in_interval(string from, string to)
{
    tm *timeinfo = get_local_time();

    if (from !is null && from.length == 10 && cmp_date_with_tm(from, timeinfo) > 0)
        return false;

    if (to !is null && to.length == 10 && cmp_date_with_tm(to, timeinfo) < 0)
        return false;

    return true;
}

public class stack(T)
{
    T[] data;
    int pos;

    this()
    {
        data = new T[ 100 ];
        pos  = 0;
    }

    T back()
    {
        //		writeln("stack:back:pos=", pos, ", data=", data[pos]);
        return data[ pos ];
    }

    T popBack()
    {
        if (pos > 0)
        {
            //			writeln("stack:popBack:pos=", pos, ", data=", data[pos]);
            pos--;
            return data[ pos + 1 ];
        }
        return data[ pos ];
    }

    void pushBack(T val)
    {
        //		writeln("stack:pushBack:pos=", pos, ", val=", val);
        pos++;
        data[ pos ] = val;
    }

    bool empty()
    {
        return pos == 0;
    }
}

string _tmp_correct_link(string link)
{
    // TODO убрать корректировки ссылок в organization: временная коррекция ссылок
    char[] sscc = link.dup;
    if (sscc[ 7 ] == '_')
        sscc = sscc[ 8..$ ];
    else if (sscc[ 8 ] == '_')
        sscc = sscc[ 9..$ ];
    return cast(string)sscc;
}

string to_lower_and_replace_delimeters(string in_text)
{
	if (in_text is null || in_text.length == 0)
		return in_text;
		
	char[] out_text = new char[in_text.length];
	
	for (int i = 0; i < in_text.length; i++)
	{
		char cc = in_text[i];
		if (cc == ':' || cc == ' ' || cc == '-')
			out_text[i] = '_';
		else
			out_text[i] = std.ascii.toLower (cc);
	}	
		
    return cast(immutable)out_text;
}

string escaping_or_uuid2search(string in_text)
{
    OutBuffer outbuff = new OutBuffer();

    escaping_or_uuid2search(in_text, outbuff);
    return outbuff.toString;
}

void escaping_or_uuid2search(string in_text, ref OutBuffer outbuff)
{
    int  count_s = 0;

    bool need_prepare = false;
    bool is_uuid      = false;

    int  idx = 0;

    foreach (ch; in_text)
    {
        if (ch == '-')
        {
            count_s++;
            if (count_s == 4 && in_text.length > 36 && in_text.length < 48)
            {
                is_uuid      = true;
                need_prepare = true;
                break;
            }
        }
        if (ch == '"' || ch == '\n' || ch == '\\' || ch == '\t' || (ch == ':' && idx < 5))
        {
            need_prepare = true;
//			break;
        }
        idx++;
    }

    bool fix_uuid_2_doc = false;

    // TODO: временная корректировка ссылок в org
    if (is_uuid == true)
    {
        if (in_text[ 0 ] == 'z' && in_text[ 1 ] == 'd' && in_text[ 2 ] == 'b' && in_text[ 3 ] == ':' && ((in_text[ 4 ] == 'd' && in_text[ 5 ] == 'e' && in_text[ 6 ] == 'p') || (in_text[ 4 ] == 'o' && in_text[ 5 ] == 'r' && in_text[ 6 ] == 'g')))
            fix_uuid_2_doc = true;
    }

    if (need_prepare)
    {
        int len = cast(uint)in_text.length;

        for (int i = 0; i < len; i++)
        {
            if (i >= len)
                break;

            char ch = in_text[ i ];

            if ((ch == '"' || ch == '\\'))
            {
                outbuff.write('\\');
                outbuff.write(ch);
            }
            else if (ch == '\n')
            {
                outbuff.write("\\n");
            }
            else if (ch == '\t')
            {
                outbuff.write("\\t");
            }
            else
            {
                if ((ch == '-' && is_uuid == true) || ch == ':')
                    outbuff.write('_');
                else
                {
                    if (fix_uuid_2_doc)
                    {
                        if (i == 4)
                            outbuff.write('d');
                        else if (i == 5)
                            outbuff.write('o');
                        else if (i == 6)
                            outbuff.write('c');
                        else
                            outbuff.write(ch);
                    }
                    else
                        outbuff.write(ch);
                }
            }
        }
    }
    else
    {
        outbuff.write(in_text);
    }
}

//////////////////////////////////////////////////////////////////////////////
void print_2(ref Set!string *[ string ] res)
{
    writeln("***");
    foreach (key; res.keys)
    {
        writeln(key, ":");
        Set!string * ss = res[ key ];
        foreach (aa; ss.items)
        {
            writeln("	", aa);
        }
    }
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

enum : byte
{
    TYPE  = 1,
    LINKS = 2,
    ALL   = 4
}

Set!string *[ string ] get_subject_from_BSON(string bson, byte fields = ALL)
{
    Set!string *[ string ] out_set;
    Set!string * ooz = new Set!string;
    ooz.resize(1);
    prepare_bson_element(bson, out_set, 4, ooz, 0, 0, fields);
    return out_set;
}

private static int prepare_bson_element(string bson, ref Set!string *[ string ] res, int pos, Set!string *ooz, byte parent_type, int level, byte fields)
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
                pos += prepare_bson_element(bson[ pos..pos + len ], res, 4, ooz, type, level + 1, fields);
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

                pos += prepare_bson_element(bson[ pos..pos + len ], res, 0, inner_ooz, type, level + 1, fields);
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
