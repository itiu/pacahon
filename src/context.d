module pacahon.context;

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