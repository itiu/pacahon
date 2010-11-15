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

private import pacahon.n3.parser;
private import pacahon.graph;

private import std.file;
private import std.json;

private import trioplax.triple;
private import trioplax.TripleStorage;
private import trioplax.mongodb.TripleStorageMongoDB;

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

void get_message(byte* message, int message_size, mom_client from_client)
{
	count++;
	printf("[%i] data: \n%s\n", count, cast(char*) message);

	char* buff = cast(char*) alloca(message_size);

	Subject*[] triples = parse_n3_string(cast(char*) message, message_size, buff);

	// найдем в массиве triples субьекта с типом msg
	for(int ii = 0; ii < triples.length; ii++)
	{
		Subject* ss = triples[ii];

		set_outGoingEdgesOfPredicate(ss);

		Predicate* pp = *("rdf:type" in ss.edges_of_predicate);
		Predicate* pp1 = *("mgs:reciever" in ss.edges_of_predicate);

		if(pp !is null && pp1 !is null && (":msg" in pp.objects_of_value) !is null && ("mgs:reciever" in pp1.objects_of_value) !is null)
		{
			command_preparer(ss);
		}

		/*		
		 char* type = null;
		 char* reciever = null;

		 for(short jj = 0; jj < ss.outGoingEdges.length; jj++)
		 {
		 if(strcmp(ss.outGoingEdges[jj].predicate, cast(char*) "rdf:type".ptr) == 0)
		 type = cast(char*) ss.outGoingEdges[jj].objects[0].object;

		 if(strcmp(ss.outGoingEdges[jj].predicate, cast(char*) "mgs:reciever".ptr) == 0)
		 reciever = cast(char*) ss.outGoingEdges[jj].objects[0].object;

		 if(type !is null && reciever !is null)
		 break;
		 }

		 // если это новое сообщение, проверим, нам ли оно адресованно 
		 if(strcmp(type, "msg:") == 0 && strcmp(reciever, "pacahon"))
		 {

		 // , передаем его обработчику команд
		 command_preparer (ss);
		 }
		 */
	}

	if(from_client !is null)
		from_client.send(cast(char*) "".ptr, cast(char*) "test message".ptr, false);

	return;
}

void command_preparer(Subject* ss)
{

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