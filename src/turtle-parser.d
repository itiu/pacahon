module pacahon.n3.parser;

import std.string;
import std.c.stdlib;
import std.c.string;
import std.stdio;

import pacahon.graph;
import pacahon.utils;

int def_size_out_array = 100;

struct state_struct
{
	char* P;
	void* O;
	bool O_is_literal;

	byte e;

	//	char* res_buff;
	//	char* ptr_buff;
	int len;

	Subject nodes[];
	short count_nodes;

	Subject* roots[];
	short count_roots;

	Subject* stack_nodes[8];
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

public Subject*[] parse_n3_string(char* src, int len)
{
	assert(src !is null);
	assert(len != 0);

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
	state.roots = new Subject*[def_size_out_array];
//	state.edges = new Predicate[def_size_out_array];
	state.objects = new Objectz[def_size_out_array];

	while(ch != 0)
	{
		prev_ch = ch;
		ptr++;
		if(ptr - src > len)
			break;

		ch = *ptr;

		if(ptr == src || prev_ch == '\n')
		{
			if(ch == '\n')
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
				while(ch != '\n' && ptr - src < len)
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
				while(ch != '\n' && ptr - src < len)
				{
					ptr++;
					ch = *ptr;
					prev_ch = ch;
				}
				continue;
			}

			while(ch != '\n' && ch != 0)
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

					ch = *ptr;
					while(ptr - src < len)
					{
						if(ch == '"' && *(ptr - 1) != '\\')
							break;

						ptr++;
						ch = *ptr;
					}
				}

				while(ch != ' ' && ch != '\n' && ptr - src < len)
				{
					ptr++;
					ch = *ptr;
				}

				// окончание элемента отметим 0
				*ptr = 0;

				ptr++;
				//assert (ptr - src > len);
				//{
				//	throw new Exception ("куда лезем! 8");
				//}
				ch = *ptr;

				if(*element == 0)
					break;

				next_element(element, &state);

				//				printf("[%s]\n", element);
			}

		}

	}
	state.roots.length = state.count_roots;

	return state.roots;
}

private void next_element(char* element, state_struct* state)
{
	assert(element !is null);
	assert(state !is null);

	version(trace_turtle_parser)
		printf("element: %s\n ", element);

	if(*element == ';' || *element == '.' || *element == '[' || *element == ']')
	{
		state.e = 1;
		if(*element == '.')
		{
			state.e = 0;
		}

		if(state.P !is null)
		{
			version(trace_turtle_parser)
				printf("\n pos_in_stack_nodes=%d [%s %s %s]\n", state.pos_in_stack_nodes,
						state.nodes[state.pos_in_stack_nodes].subject.ptr, state.P, state.O);

			Subject* ss = state.stack_nodes[state.pos_in_stack_nodes];

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
				version(trace_turtle_parser)
					printf("создаем новый предикат\n");

				if(ss.edges is null)
					ss.edges = new Predicate[16];

//				ee = &state.edges[state.count_edges];
				ee = &ss.edges[ss.count_edges];

				if(ee.objects is null)
					ee.objects = new Objectz[1];

				ee.predicate = fromStringz(state.P);

				ss.edges[ss.count_edges] = *ee;
				ss.count_edges++;
			}

			// увеличим размер массива если это требуется
			//			Objectz[] objects = &ee.objects;
			if(ee.count_objects >= ee.objects.length)
			{
				version(trace_turtle_parser)
					printf("увеличим размер массива если это требуется, ee.count_objects=%d, ee.objects.length= %d\n", ee.count_objects,
							ee.objects.length);

				ee.objects.length = ee.objects.length + 16;

				version(trace_turtle_parser)
					printf("ee.objects.length= %d\n", ee.objects.length);
			}

			if(*element == '[')
			{
				// создадим новую ноду				
				version(trace_turtle_parser)
					printf("создадим новую ноду\n");

				state.count_nodes++;
				Subject* new_nodes = &state.nodes[state.count_nodes];

				// и сохраним ее на стеке
				state.pos_in_stack_nodes++;
				state.stack_nodes[state.pos_in_stack_nodes] = new_nodes;

				// сохраним ее в edges
				ee.objects[ee.count_objects].subject = new_nodes;
				ee.objects[ee.count_objects].type = SUBJECT;
				ee.count_objects++;

				state.count_nodes++;
			}
			else
			{
				ee.objects[ee.count_objects].object = new char[strlen(cast(char*) state.O)];

				char* ptr = cast(char*) state.O;
				char* ptr1 = ee.objects[ee.count_objects].object.ptr;

				if(*ptr == '"')
					ptr++;
				else
					ee.objects[ee.count_objects].type = URI;

				while(*ptr != 0)
				{
					if(*ptr == '"' && *(ptr + 1) == '"' && *(ptr + 2) == '"')
					{
						*ptr1 = 0;
						break;
					}

					if(*ptr == '\\' && *(ptr + 1) == '"')
						ptr++;

					if(*ptr == '"' && *(ptr - 1) != '\\')
					{
						*ptr1 = 0;
						break;
					}

					//					if (*ptr == '^' && *(ptr+1) == '^')
					//					{
					//						*ptr1 = 0;
					//						break;
					//					}

					*ptr1 = *ptr;
					ptr++;
					ptr1++;
				}

				ee.objects[ee.count_objects].object.length = ptr1 - ee.objects[ee.count_objects].object.ptr;

				//				ee.objects[ee.count_objects].subject = state.ptr_buff;
				ee.count_objects++;
			}

//			state.count_edges++;
			state.P = null;
			state.O = null;
		}

		if(*element == ']')
		{
			state.e = 0;
		}

		return;
	}
	else
	{
		if(state.e == 0)
		{
			version(trace_turtle_parser)
				printf("new node S=%s\n", element);

			Subject* new_subject = &state.nodes[state.count_nodes];

			if(state.pos_in_stack_nodes == 0)
			{
				state.stack_nodes[state.pos_in_stack_nodes] = new_subject;
			}

			new_subject.subject = fromStringz(element);

			state.roots[state.count_roots] = new_subject;
			state.count_roots++;

			state.count_nodes++;
		}
		else if(state.e == 1)
		{
			state.P = element;
			version(trace_turtle_parser)
				printf("P=%s\n", element);
		}
		else if(state.e == 2)
		{
			state.O_is_literal = true;
			state.O = element;
			version(trace_turtle_parser)
				printf("O=%s\n", element);
		}

	}

	state.e++;
}
