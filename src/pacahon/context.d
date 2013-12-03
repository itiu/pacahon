module pacahon.context;

private import std.concurrency;
private import std.datetime;

private import ae.utils.container;
private import pacahon.graph;
private import search.vel;
private import onto.doc_template;
private import ae.utils.container;
private import util.oi;

interface Context
{
	Tid get_tid_subject_manager ();
	@property Tid tid_statistic_data_accumulator ();
	
	@property Tid tid_ticket_manager ();	
	@property StopWatch sw ();
	@property Ticket*[string] user_of_ticket ();
	@property GraphCluster ba2pacahon_records ();
	@property GraphCluster event_filters ();
	@property search.vql.VQL vql ();
	
	DocTemplate get_template (string uid, string v_dc_identifier, string v_docs_version);
	void set_template (DocTemplate tmpl, string tmpl_subj, string v_id);
		
	Ticket *foundTicket(string ticket_id);
	int get_subject_creator_size ();
	string get_subject_creator (string pp);
	void set_subject_creator (string key, string value); 
	Set!OI get_gateways (string name);
	
	@property int count_command ();
	@property int count_message ();
	@property void count_command (int n);
	@property void count_message (int n);
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

struct Ticket
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
	bool authorize (Ticket *ticket, Subject doc);	
	void get_mandats_4_whom (Ticket *ticket,  ref HashSet!Mandat mandats);
}