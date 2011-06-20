module pacahon.server;

private import myversion;

version(D1)
{
	private import std.c.stdlib;
	private import std.thread;
}

version(D2)
{
	private import core.thread;
	private import core.stdc.stdio;
	private import core.stdc.stdlib;
}

private import std.stdio;

private import std.c.string;

private import std.json_str;
private import std.outbuffer;

version(dmd2_053)
{
	private import std.datetime;
}
else
{
	private import std.datetime;
	private import std.date;
}

private import libzmq_headers;
private import zmq_point_to_poin_client;
private import zmq_pp_broker_client;

private import Integer = tango.text.convert.Integer;

private import pacahon.graph;
private import pacahon.n3.parser;
private import pacahon.json_ld.parser;

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
		}
		catch (Exception ex1)
		{
			throw new Exception ("ex! parse params", ex1);
		}

		log.trace_log_and_console("agent Pacahon, source: commit=%s date=%s", myversion.hash, myversion.date);

		mq_client client = null;

		string bind_to = props.object["zmq_point"].str;

		string mongodb_server = props.object["mongodb_server"].str;
		string mongodb_collection = props.object["mongodb_collection"].str;
		string cache_type = props.object["cache_type"].str;
		int mongodb_port = cast(int) props.object["mongodb_port"].integer;
		
		writeln("connect to mongodb, \n");
		writeln("	port:", mongodb_port);
		writeln("	server:", mongodb_server);
		writeln("	collection:",  mongodb_collection);
		writeln("	cache_type:",  cache_type);

		byte cp = caching_type.NONE;

		if(cache_type == "ALL_DATA")
			cp = caching_type.ALL_DATA;

		TripleStorage ts;
		try
		{
		    ts = new TripleStorageMongoDB(mongodb_server, mongodb_port, mongodb_collection, cp);
		    printf("ok, connected : %X\n", ts);
		}
		catch (Exception ex)
		{
		    printf("fail connect to mongo");
		    throw ex;
		}

		
		try
		{
			client = new zmq_point_to_poin_client(bind_to);
			printf("point to point zmq listener started\n");
		}
		catch (Exception ex)
		{
		}

		if (client is null)
		{
			client = new zmq_pp_broker_client(bind_to);
			printf("zmq PPP broker listener started\n");
		}
		else
		{
		}
		
		if (client !is null)
		{			
			client.set_callback(&get_message);

			ServerThread thread = new ServerThread(&client.listener, ts);
			
			thread.resource.client = client;
			
			// TODO времянка, переделать!
			{
				string reply_to_n1 = props.object["reply_to_n1"].str;
			
				if (reply_to_n1 !is null)
				{
					thread.resource.soc__reply_to_n1 = client.connect_as_req (reply_to_n1);
					log.trace("connect to %s is Ok", reply_to_n1);
				}
			}
			
			thread.start();
			
			LoadInfoThread load_info_thread = new LoadInfoThread(&thread.getStatistic);			
			load_info_thread.start();

			version(D1)
			{
				thread.wait();
			}

			while(true)
				Thread.getThis().sleep(100_000_000);
		}

	}
	catch(Exception ex)
	{
		printf("Exception: %s", ex.msg);
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
	ServerThread server_thread = cast(ServerThread) Thread.getThis();
	server_thread.sw.stop();

	version(dmd2_053)
	    long time_from_last_call = cast(long) server_thread.sw.peek().usecs;
	else
	    long time_from_last_call = cast(long) server_thread.sw.peek().microseconds;

	if(time_from_last_call < 10)
		printf("microseconds passed from the last call: %d\n", time_from_last_call);
	
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
		}
		catch(Exception ex)
		{
			log.trace("Exception in parse_json_ld_string:[%s]", ex.msg);
		}
	}
	else
	{
		try
		{
			if(trace_msg[66] == 1)
				log.trace("parse from turtle");

			msg_format = format.TURTLE;
			triples = parse_n3_string(cast(char*) msg, message_size);

			if(trace_msg[67] == 1)
				log.trace("parse from turtle, ok");
		}
		catch(Exception ex)
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

		set_hashed_data(command);

		Predicate* type = command.getEdge("a");
		if(type is null)
			type = command.getEdge(rdf__type);

		if((msg__Message in type.objects_of_value) !is null)
		{
			Predicate* reciever = command.getEdge(msg__reciever);
			Predicate* sender = command.getEdge(msg__sender);

			if(trace_msg[6] == 1)
				log.trace("message accepted from:%s", sender.getFirstObject());

			Predicate* ticket = command.getEdge(msg__ticket);

			string userId;

			if(ticket !is null && ticket.objects !is null)
			{
				string ticket_str = ticket.objects[0].object;

				if(ticket_str == "@local")
					ticket_str = local_ticket;

				Ticket tt = server_thread.foundTicket(ticket_str);

				// проверим время жизни тикета
				if(tt !is null)
				{
					version(dmd2_053)
					{
						SysTime now = Clock.currTime();
						if(now.stdTime > tt.end_time)
						{
							// тикет просрочен
							if(trace_msg[61] == 1)
								log.trace("тикет просрочен, now=%s(%d) > tt.end_time=%d", timeToString(now), now.stdTime, tt.end_time);
						}
						else
						{
							userId = tt.userId;
						}
					}
					else
					{
						auto now = UTCtoLocalTime(getUTCtime());
						if(now > tt.end_time)
						{
							// тикет просрочен
							if(trace_msg[61] == 1)
								log.trace("тикет просрочен, now=%s > tt.end_time=%s", timeToString(now), tt.end_time);
						}
						else
						{
							userId = tt.userId;
						}
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
					version(dmd2_053)
						long t = cast(long) sw.peek().usecs;
					else
						long t = cast(long) sw.peek().microseconds;
					log.trace("messages count: %d, %d [µs] next: command_preparer", server_thread.stat.count_message, t);
					sw.start();
				}

				command_preparer(command, results[ii], sender, userId, server_thread.resource, local_ticket);

				if(trace_msg[7] == 1)
				{
					sw.stop();
					version(dmd2_053)
						long t = cast(long) sw.peek().usecs;
					else
						long t = cast(long) sw.peek().microseconds;
					log.trace("messages count: %d, %d [µs] end: command_preparer", server_thread.stat.count_message, t);
					sw.start();
				}
				//				results[ii] = out_message;
			}

			Predicate* command_name = command.getEdge(msg__command);
			server_thread.stat.count_command++;
			sw_c.stop();
			version(dmd2_053)
				long t = cast(long) sw_c.peek().usecs;
			else
				long t = cast(long) sw_c.peek().microseconds;
			log.trace("command [%s] %s, count: %d, total time: %d [µs]", command_name.getFirstObject(), sender.getFirstObject(),
					server_thread.stat.count_command, t);

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

	if(trace_msg[9] == 1)
		log.trace("send");

	out_data = outbuff.toBytes();

//	if(from_client !is null)
//	{
//		out_data = msg_out;		
//		from_client.send(cast(char*) "".ptr, cast(char*) msg_out, msg_out.length, false);
//	}

	if(trace_msg[10] == 1)
		io_msg.trace_io(false, cast(byte*) out_data, out_data.length);
		
	server_thread.stat.count_message++;
	server_thread.stat.size__user_of_ticket = server_thread.resource.user_of_ticket.length;
	server_thread.stat.size__cache__subject_creator = server_thread.resource.cache__subject_creator.length;	

	
	sw.stop();
	version(dmd2_053)
		long t = cast(long) sw.peek().usecs;
	else
		long t = cast(long) sw.peek().microseconds;
	
	server_thread.stat.worked_time += t;
	
	log.trace("messages count: %d, total time: %d [µs]", server_thread.stat.count_message, t);

	server_thread.sw.reset();
	server_thread.sw.start();
	
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

class ServerThread: Thread
{
	ThreadContext resource;

	StopWatch sw;
	Statistic stat;
	
	Statistic getStatistic ()
	{
		return stat;
	}
	
	this(void delegate() _dd, TripleStorage _ts)
	{
		super(_dd);
		stat = new Statistic (); 
		resource = new ThreadContext ();	
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
			if (ticket_id ! is null && ticket_id.length > 10)
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
					log.trace("сессионный билет %s Ok, user=%s, when=%s, duration=%d", ticket_id, tt.userId, when, duration);

				// TODO stringToTime очень медленная операция ~ 100 микросекунд
				tt.end_time = stringToTime(when) + duration * 100_000_000_000; //? hnsecs?

				resource.user_of_ticket[cast(immutable) ticket_id] = tt;
			}
		}

		return tt;
	}
}
		
