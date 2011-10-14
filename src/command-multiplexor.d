// TODO reason -> exception ?

module pacahon.command.multiplexor;

private import pacahon.command.io;
private import pacahon.command.yawl;
private import pacahon.command.event_filter;

private import core.stdc.stdio;
private import core.stdc.stdlib;
private import std.c.string;
private import std.string;

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
		if(login is null || login.getFirstObject is null || login.getFirstObject.length < 2)
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

		search_mask[0] = new Triple(null, auth__login, login.getFirstObject);
		search_mask[1] = new Triple(null, auth__credential, credential.getFirstObject);

		byte[char[]] readed_predicate;
		readed_predicate[auth__login] = true;

		// TODO определится что возвращать null или пустой итератор
		if(trace_msg[65] == 1)
			log.trace("get_ticket: start getTriplesOfMask");

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
				Twister rnd;
				rnd.seed;
				UuidGen rndUuid = new RandomGen!(Twister)(rnd);
				Uuid generated = rndUuid.next;
				//						writeln("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);

				if(trace_msg[65] == 1)
					log.trace("get_ticket: store ticket in DB");

				// сохраняем в хранилище
				string ticket_id = "auth:" ~ cast(string) generated.toString;
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

public Subject set_message_trace(Subject message, Predicate* sender, string userId, ThreadContext server_thread,
		out bool isOk, out string reason)
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
					if(oo.literal.length == 1)
					{
						if(oo.literal[0] == '*')
							unset_all_messages();
					} else if(oo.literal.length > 1)
					{
						int idx = Integer.toInt(cast(char[]) oo.literal, 10);
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
					if(oo.literal.length == 1)
					{
						if(oo.literal[0] == '*')
							set_all_messages();
					} else if(oo.literal.length > 1)
					{
						int idx = Integer.toInt(cast(char[]) oo.literal, 10);
						set_message(idx);
					}
				}
			}

		}
	}

	isOk = true;

	return res;
}

void command_preparer(Subject message, Subject out_message, Predicate* sender, string userId,
		ThreadContext server_thread, out string local_ticket)
{
	if(trace_msg[11] == 1)
		log.trace("command_preparer start");

	Subject res;

	out_message.subject = generateMsgId();

	out_message.addPredicateAsURI("a", msg__Message);
	out_message.addPredicateAsURI(msg__in_reply_to, message.subject);
	out_message.addPredicate(msg__sender, "pacahon");
	out_message.addPredicate(msg__reciever, sender.getFirstObject);

	Predicate* command = message.getEdge(msg__command);

	string reason;
	bool isOk;

	if(command !is null)
	{
		if("get" in command.objects_of_value)
		{
			if(trace_msg[14] == 1)
				log.trace("command_preparer, get");

			GraphCluster gres = new GraphCluster;
			get(message, sender, userId, server_thread, isOk, reason, gres);
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
		} else if("yawl:announceItemEnabled" in command.objects_of_value)
		{
			yawl_announceItemEnabled(message, sender, userId, server_thread, isOk, reason);

		} else if("yawl:ParameterInfoRequest" in command.objects_of_value)
		{
			GraphCluster gres = new GraphCluster;
			yawl_ParameterInfoRequest(message, sender, userId, server_thread, isOk, reason, gres);
			out_message.addPredicate(msg__result, gres);

		} else if("set_message_trace" in command.objects_of_value)
		{
			//			if(trace_msg[63] == 1)
			res = set_message_trace(message, sender, userId, server_thread, isOk, reason);
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

	if(res !is null)
		out_message.addPredicate(msg__result, res);

	out_message.addPredicate(msg__reason, reason);

	if(trace_msg[16] == 1)
		log.trace("command_preparer end");
}
