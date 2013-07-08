module pacahon.command.io;

private import core.stdc.stdio;
private import core.stdc.stdlib;
private import std.c.string;
private import std.string;
private import std.conv;

private import std.datetime;

private import std.stdio;
private import std.outbuffer;

private import std.datetime;

//private import trioplax.mongodb.triple;
//private import trioplax.mongodb.TripleStorage;

private import pacahon.graph;

private import pacahon.json_ld.parser1;

private import pacahon.authorization;
private import pacahon.know_predicates;
private import pacahon.log_msg;
private import pacahon.thread_context;

private import util.Logger;
private import util.utils;

private import pacahon.command.event_filter;
private import pacahon.search;

import onto.docs_base;

Logger log;
//char[] buff;
char[] buff1;
string[] reifed_data_subj;

//int read_from_mongo = 0;
//int read_from_mmf = 0;

static this()
{
	//	buff = new char[21];
	buff1 = new char[6];
	log = new Logger("pacahon", "log", "command-io");
	reifed_data_subj = new string[1];
	reifed_data_subj[0] = "_:R__01";
}

/*
 * комманда добавления / изменения фактов в хранилище 
 * TODO !в данный момент обрабатывает только одноуровневые графы
 */
Subject put(Subject message, Predicate sender, string userId, ThreadContext server_context, out bool isOk, out string reason)
{
	if(trace_msg[31] == 1)
		log.trace("command put");

	isOk = false;

	reason = "добавление фактов не возможно";

	Subject res;

	Predicate args = message.getPredicate(msg__args);

	if(trace_msg[32] == 1)
		log.trace("command put, args.count_objects=%d ", args.count_objects);

	foreach(arg; args.getObjects)
	{
		Subject[] graphs_on_put = null;

		if(trace_msg[33] == 1)
			log.trace("args.objects.type = %s", text(arg.type));

		try
		{
			if(arg.type == OBJECT_TYPE.CLUSTER)
			{
				graphs_on_put = arg.cluster.graphs_of_subject.values;
			} else if(arg.type == OBJECT_TYPE.SUBJECT)
			{
				graphs_on_put = new Subject[1];
				graphs_on_put[0] = arg.subject;
			}
		} catch(Exception ex)
		{
			log.trace("cannot parse arg message: ex %s", ex.msg);
		}

		if(trace_msg[34] == 1)
			log.trace("arguments has been read");

		if(trace_msg[64] == 1)
		{
			OutBuffer outbuff = new OutBuffer();
			toJson_ld(graphs_on_put, outbuff);
			outbuff.write(0);
			ubyte[] bb = outbuff.toBytes();
			log.trace_io(true, cast(byte*) bb, bb.length);
		}

		if(graphs_on_put is null)
		{
			reason = "в сообщении нет фактов которые следует поместить в хранилище";
		}

		if(trace_msg[34] == 1)
			log.trace("фаза I, добавим основные данные");

		store_graphs(graphs_on_put, userId, server_context, isOk, reason);

		if(trace_msg[37] == 1)
			log.trace("command put is finish");

		//		return res;
	}

	return res;
}

