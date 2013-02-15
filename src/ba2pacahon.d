module pacahon.ba2pacahon;

private import std.stdio;
private import std.xml;
private import std.csv;

private import trioplax.triple;
private import trioplax.mongodb.TripleStorage;

private import util.Logger;

private import pacahon.know_predicates;

private import pacahon.graph;
private import pacahon.thread_context;

string[string][string][string] map_ba2onto;
string[string][string][string] map_onto2ba;

/*
 * маппер словарей [ba] <-> [pacahon]
 * 
 */

void init_ba2pacahon(ThreadContext server_thread)
{
	string file_name = "map-ba2onto.csv";

	if(std.file.exists(file_name))
	{
		writeln("init ba2pacahon: load ", file_name);
		try
		{
			char[] buff = cast(char[]) std.file.read(file_name);

			struct Layout
			{
				string _id;
				string _version;
				string _code;
				string _onto;
				string _type;
			}

			auto records = csvReader!Layout(buff,';'); 
			foreach(record; records)
			{
				map_ba2onto[record._id][record._version][record._code] = record._onto;
				map_ba2onto["doc:" ~ record._id][record._version][record._code] = record._onto;
			}

			writeln("test: ###:", map_ba2onto["id2"]["v1"]["автор"]);
			writeln("test: ###:", map_ba2onto["id1"]["v1"]["имя"]);
		} catch(Exception ex1)
		{
			throw new Exception("ex! parse params:" ~ ex1.msg, ex1);
		}

	}
	
	TLIterator it = server_thread.ts.getTriples(null, "a", ba2pacahon__Record);
	foreach(triple; it)
		server_thread.ba2pacahon_records.addTriple(triple.S, triple.P, triple.O, triple.lang);

	delete (it);
	writeln("loaded ",  server_thread.ba2pacahon_records.length, " ba2pacahon map records");	
}

Subject[] ba2pacahon(string str_xml)
{

	// Check for well-formedness 
	check(str_xml);
	// Make a DOM tree 
	auto doc = new Document(str_xml); // Plain-print it 
	writeln(doc);
	return null;
}