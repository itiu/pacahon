module pacahon.json_ld.parser;

private import std.stdio;
private import std.datetime;
private import std.json;
private import std.outbuffer;

private import pacahon.graph;

private import trioplax.Logger;

Logger log;

static this()
{
	log = new Logger("pacahon.log", "pacahon.json_ld.parser");
}

public Subject[] parse_json_ld_string(char* msg, int message_size)
{
	// простой вариант парсинга, когда уже есть json-tree в памяти
	// но это не оптимально по затратам памяти и производительности

	void prepare_node(JSONValue node, GraphCluster* gcl, Subject ss = null)
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
					ss.subject = cast(char[]) node.object.values[i].str;
					//										writeln("SUBJECT = ", ss.subject);
					gcl.addSubject(ss);
				}
				else
				{
					JSONValue element = node.object.values[i];

					//	writeln(element.type, ":key= ", key);

					//	if(element.type == JSON_TYPE.STRING)
					//	writeln(" element value=", element.str);

					if(element.type == JSON_TYPE.OBJECT)
					{
						if(("@" in element.object) is null)
						{
							Subject ss_in = new Subject;
							prepare_node(element, gcl, ss_in);
							ss.addPredicate(cast(char[]) key, ss_in);
						}
						else
						{
							GraphCluster inner_gcl;
							prepare_node(element, &inner_gcl);
							ss.addPredicate(cast(char[]) key, inner_gcl);
						}
					}

					if(element.type == JSON_TYPE.STRING)
					{
						char[] val = cast(char[]) element.str;

						//						writeln("ss=", ss.subject, ",key=", key, ",val=", val);

						if(val !is null && val.length > 12 && val[val.length - 12] == '^' && val[val.length - 7] == ':' && val[val.length - 6] == 's')
						{
							// очень вероятно что окончание строки содержит ^^xsd:string
							val = val[0 .. val.length - 12];
						}

						ss.addPredicate(cast(char[]) key, val);
					}
				}
			}
		}
		else if(JSON_TYPE.ARRAY)
		{
			foreach(element; node.array)
			{
				prepare_node(element, gcl);
			}
		}
	}

	GraphCluster gcl;

	JSONValue node;

	StopWatch sw1;
	sw1.start();

	char[] buff = getString(msg, message_size);

	node = parseJSON(buff);

	prepare_node(node, &gcl);

	//	sw1.stop();
	//	log.trace("json msg parse %d [µs]", cast(long) sw1.peek().microseconds);

	return gcl.graphs_of_subject.values;
}

char[] getString(char* s, int length)
{
	return s ? s[0 .. length] : null;
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

	for(int i = 0; i < level; i++)
		outbuff.write(cast(char[]) "	");

	outbuff.write(cast(char[]) "{\n");

	for(int i = 0; i < level; i++)
		outbuff.write(cast(char[]) "	");

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
			outbuff.write(cast(char[]) "	");

		outbuff.write('"');
		outbuff.write(pp.predicate);
		outbuff.write(cast(char[]) "\" : ");

		if(pp.count_objects > 1)
			outbuff.write('[');

		for(int kk = 0; kk < pp.count_objects; kk++)
		{
			Objectz oo = pp.objects[kk];

			if(oo.type == OBJECT_TYPE.LITERAL)
			{
				//				log.trace ("write literal");

				outbuff.write('"');
				// заменим все неэкранированные кавычки на [\"]
				bool is_exist_quotes = false;
				foreach(ch; oo.object)
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
					int len = oo.object.length;

					for(int i = 0; i < len; i++)
					{
						if(i >= len)
							break;

						char ch = oo.object[i];

						if(ch == '"' && len > 4)
						{
							outbuff.write('\\');
						}

						outbuff.write(ch);
					}
				}

				else
				{
					outbuff.write(oo.object);
				}
				outbuff.write('"');
				//				log.trace ("write literal end");
			}
			else if(oo.type == OBJECT_TYPE.URI)
			{
				outbuff.write('"');
				outbuff.write(oo.object);
				outbuff.write('"');
			}
			else if(oo.type == OBJECT_TYPE.SUBJECT)
			{
				outbuff.write('\n');
				toJson_ld(oo.subject, outbuff, level + 1);
			}
			else if(oo.type == OBJECT_TYPE.CLUSTER)
			{
				foreach(element; oo.cluster.graphs_of_subject.values)
				{
					toJson_ld(element, outbuff, level + 1);
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
