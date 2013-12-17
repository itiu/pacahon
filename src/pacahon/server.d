module pacahon.server;

private
{
	import core.thread;
	import std.stdio;
	import std.string;
	import std.c.string;
	import std.json;
	import std.outbuffer;
	import std.datetime;
	import std.conv;
	import std.concurrency;

	import mq.zmq_pp_broker_client;
	import mq.mq_client;
	import mq.rabbitmq_client;
	import mq.file_reader;

	import storage.acl;
	import storage.ticket;
	import storage.subject;

	import util.logger;
	import util.json_ld.parser;
	import util.turtle_parser;
	import util.utils;
	import util.oi;
	
	import pacahon.context;
	import pacahon.graph;
	import pacahon.multiplexor;
	import pacahon.know_predicates;
	import pacahon.log_msg;
	import pacahon.load_info;
	import pacahon.thread_context;
	import pacahon.event_filter;
	import pacahon.define;
	
	import search.ba2pacahon;	
	import search.xapian;
}

logger log;
logger io_msg;

static this()
{
	log = new logger("pacahon", "log", "server");
	io_msg = new logger("pacahon", "io", "server");
}

void main(char[][] args)
{
	Tid tid_ticket_manager = spawn (&ticket_manager);
	Tid tid_subject_manager = spawn (&subject_manager);	
	Tid tid_acl_manager = spawn (&acl_manager); 
			
    Tid tid_xapian_indexer = spawn (&xapian_indexer, tid_subject_manager);	
    spawn (&xapian_indexer_commiter, tid_xapian_indexer);
    
    Tid tid_statistic_data_accumulator = spawn (&statistic_data_accumulator);
    spawn (&print_statistic, tid_statistic_data_accumulator);    	
    	    	
	try
	{
		log.trace_log_and_console("\nPACAHON %s.%s.%s\nSOURCE: commit=%s date=%s\n", pacahon.myversion.major, pacahon.myversion.minor,
				pacahon.myversion.patch, pacahon.myversion.hash, pacahon.myversion.date);

		{
			JSONValue props;

			try
			{
				props = get_props("pacahon-properties.json");
			} catch(Exception ex1)
			{
				throw new Exception("ex! parse params:" ~ ex1.msg, ex1);
			}

			/////////////////////////////////////////////////////////////////////////////////////////////////////////			
			
			JSONValue[] _listeners;
			if(("listeners" in props.object) !is null)
			{
				_listeners = props.object["listeners"].array;
				int listener_section_count = 0;				
				foreach(listener; _listeners)
				{					
					listener_section_count++;
					string[string] params;
					foreach(key; listener.object.keys)
						params[key] = listener[key].str;

					if(params.get("transport", "") == "file_reader")
					{
						//spawn (&mq.file_reader.file_reader_thread, "pacahon-properties.json", tid_xapian_indexer, tid_ticket_manager, tid_subject_manager, tid_acl_manager, tid_statistic_data_accumulator);
						FileReadThread frt = new FileReadThread ("pacahon-properties.json", tid_xapian_indexer, tid_ticket_manager, tid_subject_manager, tid_acl_manager, tid_statistic_data_accumulator);
						frt.start ();  													
					}
					else if(params.get("transport", "") == "nanomsg")
					{
						spawn (&mq.nanomsg_listener.nanomsg_thread, "pacahon-properties.json", tid_xapian_indexer, tid_ticket_manager, tid_subject_manager, tid_acl_manager, tid_statistic_data_accumulator);							
					}
					else if(params.get("transport", "") == "zmq")
					{
						mq_client zmq_connection = null;
						
						string zmq_connect_type = params.get("zmq_connect_type", "server");
//						log.trace_log_and_console("LISTENER: connect to zmq:" ~ text (params), "");
						
						if(zmq_connect_type == "server")
						{
							try
							{
								spawn (&mq.zmq_listener.zmq_thread, "pacahon-properties.json", listener_section_count, tid_xapian_indexer, tid_ticket_manager, tid_subject_manager, tid_acl_manager, tid_statistic_data_accumulator);	
								log.trace_log_and_console("LISTENER: connect to zmq:" ~ text (params), "");
								
//								zmq_connection = new zmq_point_to_poin_client();
//								zmq_connection.connect_as_listener(params);
							} catch(Exception ex)
							{
							}
						} else if(zmq_connect_type == "broker")
						{
							if(zmq_connection is null)
							{
								//								zmq_connection = new zmq_pp_broker_client(bind_to, behavior);
								//								writeln("zmq PPP broker listener started:", bind_to);
							} else
							{
							}
						}

//						if(zmq_connection !is null)
//						{
//							zmq_connection.set_callback(&get_message);
//							ServerThread thread_listener_for_zmq = new ServerThread(&zmq_connection.listener, props, "ZMQ", 
//									tid_xapian_indexer, tid_ticket_manager, tid_subject_manager, tid_acl_manager, tid_statistic_data_accumulator);

//							if(("IGNORE_EMPTY_TRIPLE" in props.object) !is null)
//							{
//								if(props.object["IGNORE_EMPTY_TRIPLE"].str == "NO")
//									thread_listener_for_zmq.resource.IGNORE_EMPTY_TRIPLE = false;
//								else
//									thread_listener_for_zmq.resource.IGNORE_EMPTY_TRIPLE = true;
//							}

//							writeln("IGNORE_EMPTY_TRIPLE:", thread_listener_for_zmq.resource.IGNORE_EMPTY_TRIPLE);

//							writeln("start zmq listener");
//							thread_listener_for_zmq.start();

//							LoadInfoThread load_info_thread = new LoadInfoThread(&thread_listener_for_zmq.getStatistic);
//							load_info_thread.start();
//						}

					} else if(params.get("transport", "") == "rabbitmq")
					{
						mq_client rabbitmq_connection = null;
						
						// прием данных по каналу rabbitmq
						log.trace_log_and_console("LISTENER: connect to rabbitmq");

						try
						{
							rabbitmq_connection = new rabbitmq_client();
							rabbitmq_connection.connect_as_listener(params);

							if(rabbitmq_connection.is_success() == true)
							{
								rabbitmq_connection.set_callback(&get_message);

								ServerThread thread_listener_for_rabbitmq = new ServerThread(&rabbitmq_connection.listener,
										props, "RABBITMQ", tid_xapian_indexer, tid_ticket_manager, tid_subject_manager, tid_acl_manager,
										tid_statistic_data_accumulator);

								init_ba2pacahon(thread_listener_for_rabbitmq.resource);

								thread_listener_for_rabbitmq.start();

//								LoadInfoThread load_info_thread1 = new LoadInfoThread(&thread_listener_for_rabbitmq.getStatistic);
//								load_info_thread1.start();

							} else
							{
								writeln(rabbitmq_connection.get_fail_msg);
							}
						} catch(Exception ex)
						{
						}

					}

				}

				

				while(true)
					core.thread.Thread.sleep(dur!("seconds")(1000));
			}
		}
	} catch(Exception ex)
	{
		writeln("Exception: ", ex.msg);
	}

}