public void store_graphs(Subject[] graphs_on_put, string userId, ThreadContext server_context, out bool isOk, out string reason,
		bool prepareEvents = true)
{
	// фаза I, добавим основные данные
	foreach(graph; graphs_on_put)
	{
		Predicate type = graph.getPredicate(rdf__type);

		if(type !is null && ((rdf__Statement in type.objects_of_value) is null))
		{
			if(trace_msg[35] == 1)
				log.trace("[35.1] adding subject=%s", graph.subject);

			// цикл по всем добавляемым субьектам
			/* 2. если создается новый субъект, то ограничений по умолчанию нет
			 * 3. если добавляются факты к уже созданному субъекту, то разрешено добавлять 
			 * если добавляющий автор субъекта 
			 * или может быть вычислено разрешающее право на U данного субъекта. */

			string authorize_reason;
			bool subjectIsExist = false;

			bool authorization_res = false;

			if(userId !is null)
			{
				authorization_res = authorize(userId, graph.subject, operation.CREATE | operation.UPDATE, server_context,
						authorize_reason, subjectIsExist);
			}

			if(authorization_res == true || userId is null)
			{
				if(userId !is null && graph.isExsistsPredicate(dc__creator) == false)
				{
					// добавим признак dc:creator
					graph.addPredicate(dc__creator, userId);
				}

				server_context.ts.storeSubject(graph, server_context);

				if(prepareEvents == true)
				{
					if(type.isExistLiteral(event__Event))
					{
						// если данный субьект - фильтр событий, то дополнительно сохраним его в кеше
						server_context.event_filters.addSubject(graph);

						writeln("add new event_filter [", graph.subject, "]");
					} else
					{
						string event_type;

						if(subjectIsExist == true)
							event_type = "update subject";
						else
							event_type = "create subject";

						processed_events(graph, event_type, server_context);
					}
				}

				reason = "добавление фактов выполнено:" ~ authorize_reason;
				isOk = true;
				
				search_event(graph, server_context);				
			} else
			{
				reason = "добавление фактов не возможно: " ~ authorize_reason;
				if(trace_msg[36] == 1)
					log.trace("autorize=%s", reason);
			}

		} else
		{
			if(type is null)
				reason = "добавление фактов не возможно: не указан rdf:type для субьекта" ~ graph.subject;
		}
	}

	if(trace_msg[34] == 1)
		log.trace("фаза II, добавим основные данные");

	// фаза II, добавим реифицированные данные 
	// !TODO авторизация для реифицированных данных пока не выполняется
	for(int jj = 0; jj < graphs_on_put.length; jj++)
	{
		Subject graph = graphs_on_put[jj];

		Predicate type = graph.getPredicate(rdf__type);

		if(type !is null && (rdf__Statement in type.objects_of_value))
		{
			// определить, несет ли в себе субьект, реифицированные данные (a rdf:Statement)
			// если, да то добавить их в хранилище через метод addTripleToReifedData
			Predicate r_subject = graph.getPredicate(rdf__subject);
			Predicate r_predicate = graph.getPredicate(rdf__predicate);
			Predicate r_object = graph.getPredicate(rdf__object);

			if(r_subject !is null && r_predicate !is null && r_object !is null)
			{
				Triple reif = new Triple(r_subject.getFirstLiteral(), r_predicate.getFirstLiteral(), r_object.getFirstLiteral());

				foreach(pp; graph.getPredicates)
				{
					if(pp != r_subject && pp != r_predicate && pp != r_object && pp != type)
					{
						foreach(oo; pp.getObjects())
						{
							if(oo.type == OBJECT_TYPE.LITERAL || oo.type == OBJECT_TYPE.URI)
								server_context.ts.addTripleToReifedData(reif, pp.predicate, oo.literal, oo.lang);
							else
								server_context.ts.addTripleToReifedData(reif, pp.predicate, oo.subject.subject, oo.lang);
						}
					}

				}
			}
		} else
		{
			if(type is null)
				reason = "добавление фактов не возможно: не указан rdf:type для субьекта " ~ graph.subject;
		}

	}

}

public void store_graph(Subject graph, string userId, ThreadContext server_context, out bool isOk, out string reason,
		bool prepareEvents = true)
{
	// фаза I, добавим основные данные
	Predicate type = graph.getPredicate(rdf__type);

	if(type !is null && ((rdf__Statement in type.objects_of_value) is null))
	{
		if(trace_msg[35] == 1)
			log.trace("[35.2] adding subject=%s", graph.subject);

		// цикл по всем добавляемым субьектам
		/* 2. если создается новый субъект, то ограничений по умолчанию нет
		 * 3. если добавляются факты к уже созданному субъекту, то разрешено добавлять 
		 * если добавляющий автор субъекта 
		 * или может быть вычислено разрешающее право на U данного субъекта. */

		string authorize_reason;
		bool subjectIsExist = false;

		bool authorization_res = false;

		if(userId !is null)
		{
			authorization_res = authorize(userId, graph.subject, operation.CREATE | operation.UPDATE, server_context,
					authorize_reason, subjectIsExist);
		}

		if(authorization_res == true || userId is null)
		{
			if(userId !is null && graph.isExsistsPredicate(dc__creator) == false)
			{
				// добавим признак dc:creator
				graph.addPredicate(dc__creator, userId);
			}

			server_context.ts.storeSubject(graph, server_context);

			if(prepareEvents == true)
			{
				if(type.isExistLiteral(event__Event))
				{
					// если данный субьект - фильтр событий, то дополнительно сохраним его в кеше
					server_context.event_filters.addSubject(graph);

					writeln("add new event_filter [", graph.subject, "]");
				} else
				{
					string event_type;

					if(subjectIsExist == true)
						event_type = "update subject";
					else
						event_type = "create subject";

					processed_events(graph, event_type, server_context);
				}
			}

			reason = "добавление фактов выполнено:" ~ authorize_reason;
			isOk = true;
			
			search_event(graph, server_context);			
		} else
		{
			reason = "добавление фактов не возможно: " ~ authorize_reason;
			if(trace_msg[36] == 1)
				log.trace("autorize=%s", reason);
		}

	} else
	{
		if(type is null)
			reason = "добавление фактов не возможно: не указан rdf:type для субьекта" ~ graph.subject;
	}

}

