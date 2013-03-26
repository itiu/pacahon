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

private import std.json_str;
private import std.string;

string[string][string][string] map_ba2onto;
string[string][string][string] map_onto2ba;

/*
 * маппер структур [ba] <-> [pacahon]
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
				//				map_ba2onto["doc:" ~ record._id][record._version][record._code] = record._onto;
			}
			writeln("loaded ", map_ba2onto.length, " ba2pacahon map records from file");

			writeln("test: ###:", map_ba2onto["id2"]["v1"]["автор"]);
			writeln("test: ###:", map_ba2onto["id1"]["v1"]["имя"]);
			writeln("test: ###:", map_ba2onto["*"]["*"]["date_to"]);
		} catch(Exception ex1)
		{
			throw new Exception("ex! parse params:" ~ ex1.msg, ex1);
		}

	}

	TLIterator it = server_thread.ts.getTriples(null, "a", ba2pacahon__Record);
	foreach(triple; it)
	{
		server_thread.ba2pacahon_records.addTriple(triple.S, triple.P, triple.O, triple.lang);
	}

	delete (it);
	writeln("loaded ", server_thread.ba2pacahon_records.length, " ba2pacahon map records from storage");
}

Subject[] ba2pacahon(string str_json)
{
	/* Обновляется (документ/шаблон/справочник)
	 * считаем что связанные документы должны быть в наличии и актуальны,
	 * если таковых нет, то не заполняем реификацию
	 */
	
	
	JSONValue doc;

	writeln("src=" ~ str_json ~ "");

	try
	{
		doc = parseJSON(cast(char[]) str_json);

		string id = doc.object["id"].str;
		string versionId = doc.get_str("versionId");
		string objectType = doc.get_str("objectType");
		string typeVersionId = doc.get_str("typeVersionId");
		string dateCreated = doc.get_str("dateCreated");
		string active = doc.get_str("active");
		string typeId = doc.get_str("typeId");
		string authorId = doc.get_str("authorId");
		string systemInformation = doc.get_str("systemInformation");

		if (systemInformation !is null && objectType == "TEMPLATE") // есть только у шаблона
		{
				foreach (el ; split (systemInformation, ";"))
				{
//					writeln ("el=" ~ el);
					if (el.indexOf("$defaultRepresentation") == 0)
					{
						string[] el_spl = split (el, "=");
						writeln (el_spl[0], " = ", el_spl[1]);
//						def_repr_code = new String[1];
//						def_repr_code[0] = el.split("=")[1];
					}
				}
		}
		
		JSONValue[] attributes;

		if(("attributes" in doc.object) !is null)
		{
			attributes = doc.object["attributes"].array;

			if(attributes !is null)
			{
				foreach(att; attributes)
				{
					writeln(att.object["code"].str);

				}
			}
		}

		writeln("success!");

	} catch(Exception ex)
	{
		writeln("Ex:" ~ ex.msg);
	}
	// Make a DOM tree 
	return null;
}
