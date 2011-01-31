module pacahon.n3.parser;

private import std.string;
private import std.c.stdlib;
private import std.c.string;
private import std.stdio;
private import std.datetime;
private import std.outbuffer;

private import pacahon.graph;
private import pacahon.utils;

int def_size_out_array = 100;

version(trace_turtle_parser)
	bool print_found_element = true;
else
	bool print_found_element = false;

struct state_struct
{
	char* P;
	int P_length;

	void* O;
	int O_length;
	bool O_is_literal;

	byte e;

	//	char* res_buff;
	//	char* ptr_buff;
	int len;

	Subject nodes[];
	short count_nodes;

	Subject roots[];
	short count_roots;

	Subject stack_nodes[8];
	byte pos_in_stack_nodes;

	//	Predicate edges[];
	//	int count_edges;

	Objectz objects[];
	int count_objects;

	short parent[];
	short child[];
	short count_parent_child;
}

/*
 * 	src - С-шная строка содержащая факты в формате n3,
 * 	len - длинна исходной строки,
 * 	res_buff - буффер для размещения результатов парсинага, 
 *  должен быть не меньше чем суммарная длинна всех строк составляющих триплеты.
 *  ! память res_buff данной функцией не освобождается  
 */

public Subject[] parse_n3_string(char* src, int len)
{
	StopWatch sw;
	sw.start();

	assert(src !is null);
	if(len == 0)
		return null;

	char* ptr = src - 1;
	char* new_line_ptr = src;
	char* element;
	char ch = *src;
	char prev_ch = 0;
	state_struct state;

	state.P = null;
	state.O = null;
	state.e = 0;
	state.len = len;
	state.pos_in_stack_nodes = 0;

	state.count_nodes = 0;
	//	state.count_edges = 0;
	state.nodes = new Subject[def_size_out_array];
	state.roots = new Subject[def_size_out_array];
	//	state.edges = new Predicate[def_size_out_array];
	state.objects = new Objectz[def_size_out_array];

	while(ch != 0 && ptr - src < len)
	{
		prev_ch = ch;
		ptr++;
		if(ptr - src > len)
			break;

		ch = *ptr;

		if(ptr == src || (prev_ch == '\n' || prev_ch == '\r'))
		{
			if(ch == '\n' || ch == '\r')
			{
				continue;
			}

			// new line
			new_line_ptr = ptr;

			//			printf("!NewLine!%s\n", new_line_ptr);

			if(ch == '@')
			{
				// это блок назначения префиксов

				// пропускаем строку
				while(ch != '\n' && ch != '\r' && ptr - src < len)
				{
					ptr++;
					ch = *ptr;
					prev_ch = ch;
				}
				continue;
			}

			if(ch == '#')
			{
				// это комментарий

				// пропускаем строку
				while(ch != '\n' && ch != '\r' && ptr - src < len)
				{
					ptr++;
					ch = *ptr;
					prev_ch = ch;
				}
				continue;
			}

			while(ch != '\n' && ch != '\r' && ch != 0)
			{

				// пропустим прообелы
				while((ch == ' ' || ch == 9) && ptr - src < len)
				{
					ptr++;
					ch = *ptr;
				}

				// это начало элемента
				element = ptr;

				if(*element == '"')
				{
					if(*(element + 1) == '"' && *(element + 2) == '"')
					{
						ptr += 2;
						element = ptr;
					}

					ptr++;
					if(ptr - src > len)
					{
						//						printf ("куда лезем! 7  ptr - src=%d > len=%d \n", ptr - src, len);
						break;
					}

					ch = *ptr;
					while(ptr - src < len)
					{
						if(ch == '"' && *(ptr - 1) != '\\')
							break;

						ptr++;
						ch = *ptr;
					}
				}

				while(ch != ' ' && ch != '\r' && ch != '\n' && ptr - src < len)
				{
					ptr++;
					ch = *ptr;
					//					writeln("CH [", ch, "]");					
				}

				if(ptr - src > len)
				{
					break;
				}

				if(*element == 0)
					break;

				next_element(element, ptr - element, &state);

				ptr++;

				if(ptr - src > len)
				{
					break;
				}
				ch = *ptr;

				//				printf("[%s]\n", element);
			}

		}

	}
	state.roots.length = state.count_roots;

	version(trace_turtle_parser)
		printf("parse finish\n");

	sw.stop();
	long t = cast(long) sw.peek().microseconds;

	if(t > 100)
	{
		printf("total time parse: %d[µs]\n", t);
	}

	return state.roots;
}

