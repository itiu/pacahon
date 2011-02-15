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

private import std.json;
private import std.outbuffer;

version(dmd2_052)
{
	private import std.datetime;
}
else
{
	private import std.datetime;
	private import std.date;
}

private import libzmq_headers;
private import libzmq_client;

private import Integer = tango.text.convert.Integer;

private import pacahon.graph;
private import pacahon.n3.parser;
private import pacahon.json_ld.parser;

private import trioplax.triple;
private import trioplax.TripleStorage;
private import trioplax.mongodb.TripleStorageMongoDB;

private import pacahon.command.multiplexor;
private import pacahon.know_predicates;

private import pacahon.utils;
private import trioplax.Logger;

private import pacahon.log_msg;

private import pacahon.load_info;

Logger log;
Logger io_msg;

static this()
{
	log = new Logger("pacahon.log", "server");
	io_msg = new Logger("pacahon.io", "server");
}

void main(char[][] args)
{
	try
	{
		JSONValue props = get_props("pacahon-properties.json");

		log.trace_log_and_console("agent Pacahon, source: commit=%s date=%s", myversion.hash, myversion.date);

		mom_client client = null;

		char* bind_to = cast(char*) props.object["zmq_point"].str;

		string mongodb_server = props.object["mongodb_server"].str;
		string mongodb_collection = props.object["mongodb_collection"].str;
		int mongodb_port = cast(int) props.object["mongodb_port"].integer;

		printf("connect to mongodb, \n");
		printf("	port: %d\n", mongodb_port);
		printf("	server: %s\n", cast(char*) mongodb_server);
		printf("	collection: %s\n", cast(char*) mongodb_collection);

		TripleStorage ts = new TripleStorageMongoDB(mongodb_server, mongodb_port, mongodb_collection, caching_type.NONE);
		printf("ok, connected : %X\n", ts);

		client = new libzmq_client(bind_to);
		client.set_callback(&get_message);

		ServerThread thread = new ServerThread(&client.listener, ts);

		thread.start();

		printf("listener of zmq started\n");

		LoadInfoThread load_info_thread = new LoadInfoThread(&client.get_count);
		load_info_thread.start();

		version(D1)
		{
			thread.wait();
		}

		while(true)
			Thread.getThis().sleep(100_000_000);

	}
	catch(Exception ex)
	{
		printf("Exception: %s", ex.msg);
	}

}

class Ticket
{
	string id;
	string userId;

	long end_time;
}

Ticket[string] user_of_ticket;

enum format: byte
{
	TURTLE = 0,
	JSON_LD = 1,
	UNKNOWN = -1
}

class ServerThread: Thread
{
	TripleStorage ts;

	this(void delegate() _dd, TripleStorage _ts)
	{
		super(_dd);
		ts = _ts;
	}
}

void get_message(byte* msg, int message_size, mom_client from_client)
{
	byte msg_format = format.UNKNOWN;

	int count;
	from_client.get_count(count);

	if(trace_msg[0] == 1)
		io_msg.trace_io(true, msg, message_size);

	StopWatch sw;
	sw.start();

	ServerThread server_thread = cast(ServerThread) Thread.getThis();
	TripleStorage ts = server_thread.ts;

	if(trace_msg[1] == 1)
		log.trace("get message, count:[%d]", count);

	Subject[] triples;

	if(*msg == '{' || *msg == '[')
	{
		msg_format = format.JSON_LD;
		triples = parse_json_ld_string(cast(char*) msg, message_size);
	}
	else
	{
		msg_format = format.TURTLE;
		triples = parse_n3_string(cast(char*) msg, message_size);
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

				Ticket tt = foundTicket(ticket_str, ts);

				// проверим время жизни тикета
				if(tt !is null)
				{
					version(dmd2_052)
					{
						SysTime now = Clock.currTime(UTC());
						if(now.stdTime > tt.end_time)
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
					version(dmd2_052)
						long t = cast(long) sw.peek().usecs;
					else
						long t = cast(long) sw.peek().microseconds;
					log.trace("T count: %d, %d [µs] next: command_preparer", count, t);
					sw.start();
				}

				command_preparer(command, results[ii], sender, userId, ts, local_ticket);

				if(trace_msg[7] == 1)
				{
					sw.stop();
					version(dmd2_052)
						long t = cast(long) sw.peek().usecs;
					else
						long t = cast(long) sw.peek().microseconds;
					log.trace("T count: %d, %d [µs] end: command_preparer", count, t);
					sw.start();
				}
				//				results[ii] = out_message;
			}

		}

	}

	if(trace_msg[8] == 1)
		log.trace("формируем ответ, серилизуем ответные графы в строку");

	StopWatch sw1;
	sw1.start();

	OutBuffer outbuff = new OutBuffer();

	if(msg_format == format.TURTLE)
		toTurtle(results, outbuff);

	if(msg_format == format.JSON_LD)
		toJson_ld(results, outbuff);

	outbuff.write(0);

	//       sw1.stop();
	//               log.trace("json msg serilize %d [µs]", cast(long) sw1.peek().microseconds);

	if(trace_msg[9] == 1)
		log.trace("send");

	ubyte[] msg_out = outbuff.toBytes();

	if(from_client !is null)
		from_client.send(cast(char*) "".ptr, cast(char*) msg_out, false);

	if(trace_msg[10] == 1)
		io_msg.trace_io(false, cast(byte*) msg_out, msg_out.length);

	sw.stop();
	version(dmd2_052)
		long t = cast(long) sw.peek().usecs;
	else
		long t = cast(long) sw.peek().microseconds;
	log.trace("count: %d, total time: %d [µs]", count, t);

	return;
}

Ticket foundTicket(string ticket_id, TripleStorage ts)
{
	Ticket tt;

	//	trace_msg[2] = 0;

	if((ticket_id in user_of_ticket) !is null)
	{
		if(trace_msg[17] == 1)
			log.trace("тикет нашли в кеше, %s", ticket_id);

		tt = user_of_ticket[ticket_id];
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

		// найдем пользователя по сессионному билету и проверим просрочен билет или нет
		List iterator = ts.getTriples(ticket_id, null, null);

		string when = null;
		int duration = 0;

		if(trace_msg[19] == 1)
			if(iterator is null)
				log.trace("сессионный билет не найден");

		foreach(triple; iterator.lst.data)
		{
			if(trace_msg[20] == 1)
				log.trace("%s %s %s", triple.S, triple.P, triple.O);

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
				log.trace("сессионный билет %s Ok, user=%s", ticket_id, tt.userId);

			// TODO stringToTime очень медленная операция ~ 100 микросекунд
			tt.end_time = stringToTime(cast(char*) when) + duration * 1000;

			user_of_ticket[cast(immutable) ticket_id] = tt;
		}
	}

	return tt;
}
