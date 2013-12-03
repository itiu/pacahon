module pacahon.thread_context;

private
{ 
	import std.json;
	import std.stdio;
	import std.format;
	import std.datetime;
	import std.concurrency;
	import std.conv;
	
	import mq.mq_client;

	import ae.utils.container;
	import util.json_ld.parser1;
	import util.Logger;
	import util.oi:OI;
	import util.utils;	
	
	import storage.ticket;
	
	import bind.xapian_d_header;	
//	import bind.lmdb_header;	

	import onto.doc_template;

	import pacahon.context;
	import pacahon.graph;
//	import pacahon.command.event_filter;
	import pacahon.know_predicates;
	import pacahon.define;

//	import search.vql;
	import az.condition:MandatManager;
}

Logger log;

static this()
{
	log = new Logger("pacahon", "log", "server");
}


class ThreadContext: Context, Authorizer
{	
	private Tid _tid_statistic_data_accumulator;
	@property Tid tid_statistic_data_accumulator () { return _tid_statistic_data_accumulator; }	
	
	private Tid _tid_ticket_manager;
	@property Tid tid_ticket_manager () { return _tid_ticket_manager; }
			
	private StopWatch _sw;
	@property StopWatch sw () { return _sw; }
		
	private Ticket*[string] _user_of_ticket;
	@property Ticket*[string] user_of_ticket () { return _user_of_ticket; }
	
	private GraphCluster _ba2pacahon_records;
	@property GraphCluster ba2pacahon_records () { return _ba2pacahon_records; }
	
	private GraphCluster _event_filters;
	@property GraphCluster event_filters () { return _event_filters; }
	
	private search.vql.VQL _vql;
	@property search.vql.VQL vql () { return _vql; }
		
	Tid tid_subject_manager;
	Tid tid_acl_manager;			
	bool use_caching_of_documents = false;
	bool IGNORE_EMPTY_TRIPLE = false;

	int _count_command;
	int _count_message;

	@property int count_command () { return _count_command;}
	@property int count_message () { return _count_message;}
	@property void count_command (int n) {_count_command = n;}
	@property void count_message (int n) {_count_message = n;}
	
	/////////////////////////////////////////////////////////
	private string[string] cache__subject_creator;	
	int get_subject_creator_size ()
	{
		return cast(int)cache__subject_creator.length;
	}
	
	string get_subject_creator (string pp)
	{
		return cache__subject_creator.get (pp, null);
	}
	
	void set_subject_creator (string key, string value)
	{
		cache__subject_creator[key] = value;
	} 
	/////////////////////////////////////////////////////////

	MandatManager mandat_manager;

	//	 TODO предусмотреть сброс кэша шаблонов
	private DocTemplate[string][string] templates;

	DocTemplate get_template (string uid, string v_dc_identifier, string v_docs_version)
	{
		DocTemplate res;
		try
		{
		DocTemplate[string] rr;

		if(uid !is null)
		{
			v_dc_identifier = uid;
			v_docs_version = "@";
		}

		rr = templates.get(v_dc_identifier, null);

		if(rr !is null)
		{
			if(v_docs_version is null)
				res = rr.get("actual", null);
			else
				res = rr.get(v_docs_version, null);
		}
		} catch(Exception ex)
		{
		// writeln("Ex!" ~ ex.msg);
		}		
		return res;
	}

	void set_template (DocTemplate tmpl, string tmpl_subj, string v_id)
	{
		templates[tmpl_subj][v_id] = tmpl;
	}
	
	mq_client client;

	private Set!OI[string] gateways;
	
	Set!OI empty_set;
	Set!OI get_gateways (string name)
	{
		return gateways.get(name, empty_set);
	}
	


