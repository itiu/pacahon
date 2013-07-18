module pacahon.vql;

private
{
	import std.string;
	import std.array;
	import std.stdio;
	import std.conv;
	import std.datetime;
	import std.json;
	import pacahon.graph;
	import trioplax.mongodb.TripleStorage;
	import std.outbuffer;
	import mongoc.bson_h;
	import std.c.string;
}

// filter
// "==", "!=" 
// "=*" : полнотекстовый поиск
// "=+" : полнотекстовый поиск в реификации
// "&&", "||", 
// ">", "<", ">=", "<=", 
// "->" : переход по ссылке на другой документ 

class stack(T)
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

bool delim(char c)
{
	return c == ' ';
}

string is_op(string c)
{
	//    writeln (c);

	if(c.length == 1)
	{
		if(c[0] == '>')
			return ">";
		if(c[0] == '<')
			return "<";
	} else if(c.length == 2)
	{
		if(c[0] == '>' && c[1] != '=')
			return ">";

		if(c[0] == '<' && c[1] != '=')
			return "<";

		if(c == ">=" || c == "<=" || c == "==" || c == "!=" || c == "=*" || c == "=+" || c == "->" || c == "||" || c == "&&")
			return c;
	}
	return null;
}

int priority(string op)
{
	if(op == "<" || op == "<=" || op == ">" || op == "=>")
		return 4;

	if(op == "==" || op == "!=" || op == "=*" || op == "=+" || op == "->")
		return 3;

	if(op == "&&")
		return 2;

	if(op == "||")
		return 1;

	return -1;
}

 void process_op (ref stack!TTA st, string op) 
 {
 TTA r = st.popBack();
 TTA l = st.popBack();
 //	writeln ("process_op:op[", op, "], L:", l, ", R:", r);
 switch (op) 
 {
 case "<":  st.pushBack (new TTA (op, l, r));  break;
 case ">":  st.pushBack (new TTA (op, l, r));  break;
 case "==":  st.pushBack (new TTA (op, l, r));  break;
 case "!=":  st.pushBack (new TTA (op, l, r));  break;
 case "=*":  st.pushBack (new TTA (op, l, r));  break;
 case "=+":  st.pushBack (new TTA (op, l, r));  break;
 case "->":  st.pushBack (new TTA (op, l, r));  break;
 case ">=":  st.pushBack (new TTA (op, l, r));  break;
 case "<=":  st.pushBack (new TTA (op, l, r));  break;
 case "||":  st.pushBack (new TTA (op, l, r));  break;
 case "&&":  st.pushBack (new TTA (op, l, r));  break;
 default:
 }
 }

//int g_count = 0;
class TTA
{
	string op;

	TTA L;
	TTA R;
	int count = 0;

	this(string _op, TTA _L, TTA _R)
	{
		op = _op;
		L = _L;
		R = _R;
		//	g_count ++;
		//	count = g_count;
	}

	override public string toString()
	{
		//	string res = "[" ~ text (count) ~ "]:{";
		string res = "{";

		if(L !is null)
			res ~= L.toString();

		res ~= op;

		if(R !is null)
			res ~= R.toString();

		return res ~ "}";
	}

	public string toMongoBSON(string p_op, bson* val, int level)
	{
		if(op == "==")
		{
			_bson_append_start_object(val, "");

			string ls = L.toMongoBSON(op, val, level + 1);
			string rs = R.toMongoBSON(op, val, level + 1);

			_bson_append_string(val, ls, rs);

			bson_append_finish_object(val);
		} else if(op == ">")
		{
			string ls = L.toMongoBSON(op, val, level + 1);
			string rs = R.toMongoBSON(op, val, level + 1);

			_bson_append_start_object(val, "");
			_bson_append_start_object(val, ls);

			_bson_append_string(val, "$gt", rs);

			bson_append_finish_object(val);
			bson_append_finish_object(val);
		} else if(op == ">=")
		{
			string ls = L.toMongoBSON(op, val, level + 1);
			string rs = R.toMongoBSON(op, val, level + 1);

			_bson_append_start_object(val, "");
			_bson_append_start_object(val, ls);

			_bson_append_string(val, "$gte", rs);

			bson_append_finish_object(val);
			bson_append_finish_object(val);
		} else if(op == "<")
		{
			string ls = L.toMongoBSON(op, val, level + 1);
			string rs = R.toMongoBSON(op, val, level + 1);

			_bson_append_start_object(val, "");
			_bson_append_start_object(val, ls);

			_bson_append_string(val, "$lt", rs);

			bson_append_finish_object(val);
			bson_append_finish_object(val);
		} else if(op == ">=")
		{
			string ls = L.toMongoBSON(op, val, level + 1);
			string rs = R.toMongoBSON(op, val, level + 1);

			_bson_append_start_object(val, "");
			_bson_append_start_object(val, ls);

			_bson_append_string(val, "$lte", rs);

			bson_append_finish_object(val);
			bson_append_finish_object(val);
		} else if(op == "!=")
		{
			string ls = L.toMongoBSON(op, val, level + 1);
			string rs = R.toMongoBSON(op, val, level + 1);

			_bson_append_start_object(val, "");
			_bson_append_start_object(val, ls);

			_bson_append_string(val, "$ne", rs);

			bson_append_finish_object(val);
			bson_append_finish_object(val);
		} else if(op == "&&" || op == "||")
		{
			if(p_op == op)
			{
				if(L !is null)
				{
					L.toMongoBSON(op, val, level + 1);
				}
				if(R !is null)
				{
					R.toMongoBSON(op, val, level + 1);
				}

			} else
			{
				if(op == "&&")
					_bson_append_start_array(val, "$and");

				if(op == "||")
					_bson_append_start_array(val, "$or");

				if(L !is null)
				{
					L.toMongoBSON(op, val, level + 1);
				}
				if(R !is null)
				{
					R.toMongoBSON(op, val, level + 1);
				}

				bson_append_finish_object(val);
			}

		} else
		{
			return op;
		}
		return null;
	}

