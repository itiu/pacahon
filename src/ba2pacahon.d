module pacahon.ba2pacahon;

private import std.stdio;
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
private import docs.docs_base;

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
	// шаблоны загружаем по мере необходимости

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

void ba2pacahon(string str_json, ThreadContext server_context)
{
	/* Обновляется (документ/шаблон/справочник)
	 * считаем что связанные документы должны быть в наличии и актуальны,
	 * если таковых нет, то не заполняем реификацию
	 */

	JSONValue doc;
	GraphCluster gcl_versioned = new GraphCluster();
	GraphCluster gcl_actual = new GraphCluster();

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
		string authorId = doc.get_str("authorId");
		string dateLastModified = doc.get_str("dateLastModified");

		Subject node = new Subject();
		Subject actual_node = null;

		writeln("objectType=", objectType);

		if(objectType == "TEMPLATE")
		{
			string c_id;
			if(id.length > 7)
				c_id = id[0 .. 7];
			else
				c_id = id;

			string c_vid;
			if(versionId.length > 7)
				c_vid = versionId[0 .. 7];
			else
				c_vid = versionId;

			//			writeln ("TEMPLATE c_id=", c_id, "c_vid=", c_vid);

			templateId = "uo:tmpl_" ~ c_id ~ "_" ~ c_vid;

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

			if(active == "1")
				node.addPredicate(docs__active, "true");
			else
				node.addPredicate(docs__active, "false");

			node.addPredicate(docs__kindOf, "user_template");

			string systemInformation = doc.get_str("systemInformation");
			node.addPredicate(ba__systemInformation, systemInformation);

			string[string] systemInformation_els;
			if(systemInformation !is null)
			{

				if(systemInformation.indexOf("$") >= 0)
				{
					string[] els = systemInformation.split(";");
					foreach(el; els)
					{
						string[] el_els = el.split("=");
						if(el_els.length == 2)
							systemInformation_els[el_els[0]] = el_els[1];
					}
				}

				string defaultRepresentation = systemInformation_els.get("$defaultRepresentation", null);
				if(defaultRepresentation !is null)
				{
					string[] defaultRepresentation_els = defaultRepresentation.split("|");
					foreach(el; defaultRepresentation_els)
					{
						string new_code = ba2user_onto(el);
						node.addPredicate(docs__exportPredicate, new_code);
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

						string new_code = ba2user_onto(code);

						//						writeln("\r\n\r\n[" ~ code ~ "]->[" ~ new_code ~ "]");

						string restrictionId;
						restrictionId = "uo:rstr_" ~ c_id ~ "_" ~ c_vid ~ "_" ~ new_code;

						Subject attr_node = new Subject();
						attr_node.subject = restrictionId;
						attr_node.addPredicate(rdf__type, owl__Restriction);

						attr_node.addPredicate(dc__hasPart, templateId);
						attr_node.addPredicate(owl__onProperty, new_code);
						attr_node.addPredicate(ba__code, code);

						attr_node.addPredicate(dc__identifier, id);
						attr_node.addPredicate(docs__version, versionId);

						string att_name[3] = split_lang(att.get_str("name"));

						attr_node.addPredicate(rdfs__label, att_name[LANG.RU], LANG.RU);
						attr_node.addPredicate(rdfs__label, att_name[LANG.EN], LANG.EN);

						node.addPredicate(rdfs__subClassOf, restrictionId);

						string description = att.get_str("description");
						attr_node.addPredicate(ba__description, description);

						string[string] descr_els;

						if(description.indexOf("$") >= 0)
						{
							string[] els = description.split(";");
							foreach(el; els)
							{
								string[] el_els = el.split("=");
								if(el_els.length == 2)
									descr_els[el_els[0]] = el_els[1];
							}
						}

						//						writeln(descr_els);

						string obligatory = att.get_str("obligatory");
						if(obligatory == "true")
							attr_node.addPredicate(owl__minCardinality, "1");

						string multiSelect = att.get_str("multiSelect");
						if(multiSelect == "false")
							attr_node.addPredicate(owl__maxCardinality, "1");

						string computationalReadonly = att.get_str("computationalReadonly");
						if(computationalReadonly == "true")
							attr_node.addPredicate(ba__readOnly, "true");

						string type = att.get_str("type");

						if(type == "BOOLEAN")
						{
							attr_node.addPredicate(owl__allValuesFrom, xsd__boolean);

						} else if(type == "TEXT" || type == "STRING")
						{
							if(value !is null && value.length > 0)
								attr_node.addPredicate(docs__defaultValue, value);

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
						} else if(type == "LINK" || type == "DICTIONARY")
						{
							string allValuesFrom;
							string dc_identifier_val;

							if(type == "LINK")
							{
								string isTable = descr_els.get("$isTable", null);
								if(isTable !is null)
								{
									allValuesFrom = "uo:doc_" ~ isTable;
									dc_identifier_val = isTable;
								} else
									allValuesFrom = docs__Document;

							} else if(type == "DICTIONARY")
							{
								//docs__defaultValue
								string dictionaryIdValue = att.get_str("dictionaryIdValue");
								allValuesFrom = "uo:tmpl_" ~ dictionaryIdValue;
								dc_identifier_val = dictionaryIdValue;

								string recordIdValue = att.get_str("recordIdValue");
								if(recordIdValue !is null)
									attr_node.addPredicate(docs__defaultValue, "uo:doc_" ~ recordIdValue);

								string dictionaryNameValue = att.get_str("dictionaryNameValue");
								attr_node.addPredicate(rdfs__comment, dictionaryNameValue);

							}

							if(allValuesFrom !is null)
								attr_node.addPredicate(owl__allValuesFrom, allValuesFrom);

							string composition = descr_els.get("$composition", null);
							if(composition !is null)
							{
								//								writeln("composition=", composition);
								string[] composition_els = composition.split("|");
								foreach(el; composition_els)
								{
									el = ba2user_onto(el);

									attr_node.addPredicate(docs__importPredicate, el);
								}
							} else
							{
								// композиция не заданна, берем представление по умолчанию у шаблона на который ссылаемся

								writeln("композиция не задана, берем представление по умолчанию у шаблона на который ссылаемся");
								GraphCluster _tmpl = getTemplate(dc_identifier_val, null, server_context);

								if(_tmpl !is null)
								{
									writeln("шаблон найден");
									Predicate* export_predicates = _tmpl.find_subject_and_get_predicate(rdf__type, rdfs__Class,
											docs__exportPredicate);
									if(export_predicates !is null)
									{
										foreach(el; export_predicates.objects)
										{
											attr_node.addPredicate(docs__importPredicate, el);
											writeln("import predicate", el);
										}
									}

									//								export_predicates
								}

							}

						} else if(type == "ORGANIZATION")
						{
							string organizationTag = att.get_str("organizationTag");

							if(organizationTag !is null && organizationTag.length > 5)
							{
								if(organizationTag.indexOf("user") >= 0)
								{
									if(organizationTag.indexOf(";") > 0)
										attr_node.addPredicate(owl__someValuesFrom, swrc__Person);
									else
										attr_node.addPredicate(owl__allValuesFrom, swrc__Person);

									attr_node.addPredicate(docs__importPredicate, swrc__lastName);
									attr_node.addPredicate(docs__importPredicate, swrc__firstName);
									attr_node.addPredicate(docs__importPredicate, docs__middleName);
								}
								if(organizationTag.indexOf("department") >= 0)
								{
									attr_node.addPredicate(docs__importPredicate, swrc__name);

									if(organizationTag.indexOf(";") > 0)
										attr_node.addPredicate(owl__someValuesFrom, swrc__Department);
									else
										attr_node.addPredicate(owl__allValuesFrom, swrc__Department);
								}

								attr_node.addPredicate(ba__organizationTag, organizationTag);

								/*	пока не целесообразно раскладывать 	organizationTag					
								 string qq[] = organizationTag.split("|");
								 if(qq.length == 2)
								 {
								 string ou_ids[] = qq[1].split(",");

								 foreach(ou_id; ou_ids)
								 {
								 writeln (ou_id);
								 //									string uri = ouId__ouUri.get(ou_id);
								 //									if(uri != null)
								 //										attr_node.addPredicate(docs__defaultValue, uri);
								 }
								 }
								 */}
						}

						gcl_versioned.addSubject(attr_node);
					}
				}
			}
			gcl_versioned.addSubject(node);

			if(actual == "1")
			{
				actual_node = node.dup();
				actual_node.addPredicate(docs__actual, "true");
				actual_node.subject = "uo:tmpl_" ~ id;
				gcl_actual.addSubject(actual_node);
			}

			node.addPredicate(docs__version, versionId);
			
			//node.addPredicate(docs__actual, "false");
				
			/*
			 // установим неактуальным предыдущий шаблон
			 GraphCluster prev_version_tmpl = getTemplate(id, null, server_context);

			 if(prev_version_tmpl !is null)
			 {
			 //				writeln("предыдущий шаблон найден id=", id, "\n", prev_version_tmpl);
			 //				writeln("prev_version_tmpl.i1PO=", prev_version_tmpl.i1PO);
			 Subject ss = prev_version_tmpl.find_subject(rdf__type, rdfs__Class);

			 if(ss !is null)
			 {
			 //					writeln("###1");
			 Subject nss = new Subject();
			 nss.subject = ss.subject;
			 nss.addPredicate(docs__actual, "false");
			 gcl_versioned.addSubject(nss);
			 }

			 setActualTemplate(id, prev_version_tmpl, gcl_versioned, server_context);
			 } else
			 {
			 writeln("предыдущий шаблон не найден");
			 }
			 */
		} else
		{
			string typeId = doc.get_str("typeId");
			string typeVersionId = doc.get_str("typeVersionId");
			GraphCluster tmplate = getTemplate(typeId, typeVersionId, server_context);
			if(tmplate !is null)
			{
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

							if(value !is null && value.length > 0)
							{
								writeln("value=", value);
								string new_code = ba2user_onto(code);

								Subject restriction = tmplate.find_subject(owl__onProperty, new_code);

								if(restriction !is null)
								{
									writeln("restriction=", restriction);
									Predicate* importPredicates = restriction.edges_of_predicate.get(docs__importPredicate, null);
									if(importPredicates !is null)
										writeln("docs__importPredicates=", importPredicates.objects);
								}
							}
							//							writeln ("ss=", ss);

						}
					}
				}
			}
			gcl_versioned.addSubject(node);

		}

		log.trace("*");
		writeln("*");

		OutBuffer outbuff = new OutBuffer();
		toJson_ld(gcl_versioned.graphs_of_subject.values, outbuff);
		outbuff.write(0);
		ubyte[] bb = outbuff.toBytes();
		log.trace_io(false, cast(byte*) bb, bb.length);

		// store versioned 
		foreach(subject; gcl_versioned.graphs_of_subject.values)
		{
			server_context.ts.addSubject(subject);
		}

		if(actual == "1")
		{
			// store actual 
			server_context.ts.removeSubject(actual_node.subject);
			foreach(subject; gcl_actual.graphs_of_subject.values)
			{
				server_context.ts.addSubject(subject);
			}
		}

	} catch(Exception ex)
	{
		writeln("Ex:" ~ ex.msg);
	}

}

static string ba2user_onto(string code)
{
	return "uo:" ~ toTranslit(code);
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
