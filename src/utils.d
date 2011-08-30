module pacahon.utils;

private import std.file;

private import std.datetime;

private import std.json_str;
private import core.stdc.stdio;
private import std.c.string;
private import std.c.linux.linux;

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

	if(exists(file_name))
	{
		char[] buff = cast(char[]) read(file_name);

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

		write(file_name, buff);
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