	this(JSONValue props, string context_name, Tid tid_xapian_indexer, Tid _tid_ticket_manager_, Tid _tid_subject_manager_, Tid _tid_acl_manager_, Tid _tid_statistic_data_accumulator_)
	{
		_tid_statistic_data_accumulator = _tid_statistic_data_accumulator_;
		_tid_ticket_manager = _tid_ticket_manager_;
		tid_subject_manager = _tid_subject_manager_;
		tid_acl_manager = _tid_acl_manager_;
		
		_event_filters = new GraphCluster();
		_ba2pacahon_records = new GraphCluster();

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

//		_ts = connect_to_mongodb_triple_storage(mongodb_port, mongodb_server, db_name, context_name, use_caching_of_documents);
		

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

					string io_alias = gateway.object["alias"].str; 	
					
					Set!OI empty_set;									
					Set!OI gws = gateways.get(io_alias, empty_set);
					
					if (gws.size == 0)
						gateways[io_alias] = empty_set;
										
					OI oi = new OI();															
					if (oi.connect(params) == 0)
						writeln ("#A1:", oi.get_alias);
					else 
						writeln ("#A2:", oi.get_alias);					
						
					if (oi.get_db_type == "xapian")
					{
						writeln ("gateway [", gateway.object["alias"].str, "] is embeded, tid=", tid_xapian_indexer);	
						oi.embedded_gateway = tid_xapian_indexer;
					}

					gws ~= oi;
					gateways[io_alias] = gws;						
				}
			}
		}				
		
		Set!OI empty_set;									
		Set!OI from_search = gateways.get("from-search", empty_set);											
		_vql = new search.vql.VQL(from_search);

		writeln(context_name ~ ": connect to mongodb is ok");

		writeln(context_name ~ ": load events");
		pacahon.event_filter.load_events(this);
		writeln(context_name ~ ": load events... ok");

		mandat_manager = new MandatManager(this);
		mandat_manager.load();
	}

	bool authorize(Ticket *ticket, Subject doc)
	{
		return false;//mandat_manager.ca;
	}

	Tid get_tid_subject_manager ()
	{
		return tid_subject_manager;
	}

	void get_mandats_4_whom(Ticket *ticket, ref HashSet!Mandat mandats)
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
	
	
	Ticket *foundTicket(string ticket_id)
	{
		Ticket *tt = user_of_ticket.get(ticket_id, null);

		//	trace_msg[2] = 0;

		if(tt is null)
		{
			string when = null;
			int duration = 0;
			
//			writeln ("#1");
			send (tid_ticket_manager, FOUND, ticket_id, thisTid);
//			writeln ("#2");
			string ticket_str = receiveOnly!(string);
			
			if (ticket_str !is null && ticket_str.length > 128)
			{
				tt = new Ticket;
				Subject ticket = Subject.fromBSON (ticket_str);
//				writeln ("Ticket=",ticket);
				tt.id = ticket.subject;
				
				tt.userId = ticket.getFirstLiteral (ticket__accessor);
				when = ticket.getFirstLiteral (ticket__when);
				string dd = ticket.getFirstLiteral (ticket__duration);
				duration = parse!uint(dd); 
				
//				writeln ("tt.userId=", tt.userId);				
			}
			
			//////////////////////////////
/*			
			tt.id = ticket_id;

			if(trace_msg[18] == 1)
			{
				log.trace("найдем пользователя по сессионному билету ticket=%s", ticket_id);
				//			printf("T count: %d, %d [µs] start get data\n", count, cast(long) sw.peek().microseconds);
			}

			string when = null;
			int duration = 0;

			// найдем пользователя по сессионному билету и проверим просрочен билет или нет
			if(ticket_id !is null && ticket_id.length > 10)
			{
				TLIterator it = ts.getTriples(ticket_id, null, null);

				if(trace_msg[19] == 1)
					if(it is null)
						log.trace("сессионный билет не найден");

				foreach(triple; it)
				{
					if(trace_msg[20] == 1)
						log.trace("foundTicket: %s %s %s", triple.S, triple.P, triple.O);

					if(triple.P == ticket__accessor)
					{
						tt.userId = triple.O;
					}
					else if(triple.P == ticket__when)
					{
						when = triple.O;
					}
					else if(triple.P == ticket__duration)
					{
						duration = parse!uint(triple.O);
					}
					else if(triple.P == ticket__parentUnitOfAccessor)
					{
						tt.parentUnitIds ~= triple.O;
					}
					
//					if(tt.userId !is null && when !is null && duration > 10)
//						break;
				}

				delete (it);
			}
*/
			if(trace_msg[20] == 1)
				log.trace("foundTicket end");

			if(tt.userId is null)
			{
				if(trace_msg[22] == 1)
					log.trace("найденный сессионный билет не полон, пользователь не найден");
			}

			if(tt.userId !is null && (when is null || duration < 10))
			{
				if(trace_msg[23] == 1)
					log.trace("найденный сессионный билет не полон, считаем что пользователь не был найден");
				tt.userId = null;
			}

			if(when !is null)
			{
				if(trace_msg[24] == 1)
					log.trace("сессионный билет %s Ok, user=%s, when=%s, duration=%d, parentUnitIds=%s", ticket_id, tt.userId, when, duration, text(tt.parentUnitIds));

				// TODO stringToTime очень медленная операция ~ 100 микросекунд
				tt.end_time = stringToTime(when) + duration * 100_000_000_000; //? hnsecs?

				_user_of_ticket[ticket_id] = tt;
			}
		} else
		{
			if(trace_msg[17] == 1)
				log.trace("тикет нашли в кеше, %s", ticket_id);
		}

		return tt;
	}
	
}