private void next_element(char* element, int el_length, state_struct* state)
{
	assert(element !is null);
	assert(state !is null);

	if(el_length == 1 && !(*element == ';' || *element == '.' || *element == '[' || *element == ']' || *element == ',' || *element == 'a'))
		return;

	if(print_found_element)
	{
		writeln("ELEMENT [", *element, "]");
		writeln("ELEMENT (", el_length, ") [", fromStringz(element, el_length), "]");
	}

	if(*element == ';' || *element == '.' || *element == '[' || *element == ']' || *element == ',')
	{
		if(*element != ',')
		{
			state.e = 1;
		}

		if(*element == ',')
		{
			state.e = 2;
		}

		if(*element == '.')
		{
			state.e = 0;
		}

		if(state.P !is null)
		{
			version(trace_turtle_parser)
				writeln("pos_in_stack_nodes=", state.pos_in_stack_nodes, "[", state.stack_nodes[state.pos_in_stack_nodes].subject, " ",
						state.P, " ", state.O, "]");

			Subject ss = state.stack_nodes[state.pos_in_stack_nodes];

			if(*element == ']')
				state.pos_in_stack_nodes--;

			Predicate* ee = null;

			// прежде чем создать новый Predicate, следует поискать у данного ss предикат с значением state.P
			for(short jj = 0; jj < ss.count_edges; jj++)
			{
				if(strcmp(ss.edges[jj].predicate.ptr, state.P) == 0)
				{
					// такой уже найден
					ee = &ss.edges[jj];
					//					printf("такой уже найден %s\n", state.P);
				}

			}

			//					printf("count_edges=%d\n", state.count_edges);
			if(ee is null)
			{
				// создаем новый предикат
				if(ss.edges is null)
					ss.edges = new Predicate[16];

				//				ee = &state.edges[state.count_edges];
				ee = &ss.edges[ss.count_edges];

				if(ee.objects is null)
					ee.objects = new Objectz[1];

				if(*state.P == 'a' && *(state.P + 1) == 0)
				{
					ee.predicate = "rdf:type";
				}
				else
					ee.predicate = fromStringz(state.P, state.P_length);
				//					ee.predicate[state.P_length] = 0;

				version(trace_turtle_parser)
					writeln("создаем новый предикат, p=", ee.predicate);

				ss.edges[ss.count_edges] = *ee;
				ss.count_edges++;

				version(trace_turtle_parser)
					printf("ok, ss.count_edges=%d\n", ss.count_edges);
			}

			// увеличим размер массива если это требуется
			//			Objectz[] objects = &ee.objects;
			if(ee.count_objects >= ee.objects.length)
			{
				version(trace_turtle_parser)
					printf("увеличим размер массива если это требуется, ee.count_objects=%d, ee.objects.length= %d\n", ee.count_objects,
							ee.objects.length);

				ee.objects.length = ee.objects.length + 20;

				version(trace_turtle_parser)
					printf("ee.objects.length= %d\n", ee.objects.length);
			}

			if(*element == '[')
			{
				// создадим новую ноду				
				version(trace_turtle_parser)
					printf("создадим новую ноду\n");

				Subject new_nodes = new Subject();
				state.nodes[state.count_nodes] = new_nodes;
				state.count_nodes++;

				version(trace_turtle_parser)
					printf("и сохраним ее на стеке -> pos_in_stack_nodes=%X\n", state.pos_in_stack_nodes);

				// и сохраним ее на стеке
				state.pos_in_stack_nodes++;
				state.stack_nodes[state.pos_in_stack_nodes] = new_nodes;

				version(trace_turtle_parser)
					printf("и сохраним ее на стеке -> pos_in_stack_nodes=%X\n", state.pos_in_stack_nodes);

				// сохраним ее в edges
				ee.objects[ee.count_objects].subject = new_nodes;
				ee.objects[ee.count_objects].type = OBJECT_TYPE.SUBJECT;
				ee.count_objects++;

				//				state.count_nodes++;
			}
			else
			{
				char[] buff = new char[state.O_length];
				ee.objects[ee.count_objects].object = cast(immutable)buff;

				char* ptr = cast(char*) state.O;
				int idx1 = 0;

				if(*ptr == '"')
					ptr++;
				else
				{
					ee.objects[ee.count_objects].type = OBJECT_TYPE.URI;
				}

				while(ptr - state.O < state.O_length)
				{
					if(*ptr == '"' && *(ptr + 1) == '"' && *(ptr + 2) == '"')
					{
						buff[idx1] = 0;
						break;
					}

					if(*ptr == '\\' && *(ptr + 1) == '"')
						ptr++;

					if(*ptr == '"' && *(ptr - 1) != '\\')
					{
						buff[idx1] = 0;
						break;
					}

					//					if (*ptr == '^' && *(ptr+1) == '^')
					//					{
					//						*ptr1 = 0;
					//						break;
					//					}

					buff[idx1] = *ptr;

					ptr++;
					idx1++;
				}

				ptr++;

				if(*ptr == '@')
				{
					if(*(ptr + 1) == 'r' && *(ptr + 2) == 'u')
						ee.objects[ee.count_objects].lang = LITERAL_LANG.RU;

					if(*(ptr + 1) == 'e' && *(ptr + 2) == 'n')
						ee.objects[ee.count_objects].lang = LITERAL_LANG.EN;
				}
				//				printf("!!! 7\n");

				//				ee.objects[ee.count_objects].object.length = ptr1 - ee.objects[ee.count_objects].object.ptr;
				ee.objects[ee.count_objects].object.length = idx1;

				version(trace_turtle_parser)
					writeln("set object=", ee.objects[ee.count_objects].object, " lang=", ee.objects[ee.count_objects].lang);

				//				ee.objects[ee.count_objects].subject = state.ptr_buff;
				ee.count_objects++;

				version(trace_turtle_parser)
					printf("ee.count_objects=%d\n", ee.count_objects);
			}

			//			state.count_edges++;
			if(*element != ',')
				state.P = null;

			state.O = null;
		}
		if(*element == ']')
		{
			state.e = 0;
		}

		version(trace_turtle_parser)
			printf("next element finish #1, state.e=%d\n", state.e);

		return;
	}
	else
	{
		version(trace_turtle_parser)
			writeln("state.e:", state.e);

		if(state.e == 0)
		{
			version(trace_turtle_parser)
				writeln("new node S=", element);

			Subject new_subject = new Subject;
			state.nodes[state.count_nodes] = new_subject;

			if(state.pos_in_stack_nodes == 0)
			{
				state.stack_nodes[state.pos_in_stack_nodes] = new_subject;
			}

			new_subject.subject = fromStringz(element, el_length);
			//			new_subject.subject[el_length] = 0;

			state.roots[state.count_roots] = new_subject;
			state.count_roots++;

			state.count_nodes++;
		}
		else if(state.e == 1)
		{
			state.P = element;
			state.P_length = el_length;
			version(trace_turtle_parser)
				writeln("found P=", fromStringz(element, el_length));
		}
		else if(state.e == 2)
		{
			state.O_is_literal = true;
			state.O = element;
			state.O_length = el_length;
			version(trace_turtle_parser)
				writeln("found O=", fromStringz(element, el_length));
		}

	}

	//	if(*element == ',')
	//	{
	//		state.e = 2;
	//	}
	//	else
	//	{
	state.e++;
	//	}

	version(trace_turtle_parser)
		printf("next element finish #2, state.e=%d\n", state.e);
}

