module pacahon.server;

private import std.c.stdlib;
private import myversion;

private import std.thread;

private import libzmq_headers;
private import libzmq_client;

void main(char[][] args)
{
    printf ("Pacahon commit=%s date=%s\n", myversion.hash.ptr, myversion.date.ptr);

	mom_client client = null;

	char* bind_to = "tcp://127.0.0.1:5556".ptr;
	client = new libzmq_client(bind_to);

	client.set_callback(&get_message);

	Thread thread = new Thread(&client.listener);

	thread.start();
	thread.wait();
}

int count = 0;

void get_message(byte* message, ulong message_size, mom_client from_client)
{
	count++;
	printf("[%i] data: %s\n", count, cast(char*) message);

	from_client.send("", "test message", false);
	return;
}
