module mmf.rebuild_graph;

private
{
	import std.mmfile;
	import std.stdio;

	import std.c.stdio;

	import std.json;

	import trioplax.mongodb.triple;
	import trioplax.mongodb.TripleStorage;

	import util.Logger;

	import util.utils;
	import std.datetime;

	import std.string;
	import std.array;

	import mmf.mmfgraph;

	import libchash_h;

	private import mongoc.bson_h;
	private import mongoc.mongo_h;
}

Logger log;

static this()
{
	log = new Logger("rebuild graph file", "log", "server");
}

void rebuild()
{
	//	HashTable* ht;
	//	ht = AllocateHashTable(0, 1);

	JSONValue props;

	try
	{
		props = get_props("pacahon-properties.json");
	} catch(Exception ex1)
	{
		throw new Exception("ex! parse params", ex1);
	}

	string mongodb_server = "localhost";
	if(("mongodb_server" in props.object) !is null)
		mongodb_server = props.object["mongodb_server"].str;

	string mongodb_collection = "pacahon";
	if(("mongodb_collection" in props.object) !is null)
		mongodb_collection = props.object["mongodb_collection"].str;

	int mongodb_port = 27017;
	if(("mongodb_port" in props.object) !is null)
		mongodb_port = cast(int) props.object["mongodb_port"].integer;

	writeln("connect to mongodb, \n");
	writeln("	port:", mongodb_port);
	writeln("	server:", mongodb_server);
	writeln("	collection:", mongodb_collection);

	TripleStorage ts;
	try
	{
		ts = new TripleStorage(mongodb_server, mongodb_port, mongodb_collection);

		ts.define_predicate_as_multiple("a");
		ts.define_predicate_as_multiple("rdf:type");
		ts.define_predicate_as_multiple("rdfs:subClassOf");
		ts.define_predicate_as_multiple("gost19:take");
		ts.define_predicate_as_multiple("event:msg_template");

		ts.define_predicate_as_multilang("swrc:name");
		ts.define_predicate_as_multilang("swrc:firstName");
		ts.define_predicate_as_multilang("swrc:lastName");
		//			ts.define_predicate_as_multilang("gost19:middleName");
		ts.define_predicate_as_multilang("docs:position");

		ts.set_fulltext_indexed_predicates("swrc:name");
		ts.set_fulltext_indexed_predicates("swrc:firstName");
		ts.set_fulltext_indexed_predicates("swrc:lastName");
		ts.set_fulltext_indexed_predicates("gost19:middleName");
		ts.set_fulltext_indexed_predicates("docs:position");
		ts.set_fulltext_indexed_predicates("rdfs:label");
		ts.set_fulltext_indexed_predicates("swrc:email");
		ts.set_fulltext_indexed_predicates("swrc:phone");
		ts.set_fulltext_indexed_predicates("gost19:internal_phone");

		printf("ok, connected : %X\n", ts);
	} catch(Exception ex)
	{
		throw new Exception("Connect to mongodb: " ~ ex.msg, ex);
	}

	size_t win = 64 * K; // assume the page size is 64K
	version(Win32)
	{
		/+ these aren't defined in std.c.windows.windows so let's use default
		 SYSTEM_INFO sysinfo;
		 GetSystemInfo(&sysinfo);
		 win = sysinfo.dwAllocationGranularity;
		 +/
	} else version(linux)
	{
		// getpagesize() is not defined in the unix D headers so use the guess
	}

	GraphIO gio;

	gio.open_mmfiles("HA1");

	log.trace("mdb -> ha1 start");

	if(trace)
		writeln("#1");

	if(trace)
		writeln("#2");

	TLIterator it;

	int count = 0;

	char*[] keys;
	char* qqqq;

	//	keys = new char*[10_000_000];

	mongo_cursor* cursor = null;
	if(trace)
		writeln("#3");

	string subj = "";
	while(subj !is null)
	{
		if(trace)
			writeln("#4");
		subj = ts.getNextSubject(cursor);

		//		keys[count] = cast(char*) toStringz(subj);
		//		qqqq = cast(char*) toStringz(subj);
		//			writeln (triple.S);
		//			printf ("#4 ss=%s cast(uint) ss=%X\n", ss, cast(uint) ss);
		//		HTItem* bck = HashFind(ht, cast(uint) qqqq);
		//			log.trace("#0.2");
		//			printf ("#5\n");
		if(trace)
			writeln("#5");
		if(count % 10000 == 0)
		{
			writeln("count subjects: ", count);//, ", mmf allocated:", mmfi.allocate_bytes, ", mmf vertex:",
			//					mmfi.allocate_vertex);
		}

		//		if(bck is null)
		if(subj.length > 0)
		{
			//				log.trace("#1");
			//		int len = strlen (cast(char*) triple.S);
			//		printf ("bck=%X %d\n", bck, len);	    
			//				printf ("#6\n");

			//				printf ("#7\n");
			if(trace)
				writeln("#6");
			TLIterator it1 = ts.getTriples(subj, null, null);
			(cast(TripleStorageMongoDBIterator) it1).is_get_all_reifed = true;

			//				printf ("#8\n");

			if(it1 !is null)
			{
				Vertex_vmm*[string] vmms;
				Vertex_vmm* vmm;
				//				vmm.ch = &mmfi;
				//					log.trace("#2");

				//					printf ("#9\n");
				//				HashInsert(ht, cast(uint) keys[count], count);
				//					printf ("#10\n");
				//					writeln(triple.S);
				//				printf ("%s\n",ss);
				if(trace)
					writeln("#7");
				log.trace("subject:%s count:%d", subj, count);

				foreach(triple1; it1)
				{
					if(triple1.O.length > 0)
					{
						string ss;

						if(triple1.S != subj)
						{
							ss = triple1.S;

							log.trace("	--- s:%s p:%s  o:%s", ss, triple1.P, triple1.O);
						} else
						{
							ss = subj;

							log.trace("		s:%s p:%s  o:%s", ss, triple1.P, triple1.O);
						}

						if((ss in vmms) is null)
						{
							vmm = new Vertex_vmm;
							vmms[ss] = vmm;
							vmm.gio = &gio;
							vmm.setLabel(ss);
						} else
						{
							vmm = vmms[ss];
						}

						string[] values = vmm.edges.get(triple1.P, []);

						string new_values[] = new string[values.length + 1];

						new_values[0 .. $ - 1] = values[];
						new_values[values.length] = triple1.O;

						vmm.edges[triple1.P] = new_values;

					}
				}

				foreach(vmmi; vmms.values)
				{
					log.trace("	store : %s", vmmi.getLabel);
					int res = vmmi.insert_to_file();

					if(res < 0)
					{
						writeln("rebuild_graph:fail, errcode=", res);
						return;
					}
				}

				count++;

				if(trace)
					writeln("#9");
			}

		}

	}

	writeln("count subjects: ", count);
	log.trace("mdb -> ha1, loaded %d", count);

	//	delete mmfi.array;
}