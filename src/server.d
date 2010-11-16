module pacahon.server;

private import myversion;

version(D1)
{
	private import std.c.stdlib;
	private import std.thread;
	private import std.stdio;
}

version(D2)
{
	private import core.thread;
	private import core.stdc.stdio;
	private import core.stdc.stdlib;
}

private import std.c.string;

private import libzmq_headers;
private import libzmq_client;

private import std.file;
private import std.json;
private import std.datetime;

private import pacahon.n3.parser;
private import pacahon.graph;

private import trioplax.triple;
private import trioplax.TripleStorage;
private import trioplax.mongodb.TripleStorageMongoDB;

private import pacahon.command.multiplexor;

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

		Thread thread = new Thread(&client.listener);

		thread.start();

		version(D1)
		{
			thread.wait();
		}

		string mongodb_server = props.object["mongodb_server"].str;
		string mongodb_collection = props.object["mongodb_collection"].str;
		int mongodb_port = cast(int) props.object["mongodb_port"].integer;

		printf("connect to mongodb, \n");
		printf("	port: %d\n", mongodb_port);
		printf("	server: %s\n", cast(char*) mongodb_server);
		printf("	collection: %s\n", cast(char*) mongodb_collection);

		TripleStorage ts_mongo = new TripleStorageMongoDB(mongodb_server, mongodb_port, mongodb_collection);
	} catch(Exception ex)
	{
		printf("Exception: %s", ex.msg);
	}

}

int count = 0;

struct subject_array
{
	Subject*[] array;	
}

void get_message(byte* msg, int message_size, mom_client from_client)
{
	count++;

	printf("[%i] data: \n%s\n", count, cast(char*) msg);

	StopWatch sw;
	sw.start();

	char* buff = cast(char*) alloca(message_size);

	Subject*[] triples = parse_n3_string(cast(char*) msg, message_size, buff);

	printf ("triples.length=%d\n", triples.length);
	subject_array[] results = new subject_array[triples.length];
	
	// найдем в массиве triples субьекта с типом msg
	for(int ii = 0; ii < triples.length; ii++)
	{
		Subject* message = triples[ii];

		set_hashed_data(message);

		Predicate* type = message.getEdge("a");
		if(type is null)
			type = message.getEdge("rdf:type");

		Predicate* reciever = message.getEdge("msg:reciever");

		if(type !is null && reciever !is null && ("msg:Message" in type.objects_of_value) !is null && ("pacahon" in reciever.objects_of_value) !is null)
		{
			Predicate* sender = message.getEdge("msg:sender");
			Subject*[] ss = command_preparer(message, sender);
//			Subject*[] ss = new Subject*[3];
			results[ii].array = ss;
		}

	}

	
	for(int ii = 0; ii < results.length; ii++)
	{
//		Subject*[] qq = results[ii].array;
			
//		for(int jj = 0; jj < qq.length; jj++)
		{
//			printf("*******\n%s\n", qq[jj].toString());			
		}				
	}

	
	
	if(from_client !is null)
		from_client.send(cast(char*) "".ptr, cast(char*) "test message".ptr, false);

	sw.stop();

	printf("count: %d, total time: %d microseconds\n", count, cast(long) sw.peek().microseconds);

	return;
}

Subject*[] command_preparer(Subject* message, Predicate* sender)
{
	Subject*[] res;

	printf("command_preparer\n");

	Predicate* command = message.getEdge("msg:command");

	if("put" in command.objects_of_value)
	{
		res = put(message, sender);
	}
	else if("get" in command.objects_of_value)
	{
		res = get(message, sender);
	}
	else if("get-ticket" in command.objects_of_value)
	{
		res = get_ticket(message, sender);
	}

	return res;
}

JSONValue get_props(string file_name)
{
	JSONValue res;

	if(exists(file_name))
	{
		string buff = cast(string) read(file_name);

		res = parseJSON(buff);
	}
	else
	{
		res.type = JSON_TYPE.OBJECT;

		JSONValue element1;
		element1.str = "tcp://127.0.0.1:5555";
		res.object["zmq_point"] = element1;

		JSONValue element2;
		element2.str = "127.0.0.1";
		res.object["mongodb_server"] = element2;

		JSONValue element3;
		element3.type = JSON_TYPE.INTEGER;
		element3.integer = 27017;
		res.object["mongodb_port"] = element3;

		JSONValue element4;
		element4.str = "pacahon";
		res.object["mongodb_collection"] = element4;

		string buff = toJSON(&res);

		write(file_name, buff);
	}

	return res;
}