public void get(Subject message, Predicate sender, string userId, ThreadContext server_context, out bool isOk, out string reason,
		ref GraphCluster res, out char from_out)
{
	//	log.trace("GET");

	// в качестве аргумента - шаблон для выборки
	// query:get - обозначает что будет возвращено значение соответствующего предиката
	// TODO ! в данный момент метод обрабатывает только одноуровневые шаблоны

	isOk = false;

	if(trace_msg[41] == 1)
		log.trace("command get");

	reason = "запрос не выполнен";

	Predicate args = message.getPredicate(msg__args);

	if(trace_msg[42] == 1)
	{
		OutBuffer outbuff = new OutBuffer();
		toJson_ld(message, outbuff);
		log.trace("[42] command get, cmd=%s", outbuff.toString);
	}

	if(args !is null)
	{
		foreach(arg; args.getObjects())
		{
			if(trace_msg[43] == 1)
				log.trace("[43] args.objects.type = %s", text(arg.type));

			Subject[] graphs_as_template;

			if(arg.type == OBJECT_TYPE.CLUSTER)
			{
				graphs_as_template = arg.cluster.graphs_of_subject.values;
			} else if(arg.type == OBJECT_TYPE.SUBJECT)
			{
				graphs_as_template = new Subject[1];
				graphs_as_template[0] = arg.subject;
			}

			if(trace_msg[45] == 1)
				log.trace("[45] arguments has been read");

			if(graphs_as_template is null)
			{
				reason = "в сообщении отсутствует граф-шаблон";
			}

			StopWatch sw;
			sw.start();

			for(int jj = 0; jj < graphs_as_template.length; jj++)
			{
				Subject graph = graphs_as_template[jj];

				//					read_from_mongo++;
				//					log.trace("MONGO:%d", read_from_mongo);
				from_out = 'D';

				// считываем данные из mongodb

				byte[string] readed_predicate;
				Triple[] search_mask = new Triple[graph.count_edges];
				int search_mask_length = 0;

				// найдем предикаты, которые следует вернуть
				foreach(pp; graph.getPredicates)
				{
					if(trace_msg[46] == 1)
						log.trace("[46.1] pp0=%s", pp.predicate);

					Triple statement = null;

					foreach(oo; pp.getObjects())
					{
						if(oo.type == OBJECT_TYPE.LITERAL || oo.type == OBJECT_TYPE.URI)
						{
							if(trace_msg[46] == 1)
								log.trace("[46.2] pp1=%s", pp.predicate);

							// if(oo.literal.length > 0)
							{
								if(oo.literal == "query:get_reifed")
								{
									// требуются так-же реифицированные данные по этому полю
									// данный предикат добавить в список возвращаемых
									if(trace_msg[47] == 1)
										log.trace("[47] данный предикат и реифицированные данные добавим в список возвращаемых: %s",
												pp.predicate);

									readed_predicate[cast(string) pp.predicate] = field.GET_REIFED;

									if(trace_msg[48] == 1)
										log.trace("[48] readed_predicate.length=%d", readed_predicate.length);
								} else if(oo.literal == "query:get")
								{
									// данный предикат добавить в список возвращаемых
									if(trace_msg[49] == 1)
										log.trace("[49] данный предикат добавим в список возвращаемых: %s", pp.predicate);

									readed_predicate[cast(string) pp.predicate] = field.GET;

									if(trace_msg[50] == 1)
										log.trace("[50] readed_predicate.length=%d", readed_predicate.length);
								} else
								{
									// это условие ограничивающее результаты выборки
									if(statement is null)
										statement = new Triple(null, pp.predicate, oo.literal);

									if(trace_msg[51] == 1)
										log.trace("[51] statement: p=%s o=%s", statement.P, statement.O);
								}
							}
						}

					}

					if(graph.subject != "query:any" && (statement !is null || search_mask_length == 0))
					{
						if(trace_msg[53] == 1)
						{
							log.trace("[53] subject=%s", graph.subject);
//							log.trace("statement=%X", statement);
						}

						if(statement is null)
							statement = new Triple(graph.subject, null, null);
						else
							statement.S = graph.subject;

						if(trace_msg[54] == 1)
							log.trace("[54] s=%s", statement.S);
					}

					if(statement !is null)
					{
						search_mask[search_mask_length] = statement;
						search_mask_length++;

						if(trace_msg[55] == 1)
							log.trace("[55] search_mask_length=%d", search_mask_length);
					}

				}

				if(search_mask_length > 0)
				{
					search_mask.length = search_mask_length;

					//					if(trace_msg[56] == 1)
					//						log.trace("search_mask.length=[%d] search_mask=[%s]", search_mask.length, search_mask);

					TLIterator it;

					it = server_context.ts.getTriplesOfMask(search_mask, readed_predicate);

					if(trace_msg[56] == 1)
						log.trace("[56] server_context.ts.getTriplesOfMask(search_mask, readed_predicate) is ok");

					if(trace_msg[57] == 1)
						log.trace("[57] формируем граф содержащий результаты {");

					if(it !is null)
					{
						foreach(triple; it)
						{
							if(trace_msg[57] == 1)
								log.trace("GET: triple %s", triple);

							if(server_context.IGNORE_EMPTY_TRIPLE == true)
							{
								if(triple.O !is null && triple.O.length > 0)
								{
									//									log.trace("DB: addTriple [%s %s %s]", triple.S, triple.P, triple.O);									
									res.addTriple(triple.S, triple.P, triple.O, triple.lang);
								}
							} else
							{
								res.addTriple(triple.S, triple.P, triple.O, triple.lang);
							}

						}
						sw.stop();

						delete it;
					}
				}

				if(trace_msg[61] == 1)
				{
					sw.stop();
					long t = cast(long) sw.peek().usecs;

					log.trace("get, read data time: %d [µs]", t);
					sw.start();
				}

				if(trace_msg[57] == 1)
					log.trace("}");

				if(trace_msg[58] == 1)
					log.trace("авторизуем найденные субьекты, для пользователя %s", userId);

				// авторизуем найденные субьекты
				int count_found_subjects = 0;
				int count_authorized_subjects = 0;

				string authorize_reason;

				foreach(s; res.graphs_of_subject)
				{
					count_found_subjects++;

					bool isExistSubject;
					bool result_of_az = authorize(userId, s.subject, operation.READ, server_context, authorize_reason,
							isExistSubject);

					if(result_of_az == false)
					{
						if(trace_msg[59] == 1)
							log.trace("AZ: s=%s -> %s ", s.subject, authorize_reason);

						s.count_edges = 0;
						s.subject = null;

						if(trace_msg[60] == 1)
							log.trace("remove from list");
					} else
					{
						count_authorized_subjects++;
					}

				}

				if(count_found_subjects == count_authorized_subjects)
				{
					reason = "запрос выполнен: авторизованны все найденные субьекты :" ~ text(count_found_subjects);
				} else if(count_found_subjects > count_authorized_subjects && count_authorized_subjects > 0)
				{
					reason = "запрос выполнен: не все найденные субьекты " ~ text(count_found_subjects) ~ " успешно авторизованны";
				} else if(count_authorized_subjects == 0 && count_found_subjects > 0)
				{
					reason = "запрос выполнен: ни один из найденных субьектов (" ~ text(count_found_subjects) ~ "), не был успешно авторизован:" ~ authorize_reason;
				}

				isOk = true;
				//				}
			}

			if(trace_msg[61] == 1)
			{
				sw.stop();
				long t = cast(long) sw.peek().usecs;

				log.trace("total time command get: %d [µs]", t);
			}

		}
	}

	// TODO !для безопасности, факты с предикатом [auth:credential] не отдавать !
	//	core.thread.Thread.getThis().sleep(dur!("msecs")( 1 ));

	return;
}

