module pacahon.json_ld.parser;

private import std.datetime;
private import std.json;
private import pacahon.graph;

private import trioplax.Logger;

Logger log;

static this()
{
        log = new Logger("pacahon.log", "pacahon.json_ld.parser");
}



public Subject[] parse_json_ld_string(char* msg, int message_size)
{
	void prepare_node(JSONValue node, GraphCluster* gcl)
	{
		if(node.type == JSON_TYPE.OBJECT)
		{
			Subject ss = new Subject;
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
						GraphCluster inner_gcl;
						//	writeln(" element value= \n{");
						prepare_node(element, &inner_gcl);
						//	writeln("}");
						ss.addPredicate(cast(char[]) key, inner_gcl);
					}

					if(element.type == JSON_TYPE.STRING)
					{
//						writeln("ss.addPredicate ", key, " ", element.str);
						ss.addPredicate(cast(char[]) key, cast(char[]) element.str);
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

	sw1.stop();
	log.trace("json msg parse %d [µs]", cast(long) sw1.peek().microseconds);

	return gcl.graphs_of_subject.values;
}

char[] getString(char* s, int length)
{
    return s ? s[0 .. length] : null;
}
        
        