enum format: byte
{
	TURTLE = 0,
	JSON_LD = 1,
	UNKNOWN = -1
}

void get_message(byte* msg, int message_size, mq_client from_client, ref ubyte[] out_data, Context context = null)
{
	StopWatch sw;
	sw.start();

	if (context is null)
	{
		ServerThread server_thread = cast(ServerThread) core.thread.Thread.getThis();
		context = server_thread.resource;
	}
	
	byte msg_format = format.UNKNOWN;
	
	if(trace_msg[1] == 1)
	{
		log.trace("get message, count:[%d], message_size:[%d]", context.count_command, message_size);
	}	

	Subject[] subjects;

	if(trace_msg[0] == 1)
		io_msg.trace_io(true, msg, message_size);
	/*	
	 {
	 sw.stop();
	 long t = cast(long) sw.peek().usecs;
	 log.trace("messages count: %d, %d [µs] next: message parser start", server_thread.stat.count_message, t);
	 sw.start();
	 }
	 */

	bool is_parse_success = true;
	string parse_error;
	
	if(*msg == '{' || *msg == '[')
	{
		try
		{
			if(trace_msg[66] == 1)
				log.trace("parse from json");

			bool tmp_is_ba = true;
			for(int idx = 0; idx < message_size; idx++)
			{
				if(msg[idx] == '\"' && msg[idx + 1] == '@' && msg[idx + 2] == '\"')
				{
					tmp_is_ba = false;
					break;
				}
			}

//			if(tmp_is_ba == true)
//			{
//				string msg_str = util.utils.fromStringz(cast(char*) msg);
//				ba2pacahon(msg_str, context);
//
//				send(context.tid_statistic_data_accumulator, PUT, COUNT_COMMAND, 1);
//
//				sw.stop();
//				int t = cast(int) sw.peek().usecs;
//
//				send(context.tid_statistic_data_accumulator, PUT, WORKED_TIME, t);
//
//				if(trace_msg[69] == 1)
//					log.trace("messages, total time: %d [µs]", t);
//
////				context.sw.reset();
////				context.sw.start();
//				
//				return;
//			} else
			{
				msg_format = format.JSON_LD;
				subjects = parse_json_ld_string(cast(char*) msg, message_size);
			}

			if(trace_msg[67] == 1)
				log.trace("parse from json, ok");
		} catch(Exception ex)
		{
			is_parse_success = false;
			parse_error = ex.msg;
			log.trace("Exception in parse_json_ld_string:[%s]", ex.msg);

		}
	}
	else
	{
		//msg_format = format.TURTLE;
		msg_format = format.JSON_LD;
		subjects = parse_turtle_string(cast(char*) msg, message_size);
		
//		OutBuffer outbuff = new OutBuffer();
//		toJson_ld(subjects, outbuff, true);
//		outbuff.write(0);
//		ubyte[] bb = outbuff.toBytes();
//		io_msg.trace_io(true, cast(byte*) bb, bb.length);
		
	}
		
	if (subjects is null)
		subjects = new Subject[0];
	
	 /*
	 {
	 sw.stop();
	 long t = cast(long) sw.peek().usecs;
	 log.trace("messages count: %d, %d [µs] next: message parser stop", server_thread.stat.count_message, t);
	 sw.start();
	 }
	 */

	if(trace_msg[3] == 1)
	{
		OutBuffer outbuff = new OutBuffer();
		toJson_ld(subjects, outbuff, true);
		outbuff.write(0);
		ubyte[] bb = outbuff.toBytes();
		io_msg.trace_io(true, cast(byte*) bb, bb.length);
	}

	if(trace_msg[4] == 1)
		log.trace("command.length=%d", subjects.length);

	Subject[] results;

//	if(is_parse_success == false)
//	{
//		results = new Subject[1];
//
//		Subject res = new Subject();
//
//		res.subject = generateMsgId();
//
//		res.addPredicateAsURI("a", msg__Message);
//		res.addPredicate(msg__sender, "pacahon");
//
//		//			if(message !is null)
//		//			{
//		//				res.addPredicateAsURI(msg__in_reply_to, message.subject);								
//		//			}
//
//		res.addPredicate(msg__reason, "JSON Parsing error:" ~ parse_error);
//		res.addPredicate(msg__status, "400");
//
//		results[0] = res;
//	} else
	{
		results = new Subject[subjects.length];

		// найдем в массиве triples субьекта с типом msg

		// local_ticket <- здесь может быть тикет для выполнения пакетных операций
		Ticket *ticket;
		char from;

		int ii = 0;
		foreach (command ; subjects)
		{
			StopWatch sw_c;
			sw_c.start();

			if(trace_msg[5] == 1)
			{
				log.trace("get_message:subject.count_edges=%d", command.count_edges);
				log.trace("get_message:message.subject=%s", command.subject);
			}

			if(command.count_edges < 3)
			{
				log.trace("данная команда [%s] не является полной (command.count_edges < 3), пропустим\n", command.subject);
				continue;
			}

			//		command.reindex_predicate();

			Predicate type = command.getPredicate("a");
			if(type is null)
				type = command.getPredicate(rdf__type);

			if(trace_msg[6] == 1)
			{
				if(type !is null)
					log.trace("command type:" ~ type.toString());
				else
					log.trace("command type: unknown");
			}


			if(type !is null && (msg__Message in type.objects_of_value) !is null)
			{				
				Predicate reciever = command.getPredicate(msg__reciever);
				Predicate sender = command.getPredicate(msg__sender);

				if(trace_msg[6] == 1)
					log.trace("message accepted from:%s", sender.getFirstLiteral());

				Predicate p_ticket = command.getPredicate(msg__ticket);
				string userId;

				if(p_ticket !is null && p_ticket.getObjects() !is null)
				{
					string ticket_id = p_ticket.getObjects()[0].literal;
					
					if (ticket_id != "@local")
					{
						ticket = context.foundTicket(ticket_id);

						// проверим время жизни тикета
						if(ticket !is null)
						{
							SysTime now = Clock.currTime();
							if(now.stdTime > ticket.end_time)
							{
								// тикет просрочен
								if(trace_msg[61] == 1)
									log.trace("тикет просрочен, now=%s(%d) > tt.end_time=%d", timeToString(now), now.stdTime,
											ticket.end_time);
							} else
							{
								userId = ticket.userId;
								// продляем тикет
							
								ticket.end_time = now.stdTime + 3600;
							}
						}

						if(trace_msg[62] == 1)
							if(userId !is null)
								log.trace("пользователь найден, userId=%s", userId);

					}
					
				}

				if(type !is null && reciever !is null && ("pacahon" in reciever.objects_of_value) !is null)
				{
					results[ii] = new Subject;
					
					command_preparer(ticket, command, results[ii], sender, context, ticket, from);
				}

				Predicate command_name = command.getPredicate(msg__command);
				send(context.tid_statistic_data_accumulator, PUT, COUNT_COMMAND, 1);
				sw_c.stop();
				long t = cast(long) sw_c.peek().usecs;

				if(trace_msg[68] == 1)
				{
					log.trace("command [%s][%s] %s, count: %d, total time: %d [µs]", command_name.getFirstLiteral(),
							command.subject, sender.getFirstLiteral(), context.count_command, t);
					if(t > 60_000_000)
						log.trace("command [%s][%s] %s, time > 1 min", command_name.getFirstLiteral(), command.subject,
								sender.getFirstLiteral());
					else if(t > 10_000_000)
						log.trace("command [%s][%s] %s, time > 10 s", command_name.getFirstLiteral(), command.subject,
								sender.getFirstLiteral());
					else if(t > 1_000_000)
						log.trace("command [%s][%s] %s, time > 1 s", command_name.getFirstLiteral(), command.subject,
								sender.getFirstLiteral());
					else if(t > 100_000)
						log.trace("command [%s][%s] %s, time > 100 ms", command_name.getFirstLiteral(), command.subject,
								sender.getFirstLiteral());
				}

			} else
			{
				results[ii] = new Subject;
				//command_preparer(ticket, command, results[ii], null, null, server_thread.resource, ticket, from);
			}
//				writeln ("##6");
			ii++;
		}
		
		if (ii == 0)
			writeln ("II == 0, MSG_LENGTH=, ", message_size, ", msg=", cast (string)msg[0..message_size]);
		
	}

	if(trace_msg[8] == 1)
		log.trace("формируем ответ, серилизуем ответные графы в строку");

	OutBuffer outbuff = new OutBuffer();


	if(msg_format == format.JSON_LD)
		toJson_ld(results, outbuff, false);

	//outbuff.write(0);

	out_data = outbuff.toBytes();

	if(trace_msg[9] == 1)
		log.trace("данные для отправки сформированны, out_data=%s", cast(char[]) out_data);

	//if(from_client !is null)
	//	{
	//		out_data = msg_out;		
	//		from_client.send(cast(char*) "".ptr, cast(char*) msg_out, msg_out.length, false);
	//	}

	if(trace_msg[10] == 1)
	{
		if(out_data !is null)
			io_msg.trace_io(false, cast(byte*) out_data, out_data.length);
	}
		
	send(context.tid_statistic_data_accumulator, PUT, COUNT_MESSAGE, 1);
		
	sw.stop();
	int t = cast(int) sw.peek().usecs;
	send(context.tid_statistic_data_accumulator, PUT, WORKED_TIME, t);

	if(trace_msg[69] == 1)
		log.trace("messages count: %d, total time: %d [µs]", context.count_message, t);

//	context.sw.reset();
//	context.sw.start();
	/*
	 if ((server_thread.stat.count_message % 10_000) == 0)
	 {
	 writeln ("start GC");
	 GC.collect();
	 GC.minimize();
	 }
	 */
	
	return;
}

class ServerThread: core.thread.Thread
{
	ThreadContext resource;

	this(void delegate() _dd, JSONValue props, string context_name, Tid tid_xapian_indexer, Tid tid_ticket_manager, Tid tid_subject_manager, Tid tid_acl_manager, Tid tid_statistic_data_accumulator)
	{
		super(_dd);
		resource = new ThreadContext(props, context_name, tid_xapian_indexer, tid_ticket_manager, tid_subject_manager, tid_acl_manager, tid_statistic_data_accumulator);				
		
//		resource.sw.start();
	}


}
