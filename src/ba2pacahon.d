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

private import util.Logger;
private import std.outbuffer;
private import pacahon.json_ld.parser;

private import util.utils;

string[string][string][string] map_ba2onto;
string[string][string][string] map_onto2ba;

Logger log;

static this()
{
	log = new Logger("pacahon", "log", "command-io");
}

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

	try
	{
		log.trace("start parse json");

		doc = parseJSON(cast(char[]) str_json);

		log.trace("start convert");

		string templateId;

		string id = doc.object["id"].str;
		string versionId = doc.get_str("versionId");
		string objectType = doc.get_str("objectType");
		string dateCreated = doc.get_str("dateCreated");
		string active = doc.get_str("active");
		string actual = doc.get_str("actual");
		string typeId = doc.get_str("typeId");
		string authorId = doc.get_str("authorId");
		string dateLastModified = doc.get_str("dateLastModified");

		GraphCluster gl = new GraphCluster();
		Subject node = new Subject();

		if(objectType == "TEMPLATE")
		{
			//			writeln("TEMPLATE");
			templateId = "user_onto:tmpl_" ~ id[0 .. 7] ~ "_" ~ versionId[0 .. 7];
			node.subject = templateId;
			node.addPredicate(rdfs__subClassOf, docs__Document);
			node.addPredicate(rdf__type, rdfs__Class);
			node.addPredicate(dc__identifier, id);
			node.addPredicate(dc__creator, "zdb:person_" ~ authorId);

			string name[3] = split_lang(doc.get_str("name"));

			if(name[LANG.RU] !is null && name[LANG.EN] !is null)
				node.addPredicate(rdfs__label, name[LANG.RU], LANG.RU);

			if(name[LANG.EN] !is null)
				node.addPredicate(rdfs__label, name[LANG.EN], LANG.EN);

			if(name[LANG.RU] !is null && name[LANG.EN] is null)
				node.addPredicate(rdfs__label, name[LANG.RU]);

			if(dateCreated != null)
				node.addPredicate(dc__created, dateCreated);

			if(dateLastModified != null)
				node.addPredicate(dc__modified, dateLastModified);

			if(active == "true")
				node.addPredicate(docs__active, "true");
			else
				node.addPredicate(docs__active, "false");

			if(actual == "1")
				node.addPredicate(docs__actual, "true");
			else
				node.addPredicate(docs__actual, "false");

			node.addPredicate(docs__kindOf, "user_template");

			string systemInformation = doc.get_str("systemInformation");
			node.addPredicate(ba__systemInformation, systemInformation);

			if(systemInformation !is null)
			{
				foreach(el; split(systemInformation, ";"))
				{
					//					writeln ("el=" ~ el);
					if(el.indexOf("$defaultRepresentation") == 0)
					{
						string[] el_spl = split(el, "=");
						//						writeln(el_spl[0], " = ", el_spl[1]);
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
						string code = att.object["code"].str;

						string value = att.get_str("value");

						string new_code = toTranslit(code);

						//						writeln("[" ~ code ~ "]->[" ~ new_code ~ "]");

						string restrictionId = "user-onto:rstr_" ~ id[0 .. 7] ~ "_" ~ versionId[0 .. 7] ~ "_" ~ new_code;

						Subject attr_node = new Subject();
						attr_node.subject = restrictionId;
						attr_node.addPredicate(rdf__type, owl__Restriction);

						//						attr_node.addPredicate (gost19__isRelatedTo, docs__Document);						
						//						node.addPredicate (gost19__isRelatedTo, docs__Document);						

						attr_node.addPredicate(dc__hasPart, templateId);
						attr_node.addPredicate(owl__onProperty, new_code);
						attr_node.addPredicate(dc__identifier, code);

						string att_name[3] = split_lang(att.get_str("name"));

						attr_node.addPredicate(rdfs__label, att_name[LANG.RU], LANG.RU);
						attr_node.addPredicate(rdfs__label, att_name[LANG.EN], LANG.EN);

						node.addPredicate(rdfs__subClassOf, restrictionId);

						string description = att.get_str("description");
						attr_node.addPredicate(ba__description, description);

						string obligatory = att.get_str("obligatory");
						if(obligatory == "true")
						{
							attr_node.addPredicate(owl__minCardinality, "1");
						}

						string multiSelect = att.get_str("multiSelect");
						if(multiSelect == "false")
						{
							attr_node.addPredicate(owl__maxCardinality, "1");
						}

						string type = att.get_str("type");

						if(type == "BOOLEAN")
						{
							attr_node.addPredicate(owl__allValuesFrom, xsd__boolean);

						} else if(type == "TEXT" || type == "STRING")
						{
							if(value !is null && value.length > 0)
							{
								attr_node.addPredicate(docs__defaultValue, value);
							}

							attr_node.addPredicate(owl__allValuesFrom, xsd__string);

						} else if(type == "NUMBER")
						{
							attr_node.addPredicate(owl__allValuesFrom, xsd__decimal);
						} else if(type == "DATE")
						{
							attr_node.addPredicate(owl__allValuesFrom, xsd__dateTime);
						} else if(type == "FILE")
						{
							attr_node.addPredicate(owl__allValuesFrom, docs__FileDescription);
						} else if(type == "LINK")
						{
							attr_node.addPredicate(owl__allValuesFrom, docs__Document);
						} else if(type == "DICTIONARY")
						{
							//docs__defaultValue
							string dictionaryIdValue = att.get_str("dictionaryIdValue");
							attr_node.addPredicate(owl__allValuesFrom, "user_onto:tmpl_" ~ dictionaryIdValue);

							string recordIdValue = att.get_str("recordIdValue");
							if(recordIdValue !is null)
								attr_node.addPredicate(docs__defaultValue, "user_onto:doc_" ~ recordIdValue);

							string dictionaryNameValue = att.get_str("dictionaryNameValue");
							attr_node.addPredicate(rdfs__comment, dictionaryNameValue);

						} else if(type == "ORGANIZATION")
						{
							string organizationTag = att.get_str("organizationTag");

							if(organizationTag == "user")
							{
								if(organizationTag.indexOf(";") > 0)
									attr_node.addPredicate(owl__someValuesFrom, swrc__Person);
								else
									attr_node.addPredicate(owl__allValuesFrom, swrc__Person);

								attr_node.addPredicate(docs__take, swrc__lastName);
								attr_node.addPredicate(docs__take, swrc__firstName);
								attr_node.addPredicate(docs__take, docs__middleName);
							} else if("department")
							{
								attr_node.addPredicate(docs__take, swrc__name);
								
								if(organizationTag.indexOf(";") > 0)
									attr_node.addPredicate(owl__someValuesFrom, swrc__Department);
								else
									attr_node.addPredicate(owl__allValuesFrom, swrc__Department);
							}
						}

						gl.addSubject(attr_node);
					}
				}
			}
		} else
		{
			string typeVersionId = doc.get_str("typeVersionId");
		}

		gl.addSubject(node);

		log.trace("*");
		writeln("*");

		OutBuffer outbuff = new OutBuffer();
		toJson_ld(gl.graphs_of_subject.values, outbuff);
		outbuff.write(0);
		ubyte[] bb = outbuff.toBytes();
		log.trace_io(false, cast(byte*) bb, bb.length);
	} catch(Exception ex)
	{
		writeln("Ex:" ~ ex.msg);
	}
	// Make a DOM tree 
	return null;
}

static string[3] split_lang(string src)
{
	string res[3];
	// пример: "@ru@ru{Аудит ОВА}@@en{Audit}@"
	if(src.indexOf("@@") > 0)
	{
		string[] name_els = split(src, "@");
		//	writeln("name_els=", name_els);

		foreach(el; name_els)
		{
			if(el.length > 3)
			{
				if(el[0] == 'r' && el[1] == 'u' && el[2] == '{')
				{
					res[LANG.RU] = el[3 .. $ - 1];
				} else if(el[0] == 'e' && el[1] == 'n' && el[2] == '{')
				{
					res[LANG.EN] = el[3 .. $ - 1];
				}
			}
		}
	}
	return res;
}
