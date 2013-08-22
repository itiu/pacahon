module util.utils;

private import std.file;

private import std.datetime;

private import std.json;
private import core.stdc.stdio;
private import std.c.string;
private import std.c.linux.linux;

private import std.format;
private import std.stdio;
private import std.conv;
private import std.string;

string getNowAsString()
{
	SysTime sysTime = Clock.currTime();
	return sysTime.toISOExtString();
}

string timeToString(SysTime sysTime)
{
	return sysTime.toISOExtString();
}

long stringToTime(string str)
{
	SysTime st = SysTime.fromISOExtString(str);
	return st.stdTime;
}

JSONValue get_props(string file_name)
{
	JSONValue res;

	if(std.file.exists(file_name))
	{
		char[] buff = cast(char[]) std.file.read(file_name);

		res = parseJSON(buff);
	} else
	{
		res.type = JSON_TYPE.OBJECT;

		JSONValue element1;
		element1.str = "tcp://127.0.0.1:5555";
		res.object["zmq_point"] = element1;

		JSONValue element2;
		element2.str = "127.0.0.1";
		res.object["mongodb_server"] = element2;

		JSONValue element3;
		element3.type = JSON_TYPE.INTEGER;
		element3.integer = 27017;
		res.object["mongodb_port"] = element3;

		JSONValue element4;
		element4.str = "pacahon";
		res.object["mongodb_collection"] = element4;

		string buff = toJSON(&res);

		std.file.write(file_name, buff);
	}

	return res;
}

string fromStringz(char* s)
{
	return cast(string) (s ? s[0 .. strlen(s)] : null);
}

string fromStringz(char* s, int len)
{
	return cast(string) (s ? s[0 .. len] : null);
}

public string generateMsgId()
{
	SysTime sysTime = Clock.currTime(UTC());
	long tm = sysTime.stdTime;

	return "msg:M" ~ text(tm);
}

// !!! stupid, but quickly
void formattedWrite(Writer, Char, A)(Writer w, in Char[] fmt, A[] args)
{
	if(args.length == 1)
	{
		std.format.formattedWrite(w, fmt, args[0]);
		return;
	} else if(args.length == 2)
	{
		std.format.formattedWrite(w, fmt, args[0], args[1]);
		return;
	} else if(args.length == 3)
	{
		std.format.formattedWrite(w, fmt, args[0], args[1], args[2]);
		return;
	} else if(args.length == 4)
	{
		std.format.formattedWrite(w, fmt, args[0], args[1], args[2], args[3]);
		return;
	} else if(args.length == 5)
	{
		std.format.formattedWrite(w, fmt, args[0], args[1], args[2], args[3], args[4]);
		return;
	} else if(args.length == 6)
	{
		std.format.formattedWrite(w, fmt, args[0], args[1], args[2], args[3], args[4], args[5]);
		return;
	} else if(args.length == 7)
	{
		std.format.formattedWrite(w, fmt, args[0], args[1], args[2], args[3], args[4], args[5], args[6]);
		return;
	} else if(args.length == 8)
	{
		std.format.formattedWrite(w, fmt, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]);
		return;
	} else if(args.length == 9)
	{
		std.format.formattedWrite(w, fmt, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]);
		return;
	} else if(args.length == 10)
	{
		std.format.formattedWrite(w, fmt, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8],
				args[9]);
		return;
	} else if(args.length == 11)
	{
		std.format.formattedWrite(w, fmt, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8],
				args[9], args[10]);
		return;
	} else if(args.length == 12)
	{
		std.format.formattedWrite(w, fmt, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8],
				args[9], args[10], args[11]);
		return;
	} else if(args.length == 13)
	{
		std.format.formattedWrite(w, fmt, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8],
				args[9], args[10], args[11], args[12]);
		return;
	} else if(args.length == 14)
	{
		std.format.formattedWrite(w, fmt, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8],
				args[9], args[10], args[11], args[12], args[13]);
		return;
	} else if(args.length == 15)
	{
		std.format.formattedWrite(w, fmt, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8],
				args[9], args[10], args[11], args[12], args[13], args[14]);
		return;
	} else if(args.length == 16)
	{
		std.format.formattedWrite(w, fmt, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8],
				args[9], args[10], args[11], args[12], args[13], args[14], args[15]);
		return;
	}

	throw new Exception("util.formattedWrite (), count args > 16");
}

private static string[dchar] translit_table;

