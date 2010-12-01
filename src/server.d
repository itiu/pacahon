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
	count++;

	//	msg[message_size - 1] = 0;
	printf("********************************************************************\n");
//	printf("[%i] GET MESSAGE [%d]: \n%s\n", count, message_size, cast(char*) msg);
//	printf("********************************************************************\n");

	StopWatch sw;
	sw.start();

	ServerThread server_thread = cast(ServerThread) Thread.getThis();
	TripleStorage ts = server_thread.ts;
	ts.release_all_lists();

	//	printf("[%i] \n", count);

	Subject*[] triples = parse_n3_string(cast(char*) msg, message_size);
//	printf("command.length=%d\n", triples.length);
	Subject*[] results = new Subject*[triples.length];

	// найдем в массиве triples субьекта с типом msg

	// local_ticket <- здесь может быть тикет для выполнения пакетных операций
	char[] local_ticket;		

	for(int ii = 0; ii < triples.length; ii++)
	{
		Subject* command = triples[ii];

		printf("\n--subject.count_edges=%d>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n%s\n<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n",
				command.count_edges, command.toStringz());
		writeln("get_message:message.subject=", command.subject);

		if(command.count_edges < 3)
		{
			printf("подозрительная комманда, пропустим\n");
			continue;
		}

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
				
				if (ticket_str == "@local")
					ticket_str = local_ticket;

				printf("# найдем пользователя по сессионному билету ticket=%s\n", cast(char*) ticket_str);

				// найдем пользователя по сессионному билету и проверим просрочен билет или нет
				triple_list_element* iterator = ts.getTriples(ticket_str, null, null);

				char[] when = null;
				int duration = 0;

				if(iterator is null)
				{
					printf("# сессионный билет не найден\n");
				}

				while(iterator !is null)
				{
					if(iterator.triple.p == ticket__accessor)
						userId = iterator.triple.o;

					if(iterator.triple.p == ticket__when)
						when = iterator.triple.o;

					if(iterator.triple.p == ticket__duration)
					{
						duration = Integer.toInt(iterator.triple.o);
//						writeln("# str duration = ", iterator.triple.o);
//						writeln("# duration = ", duration);
					}

					if(userId !is null && when !is null && duration > 10)
						break;

					iterator = iterator.next_triple_list_element;
				}

				if(userId is null)
				{
					printf("# найденный сессионный билет не полон, пользователь не найден\n");
				}

				if(userId !is null && (when is null || duration < 10))
				{
					printf("# найденный сессионный билет не полон, считаем что пользователь не был найден\n");
					userId = null;
				}

				// проверим время жизни тикета
				if(userId !is null)
				{
					// TODO stringToTime очень медленная операция ~ 100 микросекунд
					auto now = UTCtoLocalTime(getUTCtime());

					d_time ticket_create_time = stringToTime(when.ptr);

					//					printf("# duration=%d , now=%d\n", duration, (now - ticket_create_time) / 1000);
					if((now - ticket_create_time) / 1000 > duration)
					{
						// тикет просрочен
						printf("# тикет просрочен\n");
						userId = null;
					}
				}
				//

				if(userId !is null)
				{
					writeln("# пользователь найден, userId=", userId);
				}
			}

			if(type !is null && reciever !is null && ("pacahon" in reciever.objects_of_value) !is null)
			{
				Predicate* sender = command.getEdge(msg__sender);
				Subject out_message;

				command_preparer(command, out_message, sender, userId, ts, local_ticket);

				results[ii] = &out_message;
			}

		}

	}

	//	printf("# формируем ответ, серилизуем ответные графы в строку\n");
	OutBuffer outbuff = new OutBuffer();

	for(int ii = 0; ii < results.length; ii++)
	{
		Subject* out_message = results[ii];

		if(out_message !is null)
		{
			//			printf("# серилизуем граф %X в строку\n", out_message);
			out_message.toOutBuffer(outbuff);
		}
	}
	outbuff.write(0);

	//	printf("# отправляем ответ:\n[%s] \n", cast(char*) outbuff.toBytes());

	if(from_client !is null)
		from_client.send(cast(char*) "".ptr, cast(char*) outbuff.toBytes(), false);

	//	from_client.send(cast(char*) "".ptr, cast(char*) "empty", false);

	sw.stop();

	printf("count: %d, total time: %d microseconds\n", count, cast(long) sw.peek().microseconds);

	return;
}

void command_preparer(Subject* message, ref Subject out_message, Predicate* sender, char[] userId, TripleStorage ts, out char[] local_ticket)
{
	printf("command_preparer\n");
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
				out_message.addPredicate(msg__result, fromStringz (gres.toEscStringz()));
			}
		}
		else if("get_ticket" in command.objects_of_value)
		{
			res = get_ticket(message, sender, userId, ts, isOk, reason);
			if (isOk)
				local_ticket = res.edges[0].getFirstObject;
		}

		reason = cast(char[]) "запрос выполнен";
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
}
