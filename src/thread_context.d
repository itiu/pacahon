module pacahon.thread_context;

private import trioplax.TripleStorage;
private import mq_client;
private import trioplax.Logger;
private import pacahon.graph;
private import pacahon.zmq_connection;
import mmf.graph;

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
	GraphIO mmf;
	bool useMMF = false;
	
	GraphCluster event_filters;
	Ticket[string] user_of_ticket;
	string[string] cache__subject_creator;
	TripleStorage ts;

	mq_client client;

	// TODO времянка, переделать!
	void* soc__reply_to_n1 = null;

	ZmqConnection[string] gateways;

	this()
	{
		event_filters = new GraphCluster();
	}

	ZmqConnection getGateway(string _alias)
	{
		if((_alias in gateways) !is null)
			return gateways[_alias];
		return null;
	}

}
