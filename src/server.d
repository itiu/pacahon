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

//private import std.stdio;

private import std.c.string;

private import libzmq_headers;
private import libzmq_client;

private import std.json;
private import std.datetime;
private import std.outbuffer;

private import Integer = tango.text.convert.Integer;

private import pacahon.n3.parser;
private import pacahon.graph;

private import trioplax.triple;
private import trioplax.TripleStorage;
private import trioplax.mongodb.TripleStorageMongoDB;

private import pacahon.command.multiplexor;
private import pacahon.know_predicates;

private import pacahon.utils;

void main(char[][] args)
{
	try
	{
		JSONValue props = get_props("pacahon-properties.json");

		printf("Pacahon commit=%s date=%s\n", myversion.hash.ptr, myversion.date.ptr);

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

void get_message(byte* msg, int message_size, mom_client from_client)
{
	msg[message_size] = 0;

	ServerThread server_thread = cast(ServerThread) Thread.getThis();
	TripleStorage ts = server_thread.ts;

	count++;

	printf("[%i] get message[%d]: \n%s\n", count, message_size, cast(char*) msg);
	//	printf("[%i] \n", count);

	StopWatch sw;
	sw.start();

	Subject*[] triples = parse_n3_string(cast(char*) msg, message_size);
	Subject*[] results = new Subject*[triples.length];

	// найдем в массиве triples субьекта с типом msg
	for(int ii = 0; ii < triples.length; ii++)
	{
		Subject* command = triples[ii];
		printf("\n-----\n%s\n-----\n", command.toString());

		printf("message.subject=%s\n", command.subject.ptr);

		set_hashed_data(command);

		Predicate* type = command.getEdge(cast(char[]) "a");
		if(type is null)
			type = command.getEdge(rdf__type);

		if((msg__Message in type.objects_of_value) !is null)
		{
			Predicate* reciever = command.getEdge(msg__reciever);

			Predicate* ticket = command.getEdge(msg__ticket);

			char[] userId = null;

			if(ticket !is null && ticket.objects !is null)
			{
				char[] ticket_str = ticket.objects[0].object;

				printf("# найдем пользователя по сессионному билету ticket=%s\n", cast(char*) ticket_str);

				// найдем пользователя по сессионному билету
				triple_list_element* iterator = ts.getTriples(null, msg__ticket, ticket_str);

				if(iterator !is null)
				{
					userId = pacahon.utils.fromStringz(iterator.triple.s);
				}
				else
				{
					printf("# пользователь не найден\n");
				}
			}

			if(type !is null && reciever !is null && ("pacahon" in reciever.objects_of_value) !is null)
			{
				Predicate* sender = command.getEdge(msg__sender);
				Subject out_message;
				command_preparer(command, out_message, sender, userId, ts);

				results[ii] = &out_message;
			}
		}
	}

	printf("# формируем ответ, серилизуем ответные графы в строку\n");
	OutBuffer outbuff = new OutBuffer();

	for(int ii = 0; ii < results.length; ii++)
	{
		Subject* out_message = results[ii];

		if(out_message !is null)
		{
			printf("# серилизуем граф %X в строку\n", out_message);
			out_message.toOutBuffer(outbuff);
		}
	}
	outbuff.write(0);

	printf("# отправляем ответ:\n[%s] \n", cast(char*) outbuff.toBytes());

	if(from_client !is null)
		from_client.send(cast(char*) "".ptr, cast(char*) outbuff.toBytes(), false);

	sw.stop();

	printf("count: %d, total time: %d microseconds\n", count, cast(long) sw.peek().microseconds);

	return;
}

void command_preparer(Subject* message, ref Subject out_message, Predicate* sender, char[] userId, TripleStorage ts)
{
	//	printf("command_preparer\n");
	Predicate[] ppp = new Predicate[5];

	Subject* res;

	Ticks m_TimeStart = systime();
	char[] time = new char[18];
	time[0] = 'm';
	time[1] = 's';
	time[2] = 'g';
	time[3] = ':';
	time[4] = 'M';
	Integer.format(time, m_TimeStart.value, cast(char[]) "X2");

	out_message.subject = time;

	out_message.addPredicateAsURI(rdf__type, msg__Message);
	out_message.addPredicate(msg__in_reply_to, message.subject);
	out_message.addPredicate(msg__sender, cast(char[]) "pacahon");
	out_message.addPredicate(msg__reciever, sender.getFirstObject);

	Predicate* command = message.getEdge(msg__command);
	char[] reason;

	if("put" in command.objects_of_value)
	{
		res = put(message, sender, userId, ts, reason);
	}
	else if("get" in command.objects_of_value)
	{
		res = get(message, sender, userId, ts, reason);
	}
	else if("msg:get_ticket" in command.objects_of_value)
	{
		res = get_ticket(message, sender, userId, ts, reason);
	}

	out_message.addPredicate(msg__reason, reason);
	out_message.addPredicate(msg__result, res);

	if(res is null)
	{
		out_message.addPredicate(msg__status, cast(char[]) "fail");
	}
	else
	{
		out_message.addPredicate(msg__status, cast(char[]) "ok");
	}

}
