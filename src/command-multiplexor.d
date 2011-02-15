// TODO reason -> exception ?

module pacahon.command.multiplexor;

private import core.stdc.stdio;
private import core.stdc.stdlib;
private import std.c.string;
//private import std.date;

private import std.datetime; // 2.052

private import std.stdio;
private import std.outbuffer;

private import tango.util.uuid.NamespaceGenV5;
private import tango.util.digest.Sha1;
private import tango.util.uuid.RandomGen;
private import tango.math.random.Twister;

private import std.datetime;

private import trioplax.triple;
private import trioplax.TripleStorage;

private import pacahon.graph;

private import pacahon.n3.parser;
private import pacahon.json_ld.parser;

private import pacahon.authorization;
private import pacahon.know_predicates;

private import pacahon.utils;
private import trioplax.Logger;

private import pacahon.log_msg;

Logger log;

static this()
{
	log = new Logger("pacahon.log", "multiplexor");
}

/*
 * комманда добавления / изменения фактов в хранилище 
 * TODO !в данный момент обрабатывает только одноуровневые графы
 */
Subject put(Subject message, Predicate* sender, string userId, TripleStorage ts, out bool isOk, out string reason)
{
	if(trace_msg[31] == 1)
		log.trace("command put");

	isOk = false;

	reason = "добавление фактов не возможно";

	Subject res;

	Predicate* args = message.getEdge(msg__args);

	if(trace_msg[32] == 1)
		log.trace("command put, args=%X ", args);

	for(short ii; ii < args.count_objects; ii++)
	{
		Subject[] graphs_on_put = null;

		if(trace_msg[33] == 1)
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

		if(trace_msg[64] == 1)
		{
			OutBuffer outbuff = new OutBuffer();
			toJson_ld(graphs_on_put, outbuff);
			outbuff.write(0);
			ubyte[] bb = outbuff.toBytes();
			log.trace_io(true, cast(byte*) bb, bb.length);
		}

		if(trace_msg[34] == 1)
			log.trace("arguments has been read");

		if(graphs_on_put is null)
		{
			reason = "в сообщении нет фактов которые следует поместить в хранилище";
		}

		// фаза I, добавим основные данные
		for(int jj = 0; jj < graphs_on_put.length; jj++)
		{
			Subject graph = graphs_on_put[jj];
			set_hashed_data(graph);

			Predicate* type = graph.getEdge("a");
			if(type is null)
				type = graph.getEdge(rdf__type);

			if((rdf__Statement in type.objects_of_value) is null)
			{
				if(trace_msg[35] == 1)
					log.trace("adding subject=%s", graph.subject);

				// цикл по всем добавляемым субьектам
				/* Doc 2. если создается новый субъект, то ограничений по умолчанию нет
				 * Doc 3. если добавляются факты на уже созданного субъекта, то разрешено добавлять если добавляющий автор субъекта 
				 * или может быть вычислено разрешающее право на U данного субъекта. */

				string authorize_reason;

				if(authorize(userId, graph.subject, operation.CREATE | operation.UPDATE, ts, authorize_reason) == true)
				{
					if(userId !is null)
					{
						// добавим признак dc:creator
						ts.addTriple(new Triple(graph.subject, dc__creator, userId));
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
								ts.addTriple(new Triple(graph.subject, pp.predicate, oo.object, oo.lang));
							else
								ts.addTriple(new Triple(graph.subject, pp.predicate, oo.subject.subject, oo.lang));
						}

					}

					reason = "добавление фактов выполнено:" ~ authorize_reason;
					isOk = true;
				}
				else
				{
					reason = "добавление фактов не возможно: " ~ authorize_reason;
					if(trace_msg[36] == 1)
						log.trace("autorize=%s", reason);
				}

			}
		}

		// фаза I, добавим реифицированные данные 
		// !TODO авторизация для реифицированных данных пока не выполняется
		for(int jj = 0; jj < graphs_on_put.length; jj++)
		{
			Subject graph = graphs_on_put[jj];

			Predicate* type = graph.getEdge("a");
			if(type is null)
				type = graph.getEdge(rdf__type);

			if((rdf__Statement in type.objects_of_value))
			{
				// определить, несет ли в себе субьект, реифицированные данные (a rdf:Statement)
				// если, да то добавить их в хранилище через метод addTripleToReifedData
				Predicate* r_subject = graph.getEdge("rdf:subject");
				Predicate* r_predicate = graph.getEdge("rdf:predicate");
				Predicate* r_object = graph.getEdge("rdf:object");

				if(r_subject !is null && r_predicate !is null && r_object !is null)
				{
					Triple reif = new Triple(r_subject.getFirstObject(), r_predicate.getFirstObject(), r_object.getFirstObject());

					for(int kk = 0; kk < graph.count_edges; kk++)
					{
						Predicate* pp = &graph.edges[kk];

						if(pp != r_subject && pp != r_predicate && pp != r_object && pp != type)
						{
							for(int ll = 0; ll < pp.count_objects; ll++)
							{
								Objectz oo = pp.objects[ll];

								if(oo.type == OBJECT_TYPE.LITERAL || oo.type == OBJECT_TYPE.URI)
									ts.addTripleToReifedData(reif, pp.predicate, oo.object, oo.lang);
								else
									ts.addTripleToReifedData(reif, pp.predicate, oo.subject.subject, oo.lang);
							}
						}

					}
				}
			}
		}

		if(trace_msg[37] == 1)
			log.trace("command put is finish");

		return res;
	}

	return res;
}

