module pacahon.ba2pacahon;

private import std.stdio;
private import std.csv;

private import trioplax.mongodb.triple;
private import trioplax.mongodb.TripleStorage;

private import util.Logger;

private import pacahon.know_predicates;

private import pacahon.graph;
private import pacahon.thread_context;

private import std.json;
private import std.string;

private import util.Logger;
private import std.outbuffer;
//private import pacahon.json_ld.parser;

private import util.utils;
private import onto.rdf_base;
private import onto.docs_base;

private import pacahon.command.io;

string[string][string][string] map_ba2onto;
string[string][string][string] map_onto2ba;

Logger log;

int count = 0;

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
		//		log.trace("start parse json");

		doc = parseJSON(cast(char[]) str_json);

		log.trace("start convert");

		string subj_UID;
		string subj_versioned_UID;

		string id = doc.object["id"].str;
		string versionId = get_str(doc, "versionId");
		string objectType = get_str(doc, "objectType");
		string dateCreated = get_str(doc, "dateCreated");
		string active = get_str(doc, "active");
		string actual = get_str(doc, "actual");
		string authorId = get_str(doc, "authorId");
		string dateLastModified = get_str(doc, "dateLastModified");

		Subject node = new Subject();
		Subject actual_node = null;

		//writeln("objectType=", objectType);
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

		//writeln(objectType, " id=", id, " c_id=", c_id, "c_vid=", c_vid);

		if(objectType == "TEMPLATE")
		{
			subj_versioned_UID = prefix_tmpl ~ c_id ~ "_" ~ c_vid;

			if(id.indexOf(":") < 3)
				subj_UID = prefix_tmpl ~ id;
			else
				subj_UID = id;

			//writeln(subj_UID);

			node.subject = subj_versioned_UID;
			node.addPredicate(rdfs__subClassOf, docs__Document);
			node.addPredicate(rdf__type, rdfs__Class);
			node.addPredicate(dc__identifier, id);

			node.addPredicate(dc__creator, prefix_person ~ authorId);
			if(dateCreated != null)
				node.addPredicate(dc__created, dateCreated);

			if(dateLastModified != null)
				node.addPredicate(dc__modified, dateLastModified);

			string name[3] = split_lang(doc.get_str("name"));

			if(name[LANG.EN] !is null)
				node.addPredicate(rdfs__label, name[LANG.EN], LANG.EN);

			if(name[LANG.RU] !is null)
				node.addPredicate(rdfs__label, name[LANG.RU], LANG.RU);

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

				if(id == "docs:employee_card")
				{
					node.addPredicate(docs__exportPredicate, docs__position);
					node.addPredicate(docs__exportPredicate, docs__unit);
					node.addPredicate(docs__exportPredicate, gost19__middleName);
					node.addPredicate(docs__exportPredicate, swrc__firstName);
					node.addPredicate(docs__exportPredicate, swrc__lastName);
				} else
				{
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

						//writeln("\r\n\r\n[" ~ code ~ "]->[" ~ new_code ~ "]");

						string restrictionId;
						restrictionId = prefix_restriction ~ c_id ~ "_" ~ c_vid ~ "_" ~ new_code;

						Subject attr_node = new Subject();
						attr_node.subject = restrictionId;
						attr_node.addPredicate(rdf__type, owl__Restriction);

						attr_node.addPredicate(owl__onProperty, new_code);
						attr_node.addPredicate(ba__code, code);

						attr_node.addPredicate(dc__identifier, id);

						string att_name[3] = split_lang(att.get_str("name"));

						attr_node.addPredicate(rdfs__label, att_name[LANG.RU], LANG.RU);
						attr_node.addPredicate(rdfs__label, att_name[LANG.EN], LANG.EN);

						//						node.addPredicate(rdfs__subClassOf, restrictionId);

						string description = att.get_str("description");

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
							//writeln(descr_els);
						}

						attr_node.addPredicate(ba__description, description);

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
									allValuesFrom = prefix_tmpl ~ isTable;
									dc_identifier_val = isTable;
								} else
									allValuesFrom = docs__Document;

							} else if(type == "DICTIONARY")
							{
								//docs__defaultValue
								string dictionaryIdValue = att.get_str("dictionaryIdValue");
								allValuesFrom = prefix_tmpl ~ dictionaryIdValue;
								dc_identifier_val = dictionaryIdValue;

								string recordIdValue = att.get_str("recordIdValue");
								if(recordIdValue !is null)
									attr_node.addPredicate(docs__defaultValue, prefix_doc ~ recordIdValue);

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

								if(dc_identifier_val !is null && dc_identifier_val.length > 3)
								{
									//writeln("композиция не задана, берем представление по умолчанию у шаблона на который ссылаемся");
									GraphCluster _tmpl = getTemplate(dc_identifier_val, null, server_context);

									if(_tmpl !is null)
									{
										//									writeln("шаблон найден");
										Predicate* export_predicates = _tmpl.find_subject_and_get_predicate(rdf__type,
												rdfs__Class, docs__exportPredicate);
										if(export_predicates !is null)
										{
											//										writeln("import predicate", export_predicates);
											foreach(el; export_predicates.getObjects)
											{
												attr_node.addPredicate(docs__importPredicate, el);
												//											writeln("import predicate", el);
											}
										}

										//								export_predicates
									} else
									{
										log.trace(
												"linked template [" ~ dc_identifier_val ~ "] not found [" ~ id ~ "][" ~ code ~ "]");
									}
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
									attr_node.addPredicate(docs__importPredicate, gost19__middleName);
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

								//	пока не целесообразно раскладывать 	organizationTag	
							}
						}

						if(actual == "1")
						{
							Subject actual_attr_node = attr_node.dup();
							actual_attr_node.subject = prefix_restriction ~ id ~ "_" ~ new_code;
							actual_attr_node.addPredicate(dc__hasPart, subj_UID);
							gcl_actual.addSubject(actual_attr_node);
						}

						attr_node.addPredicate(dc__hasPart, subj_versioned_UID);
						attr_node.addPredicate(docs__version, versionId);
						gcl_versioned.addSubject(attr_node);

					}
				}
			}

		} else
		{
			// objectType != "TEMPLATE"
			subj_versioned_UID = prefix_doc ~ c_id ~ "_" ~ c_vid;
			subj_UID = prefix_doc ~ id;

			node.subject = subj_versioned_UID;
			node.addPredicate(rdf__type, docs__Document);
			node.addPredicate(dc__identifier, id);

			node.addPredicate(dc__creator, prefix_person ~ authorId);
			if(dateCreated != null)
				node.addPredicate(dc__created, dateCreated);

			if(dateLastModified != null)
				node.addPredicate(dc__modified, dateLastModified);

			string typeId = doc.get_str("typeId");
			string typeVersionId = doc.get_str("typeVersionId");
			GraphCluster tmplate = getTemplate(typeId, typeVersionId, server_context);
			if(tmplate !is null)
			{
				Subject tmpl_class = tmplate.find_subject(rdf__type, rdfs__Class);

				node.addPredicate(rdf__type, tmpl_class.subject);
				node.addPredicate(docs__label, tmpl_class.getObjects(rdfs__label));

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
								string new_code = ba2user_onto(code);
								//writeln("\r\n\r\ndoc:[" ~ code ~ "]->[" ~ new_code ~ "] = ", value);

								Subject restriction = tmplate.find_subject(owl__onProperty, new_code);

								if(restriction !is null)
								{
									
									string description = att.get_str("description");

									string[string] descr_els;
									if(description !is null)
									{
										if(description.indexOf("$") >= 0)
										{
											string[] els = description.split(";");
											foreach(el; els)
											{
												string[] el_els = el.split("=");
												if(el_els.length == 2)
													descr_els[el_els[0]] = el_els[1];
											}
											//writeln(descr_els);
										}
									}

									string type = att.get_str("type");

									if(type == "DICTIONARY")
									{
										value = prefix_doc ~ value;
										// возьмем данные для реификации из аттрибута (recordNameValue) 
										string recordNameValue = att.get_str("recordNameValue");
										string dictionaryNameValue = att.get_str("dictionaryNameValue");

										//writeln("recordNameValue=", recordNameValue);
										//writeln("dictionaryNameValue=", dictionaryNameValue);

										//writeln("restriction=", restriction);
										//writeln("value=", value);
										Predicate* importPredicates = restriction.getPredicate(docs__importPredicate);
										if(importPredicates !is null)
										{
											// создать реифицированный субьект rS к текущему аттрибуту
											Subject rS = create_reifed_info(subj_versioned_UID, new_code, value);

											// возьмем данные из импортируемых полей данного документа
											// добавим реифицированные данные в rS

											if(importPredicates.count_objects == 1)
											{
												rS.addPredicate(docs__templateName, dictionaryNameValue);
												rS.addPredicate(importPredicates.getFirstObject(), recordNameValue);
											} else
											{
												// возьмем из compositionValues
												string compositionValues = descr_els.get("$compositionValues", null);

												if(compositionValues !is null)
												{
													string[] els = compositionValues.split("|");
													foreach(el; els)
													{
														string gg[] = el.split("--");

														if(gg.length == 2)
														{
															rS.addPredicate(ba2user_onto(gg[0]), gg[1]);
														}
													}
												}
											}

											gcl_versioned.addSubject(rS);

										}
									} else if(type == "LINK" || type == "ORGANIZATION")
									{
										value = prefix_doc ~ value;
										// в случае линка, в исходной ba-json данных не достаточно для реификации ссылки, 
										// требуется считать из базы
										//writeln("restriction=", restriction);
										Predicate* importPredicates = restriction.getPredicate(docs__importPredicate);
										if(importPredicates !is null)
										{
											//writeln("#2docs__importPredicates=", importPredicates.getObjects());
											GraphCluster inner_doc = getDocument(value, importPredicates.getObjects(),
													server_context);
											//writeln("doc = ", inner_doc);	
											if(inner_doc !is null)
											{
												Subject indoc = inner_doc.find_subject(rdf__type, docs__Document);
												if(indoc is null)
													indoc = inner_doc.find_subject(rdf__type, docs__employee_card);

												if(indoc !is null)
												{
													// создать реифицированный субьект rS к текущему аттрибуту
													Subject rS = create_reifed_info(subj_versioned_UID, new_code, value);

													foreach(el; importPredicates.getObjects())
													{
														Predicate* pp = indoc.getPredicate(el.literal);
														if(pp !is null)
															rS.addPredicate(el.literal, pp.getObjects());
													}
													gcl_versioned.addSubject(rS);
												}
											}
										}

									}
								}
								node.addPredicate(new_code, value, restriction);
							}

						}
					}
				}
			}
			gcl_versioned.addSubject(node);

		}

		if(actual == "1")
		{
			actual_node = node.dup();
			actual_node.addPredicate(docs__actual, "true");
			actual_node.subject = subj_UID;
			gcl_actual.addSubject(actual_node);
		}

		node.addPredicate(docs__version, versionId);
		gcl_versioned.addSubject(node);

		//		OutBuffer outbuff = new OutBuffer();
		//		toJson_ld(gcl_versioned.graphs_of_subject.values, outbuff);
		//		outbuff.write(0);
		//		ubyte[] bb = outbuff.toBytes();
		//		log.trace_io(false, cast(byte*) bb, bb.length);

		// store versioned 
		bool isOk;
		string reason;
		store_graph(gcl_versioned.graphs_of_subject.values, null, server_context, isOk, reason);

		//		foreach(subject; gcl_versioned.graphs_of_subject.values)
		//		{
		//			server_context.ts.addSubject(subject);
		//		}

		if(actual == "1")
		{
			// store actual 			
			foreach(subject; gcl_actual.graphs_of_subject.values)
			{
				server_context.ts.removeSubject(subject.subject);
				server_context.ts.storeSubject(subject);
			}
		}

		log.trace("ba2pacahon, count:%d", ++count);
	} catch(Exception ex)
	{
		writeln("Ex:" ~ ex.msg);
	}

}

static string ba2user_onto(string code)
{
	if(code.indexOf(":") > 0)
		return code;
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
	} else
	{
		res[LANG.RU] = src;
	}
	return res;
}

public string get_str(JSONValue jv, string field_name)
{
	if(field_name in jv.object)
	{
		return jv.object[field_name].str;
	}
	return null;
}

public long get_int(JSONValue jv, string field_name)
{
	if(field_name in jv.object)
	{
		return jv.object[field_name].integer;
	}
	return 0;
}