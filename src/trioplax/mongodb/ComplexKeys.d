module trioplax.mongodb.ComplexKeys;

import std.string;
import std.stdio;

private import util.Logger;

Logger log;

static this()
{
	log = new Logger("trioplax", "log", "");
}

class FKeys
{
	// необходимо учитывать, что данный клас не хранит содержимое ключей

	string key1 = null;
	string key2 = null;
	string key3 = null;
	string key4 = null;

	byte count = 0;

	this(string _key1, string _key2 = null, string _key3 = null, string _key4 = null)
	{
		assert(_key1);

		key1 = _key1;

		count = 1;

		if(_key2 !is null)
			key2 = _key2;
		else
			return;
		count = 2;

		if(_key3 !is null)
			key3 = _key3;
		else
			return;
		count = 3;

		if(_key4 !is null)
			key4 = _key4;
		else
			return;
		count = 4;
	}

	override bool opEquals(Object o)
	{
		bool res = false;
		FKeys f = cast(FKeys) o;

		// сравним по ссылкам

		if(count > 0)
			res = (key1.ptr == f.key1.ptr);

		if(res == true && count > 1)
			res = (key2.ptr == f.key2.ptr);

		if(res == true && count > 2)
			res = (key3.ptr == f.key3.ptr);

		if(res == true && count > 3)
			res = (key4.ptr == f.key4.ptr);

		if(res == true)
			return true;

		if(count > 0)
			res = (std.string.cmp(key1, f.key1) == 0);

		if(res == true && count > 1)
			res = (std.string.cmp(key2, f.key2) == 0);

		if(res == true && count > 2)
			res = (std.string.cmp(key3, f.key3) == 0);

		if(res == true && count > 3)
			res = (std.string.cmp(key4, f.key4) == 0);

		return res;
	}

	override int opCmp(Object o)
	{
		bool res;

		FKeys f = cast(FKeys) o;

		if(count > 0)
			res = (key1.ptr == f.key1.ptr);

		if(res == true && count > 1)
			res = (key2.ptr == f.key2.ptr);

		if(res == true && count > 2)
			res = (key3.ptr == f.key3.ptr);

		if(res == true && count > 3)
			res = (key4.ptr == f.key4.ptr);

		if(res == true)
			return 0;

		int tres = 0;

		if(count > 0)
			tres += std.string.cmp(key1, f.key1);

		if(res == 0 && count > 1)
			tres += std.string.cmp(key2, f.key2);

		if(res == 0 && count > 2)
			tres += std.string.cmp(key3, f.key3);

		if(res == 0 && count > 3)
			tres += std.string.cmp(key4, f.key4);

		return tres;
	}

	override string toString()
	{
		return cast(string) ("{" ~ key1 ~ "}{" ~ key2 ~ "}{" ~ key3 ~ "}{" ~ key4 ~ "}");
	}

	override hash_t toHash()
	{
		hash_t hash;

		foreach(char c; key1)
			hash = (hash * 9) + c;

		hash_t hh = 0;

		if(count > 0 && key1 !is null)
		{
			foreach(char c; key1)
				hash = (hash * 9) + c;
		}

		if(count > 1 && key2 !is null)
		{
			foreach(char c; key2)
				hash = (hash * 9) + c;
		}

		if(count > 2 && key3 !is null)
		{
			foreach(char c; key3)
				hash = (hash * 9) + c;
		}

		if(count > 3 && key4 !is null)
		{
			foreach(char c; key4)
				hash = (hash * 9) + c;
		}

		return hash;
	}
}
