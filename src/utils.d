module pacahon.utils;

private import std.file;

version(dmd2_052)
{
	private import std.datetime;
}
else
{
	private import std.date;
}

private import std.json;
private import core.stdc.stdio;
private import std.c.string;
private import std.c.linux.linux;

string getNowAsString()
{
	version(dmd2_052)
	{
		SysTime sysTime = Clock.currTime(UTC());
		immutable dt = cast(DateTime) sysTime;

		int year = dt.year;
		int month = dt.month;
		int day = dt.day;
		int hour = dt.hour;
		int minute = dt.minute;
		int second = dt.second;
		int milliseconds = cast(ushort) sysTime.fracSec.msecs;
	}
	else
	{
		auto now = getUTCtime();

		int tt = time(null);
		tm* ptm = localtime(&tt);

		int year = ptm.tm_year + 1900;
		int month = ptm.tm_mon + 1;
		int day = ptm.tm_mday;
		int hour = ptm.tm_hour;
		int minute = ptm.tm_min;
		int second = ptm.tm_sec;
		int milliseconds = msFromTime(now);

		if(now == d_time_nan)
			return "Invalid Date";
	}

	auto buffer = new char[25 + 7 + 1];
	auto len = sprintf(buffer.ptr, "%4d-%02d-%02d %02d:%02d:%02d.%03d", year, month, day, hour, minute, second, milliseconds);

	// Ensure no buggy buffer overflows
	assert(len < buffer.length);

	return cast(immutable) buffer[0 .. len];
}

version(dmd2_052)
{
	string timeToString(SysTime sysTime)
	{
		immutable dt = cast(DateTime) sysTime;

		int year = dt.year;
		int month = dt.month;
		int day = dt.day;
		int hour = dt.hour;
		int minute = dt.minute;
		int second = dt.second;
		int milliseconds = cast(ushort) sysTime.fracSec.msecs;

		auto buffer = new char[25 + 7 + 1];
		auto len = sprintf(buffer.ptr, "%4d-%02d-%02d %02d:%02d:%02d.%03d", year, month, day, hour, minute, second, milliseconds);

		// Ensure no buggy buffer overflows
		assert(len < buffer.length);

		return cast(immutable) buffer[0 .. len];
	}
	
	long stringToTime(char* str)
	{
		long t;

		int year = (str[0] - 48) * 1000 + (str[1] - 48) * 100 + (str[2] - 48) * 10 + (str[3] - 48);
		int month = (str[5] - 48) * 10 + (str[6] - 48) - 1;
		int dayofmonth = (str[8] - 48) * 10 + (str[9] - 48);
		int hour = (str[11] - 48) * 10 + (str[12] - 48);
		int minute = (str[14] - 48) * 10 + (str[15] - 48);
		int second = (str[17] - 48) * 10 + (str[18] - 48);
		int mseconds = (str[20] - 48) * 100 + (str[21] - 48) * 10 + (str[22] - 48);

//		t = std.date.makeDate(std.date.makeDay(year, month, dayofmonth), std.date.makeTime(hour, minute, second, mseconds));

		return t;
	}
	
}
else
{
	string timeToString(long t)
	{
		// Years are supposed to be -285616 .. 285616, or 7 digits
		// "1996-02-24 02:04:57.2367"
		auto buffer = new char[25 + 7 + 1];

		if(t == d_time_nan)
			return "Invalid Date";

		auto len = sprintf(buffer.ptr, "%4d-%02d-%02d %02d:%02d:%02d.%03d", yearFromTime(t), monthFromTime(t), dateFromTime(t),
				hourFromTime(t), minFromTime(t), secFromTime(t), msFromTime(t));

		// Ensure no buggy buffer overflows
		assert(len < buffer.length);

		return cast(immutable)buffer[0 .. len];
	}

	d_time stringToTime(char* str)
	{
		d_time t;

		int year = (str[0] - 48) * 1000 + (str[1] - 48) * 100 + (str[2] - 48) * 10 + (str[3] - 48);
		int month = (str[5] - 48) * 10 + (str[6] - 48) - 1;
		int dayofmonth = (str[8] - 48) * 10 + (str[9] - 48);
		int hour = (str[11] - 48) * 10 + (str[12] - 48);
		int minute = (str[14] - 48) * 10 + (str[15] - 48);
		int second = (str[17] - 48) * 10 + (str[18] - 48);
		int mseconds = (str[20] - 48) * 100 + (str[21] - 48) * 10 + (str[22] - 48);

		t = std.date.makeDate(std.date.makeDay(year, month, dayofmonth), std.date.makeTime(hour, minute, second, mseconds));

		return t;
	}

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

string fromStringz(char* s)
{
	return cast(immutable) (s ? s[0 .. strlen(s)] : null);
}

string fromStringz(char* s, int len)
{
	return cast(immutable) (s ? s[0 .. len] : null);
}