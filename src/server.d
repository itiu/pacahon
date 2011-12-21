module pacahon.server;

private import myversion;

private import core.thread;
private import core.stdc.stdio;
private import core.stdc.stdlib;

private import std.stdio;

private import std.c.string;

private import std.json_str;
private import std.outbuffer;

private import std.datetime;

import core.memory;

private import libzmq_headers;
private import zmq_point_to_poin_client;
private import zmq_pp_broker_client;

private import Integer = tango.text.convert.Integer;

private import pacahon.graph;
private import pacahon.n3.parser;
private import pacahon.json_ld.parser1;

private import trioplax.triple;
private import trioplax.TripleStorage;
private import trioplax.mongodb.TripleStorageMongoDB;

private import trioplax.Logger;

private import pacahon.command.multiplexor;
private import pacahon.know_predicates;

private import pacahon.utils;
private import pacahon.log_msg;
private import pacahon.load_info;
private import pacahon.thread_context;

private import pacahon.command.event_filter;

private import pacahon.zmq_connection;

Logger log;
Logger io_msg;

static this()
{
	log = new Logger("pacahon", "log", "server");
	io_msg = new Logger("pacahon", "io", "server");
}

void main(char[][] args)
{
	try
	{
		JSONValue props;

		try
		{
			props = get_props("pacahon-properties.json");
		} catch(Exception ex1)
		{
			throw new Exception("ex! parse params", ex1);
		}

		log.trace_log_and_console("\nPACAHON %s.%s.%s\nSOURCE: commit=%s date=%s\n", myversion.major, myversion.minor,
				myversion.patch, myversion.hash, myversion.date);

		mq_client client = null;

		string bind_to = "tcp://*:5555";
		if(("zmq_point" in props.object) !is null)
			bind_to = props.object["zmq_point"].str;

		string mongodb_server = "localhost";
		if(("mongodb_server" in props.object) !is null)
			mongodb_server = props.object["mongodb_server"].str;

		string mongodb_collection = "pacahon";
		if(("mongodb_collection" in props.object) !is null)
			mongodb_collection = props.object["mongodb_collection"].str;

		// кеширование
		// NONE
		// ALL_DATA
		// QUERY_RESULT		
		string cache_type = "NONE";
		if(("cache_type" in props.object) !is null)
			cache_type = props.object["cache_type"].str;

		int mongodb_port = 27017;
		if(("mongodb_port" in props.object) !is null)
			mongodb_port = cast(int) props.object["mongodb_port"].integer;

		string zmq_connect_type = "server";
		if(("zmq_connect_type" in props.object) !is null)
			zmq_connect_type = props.object["zmq_connect_type"].str;

		// логгирование
		// gebug - все отладочные сообщения, внимание! при включении будут жуткие тормоза! 
		// off - выключено
		// info - краткая информация о выполненных командах 
		// info_and_io - краткая информация о выполненных командах и входящие и исходящие сообщения 
		string logging = "info_and_io";
		if(("logging" in props.object) !is null)
			logging = props.object["logging"].str;

		// поведение:
		//	all - выполняет все операции
		//  writer - только операции записи
		//  reader - только операции чтения
		//  logger - ничего не выполняет а только логгирует операции, параметры logging не учитываются 		
		string behavior = "all";
		if(("behavior" in props.object) !is null)
			behavior = props.object["behavior"].str;

		writeln("connect to mongodb, \n");
		writeln("	port:", mongodb_port);
		writeln("	server:", mongodb_server);
		writeln("	collection:", mongodb_collection);
		writeln("	cache_type:", cache_type);

		byte cp = caching_type.NONE;

		if(cache_type == "ALL_DATA")
			cp = caching_type.ALL_DATA;

		if(cache_type == "QUERY_RESULT")
			cp = caching_type.QUERY_RESULT;

		string yawl_engine = null;
		if(("yawl-engine" in props.object) !is null)
			yawl_engine = props.object["yawl-engine"].str;

		TripleStorage ts;
		try
		{
			ts = new TripleStorageMongoDB(mongodb_server, mongodb_port, mongodb_collection, cp);

			ts.define_predicate_as_multiple("a");
			ts.define_predicate_as_multiple("rdf:type");
			ts.define_predicate_as_multiple("rdfs:subClassOf");
			ts.define_predicate_as_multiple("gost19:take");
			ts.define_predicate_as_multiple("event:msg_template");

			ts.define_predicate_as_multilang("swrc:name");
			ts.define_predicate_as_multilang("swrc:firstName");
			ts.define_predicate_as_multilang("swrc:lastName");
			//			ts.define_predicate_as_multilang("gost19:middleName");
			ts.define_predicate_as_multilang("docs:position");

			ts.set_fulltext_indexed_predicates("swrc:name");
			ts.set_fulltext_indexed_predicates("swrc:firstName");
			ts.set_fulltext_indexed_predicates("swrc:lastName");
			ts.set_fulltext_indexed_predicates("gost19:middleName");
			ts.set_fulltext_indexed_predicates("docs:position");
			ts.set_fulltext_indexed_predicates("rdfs:label");
			ts.set_fulltext_indexed_predicates("swrc:email");
			ts.set_fulltext_indexed_predicates("swrc:phone");
			ts.set_fulltext_indexed_predicates("gost19:internal_phone");

			printf("ok, connected : %X\n", ts);
		} catch(Exception ex)
		{
			throw new Exception("Connect to mongodb: " ~ ex.msg, ex);
		}

		if(zmq_connect_type == "server")
		{
			try
			{
				client = new zmq_point_to_poin_client(bind_to);
				writeln("point to point zmq listener started:", bind_to);
			} catch(Exception ex)
			{
			}
		}

		if(zmq_connect_type == "broker")
		{
			if(client is null)
			{
				client = new zmq_pp_broker_client(bind_to, behavior);
				writeln("zmq PPP broker listener started:", bind_to);
			} else
			{
			}
		}

		if(client !is null)
		{
			client.set_callback(&get_message);

			ServerThread thread = new ServerThread(&client.listener, ts);

			thread.resource.client = client;

			JSONValue[] gateways;

			//TODO			thread.resource.yawl_engine_connect = new ZmqConnection (client);
			if(("gateways" in props.object) !is null)
			{
				gateways = props.object["gateways"].array;
				foreach(gateway; gateways)
				{
					if(("alias" in gateway.object) !is null && ("point" in gateway.object) !is null)
					{
						thread.resource.gateways[gateway.object["alias"].str] = new ZmqConnection(client,
								gateway.object["point"].str);
					}
				}
			}

			writeln(thread.resource.gateways);

			load_events(thread.resource);

			thread.start();

			LoadInfoThread load_info_thread = new LoadInfoThread(&thread.getStatistic);
			load_info_thread.start();

			version(D1)
			{
				thread.wait();
			}

			while(true)
				core.thread.Thread.getThis().sleep(100_000_000);
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

void get_message(byte* msg, int message_size, mq_client from_client, ref ubyte[] out_data)
{
	ServerThread server_thread = cast(ServerThread) core.thread.Thread.getThis();
	server_thread.sw.stop();

	long time_from_last_call = cast(long) server_thread.sw.peek().usecs;

	//	if(time_from_last_call < 10)
	//		printf("microseconds passed from the last call: %d\n", time_from_last_call);

	server_thread.stat.idle_time += time_from_last_call;

	StopWatch sw;
	sw.start();

	byte msg_format = format.UNKNOWN;

	if(trace_msg[1] == 1)
		log.trace("get message, count:[%d], message_size:[%d]", server_thread.stat.count_message, message_size);

	//	from_client.get_counts(count_message, count_command);

	if(trace_msg[0] == 1)
		io_msg.trace_io(true, msg, message_size);

	TripleStorage ts = server_thread.resource.ts;

	Subject[] triples;

	if(*msg == '{' || *msg == '[')
	{
		try
		{
			if(trace_msg[66] == 1)
				log.trace("parse from json");

			msg_format = format.JSON_LD;
			triples = parse_json_ld_string(cast(char*) msg, message_size);

			if(trace_msg[67] == 1)
				log.trace("parse from json, ok");
		} catch(Exception ex)
		{
			log.trace("Exception in parse_json_ld_string:[%s]", ex.msg);
		}
	} else
	{
		try
		{
			if(trace_msg[66] == 1)
				log.trace("parse from turtle");

			msg_format = format.TURTLE;
			triples = parse_n3_string(cast(char*) msg, message_size);

			if(trace_msg[67] == 1)
				log.trace("parse from turtle, ok");
		} catch(Exception ex)
		{
			log.trace("Exception in parse_n3_string:[%s]", ex.msg);
		}
	}

	if(trace_msg[2] == 1)
	{
		OutBuffer outbuff = new OutBuffer();
		toTurtle(triples, outbuff);
		outbuff.write(0);
		ubyte[] bb = outbuff.toBytes();
		io_msg.trace_io(true, cast(byte*) bb, bb.length);
	}

	if(trace_msg[3] == 1)
	{
		OutBuffer outbuff = new OutBuffer();
		toJson_ld(triples, outbuff);
		outbuff.write(0);
		ubyte[] bb = outbuff.toBytes();
		io_msg.trace_io(true, cast(byte*) bb, bb.length);
	}

	if(trace_msg[4] == 1)
		log.trace("command.length=%d", triples.length);

	Subject[] results = new Subject[triples.length];

	// найдем в массиве triples субьекта с типом msg

	// local_ticket <- здесь может быть тикет для выполнения пакетных операций
	string local_ticket;

	for(int ii = 0; ii < triples.length; ii++)
	{
		StopWatch sw_c;
		sw_c.start();

		Subject command = triples[ii];

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

		Predicate* type = command.getPredicate("a");
		if(type is null)
			type = command.getPredicate(rdf__type);

		if(trace_msg[6] == 1)
			log.trace("command type:%X", type);

		if(type !is null && (msg__Message in type.objects_of_value) !is null)
		{
			Predicate* reciever = command.getPredicate(msg__reciever);
			Predicate* sender = command.getPredicate(msg__sender);

			if(trace_msg[6] == 1)
				log.trace("message accepted from:%s", sender.getFirstObject());

			Predicate* ticket = command.getPredicate(msg__ticket);

			string userId;

			if(ticket !is null && ticket.objects !is null)
			{
				string ticket_str = ticket.objects[0].literal;

				if(ticket_str == "@local")
					ticket_str = local_ticket;

				Ticket tt = server_thread.foundTicket(ticket_str);

				// проверим время жизни тикета
				if(tt !is null)
				{
					SysTime now = Clock.currTime();
					if(now.stdTime > tt.end_time)
					{
						// тикет просрочен
						if(trace_msg[61] == 1)
							log.trace("тикет просрочен, now=%s(%d) > tt.end_time=%d", timeToString(now), now.stdTime,
									tt.end_time);
					} else
					{
						userId = tt.userId;
					}
				}

				if(trace_msg[62] == 1)
					if(userId !is null)
						log.trace("пользователь найден, userId=%s", userId);

			}

			if(type !is null && reciever !is null && ("pacahon" in reciever.objects_of_value) !is null)
			{
				//				Predicate* sender = command.getEdge(msg__sender);
				//				Subject* out_message = new Subject;
				results[ii] = new Subject;

				if(trace_msg[6] == 1)
				{
					sw.stop();
					long t = cast(long) sw.peek().usecs;

					log.trace("messages count: %d, %d [µs] next: command_preparer", server_thread.stat.count_message, t);
					sw.start();
				}

				command_preparer(command, results[ii], sender, userId, server_thread.resource, local_ticket);

				if(trace_msg[7] == 1)
				{
					sw.stop();
					long t = cast(long) sw.peek().usecs;
					log.trace("messages count: %d, %d [µs] end: command_preparer", server_thread.stat.count_message, t);
					sw.start();
				}
				//				results[ii] = out_message;
			}

			Predicate* command_name = command.getPredicate(msg__command);
			server_thread.stat.count_command++;
			sw_c.stop();
			long t = cast(long) sw_c.peek().usecs;

			if(trace_msg[68] == 1)
			{
				log.trace("command [%s] %s, count: %d, total time: %d [µs]", command_name.getFirstObject(),
						sender.getFirstObject(), server_thread.stat.count_command, t);
				if(t > 60_000_000)
					log.trace("command [%s] %s, time > 1 min", command_name.getFirstObject(), sender.getFirstObject());
				else if(t > 10_000_000)
					log.trace("command [%s] %s, time > 10 s", command_name.getFirstObject(), sender.getFirstObject());
				else if(t > 1_000_000)
					log.trace("command [%s] %s, time > 1 s", command_name.getFirstObject(), sender.getFirstObject());
				else if(t > 100_000)
					log.trace("command [%s] %s, time > 100 ms", command_name.getFirstObject(), sender.getFirstObject());
			}

		} else
		{
			results[ii] = new Subject;
			command_preparer(command, results[ii], null, null, server_thread.resource, local_ticket);
		}

	}

	if(trace_msg[8] == 1)
		log.trace("формируем ответ, серилизуем ответные графы в строку");

	OutBuffer outbuff = new OutBuffer();

	if(msg_format == format.TURTLE)
		toTurtle(results, outbuff);

	if(msg_format == format.JSON_LD)
		toJson_ld(results, outbuff);

	//	outbuff.write(0);

	out_data = outbuff.toBytes();

	if(trace_msg[9] == 1)
		log.trace("данные для отправки сформированны, out_data=%s", cast(char[]) out_data);

	//	if(from_client !is null)
	//	{
	//		out_data = msg_out;		
	//		from_client.send(cast(char*) "".ptr, cast(char*) msg_out, msg_out.length, false);
	//	}

	if(trace_msg[10] == 1)
	{
		if(out_data !is null)
			io_msg.trace_io(false, cast(byte*) out_data, out_data.length);
	}

	server_thread.stat.count_message++;
	server_thread.stat.size__user_of_ticket = cast(uint)server_thread.resource.user_of_ticket.length;
	server_thread.stat.size__cache__subject_creator = cast(uint)server_thread.resource.cache__subject_creator.length;

	sw.stop();
	long t = cast(long) sw.peek().usecs;

	server_thread.stat.worked_time += t;

	if(trace_msg[69] == 1)
		log.trace("messages count: %d, total time: %d [µs]", server_thread.stat.count_message, t);

	server_thread.sw.reset();
	server_thread.sw.start();
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

synchronized class Statistic
{
	int count_message = 0;
	int count_command = 0;
	int idle_time = 0;
	int worked_time = 0;
	int size__user_of_ticket;
	int size__cache__subject_creator;
}

class ServerThread: core.thread.Thread
{
	ThreadContext resource;

	StopWatch sw;
	Statistic stat;

	Statistic getStatistic()
	{
		return stat;
	}

	this(void delegate() _dd, TripleStorage _ts)
	{
		super(_dd);
		stat = new Statistic();
		resource = new ThreadContext();
		resource.ts = _ts;
		sw.start();
	}

	Ticket foundTicket(string ticket_id)
	{
		Ticket tt;

		//	trace_msg[2] = 0;

		if((ticket_id in resource.user_of_ticket) !is null)
		{
			if(trace_msg[17] == 1)
				log.trace("тикет нашли в кеше, %s", ticket_id);

			tt = resource.user_of_ticket[ticket_id];
		}

		if(tt is null)
		{
			tt = new Ticket;
			tt.id = ticket_id;

			if(trace_msg[18] == 1)
			{
				log.trace("найдем пользователя по сессионному билету ticket=%s", ticket_id);
				//			printf("T count: %d, %d [µs] start get data\n", count, cast(long) sw.peek().microseconds);
			}

			string when = null;
			int duration = 0;

			// найдем пользователя по сессионному билету и проверим просрочен билет или нет
			if(ticket_id !is null && ticket_id.length > 10)
			{
				TLIterator it = resource.ts.getTriples(ticket_id, null, null);

				if(trace_msg[19] == 1)
					if(it is null)
						log.trace("сессионный билет не найден");

				foreach(triple; it)
				{
					if(trace_msg[20] == 1)
						log.trace("foundTicket: %s %s %s", triple.S, triple.P, triple.O);

					if(triple.P == ticket__accessor)
					{
						tt.userId = triple.O;
						if(trace_msg[21] == 1)
							log.trace("tt.userId=%s", tt.userId);
					}
					if(triple.P == ticket__when)
						when = triple.O;

					if(triple.P == ticket__duration)
					{
						duration = Integer.toInt(cast(char[]) triple.O);
					}
					if(tt.userId !is null && when !is null && duration > 10)
						break;
				}

				delete (it);
			}

			if(trace_msg[20] == 1)
				log.trace("foundTicket end");

			if(tt.userId is null)
			{
				if(trace_msg[22] == 1)
					log.trace("найденный сессионный билет не полон, пользователь не найден");
			}

			if(tt.userId !is null && (when is null || duration < 10))
			{
				if(trace_msg[23] == 1)
					log.trace("найденный сессионный билет не полон, считаем что пользователь не был найден");
				tt.userId = null;
			}

			if(when !is null)
			{
				if(trace_msg[24] == 1)
					log.trace("сессионный билет %s Ok, user=%s, when=%s, duration=%d", ticket_id, tt.userId, when,
							duration);

				// TODO stringToTime очень медленная операция ~ 100 микросекунд
				tt.end_time = stringToTime(when) + duration * 100_000_000_000; //? hnsecs?

				resource.user_of_ticket[cast(string) ticket_id] = tt;
			}
		}

		return tt;
	}
}
