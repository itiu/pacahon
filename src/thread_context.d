module pacahon.thread_context;

private import trioplax.mongodb.TripleStorage;
private import mq_client;

private import util.Logger;

private import pacahon.graph;
private import pacahon.zmq_connection;
private import mmf.mmfgraph;

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

synchronized class Statistic
{
	int count_message = 0;
	int count_command = 0;
	int idle_time = 0;
	int worked_time = 0;
	int size__user_of_ticket;
	int size__cache__subject_creator;
}

class ThreadContext
{
	bool IGNORE_EMPTY_TRIPLE = false;
	
	Statistic stat;
	
	GraphIO *mmf;
	bool useMMF = false;
	
	GraphCluster ba2pacahon_records;	
	GraphCluster event_filters;
	Ticket[string] user_of_ticket;
	string[string] cache__subject_creator;
	TripleStorage ts;

	mq_client client;

	ZmqConnection[string] gateways;

	this()
	{
		event_filters = new GraphCluster();
		ba2pacahon_records = new GraphCluster();
	}

	ZmqConnection getGateway(string _alias)
	{
		if((_alias in gateways) !is null)
			return gateways[_alias];
		return null;
	}

}
