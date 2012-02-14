module pacahon.command.io;

private import core.stdc.stdio;
private import core.stdc.stdlib;
private import std.c.string;
private import std.string;
import std.conv;

private import std.datetime;

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
private import pacahon.log_msg;
private import pacahon.utils;
private import pacahon.thread_context;

private import trioplax.Logger;

private import pacahon.command.event_filter;

private import mmf.graph;

Logger log;
//char[] buff;
char[] buff1;

static this()
{
	buff = new char[21];
	buff1 = new char[6];
	log = new Logger("pacahon", "log", "command-io");
}

/*
 * комманда добавления / изменения фактов в хранилище 
 * TODO !в данный момент обрабатывает только одноуровневые графы
 */
Subject put(Subject message, Predicate* sender, string userId, ThreadContext server_context, out bool isOk,
		out string reason)
{
	if(trace_msg[31] == 1)
		log.trace("command put");

	isOk = false;

	reason = "добавление фактов не возможно";

	Subject res;

	Predicate* args = message.getPredicate(msg__args);

	if(trace_msg[32] == 1)
		log.trace("command put, args.count_objects=%d ", args.count_objects);

	for(short ii; ii < args.count_objects; ii++)
	{
		Subject[] graphs_on_put = null;

		if(trace_msg[33] == 1)
			log.trace("args.objects[%d].type = %s", ii, text(args.objects[ii].type));

		try
		{
			if(args.objects[ii].type == OBJECT_TYPE.CLUSTER)
			{
				graphs_on_put = args.objects[ii].cluster.graphs_of_subject.values;
			} else if(args.objects[ii].type == OBJECT_TYPE.SUBJECT)
			{
				graphs_on_put = new Subject[1];
				graphs_on_put[0] = args.objects[ii].subject;
			} else if(args.objects[ii].type == OBJECT_TYPE.LITERAL)
			{
				char* args_text = cast(char*) args.objects[ii].literal;
				int arg_size = cast(uint) strlen(args_text);

				if(trace_msg[33] == 1)
					log.trace("start parse arg");

				graphs_on_put = parse_n3_string(cast(char*) args_text, arg_size);

				if(trace_msg[33] == 1)
					log.trace("complete parse arg");
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

		// фаза I, добавим основные данные
		for(int jj = 0; jj < graphs_on_put.length; jj++)
		{
			if(trace_msg[35] == 1)
				log.trace("jj = %d", jj);

			Subject graph = graphs_on_put[jj];
			//			graph.reindex_predicate();

			if(trace_msg[35] == 1)
				log.trace("#1 jj = %d", jj);

			Predicate* type = graph.getPredicate("a");
			if(type is null)
				type = graph.getPredicate(rdf__type);

			if(trace_msg[35] == 1)
				log.trace("#2 jj = %d, type=%x", jj, type);

			if(type !is null && ((rdf__Statement in type.objects_of_value) is null))
			{
				if(trace_msg[35] == 1)
					log.trace("adding subject=%s", graph.subject);

				// цикл по всем добавляемым субьектам
				/* 2. если создается новый субъект, то ограничений по умолчанию нет
				 * 3. если добавляются факты к уже созданному субъекту, то разрешено добавлять 
				 * если добавляющий автор субъекта 
				 * или может быть вычислено разрешающее право на U данного субъекта. */

				string authorize_reason;
				bool subjectIsExist = false;

				if(authorize(userId, graph.subject, operation.CREATE | operation.UPDATE, server_context,
						authorize_reason, subjectIsExist) == true)
				{
					if(userId !is null)
					{
						// добавим признак dc:creator
						server_context.ts.addTriple(new Triple(graph.subject, dc__creator, userId));
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
								server_context.ts.addTriple(
										new Triple(graph.subject, pp.predicate, oo.literal, oo.lang));
							else
								server_context.ts.addTriple(new Triple(graph.subject, pp.predicate, oo.subject.subject,
										oo.lang));
						}

					}

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

						//						int count = 90_000;
						//						StopWatch sw;
						//						sw.start();
						//						for(int i = 0; i < count; i++)
						processed_events(graph, event_type, server_context);

						//						sw.stop();
						//						long t = cast(long) sw.peek().usecs;
						//						writeln("processed filters ", count, ", time=", t);

					}

					reason = "добавление фактов выполнено:" ~ authorize_reason;
					isOk = true;
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

			Predicate* type = graph.getPredicate("a");
			if(type is null)
				type = graph.getPredicate(rdf__type);

			if(type !is null && (rdf__Statement in type.objects_of_value))
			{
				// определить, несет ли в себе субьект, реифицированные данные (a rdf:Statement)
				// если, да то добавить их в хранилище через метод addTripleToReifedData
				Predicate* r_subject = graph.getPredicate(rdf__subject);
				Predicate* r_predicate = graph.getPredicate(rdf__predicate);
				Predicate* r_object = graph.getPredicate(rdf__object);

				if(r_subject !is null && r_predicate !is null && r_object !is null)
				{
					Triple reif = new Triple(r_subject.getFirstObject(), r_predicate.getFirstObject(),
							r_object.getFirstObject());

					for(int kk = 0; kk < graph.count_edges; kk++)
					{
						Predicate* pp = &graph.edges[kk];

						if(pp != r_subject && pp != r_predicate && pp != r_object && pp != type)
						{
							for(int ll = 0; ll < pp.count_objects; ll++)
							{
								Objectz oo = pp.objects[ll];

								if(oo.type == OBJECT_TYPE.LITERAL || oo.type == OBJECT_TYPE.URI)
									server_context.ts.addTripleToReifedData(reif, pp.predicate, oo.literal, oo.lang);
								else
									server_context.ts.addTripleToReifedData(reif, pp.predicate, oo.subject.subject,
											oo.lang);
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

		if(trace_msg[37] == 1)
			log.trace("command put is finish");

		//		return res;
	}

	return res;
}

public void get(Subject message, Predicate* sender, string userId, ThreadContext server_context, out bool isOk,
		out string reason, ref GraphCluster res)
{
	StopWatch sw;
	sw.start();

	// в качестве аргумента - шаблон для выборки
	// query:get - обозначает что будет возвращено значение соответствующего предиката
	// TODO ! в данный момент метод обрабатывает только одноуровневые шаблоны

	isOk = false;

	if(trace_msg[41] == 1)
		log.trace("command get");

	reason = "запрос не выполнен";

	Predicate* args = message.getPredicate(msg__args);

	if(trace_msg[42] == 1)
	{
		OutBuffer outbuff = new OutBuffer();
		toJson_ld(message, outbuff);
		log.trace("command get, cmd=%s", outbuff.toString);
	}

	if(args !is null)
	{
		for(short ii; ii < args.count_objects; ii++)
		{
			if(trace_msg[43] == 1)
				log.trace("args.objects[%d].type = %s", ii, text(args.objects[ii].type));

			Subject[] graphs_as_template;

			if(args.objects[ii].type == OBJECT_TYPE.CLUSTER)
			{
				graphs_as_template = args.objects[ii].cluster.graphs_of_subject.values;
			} else if(args.objects[ii].type == OBJECT_TYPE.SUBJECT)
			{
				graphs_as_template = new Subject[1];
				graphs_as_template[0] = args.objects[ii].subject;
			} else if(args.objects[ii].type == OBJECT_TYPE.LITERAL)
			{
				char* args_text = cast(char*) args.objects[ii].literal;
				int arg_size = cast(uint) strlen(args_text);

				if(trace_msg[44] == 1)
					log.trace("arg [%s], arg_size=%d", args.objects[ii].literal, arg_size);

				graphs_as_template = parse_n3_string(cast(char*) args_text, arg_size);
			}

			if(trace_msg[45] == 1)
				log.trace("arguments has been read");

			if(graphs_as_template is null)
			{
				reason = "в сообщении отсутствует граф-шаблон";
			}

			for(int jj = 0; jj < graphs_as_template.length; jj++)
			{
				Subject graph = graphs_as_template[jj];

				//				if(trace_msg[46] == 1)
				//				log.trace("graph.subject=%s", graph.subject);

				if(graph.subject != "query:any" && server_context.useMMF == true)
				{
					// считываем данные из mmfile

					Vertex_vmm* vv;
					// берем для этого субьекта заданные поля (:get, либо все) и учитываем условия ограничители

//					log.trace("#1");

					vv = new Vertex_vmm; // TODO #34 проверить, если установить vv = null
					string from = graph.subject;

					bool vertex_found = server_context.mmf.findVertex(from, vv);

//					log.trace("#2");

					// проверим на соответсвие условиям ограничителям
					bool isFilterPass = true;

					for(int kk = 0; kk < graph.count_edges; kk++)
					{
						Predicate pp = graph.edges[kk];
//						log.trace("#6 pp.predicate=%s", pp.predicate);
						for(int ll = 0; ll < pp.count_objects; ll++)
						{
//							log.trace("#4");
							Objectz oo = pp.objects[ll];
							if(oo.type == OBJECT_TYPE.LITERAL || oo.type == OBJECT_TYPE.URI)
							{
//								log.trace("#5 oo.literal=%s", oo.literal);
								// if(oo.literal.length > 0)
								{
									if(oo.literal != "query:get_reifed" && oo.literal != "query:get")
									{
										bool rr = vv.OutEdge_is_exist_value(cast(string) pp.predicate, oo.literal);

										if(rr == false)
										{
//											log.trace("#7 isFilterPass = false");
											isFilterPass = false;
											break;
										}

									}
								}
							}
						}
					}

					if(isFilterPass == true)
					{
//						log.trace("#8");
						if(graph.getFirstObject("query:all_predicates") == "query:get")
						{
//							log.trace("#9");

							// если все поля нужно вернуть
							bool isOutEdges = vv.init_OutEdges_values_cache();
							bool isProperties = vv.init_Properties_values_cache();

							foreach(string key; vv.out_edges.keys)
							{
								foreach(string val; vv.out_edges[key])
								{
//									log.trace("#100 vv.out_edges=[%s : %s]", cast(string) key, cast(string) val);
									res.addTriple(graph.subject, cast(string) key, cast(string) val);
								}
							}

							foreach(string key; vv.properties.keys)
							{
								foreach(string val; vv.properties[key])
								{
//									log.trace("#101 vv.properties=[%s : %s]", cast(string) key, cast(string) val);
									res.addTriple(graph.subject, cast(string) key, cast(string) val);
								}
							}

						} else
						{
							// если возвращаемые поля заданны					
							for(int kk = 0; kk < graph.count_edges; kk++)
							{
								Predicate pp = graph.edges[kk];
								for(int ll = 0; ll < pp.count_objects; ll++)
								{
									Objectz oo = pp.objects[ll];
									if(oo.type == OBJECT_TYPE.LITERAL || oo.type == OBJECT_TYPE.URI)
									{
										if(trace_msg[46] == 1)
											log.trace("pp1=%s", pp.predicate);

										// if(oo.literal.length > 0)
										{
											if(oo.literal == "query:get_reifed")
											{
												// требуются так-же реифицированные данные по этому полю
												// данный предикат добавить в список возвращаемых
											} else if(oo.literal == "query:get")
											{
												string val = vv.get_OutEdge_first_value(cast(string) pp.predicate);
												res.addTriple(graph.subject, cast(string) pp.predicate, val);

											}
										}
									}
								}
							}
						}
					}
					//					if(server_context.mmf.findVertex(from, vv) == true)
					//					{
					//						log.trace("found [%s]", from);
					//					} else
					//					{
					// неверно, считаем что mmfile.data == mongodb.data
					//						log.trace("[%X] not found [%s]", server_context.mmf, from);
					//						vv = null; // TODO убрать, если #34 работает 
					//					}
					//					log.trace("#2");

				} else
				{
					// считываем данные из mongodb

					byte[char[]] readed_predicate;
					Triple[] search_mask = new Triple[graph.count_edges];
					int search_mask_length = 0;

					// найдем предикаты, которые следует вернуть
					for(int kk = 0; kk < graph.count_edges; kk++)
					{
						Predicate pp = graph.edges[kk];

						if(trace_msg[46] == 1)
							log.trace("pp0=%s", pp.predicate);

						Triple statement = null;

						for(int ll = 0; ll < pp.count_objects; ll++)
						{
							Objectz oo = pp.objects[ll];
							if(oo.type == OBJECT_TYPE.LITERAL || oo.type == OBJECT_TYPE.URI)
							{
								if(trace_msg[46] == 1)
									log.trace("pp1=%s", pp.predicate);

								// if(oo.literal.length > 0)
								{
									if(oo.literal == "query:get_reifed")
									{
										// требуются так-же реифицированные данные по этому полю
										// данный предикат добавить в список возвращаемых
										if(trace_msg[47] == 1)
											log.trace(
													"данный предикат и реифицированные данные добавим в список возвращаемых: %s",
													pp.predicate);

										readed_predicate[cast(string) pp.predicate] = field.GET_REIFED;

										if(trace_msg[48] == 1)
											log.trace("readed_predicate.length=%d", readed_predicate.length);
									} else if(oo.literal == "query:get")
									{
										// данный предикат добавить в список возвращаемых
										if(trace_msg[49] == 1)
											log.trace("данный предикат добавим в список возвращаемых: %s", pp.predicate);

										readed_predicate[cast(string) pp.predicate] = field.GET;

										if(trace_msg[50] == 1)
											log.trace("readed_predicate.length=%d", readed_predicate.length);
									} else
									{
										// это условие ограничивающее результаты выборки
										if(statement is null)
											statement = new Triple(null, pp.predicate, oo.literal);

										if(trace_msg[51] == 1)
											log.trace("statement: p=%s o=%s", statement.P, statement.O);
									}
								}
							}

						}

						if(graph.subject != "query:any" && (statement !is null || search_mask_length == 0))
						{
							if(trace_msg[53] == 1)
							{
								log.trace("subject=%s", graph.subject);
								log.trace("statement=%X", statement);
							}

							if(statement is null)
								statement = new Triple(graph.subject, null, null);
							else
								statement.S = graph.subject;

							if(trace_msg[54] == 1)
								log.trace("s=%s", statement.S);
						}

						if(statement !is null)
						{
							search_mask[search_mask_length] = statement;
							search_mask_length++;

							if(trace_msg[55] == 1)
								log.trace("search_mask_length=%d", search_mask_length);
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
							log.trace("server_context.ts.getTriplesOfMask(search_mask, readed_predicate) is ok");

						if(trace_msg[57] == 1)
							log.trace("формируем граф содержащий результаты {");

						if(it !is null)
						{
							foreach(triple; it)
							{
								if(trace_msg[57] == 1)
									log.trace("GET: triple %s", triple);

								if(triple.O !is null && triple.O.length > 0)
									res.addTriple(triple.S, triple.P, triple.O, triple.lang);
							}
							delete it;
						}
					}

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

				buff1[] = ' ';
				Integer.format(buff1, count_found_subjects, cast(char[]) "");

				if(count_found_subjects == count_authorized_subjects)
				{
					reason = "запрос выполнен: авторизованны все найденные субьекты :" ~ cast(string) buff1;
				} else if(count_found_subjects > count_authorized_subjects && count_authorized_subjects > 0)
				{
					reason = "запрос выполнен: не все найденные субьекты " ~ cast(string) buff1 ~ " успешно авторизованны";
				} else if(count_authorized_subjects == 0 && count_found_subjects > 0)
				{
					reason = "запрос выполнен: ни один из найденных субьектов (" ~ cast(string) buff1 ~ "), не был успешно авторизован:" ~ authorize_reason;
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

	return;
}

Subject remove(Subject message, Predicate* sender, string userId, ThreadContext server_context, out bool isOk,
		out string reason)
{
	if(trace_msg[38] == 1)
		log.trace("command remove");

	isOk = false;

	reason = "нет причин для выполнения комманды remove";

	Subject res;

	try
	{
		Predicate* arg = message.getPredicate(msg__args);
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

		Predicate* subj_id = ss.getPredicate(rdf__subject);
		if(subj_id is null || subj_id.getFirstObject is null || subj_id.getFirstObject.length < 2)
		{
			reason = "rdf:subject не указан";
			isOk = false;
			return null;
		}

		string authorize_reason;
		bool isExistSubject;
		bool result_of_az = authorize(userId, subj_id.getFirstObject, operation.DELETE, server_context,
				authorize_reason, isExistSubject);

		if(result_of_az)
		{
			server_context.ts.removeSubject(subj_id.getFirstObject);
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
