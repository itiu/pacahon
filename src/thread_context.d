module pacahon.thread_context;

private import trioplax.TripleStorage;
private import mq_client;

class Ticket
{
	string id;
	string userId;

	long end_time;
}

class ThreadContext
{
	Ticket[string] user_of_ticket;
	string[string] cache__subject_creator;
	TripleStorage ts;
	
	mq_client client;

	// TODO времянка, переделать!
	void* soc__reply_to_n1 = null;
}
