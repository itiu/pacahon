module pacahon.thread_context;

//private import trioplax.mongodb.TripleStorage;
private import mq_client;

private import util.Logger;

private import pacahon.graph;
private import pacahon.oi;
private import pacahon.json_ld.parser1;

private import onto.doc_template;
private import std.json;
private import std.stdio;
private import pacahon.command.event_filter;
private import std.format;
private import trioplax.mongodb.MongodbTripleStorage;
private import pacahon.know_predicates;

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

synchronized class ThreadContext
{
	bool IGNORE_EMPTY_TRIPLE = false;

	Statistic stat;

	GraphCluster ba2pacahon_records;
	GraphCluster event_filters;
	Ticket[string] user_of_ticket;
	string[string] cache__subject_creator;
	TripleStorage ts;

	//	 TODO предусмотреть сброс кэша шаблонов
	DocTemplate[string][string] templates;

	mq_client client;

	OI[string] gateways;

	this(JSONValue props, string context_name)
	{
		event_filters = new GraphCluster();
		ba2pacahon_records = new GraphCluster();

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

		ts = connect_to_mongodb_triple_storage(mongodb_port, mongodb_server, db_name, context_name);
		writeln(context_name ~ ": connect to mongodb is ok");

		writeln(context_name ~ ": load events");
		load_events(this);
		writeln(context_name ~ ": load events... ok");

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
					oi.connect (params);
					gateways[gateway.object["alias"].str] = oi;										
				}
			}
		}

		stat = new Statistic();
	}
}


public static TripleStorage connect_to_mongodb_triple_storage(int mongodb_port, string mongodb_server, string mongodb_collection, string thread_name)
{
	writeln("connect to mongodb, thread:", thread_name);
	writeln("	port:", mongodb_port);
	writeln("	server:", mongodb_server);
	writeln("	collection:", mongodb_collection);

	MongodbTripleStorage ts;
	try
	{
		ts = new MongodbTripleStorage(mongodb_server, mongodb_port, mongodb_collection);

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

/////////////////////////////////// TRIPLE STORAGE

enum field: byte
{
	GET = 0,
	GET_REIFED = 1
}

interface TripleStorage
{
	public TLIterator getTriples(string s, string p, string o, int MAX_SIZE_READ_RECORDS = 1000, int OFFSET = 0);

	public bool removeSubject(string s);

	public void storeSubject(Subject graph, ThreadContext server_context);

	public bool isExistSubject(string subject);

	public void addTripleToReifedData(Triple reif, string p, string o, byte lang);

	public TLIterator getTriplesOfMask(ref Triple[] mask_triples, byte[string] reading_predicates,
			int MAX_SIZE_READ_RECORDS = 1000);

	public int addTriple(Triple tt, bool isReification = false);
}

interface TLIterator
{
	int opApply(int delegate(ref Triple) dg);

//	int length();
}

public static const byte _NONE = 0;
public static const byte _RU = 1;
public static const byte _EN = 2;

class Triple
{
	string S;
	string P;
	string O;
	//	int hhh;

	byte lang;

	this(string _S, string _P, string _O)
	{
		S = cast(string) new char[_S.length];
		P = cast(string) new char[_P.length];

		(cast(char[]) S)[] = _S[];
		(cast(char[]) P)[] = _P[];

		if(_O.length > 2 && _O[$ - 3] == '@')
		{
			O = cast(string) new char[_O.length - 3];
			(cast(char[]) O)[] = _O[0 .. $ - 3];

			if(_O[$ - 2] == 'r')
				lang = _RU;
			else if(_O[$ - 2] == 'e')
				lang = _EN;
		} else
		{
			O = cast(string) new char[_O.length];
			(cast(char[]) O)[] = _O[];
		}
	}

	this(string _S, string _P, string _O, byte _lang)
	{
		S = cast(string) new char[_S.length];
		P = cast(string) new char[_P.length];
		O = cast(string) new char[_O.length];

		(cast(char[]) S)[] = _S[];
		(cast(char[]) P)[] = _P[];
		(cast(char[]) O)[] = _O[];

		//		S = _S;
		//		P = _P;
		//		O = _O;
		lang = _lang;

		//		log.trace ("create triple %s", this);
	}

	~this()
	{
		//		log.trace ("destroy triple %s", this);
	}

	override string toString()
	{
		string sS = S;
		string sP = P;
		string sO = O;

		if(sS is null)
			sS = "";

		if(sP is null)
			sP = "";

		if(sO is null)
			sO = "";

		auto writer = appender!string();

		//		formattedWrite(writer, "%X %d %d<%s>%d<%s>%d<%s>", cast(void*)this, hhh, sS.length, sS, sP.length, sP, sO.length, sO);
		formattedWrite(writer, "<%s><%s><%s>", sS, sP, sO);

		return writer.data;
		//		return "<" ~ sS ~ ">"~sS.length~"<" ~ sP ~ "><" ~ sO ~ ">";
	}

}