Subject remove(Subject message, Predicate sender, string userId, ThreadContext server_context, out bool isOk, out string reason)
{
	if(trace_msg[38] == 1)
		log.trace("command remove");

	isOk = false;

	reason = "нет причин для выполнения комманды remove";

	Subject res;

	try
	{
		Predicate arg = message.getPredicate(msg__args);
		if(arg is null)
		{
			reason = "аргументы " ~ msg__args ~ " не указаны";
			isOk = false;
			return null;
		}

		Subject ss = arg.getObjects()[0].subject;
		if(ss is null)
		{
			reason = msg__args ~ " найден, но не заполнен";
			isOk = false;
			return null;
		}

		Predicate subj_id = ss.getPredicate(rdf__subject);
		if(subj_id is null || subj_id.getFirstLiteral is null || subj_id.getFirstLiteral.length < 2)
		{
			reason = "rdf:subject не указан";
			isOk = false;
			return null;
		}

		string authorize_reason;
		bool isExistSubject;
		bool result_of_az = authorize(userId, subj_id.getFirstLiteral, operation.DELETE, server_context, authorize_reason,
				isExistSubject);

		if(result_of_az)
		{
			server_context.ts.removeSubject(subj_id.getFirstLiteral);
			reason = "команда remove выполнена успешно";
			isOk = true;
		} else
		{
			reason = "нет прав на удаление субьекта:" ~ authorize_reason;
			isOk = false;
		}

		return res;
	} catch(Exception ex)
	{
		reason = "ошибка удаления субьекта :" ~ ex.msg;
		isOk = false;

		return res;
	}

}
