module pacahon.thread_context;

private import trioplax.TripleStorage;

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
}
