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

private import std.datetime;

private import trioplax.triple;
private import trioplax.TripleStorage;

private import pacahon.graph;
private import pacahon.n3.parser;

private import pacahon.authorization;
private import pacahon.know_predicates;

private import pacahon.utils;
private import trioplax.Logger;

Logger log;

static this()
{
	log = new Logger("pacahon.log", "multiplexor");
}

byte trace_msg[10][30];

/*
 * комманда добавления / изменения фактов в хранилище 
 * TODO !в данный момент обрабатывает только одноуровневые графы
 */
Subject put(Subject message, Predicate* sender, char[] userId, TripleStorage ts, out bool isOk, out char[] reason)
{
	//	trace_msg[0] = 1;
	//	trace_msg[0][4] = 1;
	//	trace_msg[0][5] = 1;
	//	trace_msg[0][6] = 1;

	if(trace_msg[0][0] == 1)
		log.trace("command put");

	isOk = false;

	reason = cast(char[]) "добавление фактов не возможно";

	Subject res;

	Predicate* args = message.getEdge(msg__args);

	if(trace_msg[0][1] == 1)
		log.trace("command put, args=%X ", args);

	for(short ii; ii < args.count_objects; ii++)
	{
		Subject[] graphs_on_put = null;

		if(trace_msg[0][2] == 1)
			log.trace("args.objects[%d].type = %d", ii, args.objects[ii].type);

		if(args.objects[ii].type == OBJECT_TYPE.CLUSTER)
		{
			graphs_on_put = args.objects[ii].cluster.graphs_of_subject.values;
		}
		else if(args.objects[ii].type == OBJECT_TYPE.LITERAL)
		{
			char* args_text = cast(char*) args.objects[ii].object;
			int arg_size = strlen(args_text);

			//	if(trace_msg[0][2] == 1)
			//		printf("arg [%s], arg_size=%d", args.objects[ii].object, arg_size);

			graphs_on_put = parse_n3_string(cast(char*) args_text, arg_size);
		}

		if(trace_msg[0][3] == 1)
			log.trace("arguments has been read");

		if(graphs_on_put is null)
		{
			reason = cast(char[]) "в сообщении нет фактов которые следует поместить в хранилище";
		}

		// фаза I, добавим основные данные
		for(int jj = 0; jj < graphs_on_put.length; jj++)
		{
			Subject graph = graphs_on_put[jj];
			set_hashed_data(graph);

			Predicate* type = graph.getEdge(cast(char[]) "a");
			if(type is null)
				type = graph.getEdge(rdf__type);

			if((rdf__Statement in type.objects_of_value) is null)
			{
				if(trace_msg[0][4] == 1)
					log.trace("adding subject=%s", graph.subject);

				// цикл по всем добавляемым субьектам
				/* Doc 2. если создается новый субъект, то ограничений по умолчанию нет
				 * Doc 3. если добавляются факты на уже созданного субъекта, то разрешено добавлять если добавляющий автор субъекта 
				 * или может быть вычислено разрешающее право на U данного субъекта. */

				char[] authorize_reason;

				if(authorize(userId, graph.subject, operation.CREATE | operation.UPDATE, ts, authorize_reason) == true)
				{
					if(userId !is null)
					{
						// добавим признак dc:creator
						ts.addTriple(graph.subject, dc__creator, userId);
					}

					// основной цикл по добавлению фактов в хранилище из данного субьекта 
					// TODO сделать рекурсивное добавление (для многоуровневых графов)
					for(int kk = 0; kk < graph.count_edges; kk++)
					{
						Predicate pp = graph.edges[kk];

						for(int ll = 0; ll < pp.count_objects; ll++)
						{
							Objectz oo = pp.objects[ll];

							if(oo.type == OBJECT_TYPE.LITERAL || oo.type == OBJECT_TYPE.URI)
								ts.addTriple(graph.subject, pp.predicate, oo.object, oo.lang);
							else
								ts.addTriple(graph.subject, pp.predicate, oo.subject.subject, oo.lang);
						}

					}

					reason = cast(char[]) "добавление фактов выполнено:" ~ authorize_reason;
					isOk = true;
				}
				else
				{
					reason = cast(char[]) "добавление фактов не возможно: " ~ authorize_reason;
					if(trace_msg[0][6] == 1)
						log.trace("autorize=%s", reason);
				}

			}
		}

		// фаза I, добавим реифицированные данные 
		// !TODO авторизация для реифицированных данных пока не выполняется
		for(int jj = 0; jj < graphs_on_put.length; jj++)
		{
			Subject graph = graphs_on_put[jj];

			Predicate* type = graph.getEdge(cast(char[]) "a");
			if(type is null)
				type = graph.getEdge(rdf__type);

			if((rdf__Statement in type.objects_of_value))
			{
				// определить, несет ли в себе субьект, реифицированные данные (a rdf:Statement)
				// если, да то добавить их в хранилище через метод addTripleToReifedData
				Predicate* r_subject = graph.getEdge(cast(char[]) "rdf:subject");
				Predicate* r_predicate = graph.getEdge(cast(char[]) "rdf:predicate");
				Predicate* r_object = graph.getEdge(cast(char[]) "rdf:object");

				if(r_subject !is null && r_predicate !is null && r_object !is null)
				{
					char[] sr_subject = r_subject.getFirstObject();
					char[] sr_predicate = r_predicate.getFirstObject();
					char[] sr_object = r_object.getFirstObject();

					for(int kk = 0; kk < graph.count_edges; kk++)
					{
						Predicate* pp = &graph.edges[kk];

						if(pp != r_subject && pp != r_predicate && pp != r_object && pp != type)
						{
							for(int ll = 0; ll < pp.count_objects; ll++)
							{
								Objectz oo = pp.objects[ll];

								if(oo.type == OBJECT_TYPE.LITERAL || oo.type == OBJECT_TYPE.URI)
									ts.addTripleToReifedData(sr_subject, sr_predicate, sr_object, pp.predicate, oo.object, oo.lang);
								else
									ts.addTripleToReifedData(sr_subject, sr_predicate, sr_object, pp.predicate, oo.subject.subject, oo.lang);
							}
						}

					}
				}
			}
		}

		if(trace_msg[0][7] == 1)
			log.trace("command put is finish");

		return res;
	}

	return res;
}

