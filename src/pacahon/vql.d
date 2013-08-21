module pacahon.vql;

// VEDA QUERY LANG

private    
{
	import pacahon.vel;
	import std.string;
	import std.array;
	import std.stdio;
	import std.conv;
	import std.datetime;
	import std.json;
	import std.outbuffer;
	import std.c.string;
	import mongoc.bson_h;

	import trioplax.mongodb.TripleStorage;
	import pacahon.graph;
	import pacahon.oi;
	import pacahon.context;
}

class VQL
{
	const int RETURN = 0;
	const int FILTER = 1;
	const int SORT = 2;
	const int RENDER = 3;
	const int AUTHORIZE = 4;

	string[] sections = ["return", "filter", "sort", "render", "authorize"];
	bool[] section_is_found = [false, false, false, false, false];
	string[] found_sections;

	TripleStorage ts;
	OI from_search_point;

	this(TripleStorage _ts, OI _from_search_point = null)
	{
		ts = _ts;
		from_search_point = _from_search_point;
		found_sections = new string[5];
	}

	public void get(Ticket ticket, string query_str, ref GraphCluster res, Authorizer authorizer)
	{
		//writeln("VQL:get ticket=", ticket);

		StopWatch sw;
		sw.start();

		split_on_section(query_str);
		//		sw.stop();
		//		long t = cast(long) sw.peek().usecs;

		//writeln ("found_sections", found_sections);
		//		writeln("split:", t, " µs");

		TTA tta;

		tta = parse_expr(found_sections[FILTER]);

		int render = 10000;
		try
		{
			if (found_sections[RENDER] !is null && found_sections[RENDER].length > 0)
				render = parse!int (found_sections[RENDER]);
		} catch(Exception ex)
		{
		}

		int authorize = 1000;
		try
		{
			if (found_sections[AUTHORIZE] !is null && found_sections[AUTHORIZE].length > 0)
				authorize = parse!int (found_sections[AUTHORIZE]);
		} catch(Exception ex)
		{
		}

		if(section_is_found[SORT] == true && from_search_point !is null)
		{
			// если найдена секция sort, то запрос делаем к elasticsearch, далее данные в количестве render считываем из mongo 

			JSONValue full_query = void;
			full_query.type = JSON_TYPE.OBJECT;
			full_query.object = null;

			JSONValue f1 = void;
			f1.type = JSON_TYPE.STRING;
			f1.str = "_id";

			JSONValue fields = void;
			fields.type = JSON_TYPE.ARRAY;
			fields.array = null;
			fields.array ~= f1;

			JSONValue query = void;
			query.type = JSON_TYPE.OBJECT;
			query.object = null;

			full_query.object["fields"] = fields;

			JSONValue jv1 = void;
			toElasticJSON(tta, "", &query, &jv1, 0);
			full_query.object["query"] = query;

			writeln("full_query :", toJSON(&full_query));

		} else
		{
			bson query;
			bson_init(&query);

			_bson_append_start_object(&query, "$query");

			toMongoBSON(tta, "", &query, 0);

			bson_append_finish_object(&query);

			if(section_is_found[SORT] == true)
			{
				_bson_append_start_object(&query, "$orderby");

				foreach(field; split(found_sections[SORT], ","))
				{
					long bp = indexOf(field, '\'');
					long ep = lastIndexOf(field, '\'');
					long dp = lastIndexOf(field, " desc");

					if(ep > bp && ep - bp > 0)
					{
						string key = field[bp + 1 .. ep];

						if(dp > ep)
							_bson_append_int(&query, key, -1);
						else
							_bson_append_int(&query, key, 1);
					}
				}
				bson_append_finish_object(&query);
			}

			bson_finish(&query);

			//writeln("\n", tta, "\n");
			//writeln(toJSON(&jv));

			//		writeln("str render:[", found_sections[RENDER], "]");

			//		sw.stop();
			//		long t = cast(long) sw.peek().usecs;
			string[string] fields;

			string returns[];

			if(section_is_found[RETURN] == true)
			{
				returns = split(found_sections[RETURN], ",");

				foreach(field; returns)
				{
					long bp = indexOf(field, '\'');
					long ep = lastIndexOf(field, '\'');
					long rp = lastIndexOf(field, " reif");
					if(ep > bp && ep - bp > 0)
					{
						string key = field[bp + 1 .. ep];

						if(rp > ep)
							fields[key] = "reif";
						else
							fields[key] = "1";
					}
				}
			}

			sw.stop();
			long t = cast(long) sw.peek().usecs;

			//		writeln("convert to mongo query:", t, " µs");

			//		writeln (bson_to_string(&query));		

			//		writeln (fields);
			int offset = 0;

			ts.get(ticket, res, &query, fields, render, authorize, offset, authorizer);

			bson_destroy(&query);
		}
	}

