// TODO reasin -> exception ?

module pacahon.command.multiplexor;

private import core.stdc.stdio;
private import core.stdc.stdlib;
private import std.c.string;
private import std.date;
private import std.stdio;

private import tango.util.uuid.NamespaceGenV5;
private import tango.util.digest.Sha1;
private import tango.util.uuid.RandomGen;
private import tango.math.random.Twister;

private import trioplax.triple;
private import trioplax.TripleStorage;

private import pacahon.graph;
private import pacahon.n3.parser;

private import pacahon.authorization;
private import pacahon.know_predicates;

private import pacahon.utils;

/*
 * комманда добавления / изменения фактов в хранилище 
 */
Subject* put(Subject* message, Predicate* sender, char[] userId, TripleStorage ts, out bool isOk, out char[] reason)
{
	printf("command put\n");

	isOk = false;

	reason = cast(char[]) "добавление фактов не возможно";

	Subject* res;

	Predicate* args = message.getEdge(msg__args);

	printf("command put, args=%X \n", args);

	for(short ii; ii < args.count_objects; ii++)
	{
		char* args_text = cast(char*) args.objects[ii].object;
		int arg_size = strlen(args_text);
		//		printf("arg [%s], arg_size=%d\n", args_text, arg_size);

		Subject*[] graphs_on_put = parse_n3_string(cast(char*) args_text, arg_size);
		//		Subject*[] graphs_on_put = null;

		printf("arguments has been read\n");
		if(graphs_on_put is null)
		{
			reason = cast(char[]) "в сообщении нет фактов которые следует поместить в хранилище";
		}

		for(int jj = 0; jj < graphs_on_put.length; jj++)
		{
			Subject* graph = graphs_on_put[jj];

			//			printf("Subject* graph=%X\n", graph);

			// цикл по всем добавляемым субьектам
			/* Doc 2. если создается новый субъект, то ограничений по умолчанию нет
			 * Doc 3. если добавляются факты на уже созданного субъекта, то разрешено добавлять если добавляющий автор субъекта 
			 * или может быть вычислено разрешающее право на U данного субъекта. */

			char[] authorize_reason;

			if(authorize(userId, graph.subject, operation.CREATE | operation.UPDATE, ts, authorize_reason) == true)
			{
				// можно выполнять операцию по добавлению или обновлению фактов

				if(userId !is null)
				{
					// добавим признак dc:creator
					ts.addTriple(graph.subject, dc__creator, userId);
				}

				// основной цикл по добавлению фактов в хранилище из данного субьекта 
				// TODO сделать рекурсивное добавление
				for(int kk = 0; kk < graph.count_edges; kk++)
				{
					Predicate pp = graph.edges[kk];

					for(int ll = 0; ll < pp.count_objects; ll++)
					{
						Objectz oo = pp.objects[ll];

						if(oo.type == LITERAL || oo.type == URI)
							ts.addTriple(graph.subject, pp.predicate, oo.object);
						else
							ts.addTriple(graph.subject, pp.predicate, oo.subject.subject);
					}

				}

				reason = cast(char[]) "добавление фактов выполнено:" ~ authorize_reason;
				isOk = true;
			}
			else
			{
				//				printf("end authorize = false\n");
				reason = cast(char[]) "добавление фактов не возможно: " ~ authorize_reason;
			}

		}

		printf("command put is finish \n");

		return res;
	}

	return res;
}

Subject* get(Subject* message, Predicate* sender, char[] userId, TripleStorage ts, out bool isOk, out char[] reason)
{
	isOk = false;
	Subject* res;
	printf("command get\n");

	// ! для пущей безопасности, факты с предикатом [auth:credential] не отдавать !

	return res;
}

/*
 * команда получения тикета
 */
Subject* get_ticket(Subject* message, Predicate* sender, char[] userId, TripleStorage ts, out bool isOk, out char[] reason)
{
	printf("command get_ticket\n");

	isOk = false;

	reason = cast(char[]) "нет причин для выдачи сессионного билета";

	Subject out_graph;

	Subject* res;

	try
	{
		Predicate* arg = message.getEdge(msg__args);
		if(arg is null)
		{
			reason = cast(char[]) "аргументы " ~ msg__args ~ " не указаны";
			isOk = false;
			return null;
		}

		Subject* ss = arg.objects[0].subject;
		if(ss is null)
		{
			reason = cast(char[]) msg__args ~ " найден, но не заполнен";
			isOk = false;
			return null;
		}

		Predicate* login = ss.getEdge(auth__login);
		if(login is null || login.getFirstObject() is null || login.getFirstObject.length < 2)
		{
			reason = cast(char[]) "login не указан";
			isOk = false;
			return null;
		}

		Predicate* credential = ss.getEdge(auth__credential);
		if(credential is null || credential.getFirstObject() is null || credential.getFirstObject.length < 2)
		{
			reason = cast(char[]) "credential не указан";
			isOk = false;
			return null;
		}

		Triple[] search_mask = new Triple[2];

		search_mask[0].s = null;
		search_mask[0].p = auth__login;
		search_mask[0].o = login.getFirstObject;

		search_mask[1].s = null;
		search_mask[1].p = auth__credential;
		search_mask[1].o = credential.getFirstObject;

		char[][1] readed_predicate;
		readed_predicate[0] = auth__login;
		
		triple_list_element* iterator = ts.getTriplesOfMask(search_mask, readed_predicate);

		if(iterator !is null)
		{
			writeln ("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);
			// такой логин и пароль найдены, формируем тикет
			Twister rnd;
			rnd.seed;
			UuidGen rndUuid = new RandomGen!(Twister)(rnd);
			Uuid generated = rndUuid.next;
			writeln ("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);

			// сохраняем в хранилище
			char[] ticket_id = "auth:" ~ generated.toString;
			writeln(ticket_id);
			writeln ("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);

			ts.addTriple(ticket_id, rdf__type, ticket__Ticket);
			writeln ("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);
			ts.addTriple(ticket_id, ticket__accessor, iterator.triple.s);

			writeln ("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);
			auto now = UTCtoLocalTime(getUTCtime());

			ts.addTriple(ticket_id, ticket__when, timeToString(now));
			ts.addTriple(ticket_id, ticket__duration, cast(char[]) "3600");

			reason = cast(char[]) "login и password совпадают";
			isOk = true;

			out_graph.addPredicate(auth__ticket, ticket_id);
			res = &out_graph;
		}
		else
		{
			reason = cast(char[]) "login и password не совпадают";
			isOk = false;
			return null;
		}

		return res;
	}
	catch(Exception ex)
	{
		reason = cast(char[]) "ошибка при выдачи сессионного билет :" ~ ex.msg;
		isOk = false;

		return res;
	}
	finally
	{

		printf("	результат:");

		if(isOk == true)
			printf("сессионный билет выдан\n");
		else
			printf("отказанно\n");

		printf("	причина: %s\n", reason.ptr);

	}
}