/*
 * команда получения тикета
 */
bool trace__get_ticket = false;
bool timing__get_ticket = true;

Subject get_ticket(Subject message, Predicate* sender, char[] userId, TripleStorage ts, out bool isOk, out char[] reason)
{
	StopWatch sw;
	sw.start();

	if(trace__get_ticket)
		printf("command get_ticket\n");

	isOk = false;

	reason = cast(char[]) "нет причин для выдачи сессионного билета";

	Subject res = new Subject();

	try
	{
		Predicate* arg = message.getEdge(msg__args);
		if(arg is null)
		{
			reason = cast(char[]) "аргументы " ~ msg__args ~ " не указаны";
			isOk = false;
			return null;
		}

		Subject ss = arg.objects[0].subject;
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

		search_mask[0] = new Triple;
		search_mask[0].s = null;
		search_mask[0].p = auth__login;
		search_mask[0].o = login.getFirstObject;

		search_mask[1] = new Triple;
		search_mask[1].s = null;
		search_mask[1].p = auth__credential;
		search_mask[1].o = credential.getFirstObject;

		byte[char[]] readed_predicate;
		readed_predicate[cast(immutable) auth__login] = true;

		triple_list_element iterator = ts.getTriplesOfMask(search_mask, readed_predicate);

		if(iterator !is null)
		{
			//						writeln("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);
			// такой логин и пароль найдены, формируем тикет
			Twister rnd;
			rnd.seed;
			UuidGen rndUuid = new RandomGen!(Twister)(rnd);
			Uuid generated = rndUuid.next;
			//						writeln("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);

			// сохраняем в хранилище
			char[] ticket_id = "auth:" ~ generated.toString;
			writeln(ticket_id);
			//						writeln("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);

			ts.addTriple(ticket_id, rdf__type, ticket__Ticket);
			//						writeln("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);
			ts.addTriple(ticket_id, ticket__accessor, iterator.triple.s);

			//						writeln("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);
			auto now = UTCtoLocalTime(getUTCtime());

			ts.addTriple(ticket_id, ticket__when, timeToString(now));
			ts.addTriple(ticket_id, ticket__duration, cast(char[]) "3600");

			reason = cast(char[]) "login и password совпадают";
			isOk = true;

			res.addPredicate(auth__ticket, ticket_id);
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

		if(trace__get_ticket)
		{
			printf("	результат:");

			if(isOk == true)
				printf("сессионный билет выдан\n");
			else
				printf("отказанно\n");

			printf("	причина: %s\n", reason.ptr);
		}

		if(timing__get_ticket)
		{
			sw.stop();
			printf("total time command get_ticket: %d [µs]\n", cast(long) sw.peek().microseconds);
		}

	}
}

public void get(Subject message, Predicate* sender, char[] userId, TripleStorage ts, out bool isOk, out char[] reason, ref GraphCluster res)
{
	StopWatch sw;
	sw.start();

	// в качестве аргумента - шаблон для выборки
	// query:get - обозначает что будет возвращено значение соответствующего предиката
	// TODO ! в данный момент метод обрабатывает только одноуровневые шаблоны

	isOk = false;

	if(trace_msg[2][0] == 1)
		printf("command get\n");

	reason = cast(char[]) "запрос не может быть выполнен";

	Predicate* args = message.getEdge(msg__args);

	if(trace_msg[2][1] == 1)
		printf("command get, args=%X \n", args);

	for(short ii; ii < args.count_objects; ii++)
	{
		char* args_text = cast(char*) args.objects[ii].object;
		int arg_size = strlen(args_text);

		if(trace_msg[2][2] == 1)
			printf("*** arg [%s], arg_size=%d\n", args_text, arg_size);

		Subject[] graphs_as_template = parse_n3_string(cast(char*) args_text, arg_size);

		if(trace_msg[2][3] == 1)
			printf("*** arguments has been read\n");

		if(graphs_as_template is null)
		{
			reason = cast(char[]) "в сообщении отсутствует граф-шаблон";
		}

		for(int jj = 0; jj < graphs_as_template.length; jj++)
		{
			Subject graph = graphs_as_template[jj];

			if(trace_msg[2][4] == 1)
				writeln("*** graph.subject=", graph.subject);

			byte[char[]] readed_predicate;

			Triple[] search_mask = new Triple[graph.count_edges];
			int search_mask_length = 0;

			// найдем предикаты, которые следует вернуть
			for(int kk = 0; kk < graph.count_edges; kk++)
			{
				Predicate pp = graph.edges[kk];
				Triple statement = null;

				for(int ll = 0; ll < pp.count_objects; ll++)
				{
					Objectz oo = pp.objects[ll];
					if(oo.type == OBJECT_TYPE.LITERAL || oo.type == OBJECT_TYPE.URI)
					{
						if(oo.object == "query:get_reifed")
						{
							// требуются так-же реифицированные данные по этому полю
							// данный предикат добавить в список возвращаемых
							if(trace_msg[2][5] == 1)
								writeln("*** данный предикат и реифицированные данные добавим в список возвращаемых: ", pp.predicate);

							readed_predicate[cast(immutable) pp.predicate] = _GET_REIFED;

							if(trace_msg[2][6] == 1)
								writeln("*** readed_predicate.length=", readed_predicate.length);
						}
						else if(oo.object == "query:get")
						{
							// данный предикат добавить в список возвращаемых
							if(trace_msg[2][7] == 1)
								writeln("*** данный предикат добавим в список возвращаемых: ", pp.predicate);

							readed_predicate[cast(immutable) pp.predicate] = _GET;

							if(trace_msg[2][8] == 1)
								writeln("*** readed_predicate.length=", readed_predicate.length);
						}
						else
						{
							if(statement is null)
								statement = new Triple;

							statement.p = pp.predicate;

							if(trace_msg[2][9] == 1)
								writeln("*** p=", statement.p);

							statement.o = oo.object;

							if(trace_msg[2][10] == 1)
								writeln("*** o=", statement.o);
						}

					}

				}
				if((graph.subject != "query:any" && statement !is null) || (graph.subject != "query:any" && search_mask_length == 0))
				{
					if(trace_msg[2][11] == 1)
						writeln("*** subject=", graph.subject);

					if(statement is null)
						statement = new Triple;

					statement.s = graph.subject;

					if(trace_msg[2][12] == 1)
					{
						writeln("*** s=", statement.s);
					}
				}

				if(statement !is null)
				{
					search_mask[search_mask_length] = statement;
					search_mask_length++;
					if(trace_msg[2][13] == 1)
					{
						writeln("*** search_mask_length=", search_mask_length);
					}
				}

			}

			if(trace_msg[2][14] == 1)
				writeln("*** mask formed");

			search_mask.length = search_mask_length;

			triple_list_element iterator = ts.getTriplesOfMask(search_mask, readed_predicate);

			while(iterator !is null)
			{
				if(trace_msg[2][15] == 1)
					writeln("GET: f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);

				res.addTriple(iterator.triple.s, iterator.triple.p, iterator.triple.o, iterator.triple.lang);

				iterator = iterator.next_triple_list_element;
			}

			if(trace_msg[2][16] == 1)
				writeln("*** авторизуем найденные субьекты, для пользователя %s", userId);

			// авторизуем найденные субьекты
			foreach(s; res.graphs_of_subject)
			{
				char[] authorize_reason;
				bool result_of_az = authorize(userId, s.subject, operation.READ, ts, authorize_reason);

				if(result_of_az == false)
				{
					if(trace_msg[2][17] == 1)
						writeln("AZ: s= ", s.subject, " -> ", authorize_reason);

					s.count_edges = 0;
					s.subject = null;

					if(trace_msg[2][18] == 1)
						writeln("remove from list");
				}

			}

			reason = cast(char[]) "запрос выполнен";

			isOk = true;

		}

		if(trace_msg[2][19] == 1)
		{
			sw.stop();
			printf("total time command get: %d [µs]\n", cast(long) sw.peek().microseconds);
		}
	}

	// TODO !для пущей безопасности, факты с предикатом [auth:credential] не отдавать !

	return;
}
