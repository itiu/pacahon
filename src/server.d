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
private import std.datetime;
private import std.outbuffer;
private import std.date;

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

Logger log;
Logger io_msg;

static this()
{
	log = new Logger("pacahon.log", "server");
	io_msg = new Logger("pacahon.io", "server");
}

byte trace_msg[10][30];

void main(char[][] args)
{
	try
	{
		JSONValue props = get_props("pacahon-properties.json");

		log.trace_log_and_console("agent Pacahon, source: commit=%s date=%s", myversion.hash, myversion.date);

		mom_client client = null;

		char* bind_to = cast(char*) props.object["zmq_point"].str;

		client = new libzmq_client(bind_to);
		client.set_callback(&get_message);

		string mongodb_server = props.object["mongodb_server"].str;
		string mongodb_collection = props.object["mongodb_collection"].str;
		int mongodb_port = cast(int) props.object["mongodb_port"].integer;

		printf("connect to mongodb, \n");
		printf("	port: %d\n", mongodb_port);
		printf("	server: %s\n", cast(char*) mongodb_server);
		printf("	collection: %s\n", cast(char*) mongodb_collection);

		TripleStorage ts = new TripleStorageMongoDB(mongodb_server, mongodb_port, mongodb_collection);
		printf("ok, connected : %X\n", ts);

		ServerThread thread = new ServerThread(&client.listener, ts);
		thread.start();

		printf("listener of zmq started\n");

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

class ServerThread: Thread
{
	TripleStorage ts;

	this(void delegate() _dd, TripleStorage _ts)
	{
		super(_dd);
		ts = _ts;
	}
}

int count = 0;

class Ticket
{
	char[] id;
	char[] userId;
	d_time end_time;
}

Ticket[char[]] user_of_ticket;

enum format: byte
{
	TURTLE = 0,
        JSON_LD = 1,
        UNKNOWN = -1        
}
                        
                        

void get_message(byte* msg, int message_size, mom_client from_client)
{
	byte msg_format = format.UNKNOWN;

	trace_msg[0][0] = 1; // Input message
	trace_msg[0][16] = 1; // Output message
	trace_msg[0][3] = 1;
	//	trace_msg[0] = 1;

	count++;

	if(trace_msg[0][0] == 1)
		io_msg.trace_io(true, msg, message_size);

	StopWatch sw;
	sw.start();

	ServerThread server_thread = cast(ServerThread) Thread.getThis();
	TripleStorage ts = server_thread.ts;
	ts.release_all_lists();

	if(trace_msg[0][1] == 1)
		log.trace("get message, [%d]", count);

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

	if(trace_msg[0][2] == 1)
		log.trace("command.length=%d", triples.length);

	Subject[] results = new Subject[triples.length];

	// найдем в массиве triples субьекта с типом msg

	// local_ticket <- здесь может быть тикет для выполнения пакетных операций
	char[] local_ticket;

	for(int ii = 0; ii < triples.length; ii++)
	{
		Subject command = triples[ii];

		if(trace_msg[0][3] == 1)
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

		Predicate* type = command.getEdge(cast(char[]) "a");
		if(type is null)
			type = command.getEdge(rdf__type);

		if((msg__Message in type.objects_of_value) !is null)
		{
			Predicate* reciever = command.getEdge(msg__reciever);
			Predicate* sender = command.getEdge(msg__sender);

			if(trace_msg[0][4] == 1)
				log.trace("FROM:%s", sender.getFirstObject());

			Predicate* ticket = command.getEdge(msg__ticket);

			char[] userId;

			if(ticket !is null && ticket.objects !is null)
			{
				char[] ticket_str = ticket.objects[0].object;

				if(ticket_str == "@local")
					ticket_str = local_ticket;

				Ticket tt = getTicket(ticket_str, ts);

				// проверим время жизни тикета
				if(tt !is null)
				{
					auto now = UTCtoLocalTime(getUTCtime());

					if(now > tt.end_time)
					{
						// тикет просрочен
						if(trace_msg[0][10] == 1)
							log.trace("# тикет просрочен");
					}
					else
					{
						userId = tt.userId;
					}
				}

				if(trace_msg[0][12] == 1)
					if(userId !is null)
						log.trace("# пользователь найден, userId=%s", userId);

			}

			if(type !is null && reciever !is null && ("pacahon" in reciever.objects_of_value) !is null)
			{
				//				Predicate* sender = command.getEdge(msg__sender);
				//				Subject* out_message = new Subject;
				results[ii] = new Subject;

				if(trace_msg[0][13] == 1)
				{
					sw.stop();
					printf("T  count: %d, %d [µs] next: command_preparer\n", count, cast(long) sw.peek().microseconds);
					sw.start();
				}

				command_preparer(command, results[ii], sender, userId, ts, local_ticket);

				if(trace_msg[0][14] == 1)
				{
					sw.stop();
					printf("T count: %d, %d [µs] end: command_preparer\n", count, cast(long) sw.peek().microseconds);
					sw.start();
				}
				//				results[ii] = out_message;
			}

		}

	}

	if(trace_msg[0][15] == 1)
		printf("# формируем ответ, серилизуем ответные графы в строку\n");

	OutBuffer outbuff = new OutBuffer();

	for(int ii = 0; ii < results.length; ii++)
	{
		Subject out_message = results[ii];

		if(out_message !is null)
		{
			//						printf("# серилизуем граф %X в строку 1\n", out_message);
			toTurtle(out_message, outbuff);
			//			printf("# серилизуем граф %X в строку 2\n", out_message);
		}
	}
	outbuff.write(0);

	ubyte[] msg_out = outbuff.toBytes();

	if(from_client !is null)
		from_client.send(cast(char*) "".ptr, cast(char*) msg_out, false);

	if(trace_msg[0][16] == 1)
		io_msg.trace_io(false, cast(byte*) msg_out, msg_out.length);

	sw.stop();
	log.trace("count: %d, total time: %d [µs]\n", count, cast(long) sw.peek().microseconds);

	return;
}

void command_preparer(Subject message, Subject out_message, Predicate* sender, char[] userId, TripleStorage ts, out char[] local_ticket)
{
	if(trace_msg[1][0] == 1)
		printf("command_preparer\n");

	Predicate[] ppp = new Predicate[5];

	Subject res;

	Ticks m_TimeStart = systime();
	char[] time = new char[21];
	time[0] = 'm';
	time[1] = 's';
	time[2] = 'g';
	time[3] = ':';
	time[4] = 'M';
	time[5] = '_';
	time[6] = '_';
	time[7] = '_';

	Integer.format(time, m_TimeStart.value, cast(char[]) "X2");

	out_message.subject = time;
	//	out_message.subject = cast(char[])"msg:time";

	out_message.addPredicateAsURI(rdf__type, msg__Message);
	out_message.addPredicateAsURI(msg__in_reply_to, message.subject);
	out_message.addPredicate(msg__sender, cast(char[]) "pacahon");
	out_message.addPredicate(msg__reciever, sender.getFirstObject);

	Predicate* command = message.getEdge(msg__command);

	char[] reason;
	bool isOk;

	if(command !is null)
	{

		if("put" in command.objects_of_value)
		{
			res = put(message, sender, userId, ts, isOk, reason);
		}
		else if("get" in command.objects_of_value)
		{
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
			res = get_ticket(message, sender, userId, ts, isOk, reason);
			if(isOk)
				local_ticket = res.edges[0].getFirstObject;
		}

		//		reason = cast(char[]) "запрос выполнен";
	}
	else
	{
		reason = cast(char[]) "в сообщении не указанна команда";
	}
	if(isOk == false)
	{
		out_message.addPredicate(msg__status, cast(char[]) "fail");
	}
	else
	{
		out_message.addPredicate(msg__status, cast(char[]) "ok");
	}

	if(res !is null)
		out_message.addPredicate(msg__result, res);

	out_message.addPredicate(msg__reason, reason);

	if(trace_msg[1][1] == 1)
		printf("command_preparer end\n");
}

Ticket getTicket(char[] ticket_id, TripleStorage ts)
{
	Ticket tt;

	//	trace_msg[2] = 0;

	if((ticket_id in user_of_ticket) !is null)
	{
		if(trace_msg[2][0] == 1)
			log.trace("# тикет нашли в кеше, %s", ticket_id);

		tt = user_of_ticket[ticket_id];
	}

	if(tt is null)
	{
		tt = new Ticket;
		tt.id = ticket_id;

		if(trace_msg[2][1] == 1)
		{
			log.trace("# найдем пользователя по сессионному билету ticket=%s", ticket_id);
			//			printf("T count: %d, %d [µs] start get data\n", count, cast(long) sw.peek().microseconds);
		}

		// найдем пользователя по сессионному билету и проверим просрочен билет или нет
		triple_list_element iterator = ts.getTriples(ticket_id, null, null);

		char[] when = null;
		int duration = 0;

		if(trace_msg[2][2] == 1)
			if(iterator is null)
				log.trace("# сессионный билет не найден");

		while(iterator !is null)
		{
			if(trace_msg[2][6] == 1)
				log.trace("# %s %s %s", iterator.triple.s, iterator.triple.p, iterator.triple.o);

			if(iterator.triple.p == ticket__accessor)
			{
				tt.userId = iterator.triple.o;
				if(trace_msg[2][6] == 1)
					log.trace("# tt.userId=%s", tt.userId);
			}
			if(iterator.triple.p == ticket__when)
				when = iterator.triple.o;

			if(iterator.triple.p == ticket__duration)
			{
				duration = Integer.toInt(iterator.triple.o);
			}
			if(tt.userId !is null && when !is null && duration > 10)
				break;

			iterator = iterator.next_triple_list_element;
		}

		if(tt.userId is null)
		{
			if(trace_msg[2][3] == 1)
				log.trace("# найденный сессионный билет не полон, пользователь не найден");
		}

		if(tt.userId !is null && (when is null || duration < 10))
		{
			if(trace_msg[2][4] == 1)
				log.trace("# найденный сессионный билет не полон, считаем что пользователь не был найден");
			tt.userId = null;
		}

		if(when !is null)
		{
			if(trace_msg[2][5] == 1)
				log.trace("# сессионный билет %s Ok, user=%s", ticket_id, tt.userId);

			//			printf("#1 when=%s\n", when.ptr);
			// TODO stringToTime очень медленная операция ~ 100 микросекунд
			tt.end_time = stringToTime(when.ptr) + duration * 1000;

			user_of_ticket[cast(immutable) ticket_id] = tt;
		}
	}

	return tt;
}
