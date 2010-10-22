module pacahon.server;

private import myversion;

version (D1)
{
private import std.c.stdlib;
private import std.thread;
}
version (D2)
{
private import core.thread;
private import core.stdc.stdio;
private import core.stdc.stdlib;
}

private import libzmq_headers;
private import libzmq_client;

private import pacahon.n3.parser;
private import pacahon.graph;

void main(char[][] args)
{
	printf("Pacahon commit=%s date=%s\n", myversion.hash.ptr, myversion.date.ptr);

	mom_client client = null;

	char* bind_to = cast(char*)"tcp://127.0.0.1:5556".ptr;
	client = new libzmq_client(bind_to);

	client.set_callback(&get_message);

	Thread thread = new Thread(&client.listener);

	thread.start();
	
	version (D1)
	{
	thread.wait();
	}
}

int count = 0;

void get_message(byte* message, int message_size, mom_client from_client)
{
	count++;
	printf("[%i] data: %s\n", count, cast(char*) message);

	char* buff = cast(char*) alloca(message_size);

	Subject*[] triples = parse(cast(char*) message, message_size, buff);

	from_client.send(cast(char*)"".ptr, cast(char*)"test message".ptr, false);
	return;
}
