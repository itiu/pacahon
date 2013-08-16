module pacahon.context;

import pacahon.graph;

interface Context
{
}

enum event_type
{
	EVENT_INSERT,
	EVENT_UPDATE,
	EVENT_DELETE	
}

interface BusEventListener
{
	void bus_event (event_type et);	
}

interface Authorizer
{
	bool authorize (ref Subject doc);	
}