module pacahon.thread_context;

private
{ 
	import std.json;
	import std.stdio;
	import std.format;
	import std.datetime;

	import mq.mq_client;

	import ae.utils.container;
	import util.json_ld.parser1;
	import util.Logger;
	import util.oi;

	import trioplax.mongodb.TripleStorage;
	import trioplax.mongodb.MongodbTripleStorage;

	import onto.doc_template;

	import pacahon.context;
	import pacahon.graph;
	import pacahon.command.event_filter;
	import pacahon.know_predicates;
	import pacahon.vql;
	import az.condition;
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

class ThreadContext: Context, Authorizer
{
	bool use_caching_of_documents = false;
	bool IGNORE_EMPTY_TRIPLE = false;

	Statistic stat;

	GraphCluster ba2pacahon_records;
	GraphCluster event_filters;
	Ticket[string] user_of_ticket;
	string[string] cache__subject_creator;
	TripleStorage ts;
	MandatManager mandat_manager;

	//	 TODO предусмотреть сброс кэша шаблонов
	DocTemplate[string][string] templates;

	mq_client client;

	OI[string] gateways;

	VQL vql;

	this(JSONValue props, string context_name)
	{
		event_filters = new GraphCluster();
		ba2pacahon_records = new GraphCluster();

		// использование кеша документов
		if(("use_caching_of_documents" in props.object) !is null)
		{
			if (props.object["use_caching_of_documents"].str == "true")
				use_caching_of_documents = true;
		}	

		// адрес базы данных mongodb
		string mongodb_server = "localhost";
		if(("mongodb_server" in props.object) !is null)
			mongodb_server = props.object["mongodb_server"].str;
		// порт базы данных mongodb
		int mongodb_port = 27017;
		if(("mongodb_port" in props.object) !is null)
			mongodb_port = cast(int) props.object["mongodb_port"].integer;

		// имя коллекции
		string db_name = "pacahon";
		if(("mongodb_database_name" in props.object) !is null)
			db_name = props.object["mongodb_database_name"].str;
		else
			db_name = "pacahon";

		ts = connect_to_mongodb_triple_storage(mongodb_port, mongodb_server, db_name, context_name, use_caching_of_documents);
		

		JSONValue[] _gateways;
		if(("gateways" in props.object) !is null)
		{
			_gateways = props.object["gateways"].array;
			foreach(gateway; _gateways)
			{
				if(("alias" in gateway.object) !is null)
				{
					string[string] params;
					foreach(key; gateway.object.keys)
						params[key] = gateway[key].str;

					OI oi = new OI();
					if (oi.connect(params) == 0)
						gateways[gateway.object["alias"].str] = oi;
				}
			}
		}
		
		
		
		
		OI from_search = gateways.get("from-search", null);
		vql = new VQL(ts, from_search);

		writeln(context_name ~ ": connect to mongodb is ok");

		writeln(context_name ~ ": load events");
		load_events(this);
		writeln(context_name ~ ": load events... ok");

		mandat_manager = new MandatManager(ts);
		mandat_manager.load();

		stat = new Statistic();
	}

	bool authorize(Ticket ticket, Subject doc)
	{
		return false;//mandat_manager.ca;
	}

	void get_mandats_4_whom(Ticket ticket, ref HashSet!Mandat mandats)
	{
//		writeln ("&0 ticket.userId=", ticket.userId);
//		writeln ("&1 ticket.parentUnitIds=", ticket.parentUnitIds);
//		StopWatch sw_c;
//		sw_c.start();
		
		if (ticket is null)
			return;
					
		mrf (ticket.userId, mandats, false);
//		writeln ("&2 mandats:", mandats);
		
		foreach (unit ; ticket.parentUnitIds)
			mrf (unit, mandats, true);
//		writeln ("&3 mandats:", mandats);
		
//		sw_c.stop();		
//		writeln ("время вычисления требуемых полей документа в шаблонах, time=", sw_c.peek().usecs);
//		writeln ("&1 fields=", fields);
//		writeln ("&2 templateIds=", templateIds.data.keys);
		return;
	}
	
	private void mrf (string unitId, ref HashSet!Mandat mandats, bool recursive = false)
	{		
//		writeln ("unitId=[", unitId, "]");
//		writeln (" mandat_manager.ost.node_4_parents=",  mandat_manager.ost.node_4_parents);
		string[] parent_ids;
		
		if (recursive == true)
		{
			parent_ids = mandat_manager.ost.node_4_parents.get(unitId, null);
//			writeln ("parentsIds=[", parent_ids, "]");
			
			foreach(unit_id; parent_ids)
			{				
				mrf (unit_id, mandats, recursive);
			}
		}
		
		auto cai = mandat_manager.whom_4_cai.get (unitId, null);
		if(cai !is null)
		{
//			writeln ("cai.conditions=", cai.conditions.items, "\n");
			foreach (mandat; cai.conditions.items)
				mandats.add (mandat);
			
//			foreach (field; cai.fields.data.keys)
//				fields[field] = new Set!string;
			
//			foreach (templateId; cai.templateIds.data.keys)
//				templateIds.add (templateId);
			
		}		
	}
}

public static TripleStorage connect_to_mongodb_triple_storage(int mongodb_port, string mongodb_server, string mongodb_collection,
		string context_name, bool use_caching_of_documents)
{
	writeln("connect to mongodb, thread:", context_name);
	writeln("	port:", mongodb_port);
	writeln("	server:", mongodb_server);
	writeln("	collection:", mongodb_collection);

	MongodbTripleStorage ts;
	try
	{
		ts = new MongodbTripleStorage(mongodb_server, mongodb_port, mongodb_collection, context_name, use_caching_of_documents);

		ts.define_predicate_as_multiple(rdf__type);
		ts.define_predicate_as_multiple(rdfs__subClassOf);
		ts.define_predicate_as_multiple("gost19:take");
		ts.define_predicate_as_multiple(event__msg_template);
		ts.define_predicate_as_multiple(owl__someValuesFrom);
		ts.define_predicate_as_multiple(owl__allValuesFrom);

		ts.define_predicate_as_multilang(swrc__name);
		ts.define_predicate_as_multilang(swrc__firstName);
		ts.define_predicate_as_multilang(swrc__lastName);
		//			ts.define_predicate_as_multilang("gost19:middleName");
		ts.define_predicate_as_multilang(docs__position);

		ts.set_fulltext_indexed_predicates(swrc__name);
		ts.set_fulltext_indexed_predicates(swrc__firstName);
		ts.set_fulltext_indexed_predicates(swrc__lastName);
		ts.set_fulltext_indexed_predicates(gost19__middleName);
		ts.set_fulltext_indexed_predicates(docs__position);
		ts.set_fulltext_indexed_predicates(docs__label);
		ts.set_fulltext_indexed_predicates(rdfs__label);
		ts.set_fulltext_indexed_predicates(swrc__email);
		ts.set_fulltext_indexed_predicates(swrc__phone);
		ts.set_fulltext_indexed_predicates(gost19__internal_phone);

		printf("ok, connected : %X\n", ts);
	} catch(Exception ex)
	{
		throw new Exception("Connect to mongodb: " ~ ex.msg, ex);
	}

	return ts;
}
