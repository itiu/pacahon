module pacahon.utils;

private import std.file;
private import std.date;
private import std.json;
import core.stdc.stdio;
private import std.c.string;

char[] timeString(d_time t)
{
	// Years are supposed to be -285616 .. 285616, or 7 digits
	// "1996-02-24 02:04:57.2367"
	auto buffer = new char[25 + 7 + 1];

	if(t == d_time_nan)
		return cast(char[]) "Invalid Date";

	auto len = sprintf(buffer.ptr, "%4d-%02d-%02d %02d:%02d:%02d.%03d", yearFromTime(t), monthFromTime(t), dateFromTime(t),
			hourFromTime(t), minFromTime(t), secFromTime(t), msFromTime(t));

	// Ensure no buggy buffer overflows
	assert(len < buffer.length);

	return buffer[0 .. len];
}

JSONValue get_props(string file_name)
{
	JSONValue res;

	if(exists(file_name))
	{
		string buff = cast(string) read(file_name);

		res = parseJSON(buff);
	}
	else
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

char[] fromStringz(char* s)
{
	return s ? s[0 .. strlen(s)] : null;
}