static this()
{
	translit_table = ['№': "N", '-': "_", ' ': "_", 'А': "A", 'Б': "B", 'В': "V", 'Г': "G", 'Д': "D", 'Е': "E", 'Ё': "E",
			'Ж': "ZH", 'З': "Z", 'И': "I", 'Й': "I", 'К': "K", 'Л': "L", 'М': "M", 'Н': "N", 'О': "O", 'П': "P", 'Р': "R",
			'С': "S", 'Т': "T", 'У': "U", 'Ф': "F", 'Х': "H", 'Ц': "C", 'Ч': "CH", 'Ш': "SH", 'Щ': "SH", 'Ъ': "'", 'Ы': "Y",
			'Ь': "'", 'Э': "E", 'Ю': "U", 'Я': "YA", 'а': "a", 'б': "b", 'в': "v", 'г': "g", 'д': "d", 'е': "e", 'ё': "e",
			'ж': "zh", 'з': "z", 'и': "i", 'й': "i", 'к': "k", 'л': "l", 'м': "m", 'н': "n", 'о': "o", 'п': "p", 'р': "r",
			'с': "s", 'т': "t", 'у': "u", 'ф': "f", 'х': "h", 'ц': "c", 'ч': "ch", 'ш': "sh", 'щ': "sh", 'ъ': "_", 'ы': "y",
			'ь': "_", 'э': "e", 'ю': "u", 'я': "ya"];
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

public string get_str(JSONValue jv, string field_name)
{
	if(field_name in jv.object)
	{
		return jv.object[field_name].str;
	}
	return null;
}

public long get_int(JSONValue jv, string field_name)
{
	if(field_name in jv.object)
	{
		return jv.object[field_name].integer;
	}
	return 0;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////

public tm* get_local_time()
{
	time_t rawtime;
	tm* timeinfo;

	time(&rawtime);
	timeinfo = localtime(&rawtime);

	return timeinfo;
}

public string get_year(tm* timeinfo)
{
	return text(timeinfo.tm_year + 1900);
}

public string get_month(tm* timeinfo)
{
	if(timeinfo.tm_mon < 9)
		return "0" ~ text(timeinfo.tm_mon + 1);
	else
		return text(timeinfo.tm_mon + 1);
}

public string get_day(tm* timeinfo)
{
	if(timeinfo.tm_mday < 10)
		return "0" ~ text(timeinfo.tm_mday);
	else
		return text(timeinfo.tm_mday);
}

public int cmp_date_with_tm(string date, tm* timeinfo)
{
	string today_y = get_year(timeinfo);
	string today_m = get_month(timeinfo);
	string today_d = get_day(timeinfo);

	for(int i = 0; i < 4; i++)
	{
		if(date[i + 6] > today_y[i])
		{
			return 1;
		} else if(date[i + 6] < today_y[i])
		{
			return -1;
		}
	}

	for(int i = 0; i < 2; i++)
	{
		if(date[i + 3] > today_m[i])
		{
			return 1;
		} else if(date[i + 3] < today_m[i])
		{
			return -1;
		}
	}

	for(int i = 0; i < 2; i++)
	{
		if(date[i] > today_d[i])
		{
			return 1;
		} else if(date[i] < today_d[i])
		{
			return -1;
		}
	}

	return 0;
}

public bool is_today_in_interval(string from, string to)
{
	tm* timeinfo = get_local_time();

	if(from !is null && from.length == 10 && cmp_date_with_tm(from, timeinfo) > 0)
		return false;

	if(to !is null && to.length == 10 && cmp_date_with_tm(to, timeinfo) < 0)
		return false;

	return true;
}

public class stack(T)
{

	T[] data;
	int pos;

	this()
	{
		data = new T[100];
		pos = 0;
	}

	T back()
	{
		//		writeln("stack:back:pos=", pos, ", data=", data[pos]);
		return data[pos];
	}

	T popBack()
	{
		if(pos > 0)
		{
			//			writeln("stack:popBack:pos=", pos, ", data=", data[pos]);
			pos--;
			return data[pos + 1];
		}
		return data[pos];
	}

	void pushBack(T val)
	{
		//		writeln("stack:pushBack:pos=", pos, ", val=", val);
		pos++;
		data[pos] = val;
	}

	bool empty()
	{
		return pos == 0;
	}

}

string _tmp_correct_link (string link)
{
     // TODO убрать корректировки ссылок в organization: временная коррекция ссылок
      char[] sscc = link.dup;
      if(sscc[7] == '_')
        sscc = sscc[8..$];
      else if(sscc[8] == '_')
        sscc = sscc[9..$];
        return cast(string)sscc;
}

