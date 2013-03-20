// TODO сделать серилизацию кластера фактов
module pacahon.json_ld.parser;

private import std.stdio;
private import std.datetime;
private import std.json_str;
private import std.outbuffer;

private import pacahon.graph;

private import util.Logger;

Logger log;

static this()
{
	log = new Logger("pacahon", "log", "pacahon.json_ld.parser");
}

void prepare_node(JSONValue node, GraphCluster gcl, Subject ss = null)
{
	if(node.type == JSON_TYPE.OBJECT)
	{
		if(ss is null)
			ss = new Subject;

		for(int i = 0; i < node.object.keys.length; i++)
		{
			string key = node.object.keys[i];

			if(key == "#")
				continue; // определение контекстов опустим, пока в этом нет необходимости

			if(key == "@")
			{
				ss.subject = node.object.values[i].str;
				//										writeln("SUBJECT = ", ss.subject);
				gcl.addSubject(ss);
			} else
			{
				JSONValue element = node.object.values[i];

				//				writeln(element.type, ":key= ", key);

				//	if(element.type == JSON_TYPE.STRING)
				//	writeln(" element value=", element.str);
				addElement(key, element, gcl, ss);
			}
		}
	} else if(JSON_TYPE.ARRAY)
	{
		foreach(element; node.array)
		{
			prepare_node(element, gcl);
		}
	}
}

void addElement(string key, JSONValue element, GraphCluster gcl, Subject ss = null)
{
	if(element.type == JSON_TYPE.OBJECT)
	{
		// TODO переделать: неверное определение, будет это кластер или единичный субьект
		if(("@" in element.object) is null)
		{
			Subject ss_in = new Subject;
			prepare_node(element, gcl, ss_in);
			ss.addPredicate(key, ss_in);
		} else
		{
			GraphCluster inner_gcl = new GraphCluster;
			prepare_node(element, inner_gcl);
			ss.addPredicate(key, inner_gcl);
		}
	} else if(element.type == JSON_TYPE.STRING)
	{
		string val = element.str;

		if(val !is null && val.length > 12 && val[val.length - 12] == '^' && val[val.length - 7] == ':' && val[val.length - 6] == 's')
		{
			// очень вероятно что окончание строки содержит ^^xsd:string
			val = val[0 .. val.length - 12];
		}

		if(val !is null)
		{
			if(val.length >= 3 && val[val.length - 3] == '@')
			{
				if(val[val.length - 2] == 'r' && val[val.length - 1] == 'u')
					ss.addPredicate(key, val[0 .. val.length - 3], LITERAL_LANG.RU);
				else if(val[val.length - 2] == 'e' && val[val.length - 1] == 'n')
					ss.addPredicate(key, val[0 .. val.length - 3], LITERAL_LANG.EN);
			} else
			{
				ss.addPredicate(key, val);
			}
		}
		else
		{
			ss.addPredicate(key, "");
		}

	} else if(element.type == JSON_TYPE.ARRAY)
	{
		foreach(element1; element.array)
		{
			// writeln("addElement(key, element1, gcl, ss);", key, element1, gcl, ss);
			addElement(key, element1, gcl, ss);
		}
	}

}

public Subject[] parse_json_ld_string(char* msg, int message_size)
{
	// простой вариант парсинга, когда уже есть json-tree в памяти
	// но это не оптимально по затратам памяти и производительности

	GraphCluster gcl = new GraphCluster;

	JSONValue node;

	//	StopWatch sw1;
	//	sw1.start();

	char[] buff = getString(msg, message_size);

	node = parseJSON(buff);

	prepare_node(node, gcl);

	//	sw1.stop();
	//	log.trace("json msg parse %d [µs]", cast(long) sw1.peek().microseconds);

	return gcl.graphs_of_subject.values;
}

char[] getString(char* s, int length)
{
	return s ? s[0 .. length] : null;
}

void toJson_ld(Subject[] results, ref OutBuffer outbuff, int level = 0)
{
	if (results.length > 1)
		outbuff.write(cast(char[]) "[\n");

	for(int ii = 0; ii < results.length; ii++)
	{
		Subject out_message = results[ii];

		if(out_message !is null && out_message.subject !is null)
		{
			if(ii > 0)
				outbuff.write(cast(char[]) ",\n");

			toJson_ld(out_message, outbuff);
		}
	}

	if (results.length > 1)
		outbuff.write(cast(char[]) "\n] ");
	else
		outbuff.write(' ');
}