/*
 * команда получения тикета
 */

Subject get_ticket(Subject message, Predicate* sender, string userId, TripleStorage ts, out bool isOk, out string reason)
{
	StopWatch sw;
	sw.start();

	if(trace_msg[38] == 1)
		log.trace("command get_ticket");

	isOk = false;

	reason = "нет причин для выдачи сессионного билета";

	Subject res = new Subject();

	try
	{
		Predicate* arg = message.getEdge(msg__args);
		if(arg is null)
		{
			reason = "аргументы " ~ msg__args ~ " не указаны";
			isOk = false;
			return null;
		}

		Subject ss = arg.objects[0].subject;
		if(ss is null)
		{
			reason = msg__args ~ " найден, но не заполнен";
			isOk = false;
			return null;
		}

		Predicate* login = ss.getEdge(auth__login);
		if(login is null || login.getFirstObject() is null || login.getFirstObject.length < 2)
		{
			reason = "login не указан";
			isOk = false;
			return null;
		}

		Predicate* credential = ss.getEdge(auth__credential);
		if(credential is null || credential.getFirstObject() is null || credential.getFirstObject.length < 2)
		{
			reason = "credential не указан";
			isOk = false;
			return null;
		}

		Triple[] search_mask = new Triple[2];

		search_mask[0] = new Triple;
		search_mask[0].S = null;
		search_mask[0].P = auth__login;
		search_mask[0].O = login.getFirstObject;

		search_mask[1] = new Triple;
		search_mask[1].S = null;
		search_mask[1].P = auth__credential;
		search_mask[1].O = credential.getFirstObject;

		byte[char[]] readed_predicate;
		readed_predicate[auth__login] = true;

		List iterator = ts.getTriplesOfMask(search_mask, readed_predicate);

		if(iterator !is null && iterator.lst.data.length > 0)
		{
			//						writeln("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);
			// такой логин и пароль найдены, формируем тикет
			Twister rnd;
			rnd.seed;
			UuidGen rndUuid = new RandomGen!(Twister)(rnd);
			Uuid generated = rndUuid.next;
			//						writeln("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);

			// сохраняем в хранилище
			string ticket_id = "auth:" ~ cast(immutable) generated.toString;
			//						writeln("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);
			ts.addTriple(new Triple(ticket_id, rdf__type, ticket__Ticket));
			//						writeln("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);
			ts.addTriple(new Triple(ticket_id, ticket__accessor, iterator.lst.data[0].S));

			//						writeln("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);
			ts.addTriple(new Triple(ticket_id, ticket__when, getNowAsString()));
			ts.addTriple(new Triple(ticket_id, ticket__duration, "4000"));

			reason = "login и password совпадают";
			isOk = true;

			res.addPredicate(auth__ticket, ticket_id);
		}
		else
		{
			reason = "login и password не совпадают";
			isOk = false;
			return null;
		}
		return res;
	}
	catch(Exception ex)
	{
		reason = "ошибка при выдачи сессионного билет :" ~ ex.msg;
		isOk = false;

		return res;
	}
	finally
	{

		if(trace_msg[39] == 1)
		{
			if(isOk == true)
				log.trace("результат: сессионный билет выдан, причина: %s ", reason);
			else
				log.trace("результат: отказанно, причина: %s", reason);
		}

		if(trace_msg[40] == 1)
		{
			sw.stop();

			version(dmd2_052)
				long t = cast(long) sw.peek().usecs;
			else
				long t = cast(long) sw.peek().microseconds;

			log.trace("total time command get_ticket: %d [µs]", t);
		}
	}
}

