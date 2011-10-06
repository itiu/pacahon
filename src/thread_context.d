module pacahon.thread_context;

private import trioplax.TripleStorage;
private import mq_client;
private import trioplax.Logger;
private import pacahon.graph;

Logger log;

static this()
{
	log = new Logger("pacahon", "log", "server");
}

class Ticket
{
	string id;
	string userId;

	long end_time;
}

class ThreadContext
{
	Subject[string] event_filter;
	Ticket[string] user_of_ticket;
	string[string] cache__subject_creator;
	TripleStorage ts;

	mq_client client;

	// TODO времянка, переделать!
	void* soc__reply_to_n1 = null;

	string yawl_engine_pont = null;
	void* yawl_engine_context = null;
	
	public void yawl_check_connect ()
	{
		if(yawl_engine_context is null && yawl_engine_pont !is null)
		{
			log.trace ("connect to %s", yawl_engine_pont);
			yawl_engine_context = client.connect_as_req(yawl_engine_pont);
			log.trace ("zmq context = %X", yawl_engine_context);
		}		
	}
}
