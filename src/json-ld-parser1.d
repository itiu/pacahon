module pacahon.json_ld.parser1;

private import std.outbuffer;
private import std.stdio;
private import pacahon.graph;
import std.range;
import std.ascii;
import std.utf;
import std.conv;

private import trioplax.Logger;

Logger log;

static this()
{
	log = new Logger("pacahon", "log", "pacahon.json_ld.parser1");
}

/**
 Parses a serialized string and returns a tree of JSON values.
 */

enum ParentLevelType: byte
{
	PREDICATE,
	ARRAY
}

GraphCluster parse_JSON_LD(T)(T json, int maxDepth = -1) if(isInputRange!T) 
{
	GraphCluster new_gcl = new GraphCluster;

	if(json.empty())
		return new_gcl;

	//      writeln ("json=",json);

	int depth = -1;
	dchar next = 0;
	int line = 1, pos = 1;

	void error(string msg)
	{
		throw new JSONException(msg, line, pos);
	}

	dchar peekChar()
	{
		if(!next)
		{
			if(json.empty())
				return '\0';
			next = json.front();
			json.popFront();
		}
		return next;
	}

	void skipWhitespace()
	{
		while(isWhite(peekChar()))
			next = 0;
	}

	dchar getChar(bool SkipWhitespace = false)()
	{
		static if(SkipWhitespace)
			skipWhitespace();

		dchar c = void;
		if(next)
		{
			c = next;
			next = 0;
		} else
		{
			if(json.empty())
				error("Unexpected end of data.");
			c = json.front();
			json.popFront();
		}

		if(c == '\n' || (c == '\r' && peekChar() != '\n'))
		{
			line++;
			pos = 1;
		} else
		{
			pos++;
		}

		return c;
	}

	void checkChar(bool SkipWhitespace = true, bool CaseSensitive = true)(char c)
	{

		//   	   	   writeln ("checkChar [", c, "]");

		static if(SkipWhitespace)
			skipWhitespace();
		auto c2 = getChar();
		static if(!CaseSensitive)
			c2 = toLower(c2);

		if(c2 != c)
			error(text("Found '", c2, "' when expecting '", c, "'."));
	}

	bool testChar(bool SkipWhitespace = true, bool CaseSensitive = true)(char c)
	{
		static if(SkipWhitespace)
			skipWhitespace();
		auto c2 = peekChar();
		static if(!CaseSensitive)
			c2 = toLower(c2);

		if(c2 != c)
			return false;

		getChar();
		return true;
	}

	string parseString()
	{
		auto str = appender!string();

     Next:
		switch(peekChar())
		{
			case '"':
				getChar();
			break;

			case '\\':
				getChar();
				auto c = getChar();
				switch(c)
				{
					case '"':
						str.put('"');
					break;
					case '\\':
						str.put('\\');
					break;
					case '/':
						str.put('/');
					break;
					case 'b':
						str.put('\b');
					break;
					case 'f':
						str.put('\f');
					break;
					case 'n':
						str.put('\n');
					break;
					case 'r':
						str.put('\r');
					break;
					case 't':
						str.put('\t');
					break;
					case 'u':
						dchar val = 0;
						foreach_reverse(i; 0 .. 4) 
						{
							auto hex = toUpper(getChar());
							if(!isHexDigit(hex))
								error("Expecting hex character");
							val += (isDigit(hex) ? hex - '0' : hex - ('A' - 10)) << (4 * i);
						}
						char[4] buf = void;
						str.put(toUTF8(buf, val));
					break;

					default:
						error(text("Invalid escape sequence '\\", c, "'."));
				}
				goto Next;

			default:
				auto c = getChar();
				appendJSONChar(&str, c, &error);
				goto Next;
		}

		return str.data;
	}

	void parseValue(GraphCluster gcl, Subject ss, Predicate* pp, ParentLevelType plt)
	{
//		writeln("parseValue depth=", depth);

		depth++;

		if(maxDepth != -1 && depth > maxDepth)
			error("Nesting too deep.");

		auto c = getChar!true();

		//               writeln (c);

		switch(c)
		{
			case '{':
				if(testChar('}'))
					break;

				Subject new_subject = new Subject;

				if(plt == ParentLevelType.PREDICATE)
				{
//					writeln("to ", pp.predicate, ", set subject =", new_subject.subject);
					pp.addSubject(new_subject);
				}

				do
				{
					checkChar('"');
					string name = parseString();
					checkChar(':');

//					writeln("name=", name);

					if(name == "#")
						continue; // определение контекстов опустим, пока в этом нет необходимости

					if(name == "@")
					{
						checkChar('"');
						new_subject.subject = parseString();
//						writeln("ss.subject=", new_subject.subject);

						if(plt == ParentLevelType.ARRAY)
						{
//							writeln("to cluster, set subject =", new_subject.subject);

							if(gcl is null)
							{
								gcl = new GraphCluster;
								pp.addCluster(gcl);
							}

							gcl.addSubject(new_subject);
						}

					} else
					{
						Predicate* new_predicate;
						new_predicate = new_subject.addPredicate();

						new_predicate.predicate = name;
//						writeln("to ", new_subject.subject, ", add pp.predicate=", new_predicate.predicate);
						parseValue(null, null, new_predicate, ParentLevelType.PREDICATE);
					}

				} while(testChar(','));

				checkChar('}');
			break;

			case '[':
				if(testChar(']'))
					break;

				// определить, это будет кластер или массив значений у предиката
				do
				{
					parseValue(gcl, ss, pp, ParentLevelType.ARRAY);
				} while(testChar(','));

				checkChar(']');
			break;

			case '"':

				string val = parseString();
//				writeln("case '\"' val=", val);

				if(val !is null && val.length > 12 && val[val.length - 12] == '^' && val[val.length - 7] == ':' && val[val.length - 6] == 's')
				{
					// очень вероятно что окончание строки содержит ^^xsd:string
					val = val[0 .. val.length - 12];
				}

				if(val !is null && val.length >= 3 && val[val.length - 3] == '@')
				{
					if(val[val.length - 2] == 'r' && val[val.length - 1] == 'u')
						pp.addLiteral(val[0 .. val.length - 3], LITERAL_LANG.RU);
					else if(val[val.length - 2] == 'e' && val[val.length - 1] == 'n')
						pp.addLiteral(val[0 .. val.length - 3], LITERAL_LANG.EN);
				} else
				{
					pp.addLiteral(val);
				}

			break;

			default:
				error(text("Unexpected character '", c, "'."));
		}

		depth--;
	}

	parseValue(new_gcl, null, null, ParentLevelType.ARRAY);

//	writeln(new_gcl.graphs_of_subject);

	return new_gcl;
}


 private void appendJSONChar(Appender!string* dst, dchar c, scope void delegate(string) error)
 {
	 if(isControl(c)) 
		 error("Illegal control character.");
	 dst.put(c);
 //      int stride = UTFStride((&c)[0 .. 1], 0);
 //      if(stride == 1) {
 //              if(isControl(c)) error("Illegal control character.");
 //              dst.put(c);
 //      }
 //      else {
 //              char[6] utf = void;
 //              utf[0] = c;
 //              foreach(i; 1 .. stride) utf[i] = next;
 //              size_t index = 0;
 //              if(isControl(toUnicode(utf[0 .. stride], index)))
 //                      error("Illegal control character");
 //              dst.put(utf[0 .. stride]);
 //      }
 }
 
public Subject[] parse_json_ld_string(char* msg, int message_size)
{
	//	StopWatch sw1;
	//	sw1.start();

	char[] buff = getString(msg, message_size);

	GraphCluster gcl = parse_JSON_LD(buff);

	//	sw1.stop();
	//	log.trace("json msg parse %d [µs]", cast(long) sw1.peek().microseconds);

	return gcl.graphs_of_subject.values;
}

char[] getString(char* s, int length)
{
	return s ? s[0 .. length] : null;
}

/**
 Exception thrown on JSON errors
 */
class JSONException: Exception
{
	this(string msg, int line = 0, int pos = 0)
	{
		if(line)
			super(text(msg, " (Line ", line, ":", pos, ")"));
		else
			super(msg);
	}
}

void toJson_ld(Subject[] results, ref OutBuffer outbuff, int level = 0)
{
	if(results.length > 1)
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

	if(results.length > 1)
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
						int len = oo.literal.length;

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
