module pacahon.command.multiplexor;

private import core.stdc.stdio;
private import std.c.string;
private import core.stdc.stdlib;

private import pacahon.graph;
private import pacahon.n3.parser;

private import trioplax.triple;
private import trioplax.TripleStorage;

private import pacahon.authorization;
private import pacahon.know_predicates;

/*
 * комманда добавления / изменения фактов в хранилище 
 */
Subject*[] put(Subject* message, Predicate* sender, char[] userId, TripleStorage ts)
{
	Subject*[] res;
	printf("command put\n");

	Predicate* args = message.getEdge(msg__args);

	for(short ii; ii < args.count_objects; ii++)
	{
		char* args_text = cast(char*) args.objects[ii].object;
		//		printf("arg [%s]\n", args_text);

		int arg_size = strlen(args_text);

		Subject*[] graphs_on_put = parse_n3_string(cast(char*) args_text, arg_size);

		for(int jj = 0; jj < graphs_on_put.length; jj++)
		{
			Subject* graph = graphs_on_put[jj];

			// цикл по всем добавляемым субьектам
			/* Doc 2. если создается новый субъект, то ограничений по умолчанию нет
			 * Doc 3. если добавляются факты на уже созданного субъекта, то разрешено добавлять если добавляющий автор субъекта 
			 * или может быть вычислено разрешающее право на U данного субъекта. */

			if(authorize(userId, graph.subject, operation.CREATE | operation.UPDATE, ts) == true)
			{
				// можно выполнять операцию по добавлению или обновлению фактов

				if(userId !is null)
				{
					// добавим признак dc:creator
					ts.addTriple(graph.subject, dc__creator, userId);
				}

				for(int kk = 0; kk < graph.count_edges; kk++)
				{
					Predicate* pp = graph.edges[kk];

					for(int ll = 0; ll < pp.count_objects; ll++)
					{
						Objectz oo = pp.objects[ll];

						if(oo.type == LITERAL || oo.type == URI)
							ts.addTriple(graph.subject, pp.predicate, oo.object);
						else
							ts.addTriple(graph.subject, pp.predicate, oo.subject.subject);
					}

				}
			}
		}

		printf("command put is finish \n");

		return graphs_on_put;
		//		printf(triples_on_put[0].toString());
		//		print_graph(triples_on_put[0]);
		//		triples_on_put[0].toString();
	}

	return res;
}

Subject*[] get(Subject* message, Predicate* sender, char[] userId, TripleStorage ts)
{
	Subject*[] res;
	printf("command get\n");

	// ! факты с предикатом [auth:credential] не возвращать !

	return res;
}

/*
 * команда получения тикета
 */
Subject*[] get_ticket(Subject* message, Predicate* sender, char[] userId, TripleStorage ts)
{
	printf("command get_ticket\n");
	
	bool isOk = false;

	char[] reason = cast(char[]) "нет причин для выдачи тикета";

	Subject*[] res;

	try
	{
		Predicate* login = message.getEdge(auth__login);
		Predicate* credential = message.getEdge(auth__credential);

		if(login is null || login.getFirstObject() is null || login.getFirstObject.length < 2)
		{
			reason = cast(char[]) "login не указан";
			isOk = false;
			return null;
		}

		if(credential is null || credential.getFirstObject() is null || credential.getFirstObject.length < 2)
		{
			reason = cast(char[]) "credential не указан";
			isOk = false;
			return null;
		}

		Triple[] search_mask = new Triple[2];
		
		search_mask[0].s = null;
		search_mask[0].p = auth__login.ptr;
		search_mask[0].o = login.getFirstObject.ptr; 
		
		search_mask[1].s = null;
		search_mask[1].p = auth__credential.ptr;
		search_mask[1].o = credential.getFirstObject.ptr;
		
		char[][1] readed_predicate;
		readed_predicate[0] = auth__login;
		
		triple_list_element* iterator = ts.getTriplesOfMask(search_mask, readed_predicate);

		return res;
	}
	catch(Exception ex)
	{
		reason = cast(char[]) "ошибка при вычислении прав :" ~ ex.msg;
		isOk = false;

		return res;
	}
	finally
	{

		printf("	результат:");

		if(isOk == true)
			printf("тикет выдан\n");
		else
			printf("отказанно\n");

		printf("	причина: %s\n", reason.ptr);

	}
}