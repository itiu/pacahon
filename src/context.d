module pacahon.context;

import ae.utils.container;
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

class Element
{
	Element[string] pairs;
	Element[] array;
	string str;
	string id;

	byte type;

	override string toString()
	{
		if(type == asObject)
		{
			string qq;

			foreach(key; pairs.keys)
			{
				qq ~= key ~ " : " ~ pairs[key].toString() ~ "\n";
			}

			return qq;
		}
		if(type == asArray)
		{
			string qq;

			foreach(el; array)
			{
				qq ~= el.toString() ~ "\n";
			}
			return qq;
		} else if(type == asString)
			return str;
		else
			return "?";
	}

}

interface Authorizer
{
	bool authorize (Ticket ticket, Subject doc);	
	void get_mandats_4_whom (Ticket ticket,  ref HashSet!Element mandats, ref Set!string*[string] fields, ref HashSet!string templateIds);
}