	private void split_on_section(string query)
	{
		section_is_found[] = false;
		for(int pos = 0; pos < query.length; pos++)
		{
			char cc = query[pos];
			for(int i = 0; i < sections.length; i++)
			{
				if(section_is_found[i] == false)
				{
					int j = 0;
					int t_pos = pos;
					while(sections[i][j] == cc && t_pos < query.length && j < sections[i].length)
					{
						j++;
						t_pos++;

						if(t_pos >= query.length || j >= sections[i].length)
							break;

						cc = query[t_pos];
					}

					if(j == sections[i].length)
					{
						pos = t_pos;

						// нашли
						section_is_found[i] = true;

						while(query[pos] != '{' && pos < query.length)
							pos++;

						pos++;

						while(query[pos] == ' ' && pos < query.length)
							pos++;

						// {
						int bp = pos;

						while(query[pos] != '}' && pos < query.length)
							pos++;

						pos--;

						while(query[pos] == ' ' && pos > bp)
							pos--;

						int ep = pos + 1;

						found_sections[i] = query[bp .. ep];
					}
				}
			}
		}
	}
}

///////////////////////////////////////////////////////////////////////

public string toMongoBSON(TTA tta, string p_op, bson* val, int level)
{
	if(tta.op == "==")
	{
		if(level > 0)
			_bson_append_start_object(val, "");

		string ls = toMongoBSON(tta.L, tta.op, val, level + 1);
		string rs = toMongoBSON(tta.R, tta.op, val, level + 1);

		_bson_append_string(val, ls, rs);

		if(level > 0)
			bson_append_finish_object(val);

	} else if(tta.op == ">")
	{
		string ls = toMongoBSON(tta.L, tta.op, val, level + 1);
		string rs = toMongoBSON(tta.R, tta.op, val, level + 1);

		if(level > 0)
			_bson_append_start_object(val, "");

		_bson_append_start_object(val, ls);

		_bson_append_string(val, "$gt", rs);

		bson_append_finish_object(val);

		if(level > 0)
			bson_append_finish_object(val);
	} else if(tta.op == ">=")
	{
		string ls = toMongoBSON(tta.L, tta.op, val, level + 1);
		string rs = toMongoBSON(tta.R, tta.op, val, level + 1);

		if(level > 0)
			_bson_append_start_object(val, "");
		_bson_append_start_object(val, ls);

		_bson_append_string(val, "$gte", rs);

		bson_append_finish_object(val);

		if(level > 0)
			bson_append_finish_object(val);
	} else if(tta.op == "<")
	{
		string ls = toMongoBSON(tta.L, tta.op, val, level + 1);
		string rs = toMongoBSON(tta.R, tta.op, val, level + 1);

		if(level > 0)
			_bson_append_start_object(val, "");
		_bson_append_start_object(val, ls);

		_bson_append_string(val, "$lt", rs);

		bson_append_finish_object(val);
		if(level > 0)
			bson_append_finish_object(val);
	} else if(tta.op == ">=")
	{
		string ls = toMongoBSON(tta.L, tta.op, val, level + 1);
		string rs = toMongoBSON(tta.R, tta.op, val, level + 1);

		if(level > 0)
			_bson_append_start_object(val, "");
		_bson_append_start_object(val, ls);

		_bson_append_string(val, "$lte", rs);

		bson_append_finish_object(val);

		if(level > 0)
			bson_append_finish_object(val);
	} else if(tta.op == "!=")
	{
		string ls = toMongoBSON(tta.L, tta.op, val, level + 1);
		string rs = toMongoBSON(tta.R, tta.op, val, level + 1);

		if(level > 0)
			_bson_append_start_object(val, "");
		_bson_append_start_object(val, ls);

		_bson_append_string(val, "$ne", rs);

		bson_append_finish_object(val);
		if(level > 0)
			bson_append_finish_object(val);
	} else if(tta.op == "&&" || tta.op == "||")
	{
		if(p_op == tta.op)
		{
			if(tta.L !is null)
			{
				toMongoBSON(tta.L, tta.op, val, level + 1);
			}
			if(tta.R !is null)
			{
				toMongoBSON(tta.R, tta.op, val, level + 1);
			}

		} else
		{
			if(level > 0)
				_bson_append_start_object(val, "");

			if(tta.op == "&&")
				_bson_append_start_array(val, "$and");

			if(tta.op == "||")
				_bson_append_start_array(val, "$or");

			if(tta.L !is null)
				toMongoBSON(tta.L, tta.op, val, level + 1);

			if(tta.R !is null)
				toMongoBSON(tta.R, tta.op, val, level + 1);

			bson_append_finish_object(val);

			if(level > 0)
				bson_append_finish_object(val);
		}

	} else
	{
		return tta.op;
	}
	return null;
}

