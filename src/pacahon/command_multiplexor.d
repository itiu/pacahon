// TODO reason -> exception ?

module pacahon.command.multiplexor;

private 
{
	import core.stdc.stdio;
	import core.stdc.stdlib;
	import std.c.string;
	import std.string;
	import std.datetime;
	import std.stdio;
	import std.outbuffer;
	import std.datetime;
	import std.conv;
	import std.uuid;

	import pacahon.command.io;
	import pacahon.command.event_filter;
	import pacahon.context;

	import trioplax.mongodb.TripleStorage;
	import pacahon.graph;
	import util.json_ld.parser1;

	import pacahon.authorization;
	import pacahon.know_predicates;
	import pacahon.log_msg;
	import util.utils;
	import pacahon.thread_context;

	import util.Logger;
}

Logger log;

static this()
{
	log = new Logger("pacahon", "log", "multiplexor");
}

/*
 * команда получения тикета
 */

Subject get_ticket(Subject message, Predicate sender, ThreadContext thread_context, out bool isOk,
		out string reason, out Ticket ticket)
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

		Predicate login = ss.getPredicate(auth__login);
		if(login is null || login.getFirstLiteral is null || login.getFirstLiteral.length < 2)
		{
			reason = "login не указан";
			isOk = false;
			return null;
		}

		Predicate credential = ss.getPredicate(auth__credential);
		if(credential is null || credential.getFirstLiteral() is null || credential.getFirstLiteral.length < 2)
		{
			reason = "credential не указан";
			isOk = false;
			return null;
		}

		Triple[] search_mask = new Triple[2];

		search_mask[0] = new Triple(null, auth__login, login.getFirstLiteral);
		search_mask[1] = new Triple(null, auth__credential, credential.getFirstLiteral);

		byte[string] readed_predicate;
		readed_predicate[auth__login] = true;
		readed_predicate[docs__parentUnit] = true;

		// TODO определится что возвращать null или пустой итератор
		if(trace_msg[65] == 1)
			log.trace("get_ticket: start getTriplesOfMask search_mask");

		TLIterator it = thread_context.ts.getTriplesOfMask(search_mask, readed_predicate);

		if(trace_msg[65] == 1)
			log.trace("get_ticket: iterator %x", it);

		Subject new_ticket = new Subject;

		if(it !is null)
		{
			foreach(tt; it)
			{
				//						writeln("f.read tr... S:", iterator.triple.s, " P:", iterator.triple.p, " O:", iterator.triple.o);
				if(tt.P == auth__login)
				{
					if(trace_msg[65] == 1)
						log.trace("get_ticket: read triple: %s", tt);

					// такой логин и пароль найдены, формируем тикет
					UUID new_id = randomUUID();
					new_ticket.subject = new_id.toString ();

					new_ticket.addPredicate(rdf__type, ticket__Ticket);
					new_ticket.addPredicate(ticket__accessor, tt.S);
					new_ticket.addPredicate(ticket__when, getNowAsString());
					new_ticket.addPredicate(ticket__duration, "40000");

					if(trace_msg[65] == 1)
						log.trace("get_ticket: store ticket in DB");

				} else if(tt.P == docs__parentUnit)
				{
					new_ticket.addPredicate(ticket__parentUnitOfAccessor, tt.O);
				}
			}

			if(new_ticket.subject !is null)
			{
				// сохраняем в хранилище
				thread_context.ts.storeSubject(new_ticket, thread_context);

				res.addPredicate(auth__ticket, new_ticket.subject);
				
				ticket = new Ticket ();
				
				// TODO убрать корректировки ссылок в organization: временная коррекция ссылок
				char[] sscc = new_ticket.getFirstLiteral(ticket__accessor).dup;
				if(sscc[7] == '_')
					sscc = sscc[8..$];
				else if(sscc[8] == '_')
					sscc = sscc[9..$];
				
				ticket.userId = cast(string)sscc;
				
				foreach (unit; new_ticket.getObjects(ticket__parentUnitOfAccessor))
				{
					// TODO убрать корректировки ссылок в organization: временная коррекция ссылок
					sscc = unit.literal.dup;
					if(sscc[7] == '_')
						sscc = sscc[8..$];
					else if(sscc[8] == '_')
						sscc = sscc[9..$];
					
					ticket.parentUnitIds ~= cast(string)sscc;
				}
				
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

public Subject set_message_trace(Subject message, Predicate sender, string userId, ThreadContext thread_context, out bool isOk,
		out string reason)
{
	Subject res;

	Predicate args = message.getPredicate(msg__args);

	foreach(arg; args.getObjects())
	{
		if(arg.type == OBJECT_TYPE.SUBJECT)
		{
			Subject sarg = arg.subject;

			Predicate unset_msgs = sarg.getPredicate(pacahon__off_trace_msg);

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

			Predicate set_msgs = sarg.getPredicate(pacahon__on_trace_msg);

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

void command_preparer(Ticket exist_ticket, Subject message, Subject out_message, Predicate sender, ThreadContext thread_context,
		out Ticket new_ticket, out char from)
{
	if(trace_msg[11] == 1)
		log.trace("command_preparer start");

	Subject res;

	out_message.subject = generateMsgId();

	out_message.addPredicateAsURI("a", msg__Message);
	out_message.addPredicate(msg__sender, "pacahon");

	if(sender !is null)
		out_message.addPredicate(msg__reciever, sender.getFirstLiteral);

	string reason;
	bool isOk;

	if(message !is null)
	{
		out_message.addPredicateAsURI(msg__in_reply_to, message.subject);
		Predicate command = message.getPredicate(msg__command);

		if(command !is null)
		{
			if("get" in command.objects_of_value)
			{
				if(trace_msg[14] == 1)
					log.trace("command_preparer, get");

				GraphCluster gres = new GraphCluster(STRATEGY.NOINDEXED);

				get(exist_ticket, message, sender, thread_context, isOk, reason, gres, from);
				if(isOk == true)
				{
					//				out_message.addPredicate(msg__result, fromStringz(toTurtle (gres)));
					out_message.addPredicate(msg__result, gres);
				}
			} else if("put" in command.objects_of_value)
			{
				if(trace_msg[13] == 1)
					log.trace("command_preparer, put");

				res = put(message, sender, exist_ticket.userId, thread_context, isOk, reason);
			} else if("remove" in command.objects_of_value)
			{
				if(trace_msg[14] == 1)
					log.trace("command_preparer, remove");

				res = remove(message, sender, exist_ticket.userId, thread_context, isOk, reason);
			} else if("get_ticket" in command.objects_of_value)
			{
				if(trace_msg[15] == 1)
					log.trace("command_preparer, get_ticket");

				res = get_ticket(message, sender, thread_context, isOk, reason, new_ticket);

				if(isOk)
				{
					if(trace_msg[15] == 1)
						log.trace("command_preparer, get_ticket is Ok");
				} else
				{
					if(trace_msg[15] == 1)
						log.trace("command_preparer, get_ticket is False");
				}
			} else if("set_message_trace" in command.objects_of_value)
			{
				//			if(trace_msg[63] == 1)
				res = set_message_trace(message, sender, exist_ticket.userId, thread_context, isOk, reason);
			} else
			{
				reason = "неизвестная команда";
				out_message.addPredicate(msg__status, "405");
				out_message.addPredicate(msg__reason, reason);
				return;
			}

			if("get_info" in command.objects_of_value)
			{
				Statistic stat = thread_context.stat;

				Subject res1 = new Subject();

				res1.addPredicate("count_messages", text(stat.count_message));

				out_message.addPredicate(msg__result, res1);
			}

			//		reason = cast(char[]) "запрос выполнен";
			if(isOk == false && new_ticket is null)
			{
				out_message.addPredicate(msg__status, "401");
				reason = "пользователь не авторизован";
			} else if(isOk == false)
			{
				out_message.addPredicate(msg__status, "500");
			} else
			{
				out_message.addPredicate(msg__status, "200");
			}
		} else
		{
			reason = "в сообщении не указана команда";
			out_message.addPredicate(msg__status, "400");
		}

	}

	if(res !is null)
		out_message.addPredicate(msg__result, res);

	out_message.addPredicate(msg__reason, reason);

	if(trace_msg[16] == 1)
		log.trace("command_preparer end");
}