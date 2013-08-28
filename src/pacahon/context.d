module pacahon.context;

import ae.utils.container;
import pacahon.graph;
import pacahon.vel;

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

class Ticket
{
	string id;
	string userId;
	string[] parentUnitIds = new string[0];

	long end_time;	
}

const byte asObject = 0;
const byte asArray = 1;
const byte asString = 2;

struct Mandat
{
	string id;
	string whom;
	string right;
	TTA expression;	
} 

public interface Authorizer
{
	bool authorize (Ticket ticket, Subject doc);	
	void get_mandats_4_whom (Ticket ticket,  ref HashSet!Mandat mandats);
}