public void toElasticJSON(TTA tta, string p_op, JSONValue* val, JSONValue* p_val, int level)
{
	//		string _tab = "                                                                       ";
	//		string tab = _tab[0 .. level * 2];

	//	writeln (tab, "count:", count, " ,", op, ", prev:", p_op);

	if(tta.op == "==")
	{
		val.type = JSON_TYPE.OBJECT;

		JSONValue new_val_l = void;
		JSONValue new_val_r = void;

		toElasticJSON(tta.L, tta.op, &new_val_l, val, level + 1);
		toElasticJSON(tta.R, tta.op, &new_val_r, val, level + 1);

		val.object = null;
		val.object[new_val_l.str] = new_val_r;
	} else if(tta.op == "&&" || tta.op == "||")
	{
		if(p_op == tta.op)
		{
			if(tta.R !is null)
			{
				JSONValue new_val = void;
				new_val.type = JSON_TYPE.NULL;
				toElasticJSON(tta.R, tta.op, &new_val, p_val, level + 1);
				if(new_val.type != JSON_TYPE.NULL)
					p_val.array ~= new_val;
			}

			if(tta.L !is null)
			{
				JSONValue new_val = void;
				new_val.type = JSON_TYPE.NULL;
				toElasticJSON(tta.L, tta.op, &new_val, p_val, level + 1);
				if(new_val.type != JSON_TYPE.NULL)
					p_val.array ~= new_val;
			}

		} else
		{
			val.type = JSON_TYPE.OBJECT;
			val.object = null;

			JSONValue val1 = void;
			val1.type = JSON_TYPE.ARRAY;
			val1.array = null;

			if(tta.R !is null)
			{
				JSONValue new_val = void;
				new_val.type = JSON_TYPE.NULL;
				toElasticJSON(tta.R, tta.op, &new_val, &val1, level + 1);
				if(new_val.type != JSON_TYPE.NULL)
					val1.array ~= new_val;
			}

			if(tta.L !is null)
			{
				JSONValue new_val = void;
				new_val.type = JSON_TYPE.NULL;
				toElasticJSON(tta.L, tta.op, &new_val, &val1, level + 1);
				if(new_val.type != JSON_TYPE.NULL)
					val1.array ~= new_val;
			}

			if(tta.op == "&&")
				val.object["$and"] = val1;

			if(tta.op == "||")
				val.object["$or"] = val1;
		}
	} else
	{
		//	    writeln (tab,"#4");
		val.type = JSON_TYPE.STRING;
		val.str = tta.op;
	}

	//	writeln (tab,"#5");
	//	return val;
}