public void get(Subject message, Predicate* sender, string userId, TripleStorage ts, out bool isOk, out string reason, ref GraphCluster res)
{
	StopWatch sw;
	sw.start();

	// в качестве аргумента - шаблон для выборки
	// query:get - обозначает что будет возвращено значение соответствующего предиката
	// TODO ! в данный момент метод обрабатывает только одноуровневые шаблоны

	isOk = false;

	if(trace_msg[41] == 1)
		log.trace("command get");

	reason = "запрос не может быть выполнен";

	Predicate* args = message.getEdge(msg__args);

	if(trace_msg[42] == 1)
		log.trace("command get, args=%X", args);

	for(short ii; ii < args.count_objects; ii++)
	{
		if(trace_msg[43] == 1)
			log.trace("args.objects[%d].type = %d", ii, args.objects[ii].type);

		Subject[] graphs_as_template;

		if(args.objects[ii].type == OBJECT_TYPE.CLUSTER)
		{
			graphs_as_template = args.objects[ii].cluster.graphs_of_subject.values;
		}
		else if(args.objects[ii].type == OBJECT_TYPE.LITERAL)
		{
			char* args_text = cast(char*) args.objects[ii].object;
			int arg_size = strlen(args_text);

			if(trace_msg[44] == 1)
				log.trace("arg [%s], arg_size=%d", args.objects[ii].object, arg_size);

			graphs_as_template = parse_n3_string(cast(char*) args_text, arg_size);

			if(trace_msg[45] == 1)
				log.trace("arguments has been read");

			if(graphs_as_template is null)
			{
				reason = "в сообщении отсутствует граф-шаблон";
			}
		}

		for(int jj = 0; jj < graphs_as_template.length; jj++)
		{
			Subject graph = graphs_as_template[jj];

			if(trace_msg[46] == 1)
				log.trace("graph.subject=%s", graph.subject);

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
							if(trace_msg[47] == 1)
								log.trace("данный предикат и реифицированные данные добавим в список возвращаемых: %s", pp.predicate);

							readed_predicate[cast(immutable) pp.predicate] = field.GET_REIFED;

							if(trace_msg[48] == 1)
								log.trace("readed_predicate.length=%d", readed_predicate.length);
						}
						else if(oo.object == "query:get")
						{
							// данный предикат добавить в список возвращаемых
							if(trace_msg[49] == 1)
								log.trace("данный предикат добавим в список возвращаемых: %s", pp.predicate);

							readed_predicate[cast(immutable) pp.predicate] = field.GET;

							if(trace_msg[50] == 1)
								log.trace("readed_predicate.length=%d", readed_predicate.length);
						}
						else
						{
							if(statement is null)
								statement = new Triple;

							statement.P = pp.predicate;

							if(trace_msg[51] == 1)
								log.trace("p=%s", statement.P);

							statement.O = oo.object;

							if(trace_msg[52] == 1)
								log.trace("o=%s", statement.O);
						}

					}

				}
				if((graph.subject != "query:any" && statement !is null) || (graph.subject != "query:any" && search_mask_length == 0))
				{
					if(trace_msg[53] == 1)
						log.trace("subject=%s", graph.subject);

					if(statement is null)
						statement = new Triple;

					statement.S = graph.subject;

					if(trace_msg[54] == 1)
					{
						log.trace("s=%s", statement.S);
					}
				}

				if(statement !is null)
				{
					search_mask[search_mask_length] = statement;
					search_mask_length++;
					if(trace_msg[55] == 1)
					{
						log.trace("search_mask_length=%d", search_mask_length);
					}
				}

			}

			if(trace_msg[56] == 1)
				log.trace("mask formed");

			search_mask.length = search_mask_length;

			List iterator = ts.getTriplesOfMask(search_mask, readed_predicate);

			foreach(triple; iterator.lst.data)
			{
				if(trace_msg[57] == 1)
					log.trace("GET: f.read tr... S:%s P:%s O:%s lang:%d", triple.S, triple.P, triple.O, triple.lang);

				res.addTriple(triple.S, triple.P, triple.O, triple.lang);
			}

			if(trace_msg[58] == 1)
				log.trace("авторизуем найденные субьекты, для пользователя %s", userId);

			// авторизуем найденные субьекты
			foreach(s; res.graphs_of_subject)
			{
				string authorize_reason;
				bool result_of_az = authorize(userId, s.subject, operation.READ, ts, authorize_reason);

				if(result_of_az == false)
				{
					if(trace_msg[59] == 1)
						log.trace("AZ: s=%s -> %s ", s.subject, authorize_reason);

					s.count_edges = 0;
					s.subject = null;

					if(trace_msg[60] == 1)
						log.trace("remove from list");
				}

			}

			reason = "запрос выполнен";

			isOk = true;

		}

		if(trace_msg[61] == 1)
		{
			sw.stop();
			version(dmd2_052)
				long t = cast(long) sw.peek().usecs;
			else
				long t = cast(long) sw.peek().microseconds;

			log.trace("total time command get: %d [µs]", t);
		}
	}

	// TODO !для пущей безопасности, факты с предикатом [auth:credential] не отдавать !

	return;
}

