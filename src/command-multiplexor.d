// TODO reason -> exception ?

module pacahon.command.multiplexor;

private import pacahon.command.io;
private import pacahon.command.event_filter;

private import core.stdc.stdio;
private import core.stdc.stdlib;
private import std.c.string;
private import std.string;
private import std.datetime;
private import std.stdio;
private import std.outbuffer;
private import std.datetime;
private import std.conv;
private import std.uuid;

private import trioplax.triple;
private import trioplax.mongodb.TripleStorage;

private import pacahon.graph;

private import pacahon.json_ld.parser;

private import pacahon.authorization;
private import pacahon.know_predicates;
private import pacahon.log_msg;
private import util.utils;
private import pacahon.thread_context;

private import util.Logger;

Logger log;

static this()
{
	log = new Logger("pacahon", "log", "multiplexor");
}

/*
 * команда получения тикета
 */

Subject get_ticket(Subject message, Predicate* sender, string userId, ThreadContext server_thread, out bool isOk,
		out string reason)
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
		Predicate* arg = message.getPredicate(msg__args);
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

		Predicate* login = ss.getPredicate(auth__login);
		if(login is null || login.getFirstObject is null || login.getFirstObject.length < 2)
		{
			reason = "login не указан";
			isOk = false;
			return null;
		}

		Predicate* credential = ss.getPredicate(auth__credential);
		if(credential is null || credential.getFirstObject() is null || credential.getFirstObject.length < 2)
		{
			reason = "credential не указан";
			isOk = false;
			return null;
		}

		Triple[] search_mask = new Triple[2];

		search_mask[0] = new Triple(null, auth__login, login.getFirstObject);
		search_mask[1] = new Triple(null, auth__credential, credential.getFirstObject);

		byte[char[]] readed_predicate;
		readed_predicate[auth__login] = true;

		// TODO определится что возвращать null или пустой итератор
		if(trace_msg[65] == 1)
			log.trace("get_ticket: start getTriplesOfMask search_mask");

		TLIterator it = server_thread.ts.getTriplesOfMask(search_mask, readed_predicate);

		if(trace_msg[65] == 1)
			log.trace("get_ticket: iterator %x", it);

		if(it !is null)
		{
			foreach(tt; it)
			{
				if(trace_msg[65] == 1)
					log.trace("get_ticket: read triple: %s", tt);

				// такой логин и пароль найдены, формируем тикет
				//						writeln("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);
				UUID new_id = randomUUID();

				if(trace_msg[65] == 1)
					log.trace("get_ticket: store ticket in DB");

				// сохраняем в хранилище
				string ticket_id = "auth:" ~ new_id.toString();//cast(string) generated.toString;
				//						writeln("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);
				server_thread.ts.addTriple(new Triple(ticket_id, rdf__type, ticket__Ticket));
				//						writeln("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);
				server_thread.ts.addTriple(new Triple(ticket_id, ticket__accessor, tt.S));

				//						writeln("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);
				server_thread.ts.addTriple(new Triple(ticket_id, ticket__when, getNowAsString()));
				server_thread.ts.addTriple(new Triple(ticket_id, ticket__duration, "40000"));

				res.addPredicate(auth__ticket, ticket_id);

				reason = "login и password совпадают";
				isOk = true;
			}

			delete (it);
		} else
		{
			reason = "login и password не совпадают";
			isOk = false;
			return null;
		}
		return res;
	} catch(Exception ex)
	{
		log.trace("ошибка при выдачи сессионного билетa");

		reason = "ошибка при выдачи сессионного билетa :" ~ ex.msg;
		isOk = false;

		return res;
	} finally
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

			long t = cast(long) sw.peek().usecs;

			log.trace("total time command get_ticket: %d [µs]", t);
		}
	}
}

