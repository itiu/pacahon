module pacahon.n3.parser;

import std.string;
import std.c.stdlib;
import std.c.string;
import std.stdio;

import pacahon.graph;

int def_size_out_array = 100;

struct state_struct
{
	char* P;
	void* O;
	bool O_is_literal;

	byte e;

	char* res_buff;

	Subject nodes[];
	short count_nodes;

	Subject* roots[];
	short count_roots;

	Subject* stack_nodes[8];
	byte pos_in_stack_nodes;

	PredicateObject edges[];
	int count_edges;

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

public Subject*[] parse(char* src, int len, char* res_buff)
{
	char* ptr = src - 1;
	char* new_line_ptr = src;
	char* element;
	char ch = *src;
	char prev_ch = 0;
	state_struct state;

	state.P = null;
	state.O = null;
	state.e = 0;
	state.res_buff = res_buff;
	state.pos_in_stack_nodes = 0;

	state.count_nodes = 0;
	state.count_edges = 0;
	state.nodes = new Subject[def_size_out_array];
	state.roots = new Subject*[def_size_out_array];
	state.edges = new PredicateObject[def_size_out_array];

	while(ch != 0)
	{
		prev_ch = ch;
		ptr++;
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
				while(ch != '\n')
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
				while(ch != '\n')
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
				while(ch == ' ' || ch == 9)
				{
					ptr++;
					ch = *ptr;
				}

				// это начало элемента
				element = ptr;

				if(*element == '"')
				{
					ptr++;
					ch = *ptr;
					while(ch != '"')
					{
						ptr++;
						ch = *ptr;
					}
				}

				while(ch != ' ' && ch != '\n')
				{
					ptr++;
					ch = *ptr;
				}

				// окончание элемента отметим 0
				*ptr = 0;

				ptr++;
				ch = *ptr;

				if(*element == 0)
					break;

				next_element(element, &state);

				//				printf("[%s]\n", element);
			}

		}

	}
	state.roots.length = state.count_roots;

	//        printf ("len res buff=%d res_buff=%s\n", state.res_buff - res_buff, res_buff);
	/*
	 for(short i = 0; i < state.count_parent_child; i++)
	 {
	 short parent = state.parent[i];

	 // подсчитаем количество потомков для этого родителя
	 short count_childs = 0;

	 for(short ii = 0; ii < state.count_parent_child; ii++)
	 {
	 if(state.parent[ii] == parent)
	 {
	 count_childs++;
	 }
	 }

	 if(count_childs > 0)
	 {
	 Subject* ss = &nodes[parent];
	 if(ss.outGoingEdges is null)
	 {
	 ss.outGoingEdges = new PredicateObject*[count_childs];
	 //			printf("++10\n");
	 }

	 short stored_childs = 0;

	 // сохраним этих потомков в список родителя
	 for(short ii = 0; ii < state.count_parent_child; ii++)
	 {
	 if(state.parent[ii] == parent)
	 {
	 ss.outGoingEdges[stored_childs] = &(state.edges[ii]);
	 stored_childs++;
	 }
	 }
	 }
	 */
	//				printf("paren-child %d-%d\n", state.parent[i], state.child[i]);
	/*		
	 short qq = state.parent[i];
	 short aa = state.child[i];
	 if(state.nodes[qq].subject is null)
	 {
	 if(state.edges[aa].object_as_literal == true)
	 printf("%X %s %s\n", &state.nodes[qq], state.edges[aa].predicate, state.edges[aa].object);
	 else
	 printf("%X %s %X\n", &state.nodes[qq], state.edges[aa].predicate, state.edges[aa].object);
	 }
	 else
	 {
	 if(state.edges[aa].object_as_literal == true)
	 printf("%s %s %s\n", state.nodes[qq].subject, state.edges[aa].predicate, state.edges[aa].object);
	 else
	 printf("%s %s %X\n", state.nodes[qq].subject, state.edges[aa].predicate, state.edges[aa].object);
	 }
	 */
	//	}
	return state.roots;
}

private void next_element(char* element, state_struct* state)
{
	if(*element == ']')
	{
		state.pos_in_stack_nodes--;
	}

	if(*element == ';' || *element == '.' || *element == '[' || *element == ']')
	{
		state.e = 1;
		if(*element == '.')
		{
			state.e = 0;
		}

		if(state.P !is null)
		{
			//			printf("[%s %s %s]\n", state.nodes[state.pos_in_stack_nodes].subject, state.P, state.O);
			Subject* ss = state.stack_nodes[state.pos_in_stack_nodes];

			if(ss.outGoingEdges is null)
				ss.outGoingEdges = new PredicateObject*[50];

			int Pl = strlen(state.P) + 1;

			//						printf("count_edges=%d\n", state.count_edges);
			PredicateObject* ee = &state.edges[state.count_edges];

			strncpy(state.res_buff, state.P, Pl);
			ee.predicate = state.res_buff;
			state.res_buff += Pl;

			ss.outGoingEdges[ss.count_edges] = ee;
			ss.count_edges++;

			// сохранить зависимости
			//			state.parent[state.count_parent_child] = state.stack_nodes[state.pos_in_stack_nodes];
			//			state.child[state.count_parent_child] = state.count_edges;
			//			state.count_parent_child++;

			if(*element == '[')
			{
				// создадим новую ноду				
				state.count_nodes++;
				Subject* new_nodes = &state.nodes[state.count_nodes];

				// и сохраним ее на стеке
				state.pos_in_stack_nodes++;
				state.stack_nodes[state.pos_in_stack_nodes] = new_nodes;

				// сохраним ее в edges
				ee.object = new_nodes;
				ee.object_as_literal = false;

				state.count_nodes++;
			}
			else
			{
				int Ol = strlen(cast(char*) state.O) + 1;

				strncpy(state.res_buff, cast(char*) state.O, Ol);
				ee.object = state.res_buff;
				state.res_buff += Ol;
			}

			state.count_edges++;
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
			//			printf("new node S=%s\n", element);
			Subject* new_subject = &state.nodes[state.count_nodes];

			if(state.pos_in_stack_nodes == 0)
			{
				state.stack_nodes[state.pos_in_stack_nodes] = new_subject;
			}

			int Sl = strlen(element) + 1;
			strncpy(state.res_buff, element, Sl);
			new_subject.subject = state.res_buff;

			state.roots[state.count_roots] = new_subject;
			state.count_roots++;

			state.res_buff += Sl;
			state.count_nodes++;
		}
		else if(state.e == 1)
		{
			state.P = element;
			//			printf("P=%s\n", element);
		}
		else if(state.e == 2)
		{
			state.O_is_literal = true;
			state.O = element;
			//			printf("O=%s\n", element);
		}

	}

	state.e++;
}
