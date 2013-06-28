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
	translit_table = ['№' : "N", '-': "_", ' ': "_", 'А': "A", 'Б': "B", 'В': "V", 'Г': "G", 'Д': "D", 'Е': "E", 'Ё': "E", 'Ж': "ZH", 'З': "Z", 'И': "I", 'Й': "I",
			'К': "K", 'Л': "L", 'М': "M", 'Н': "N", 'О': "O", 'П': "P", 'Р': "R", 'С': "S", 'Т': "T", 'У': "U", 'Ф': "F",
			'Х': "H", 'Ц': "C", 'Ч': "CH", 'Ш': "SH", 'Щ': "SH", 'Ъ': "'", 'Ы': "Y", 'Ь': "'", 'Э': "E", 'Ю': "U", 'Я': "YA",
			'а': "a", 'б': "b", 'в': "v", 'г': "g", 'д': "d", 'е': "e", 'ё': "e", 'ж': "zh", 'з': "z", 'и': "i", 'й': "i",
			'к': "k", 'л': "l", 'м': "m", 'н': "n", 'о': "o", 'п': "p", 'р': "r", 'с': "s", 'т': "t", 'у': "u", 'ф': "f",
			'х': "h", 'ц': "c", 'ч': "ch", 'ш': "sh", 'щ': "sh", 'ъ': "_", 'ы': "y", 'ь': "_", 'э': "e", 'ю': "u", 'я': "ya"];
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
