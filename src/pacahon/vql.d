module pacahon.vql;

// VEDA QUERY LANG

private    
{
	import std.string;
	import std.array;
	import std.stdio;
	import std.conv;
	import std.datetime;
	import std.json;
	import std.outbuffer;
	import std.c.string;
	import mongoc.bson_h;

	import ae.utils.container;
	import util.oi;

	import trioplax.mongodb.TripleStorage;
	import pacahon.graph;
	import pacahon.vel;
	import pacahon.context;
	import az.condition;
}

class VQL
{
	const int RETURN = 0;
	const int FILTER = 1;
	const int SORT = 2;
	const int RENDER = 3;
	const int AUTHORIZE = 4;

	private string[] sections = ["return", "filter", "sort", "render", "authorize"];
	private bool[] section_is_found = [false, false, false, false, false];
	private string[] found_sections;

	private TripleStorage ts;
	private OI from_search_point;

	this(TripleStorage _ts, OI _from_search_point = null)
	{
		ts = _ts;
		from_search_point = _from_search_point;
		found_sections = new string[5];
	}

	public void get(Ticket ticket, string query_str, ref GraphCluster res, Authorizer authorizer)
	{
		// writeln("VQL:get ticket=", ticket, ", authorizer=", authorizer);

		//StopWatch sw;
		//sw.start();

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

		int authorize = 10000;
		try
		{
			if (found_sections[AUTHORIZE] !is null && found_sections[AUTHORIZE].length > 0)
				authorize = parse!int (found_sections[AUTHORIZE]);
		} catch(Exception ex)
		{
		}

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

		if(section_is_found[SORT] == true && from_search_point !is null)
		{
			//writeln ("найдена секция SORT");
			// если найдена секция sort, то запрос делаем к elasticsearch, далее данные в количестве render считываем из mongo 
			//writeln ("SEARCH FROM ELASTIC");
			JSONValue full_query = void;
			full_query.type = JSON_TYPE.OBJECT;
			full_query.object = null;

			JSONValue f1 = void;
			f1.type = JSON_TYPE.STRING;
			f1.str = "_id";

			JSONValue qfields = void;
			qfields.type = JSON_TYPE.ARRAY;
			qfields.array = null;
			qfields.array ~= f1;

			JSONValue query = void;
			query.type = JSON_TYPE.OBJECT;
			query.object = null;

			full_query.object["fields"] = qfields;

			JSONValue s1 = void;
			s1.type = JSON_TYPE.STRING;
			s1.str = "asc";

			JSONValue vs1 = void;
			vs1.type = JSON_TYPE.OBJECT;
			vs1.object = null;
			vs1.object["order"] = s1;

			JSONValue vvs1 = void;
			vvs1.type = JSON_TYPE.OBJECT;
			vvs1.object = null;
			vvs1.object["doc1.dc:created.dateTime"] = vs1;
			
			JSONValue qsort = void;
			qsort.type = JSON_TYPE.ARRAY;
			qsort.array = null;
			qsort.array ~= vvs1;

			full_query.object["sort"] = qsort;

			JSONValue _must = void;
			_must.type = JSON_TYPE.ARRAY;
			_must.array = null;

			JSONValue _filter = void;
			_filter.type = JSON_TYPE.ARRAY;
			_filter.array = null;

			prepare_for_Elastic(tta, "", &_must, &_filter);
			
			JSONValue _bool = void;
			_bool.type = JSON_TYPE.OBJECT;
			_bool.object = null;


			_bool.object["must"] = _must; 

			query.object["bool"] = _bool; 

//			JSONValue jv1 = void;
//			toElasticJSON(tta, "", &query, &jv1, 0);
			full_query.object["query"] = query;
			
			JSONValue _size = void;
			_size.type = JSON_TYPE.STRING;
			_size.str = text(authorize);
			full_query.object["size"] = _size;

			string elastic_query = "GET_IDs|pacahon/doc1/_search|" ~ toJSON(&full_query); 
			//writeln("full_query :", elastic_query);
			
			from_search_point.send (elastic_query);
			string res_from_elastic = from_search_point.reciev();
			
			HashSet!Mandat mandats;		
			if(authorizer !is null && ticket !is null)
			{
				authorizer.get_mandats_4_whom(ticket, mandats);
				//writeln ("mandats=", mandats);
			}
			
			int pos = 0;
			int count=0;
			while (pos < res_from_elastic.length)
			{
				int b, e; 
				b = pos;
				while (pos < res_from_elastic.length && res_from_elastic[pos] != ',')
				  pos++;
				e = pos;
				  
				if (e-b > 2 && e-b < 64)
				{
					string id = res_from_elastic[b..e-1];
				
					Subject ss = ts.get (ticket, id, fields, authorizer, mandats);
					
					if (ss !is null)
					{
						res.addSubject (ss);
						count++;
					}
				}
				pos++;  	
			}
						
			//writeln("res_from_elastic :", res_from_elastic);
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

			//sw.stop();
			//long t = cast(long) sw.peek().usecs;

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

///////////////////////////////////////////////////////////////////////

public string prepare_for_Elastic(TTA tta, string prev_op, JSONValue* must, JSONValue* filter)
{
	if(tta.op == "==")
	{
		string ls = prepare_for_Elastic(tta.L, tta.op, must, filter);
		string rs = prepare_for_Elastic(tta.R, tta.op, must, filter);
		

		JSONValue term = void;
		term.type = JSON_TYPE.OBJECT;
		term.object = null;

		JSONValue cond = void;
		cond.type = JSON_TYPE.OBJECT;
		cond.object = null;

		JSONValue val = void;
		val.type = JSON_TYPE.STRING;
		val.str = rs;								

		cond.object[ls] = val;
			
		term.object["term"] = cond;

		if (prev_op == "&&")
			must.array ~= term;
		else if (prev_op == "||")
			filter.array ~= term;
	} 
	else if(tta.op == "&&")
	{
		if(tta.R !is null)
			prepare_for_Elastic(tta.R, tta.op, must, filter);

		if(tta.L !is null)
			prepare_for_Elastic(tta.L, tta.op, must, filter);
	}
	else if (tta.op == "||")
	{
		if(tta.R !is null)
			prepare_for_Elastic(tta.R, tta.op, must, filter);

		if(tta.L !is null)
			prepare_for_Elastic(tta.L, tta.op, must, filter);
	}
	else
	{
		return tta.op;
	}
	return null;
}
