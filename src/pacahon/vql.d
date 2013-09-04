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
	import util.Logger;	

	import trioplax.mongodb.TripleStorage;
	import pacahon.graph;
	import pacahon.vel;
	import pacahon.context;
	//import az.condition;
}

Logger log;

static this()
{
	log = new Logger("pacahon", "log", "VQL");
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

	static string ELASTIC_LIST_OK_HEADER = "200|OK|";

	public int get(Ticket ticket, string query_str, ref GraphCluster res, Authorizer authorizer)
	{
//		if (ticket !is null)
//		writeln ("userId=", ticket.userId);

		 //writeln("VQL:get ticket=", ticket, ", authorizer=", authorizer);

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

			// sort
			JSONValue qsort = void;
			qsort.type = JSON_TYPE.ARRAY;
			qsort.array = null;
								
			foreach(field; split(found_sections[SORT], ","))
			{
				long bp = indexOf(field, '\'');
				long ep = lastIndexOf(field, '\'');
				long dp = lastIndexOf(field, " desc");
			
				if(ep > bp && ep - bp > 0)
				{
					string key = field[bp + 1 .. ep];
					
					JSONValue s1 = void;
					s1.type = JSON_TYPE.STRING;
					if(dp > ep)
						s1.str = "desc";						
					else
						s1.str = "asc";											

					JSONValue vs1 = void;
					vs1.type = JSON_TYPE.OBJECT;
					vs1.object = null;
					vs1.object["order"] = s1;
					
					JSONValue vvs1 = void;
					vvs1.type = JSON_TYPE.OBJECT;
					vvs1.object = null;
					vvs1.object["doc1." ~ key] = vs1;
					
					qsort.array ~= vvs1;
				}	
			}
			full_query.object["sort"] = qsort;

			JSONValue _must = void;
			_must.type = JSON_TYPE.ARRAY;
			_must.array = null;

			JSONValue _filter = void;
			_filter.type = JSON_TYPE.ARRAY;
			_filter.array = null;

			string dummy;

			prepare_for_Elastic(tta, "", &_must, &_filter, dummy, dummy);
			
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
			
		 	if(trace_msg[71] == 1)
			 	log.trace("query to elastic:[%s]", elastic_query);

			from_search_point.send (elastic_query);
			string res_from_elastic = from_search_point.reciev();
			
			HashSet!Mandat mandats;		
			if(authorizer !is null && ticket !is null)
			{
				authorizer.get_mandats_4_whom(ticket, mandats);
				//writeln ("mandats=", mandats);
			}
			
			int pos = cast(int)ELASTIC_LIST_OK_HEADER.length;
			int count = 0;
			int read_count = 0;
			
			if (res_from_elastic !is null && res_from_elastic.length > 10 &&  res_from_elastic[0..ELASTIC_LIST_OK_HEADER.length] == "200|OK|")
			{
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

					if (id !is null && id.length > 3 && id.length < 52)
					{
					//	writeln ("[", id, "]");
					Subject ss = ts.get (ticket, id, authorizer, mandats);
					read_count++;
					
					remove_predicates (ss, fields);
										
					if (ss !is null)
					{
						res.addSubject (ss);
						count++;
					}
					}
				}
				pos++;  	
			}
			}
			return read_count;
			//writeln ("read count:", read_count, ", count:", count);			
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
			int read_count = ts.get(ticket, res, &query, render, authorize, offset, authorizer);
			bson_destroy(&query);
			
			foreach (ss ; res.getArray())
				remove_predicates (ss, fields);


			return read_count;
		}
	}

	private void remove_predicates (Subject ss, ref string[string] fields)
	{
		if (ss is null || ("*" in fields) !is null)
			return;
			
		// TODO возможно не оптимальная фильтрация	
		foreach (pp ; ss.getPredicates)
		{
//		writeln ("pp=", pp);
			if ((pp.predicate in fields) is null)
			{
				pp.count_objects = 0;
			}
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

public string prepare_for_Elastic(TTA tta, string prev_op, JSONValue* must, JSONValue* filter, out string l_token, out string op)
{	
	string dummy;
	if(tta.op == ">" || tta.op == "<")
	{		
		string ls = prepare_for_Elastic(tta.L, tta.op, must, filter, dummy, dummy);
		string rs = prepare_for_Elastic(tta.R, tta.op, must, filter, dummy, dummy);

		if (rs.length == 19 && rs[4] == '-' && rs[7] == '-' && rs[10] == 'T' && rs[13] == ':' && rs[16] == ':')
		{
			// это дата
			l_token = "doc1." ~ ls ~ ".dateTime";
			op = tta.op;
			return rs;
		}
		else
		{
			bool is_digit = false;
			try
			{
				auto b = parse!double(rs);
				is_digit = true;
			}
			catch (Exception ex)
			{
				
			}
			
//			bool is_digit = true;
//			foreach (rr ; rs)
//			{
//				if (isDigit (rr) == false)
//				{
//					is_digit = false;
//					break;	
//				}
//			}
			
			if (is_digit)
			{
				// это число
				l_token = "doc1." ~ ls ~ ".decimal";
				op = tta.op;
				return rs;				
			}
		}	
	} 
	else if(tta.op == "==")
	{
		string ls = prepare_for_Elastic(tta.L, tta.op, must, filter, dummy, dummy);
		string rs = prepare_for_Elastic(tta.R, tta.op, must, filter, dummy, dummy);		

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
		string t_op_l;
		string t_op_r;
		string token_L;
		string tta_R;		
		if(tta.R !is null)
			tta_R = prepare_for_Elastic(tta.R, tta.op, must, filter, token_L, t_op_r);

			if (t_op_r !is null)
				op = t_op_r;

		string tta_L;	
		if(tta.L !is null)
			tta_L = prepare_for_Elastic(tta.L, tta.op, must, filter, dummy, t_op_l);

			if (t_op_l !is null)
				op = t_op_l;
			
		if (token_L !is null && tta_L !is null)
		{	
		//writeln ("token_L=", token_L);	
		//writeln ("tta_R=", tta_R);	
		//writeln ("tta_L=", tta_L);	
		//writeln ("t_op_l=", t_op_l);	
		//writeln ("t_op_r=", t_op_r);	
		
		string c_to, c_from;
		
		if (t_op_r == ">")
			c_from = tta_R;
		if (t_op_r == "<")
			c_to = tta_R;

		if (t_op_l == ">")
			c_from = tta_L;
		if (t_op_l == "<")
			c_to = tta_L;
		
		JSONValue range = void;
		range.type = JSON_TYPE.OBJECT;
		range.object = null;

		JSONValue cond = void;
		cond.type = JSON_TYPE.OBJECT;
		cond.object = null;

		JSONValue delta = void;
		delta.type = JSON_TYPE.OBJECT;
		delta.object = null;

		JSONValue val_from = void;
		val_from.type = JSON_TYPE.STRING;
		val_from.str = c_from;								

		JSONValue val_to = void;
		val_to.type = JSON_TYPE.STRING;
		val_to.str = c_to;								

		delta.object["from"] = val_from; 
		delta.object["to"] = val_to; 

		cond.object[token_L] = delta;
			
		range.object["range"] = cond;

//		if (prev_op == "&&")
			must.array ~= range;
//		else if (prev_op == "||")
//			filter.array ~= term;
		
		}
		if (tta_R !is null && tta_L is null)		
		 return tta_R;
		 
		if (tta_L !is null && tta_R is null)		
		 return tta_L;
		 
		
	}
	else if (tta.op == "||")
	{
		if(tta.R !is null)
			prepare_for_Elastic(tta.R, tta.op, must, filter, dummy, dummy);

		if(tta.L !is null)
			prepare_for_Elastic(tta.L, tta.op, must, filter, dummy, dummy);
	}
	else
	{
		return tta.op;
	}
	return null;
}