void toTurtle(Subject ss, ref OutBuffer outbuff, int level = 0)
{
	for(int i = 0; i < level; i++)
		outbuff.write(cast(char[]) "  ");

	if(ss.subject !is null)
		outbuff.write(ss.subject);

	for(int jj = 0; jj < ss.count_edges; jj++)
	{
		Predicate* pp = &(ss.edges[jj]);

		for(int i = 0; i < level; i++)
			outbuff.write(cast(char[]) " ");
		outbuff.write(cast(char[]) "  ");
		outbuff.write(pp.predicate);

		for(int kk = 0; kk < pp.count_objects; kk++)
		{
			Objectz oo = pp.objects[kk];

			for(int i = 0; i < level; i++)
				outbuff.write(cast(char[]) " ");

			if(oo.type == OBJECT_TYPE.LITERAL)
			{
				outbuff.write(cast(char[]) "   \"");

				// заменим все неэкранированные кавычки на [\"]
				char prev_ch;
				char[] new_str = new char[oo.object.length * 2];
				int pos_in_new_str = 0;
				int len = oo.object.length;

				for(int i = 0; i < len; i++)
				{
					// если подрят идут "", то пропустим их
					if(len > 4 && (i == 0 || i == len - 2) && oo.object[i] == '"' && oo.object[i + 1] == '"')
					{
						for(byte hh = 0; hh < 2; hh++)
						{
							new_str[pos_in_new_str] = oo.object[i];
							pos_in_new_str++;
							i++;
						}

					}

					if(i >= len)
						break;

					char ch = oo.object[i];

					if(ch == '"' && len > 4)
					{
						new_str[pos_in_new_str] = '\\';
						pos_in_new_str++;
					}

					new_str[pos_in_new_str] = ch;
					pos_in_new_str++;

					prev_ch = ch;
				}
				new_str.length = pos_in_new_str;

				outbuff.write(new_str);

				outbuff.write(cast(char[]) "\"");
				if(oo.lang == LITERAL_LANG.RU)
				{
					outbuff.write(cast(char[]) "@ru");
				}
				else if(oo.lang == LITERAL_LANG.EN)
				{
					outbuff.write(cast(char[]) "@en");
				}
			}
			else if(oo.type == OBJECT_TYPE.URI)
			{
				outbuff.write(cast(char[]) "   ");
				outbuff.write(oo.object);
			}
			else if(oo.type == OBJECT_TYPE.SUBJECT)
			{
				outbuff.write(cast(char[]) "\n  [\n");
				toTurtle(oo.subject, outbuff, level + 1);
				outbuff.write(cast(char[]) "\n  ]");
			}
			else if(oo.type == OBJECT_TYPE.CLUSTER)
			{
				outbuff.write(cast(char[]) "\"\"");
				foreach(s; oo.cluster.graphs_of_subject)
				{
					toTurtle(s, outbuff, true);
				}
				outbuff.write(cast(char[]) "\"\"");
			}

			if(jj == ss.count_edges - 1)
			{
				if(level == 0)
					outbuff.write(cast(char[]) " .\n");
			}
			else
			{
				outbuff.write(cast(char[]) " ;\n");
			}
		}

	}

	return;
}

void toTurtle(Subject[] results, ref OutBuffer outbuff, int level = 0)
{
	for(int ii = 0; ii < results.length; ii++)
	{
		Subject out_message = results[ii];

		if(out_message !is null)
		{
			toTurtle(out_message, outbuff);
		}
	}
}

/*
 char* toTurtle(GraphCluster gcl)
 {
 OutBuffer outbuff = new OutBuffer();

 outbuff.write(cast(char[]) "\"\"");
 foreach(s; gcl.graphs_of_subject)
 {
 toTurtle(s, outbuff, true);
 }
 outbuff.write(cast(char[]) "\"\"");

 outbuff.write(0);

 //		printf ("***:%s\n", cast(char*) outbuff.toBytes());

 return cast(char*) outbuff.toBytes();
 }
 */