void toJson_ld(Subject ss, ref OutBuffer outbuff, int level = 0)
{
	// A: перевод triple-tree в json-tree, а затем серилизация с помощью метода - string toJSON(in JSONValue* root); 
	// (-) затратная операция, память на json-tree и процесс перевода
	// (+) стандартное формирование JSON
	//
	// B: запись строки в формате JSON напрямую из triple-tree
	// (+) быстрое по сравнением с вариантом A

	// вариант В
	if(ss.subject is null && ss.count_edges == 0)
	{
		return;
	}

	for(int i = 0; i < level; i++)
		outbuff.write(cast(char[]) "	");

	outbuff.write(cast(char[]) "{\n");

	for(int i = 0; i < level; i++)
		outbuff.write(cast(char[]) "	 ");

	if(ss.subject !is null)
	{
		outbuff.write(cast(char[]) "\"@\" : \"");
		outbuff.write(ss.subject);
		outbuff.write(cast(char[]) "\",\n");
	}

	for(int jj = 0; jj < ss.count_edges; jj++)
	{
		Predicate* pp = &(ss.edges[jj]);

		if(jj > 0)
			outbuff.write(cast(char[]) ",\n");

		for(int i = 0; i < level; i++)
			outbuff.write(cast(char[]) "	 ");

		outbuff.write('"');
		outbuff.write(pp.predicate);

		outbuff.write(cast(char[]) "\": ");

		if(pp.count_objects > 1)
			outbuff.write('[');

		for(int kk = 0; kk < pp.count_objects; kk++)
		{
			Objectz oo = pp.objects[kk];

			if(kk > 0)
				outbuff.write(',');

			if(oo.type == OBJECT_TYPE.LITERAL)
			{
				//				log.trace ("write literal");
//				if(oo.object is null)
//					outbuff.write(cast(char[]) "null");
//				else
				{
					outbuff.write('"');
					// заменим все неэкранированные кавычки на [\"]
					bool is_exist_quotes = false;
					foreach(ch; oo.literal)
					{
						if(ch == '"')
						{
							is_exist_quotes = true;
							break;
						}
					}
					//				log.trace ("write literal 2");

					if(is_exist_quotes)
					{
						int len = cast(uint)oo.literal.length;

						for(int i = 0; i < len; i++)
						{
							if(i >= len)
								break;

							char ch = oo.literal[i];

							if(ch == '"' && len > 4)
							{
								outbuff.write('\\');
							}

							outbuff.write(ch);
						}
					} else
					{
						outbuff.write(oo.literal);
					}

					if(oo.lang == LITERAL_LANG.RU)
					{
						outbuff.write(cast(char[]) "@ru");
					} else if(oo.lang == LITERAL_LANG.EN)
					{
						outbuff.write(cast(char[]) "@en");
					}

					outbuff.write('"');
				}
				//				log.trace ("write literal end");
			} else if(oo.type == OBJECT_TYPE.URI)
			{
				if(oo.literal is null)
				{
					outbuff.write(cast(char[]) "null");
				} else
				{
					outbuff.write('"');
					outbuff.write(oo.literal);
					outbuff.write('"');
				}
			} else if(oo.type == OBJECT_TYPE.SUBJECT)
			{
				if(oo.subject !is null && oo.subject.count_edges == 0)
				{
					outbuff.write(cast(char[]) "null");
				} else
				{
					outbuff.write('\n');
					toJson_ld(oo.subject, outbuff, level + 1);
				}
			} else if(oo.type == OBJECT_TYPE.CLUSTER)
			{
//				if(oo.cluster.graphs_of_subject.values.length == 0)
//				{
//					outbuff.write(cast(char[]) "null");
//				} else
				{
//					if(oo.cluster.graphs_of_subject.values.length > 1)
						outbuff.write('[');

					for(int i = 0; i < oo.cluster.graphs_of_subject.values.length; i++)
					{
						if(i > 0)
							outbuff.write(',');
						outbuff.write('\n');
						toJson_ld(oo.cluster.graphs_of_subject.values[i], outbuff, level + 1);
					}

//					if(oo.cluster.graphs_of_subject.values.length > 1)
						outbuff.write(']');
				}
			}

		}

		if(pp.count_objects > 1)
			outbuff.write(']');

	}

	outbuff.write('\n');

	for(int i = 0; i < level; i++)
		outbuff.write(cast(char[]) "	");

	outbuff.write('}');
}