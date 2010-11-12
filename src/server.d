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

void main(char[][] args)
{
	printf("Pacahon commit=%s date=%s\n", myversion.hash.ptr, myversion.date.ptr);

	mom_client client = null;

	char* bind_to = cast(char*) "tcp://127.0.0.1:5556".ptr;
	client = new libzmq_client(bind_to);

	client.set_callback(&get_message);

	Thread thread = new Thread(&client.listener);

	thread.start();

	version(D1)
	{
		thread.wait();
	}
	
	test1 ();
}

int count = 0;

void get_message(byte* message, int message_size, mom_client from_client)
{
	count++;
	printf("[%i] data: \n%s\n", count, cast(char*) message);

	char* buff = cast(char*) alloca(message_size);

	Subject*[] triples = parse(cast(char*) message, message_size, buff);

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

private void test1 ()
{
	printf("unittest\n");
	
	string buff = "msg:123457 \n" //
			"cmd:command cmd:put;\n" // 
			"msg:sender \"sender-uuid\";\n" //
			"msg:ticket \"12345-67890-4322-132345-56754\";\n" //
			"cmd:args \":subject1 rdf:type auth:Authenticated;\n" //
			"rdfs:label \"subject1 теперь может аутентифицироваться\";\n" //
			"auth:login \"user1\";\n" //
			"auth:credential \"QL0AFWMIX8NRZTKeof9cXsvbvu8=\".\".";

	get_message(cast(byte*) buff, buff.length, null);

}