public Subject set_message_trace(Subject message, Predicate* sender, string userId, ThreadContext server_thread, out bool isOk,
		out string reason)
{
	Subject res;

	Predicate* args = message.getPredicate(msg__args);

	foreach(arg; args.getObjects())
	{
		if(arg.type == OBJECT_TYPE.SUBJECT)
		{
			Subject sarg = arg.subject;

			Predicate* unset_msgs = sarg.getPredicate(pacahon__off_trace_msg);

			if(unset_msgs !is null)
			{
				foreach(oo; unset_msgs.getObjects())
				{
					if(oo.literal.length == 1)
					{
						if(oo.literal[0] == '*')
							unset_all_messages();
					} else if(oo.literal.length > 1)
					{
						int idx = parse!uint(oo.literal);
						unset_message(idx);
					}
				}
			}

			Predicate* set_msgs = sarg.getPredicate(pacahon__on_trace_msg);

			if(set_msgs !is null)
			{
				foreach(oo; set_msgs.getObjects())
				{
					if(oo.literal.length == 1)
					{
						if(oo.literal[0] == '*')
							set_all_messages();
					} else if(oo.literal.length > 1)
					{
						int idx = parse!uint(oo.literal);
						set_message(idx);
					}
				}
			}

		}
	}

	isOk = true;

	return res;
}

void command_preparer(Subject message, Subject out_message, Predicate* sender, string userId, ThreadContext server_thread,
		out string local_ticket, out char from)
{
	if(trace_msg[11] == 1)
		log.trace("command_preparer start");

	Subject res;

	out_message.subject = generateMsgId();

	out_message.addPredicateAsURI("a", msg__Message);
	out_message.addPredicate(msg__sender, "pacahon");

	if(sender !is null)
		out_message.addPredicate(msg__reciever, sender.getFirstObject);

	string reason;
	bool isOk;

	if(message !is null)
	{
		out_message.addPredicateAsURI(msg__in_reply_to, message.subject);
		Predicate* command = message.getPredicate(msg__command);

		if(command !is null)
		{
			if("get" in command.objects_of_value)
			{
				if(trace_msg[14] == 1)
					log.trace("command_preparer, get");

				GraphCluster gres = new GraphCluster;

				get(message, sender, userId, server_thread, isOk, reason, gres, from);
				if(isOk == true)
				{
					//				out_message.addPredicate(msg__result, fromStringz(toTurtle (gres)));
					out_message.addPredicate(msg__result, gres);
				}
			} else if("put" in command.objects_of_value)
			{
				if(trace_msg[13] == 1)
					log.trace("command_preparer, put");

				res = put(message, sender, userId, server_thread, isOk, reason);
			} else if("remove" in command.objects_of_value)
			{
				if(trace_msg[14] == 1)
					log.trace("command_preparer, remove");

				res = remove(message, sender, userId, server_thread, isOk, reason);
			} else if("get_ticket" in command.objects_of_value)
			{
				if(trace_msg[15] == 1)
					log.trace("command_preparer, get_ticket");

				res = get_ticket(message, sender, userId, server_thread, isOk, reason);

				if(isOk)
				{
					if(trace_msg[15] == 1)
						log.trace("command_preparer, get_ticket is Ok");
					local_ticket = res.edges[0].getFirstObject;
				} else
				{
					if(trace_msg[15] == 1)
						log.trace("command_preparer, get_ticket is False");
				}
			} else if("set_message_trace" in command.objects_of_value)
			{
				//			if(trace_msg[63] == 1)
				res = set_message_trace(message, sender, userId, server_thread, isOk, reason);
			}
			if("get_info" in command.objects_of_value)
			{
				Statistic stat = server_thread.stat;

				Subject res1 = new Subject();

				res1.addPredicate("count_messages", text(stat.count_message));

				out_message.addPredicate(msg__result, res1);
			}
			//		reason = cast(char[]) "запрос выполнен";
		} else
		{
			reason = "в сообщении не указана команда";
		}
		if(isOk == false)
		{
			out_message.addPredicate(msg__status, "fail");
		} else
		{
			out_message.addPredicate(msg__status, "ok");
		}
	}

	if(res !is null)
		out_message.addPredicate(msg__result, res);

	out_message.addPredicate(msg__reason, reason);

	if(trace_msg[16] == 1)
		log.trace("command_preparer end");
}