public Subject set_message_trace(Subject message, Predicate* sender, string userId, TripleStorage ts, out bool isOk, out string reason)
{
	Subject res;

	Predicate* args = message.getEdge(msg__args);

	for(short ii; ii < args.count_objects; ii++)
	{
		if(args.objects[ii].type == OBJECT_TYPE.SUBJECT)
		{
			Subject arg = args.objects[ii].subject;

			Predicate* unset_msgs = arg.getEdge(pacahon__off_trace_msg);

			if(unset_msgs !is null)
			{
				for(int ll = 0; ll < unset_msgs.count_objects; ll++)
				{
					Objectz oo = unset_msgs.objects[ll];
					if(oo.object.length == 1)
					{
						if(oo.object[0] == '*')
							unset_all_messages();
					}
					else if(oo.object.length > 1)
					{
						int idx = Integer.toInt(cast(char[]) oo.object, 10);
						unset_message(idx);
					}
				}
			}

			Predicate* set_msgs = arg.getEdge(pacahon__on_trace_msg);

			if(set_msgs !is null)
			{
				for(int ll = 0; ll < set_msgs.count_objects; ll++)
				{
					Objectz oo = set_msgs.objects[ll];
					if(oo.object.length == 1)
					{
						if(oo.object[0] == '*')
							set_all_messages();
					}
					else if(oo.object.length > 1)
					{
						int idx = Integer.toInt(cast(char[]) oo.object, 10);
						set_message(idx);
					}
				}
			}

		}
	}

	isOk = true;

	return res;
}

void command_preparer(Subject message, Subject out_message, Predicate* sender, string userId, TripleStorage ts, out string local_ticket)
{
	if(trace_msg[11] == 1)
		log.trace("command_preparer start");

	Predicate[] ppp = new Predicate[5];

	Subject res;

	char[] time = new char[21];
	time[] = '_';
	time[0] = 'm';
	time[1] = 's';
	time[2] = 'g';
	time[3] = ':';
	time[4] = 'M';

	version(dmd2_052)
	{
		SysTime sysTime = Clock.currTime(UTC());
		Integer.format(time, sysTime.stdTime, cast(char[]) "X2");
	}
	else
	{
		Ticks m_TimeStart = systime();
		Integer.format(time, m_TimeStart.value, cast(char[]) "X2");
	}

	out_message.subject = cast(immutable) time;
	//	out_message.subject = cast(char[])"msg:time";

	out_message.addPredicateAsURI("a", msg__Message);
	out_message.addPredicateAsURI(msg__in_reply_to, message.subject);
	out_message.addPredicate(msg__sender, "pacahon");
	out_message.addPredicate(msg__reciever, sender.getFirstObject);

	Predicate* command = message.getEdge(msg__command);

	string reason;
	bool isOk;

	if(command !is null)
	{

		if("put" in command.objects_of_value)
		{
			if(trace_msg[13] == 1)
				log.trace("command_preparer, put");

			res = put(message, sender, userId, ts, isOk, reason);
		}
		else if("get" in command.objects_of_value)
		{
			if(trace_msg[14] == 1)
				log.trace("command_preparer, get");

			GraphCluster gres;
			get(message, sender, userId, ts, isOk, reason, gres);
			if(isOk == true)
			{
				//				out_message.addPredicate(msg__result, fromStringz(toTurtle (gres)));
				out_message.addPredicate(msg__result, gres);
			}
		}
		else if("get_ticket" in command.objects_of_value)
		{
			if(trace_msg[15] == 1)
				log.trace("command_preparer, get_ticket");

			res = get_ticket(message, sender, userId, ts, isOk, reason);

			if(isOk)
				local_ticket = res.edges[0].getFirstObject;
		}
		else if("set_message_trace" in command.objects_of_value)
		{
			if(trace_msg[63] == 1)

				res = set_message_trace(message, sender, userId, ts, isOk, reason);
		}

		//		reason = cast(char[]) "запрос выполнен";
	}
	else
	{
		reason = "в сообщении не указана команда";
	}
	if(isOk == false)
	{
		out_message.addPredicate(msg__status, "fail");
	}
	else
	{
		out_message.addPredicate(msg__status, "ok");
	}

	if(res !is null)
		out_message.addPredicate(msg__result, res);

	out_message.addPredicate(msg__reason, reason);

	if(trace_msg[16] == 1)
		log.trace("command_preparer end");
}