	public void toMongoJSON(string p_op, JSONValue* val, JSONValue* p_val, int level)
	{
		//		string _tab = "                                                                       ";
		//		string tab = _tab[0 .. level * 2];

		//	writeln (tab, "count:", count, " ,", op, ", prev:", p_op);

		if(op == "==")
		{
			val.type = JSON_TYPE.OBJECT;

			JSONValue new_val_l = void;
			JSONValue new_val_r = void;

			L.toMongoJSON(op, &new_val_l, val, level + 1);
			R.toMongoJSON(op, &new_val_r, val, level + 1);

			val.object = null;
			val.object[new_val_l.str] = new_val_r;
		} else if(op == "&&" || op == "||")
		{
			if(p_op == op)
			{
				if(R !is null)
				{
					JSONValue new_val = void;
					new_val.type = JSON_TYPE.NULL;
					R.toMongoJSON(op, &new_val, p_val, level + 1);

					if(new_val.type != JSON_TYPE.NULL)
						p_val.array ~= new_val;

				}

				if(L !is null)
				{
					JSONValue new_val = void;
					new_val.type = JSON_TYPE.NULL;
					L.toMongoJSON(op, &new_val, p_val, level + 1);
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

				if(R !is null)
				{
					JSONValue new_val = void;
					new_val.type = JSON_TYPE.NULL;
					R.toMongoJSON(op, &new_val, &val1, level + 1);
					if(new_val.type != JSON_TYPE.NULL)
						val1.array ~= new_val;
				}

				if(L !is null)
				{
					JSONValue new_val = void;
					new_val.type = JSON_TYPE.NULL;
					L.toMongoJSON(op, &new_val, &val1, level + 1);
					if(new_val.type != JSON_TYPE.NULL)
						val1.array ~= new_val;
				}

				if(op == "&&")
					val.object["$and"] = val1;

				if(op == "||")
					val.object["$or"] = val1;
			}
		} else
		{
			//	    writeln (tab,"#4");
			val.type = JSON_TYPE.STRING;
			val.str = op;
		}

		//	writeln (tab,"#5");
		//	return val;
	}

}

TTA parse_filter(string s)
{
	stack!TTA st = new stack!TTA();
	stack!string op = new stack!string();
	//	writeln("s=", s);

	for(int i = 0; i < s.length; i++)
	{
		if(!delim(s[i]))
		{
			//	writeln("s[", i, "]:", s[i]);
			if(s[i] == '(')
				op.pushBack("(");
			else if(s[i] == ')')
			{

				while(op.back() != "(")
					process_op(st, op.popBack());
				op.popBack();
			} else
			{
				int e = i + 2;
				if(e > s.length)
					e = cast(int) (s.length - 1);

				string curop = is_op(s[i .. e]);
				if(curop !is null)
				{
					//				writeln ("	curop:", curop);
					while(!op.empty() && priority(op.back()) >= priority(curop))
						process_op(st, op.popBack());
					op.pushBack(curop);
					i += curop.length - 1;
				} else
				{
					string operand;

					while(i < s.length && s[i] == ' ')
						i++;

					if(s[i] == '\'')
					{
						i++;
						int bp = i;

						while(i < s.length && s[i] != '\'')
							i++;

						operand = s[bp .. i];
						//				    writeln ("	operand=", operand);

						st.pushBack(new TTA(operand, null, null));
					} else if(s[i] == '[')
					{
						i++;
						int bp = i;

						while(i < s.length && s[i] != ']')
							i++;

						operand = s[bp .. i];
						//				    writeln ("	operand=", operand);

						st.pushBack(new TTA(operand, null, null));
					}

				}
			}
		}
	}
	while(!op.empty())
		process_op(st, op.popBack());

	return st.back();
}

class VQL
{
	const int RETURN = 0;
	const int FILTER = 1;
	const int SORT = 2;
	const int RENDER = 3;

	string[] sections = ["return", "filter", "sort", "render"];
	bool[] section_is_found = [false, false, false, false];
	string[] found_sections;

	TripleStorage ts;

	this(TripleStorage _ts)
	{
		ts = _ts;

		found_sections = new string[4];
	}

	public void get(string query_str, ref GraphCluster res, bool function(ref string id) authorizer)
	{
		//		writeln("VQL:get");

		StopWatch sw;
		sw.start();

		split_on_section(query_str);
		//		sw.stop();
		//		long t = cast(long) sw.peek().usecs;

		//writeln ("found_sections", found_sections);
		//		writeln("split:", t, " µs");

		TTA tta;

		//			sw.reset();			
		//			sw.start();

		tta = parse_filter(found_sections[FILTER]);

		//			sw.stop();
		//			t = cast(long) sw.peek().usecs;

		//			writeln("parse:", t, " µs");

		//			sw.reset();
		//			sw.start();
		//		JSONValue jv = void;
		//		jv.type = JSON_TYPE.OBJECT;
		//		jv.object = null;

		//		JSONValue jv1 = void;
		//		tta.toMongoJSON("", &jv, &jv1, 0);

		bson query;
		bson_init(&query);

		_bson_append_start_object(&query, "$query");

		tta.toMongoBSON("", &query, 0);

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

		int render = 100;

		try
		{
			if (found_sections[RENDER] !is null && found_sections[RENDER].length > 0)
				render = parse!int (found_sections[RENDER]);
		} catch(Exception ex)
		{
		}

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

		ts.get(res, &query, fields, render, authorizer);

		bson_destroy(&query);
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
