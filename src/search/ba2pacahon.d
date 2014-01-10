module search.ba2pacahon;

private import core.thread;
private import core.vararg;
private import std.stdio;
private import std.csv;
private import std.json;
private import std.string;
private import std.outbuffer;

private import pacahon.know_predicates;
private import pacahon.context;
private import pacahon.command_io;
//private import pacahon.json_ld.parser;

private import util.graph;
private import util.utils;
private import util.logger;

private import onto.rdf_base;
private import onto.docs_base;
private import onto.doc_template;


string[ string ][ string ][ string ] map_ba2onto;
string[ string ][ string ][ string ] map_onto2ba;
Subject[ string ] doc_cache;

logger log;

int    count = 0;

static this()
{
    log = new logger("ba2pacahon", "log", "ba2pacahon");
}

/*
 * маппер структур [ba] <-> [pacahon]
 *
 */

void init_ba2pacahon(Context server_thread)
{
    // шаблоны загружаем по мере необходимости

    string file_name = "map-ba2onto.csv";

    if (std.file.exists(file_name))
    {
        // writeln("init ba2pacahon: load ", file_name);
        try
        {
            char[] buff = cast(char[])std.file.read(file_name);

            struct Layout
            {
                string _id;
                string _version;
                string _code;
                string _onto;
                string _type;
            }

            auto records = csvReader!Layout(buff, ';');
            foreach (record; records)
            {
                map_ba2onto[ record._id ][ record._version ][ record._code ] = record._onto;
                //				map_ba2onto["doc:" ~ record._id][record._version][record._code] = record._onto;
            }
            // writeln("loaded ", map_ba2onto.length, " ba2pacahon map records from file");

            // writeln("test: ###:", map_ba2onto["id2"]["v1"]["автор"]);
            // writeln("test: ###:", map_ba2onto["id1"]["v1"]["имя"]);
            // writeln("test: ###:", map_ba2onto["*"]["*"]["date_to"]);
        }
        catch (Exception ex1)
        {
            throw new Exception("ex! parse params:" ~ ex1.msg, ex1);
        }
    }

//	TLIterator it = server_thread.ts.getTriples(null, rdf__type, ba2pacahon__Record);
//	foreach(triple; it)
//	{
//		server_thread.ba2pacahon_records.addTriple(triple.S, triple.P, triple.O, triple.lang);
//	}

//	delete (it);
    // writeln("loaded ", server_thread.ba2pacahon_records.length, " ba2pacahon map records from storage");
}

void ba2pacahon(string msg_str, Context context)
{
    /* Обновляется (документ/шаблон/справочник)
     * считаем что связанные документы должны быть в наличии и актуальны,
     * если таковых нет, то не заполняем реификацию
     */

    bool is_processed_links = true;
    bool is_cached          = false;

    try
    {
        log.trace("ba2pacahon:start parse json");
        JSONValue doc = parseJSON(msg_str);

//		 writeln ("str_json = ",  str_json);

        log.trace("start convert");

        string subj_UID;
        string subj_versioned_UID;

        string id           = get_str(doc, "id");
        string objectType   = get_str(doc, "objectType");
        string versionId    = get_str(doc, "versionId");
        string dateCreated  = get_str(doc, "dateCreated");
        string active       = get_str(doc, "active");
        string actual       = get_str(doc, "actual");
        string authorId     = get_str(doc, "authorId");
        string lastEditorId = get_str(doc, "lastEditorId");

        if (authorId is null)
            authorId = lastEditorId;

        string  dateLastModified = get_str(doc, "dateLastModified");

        Subject node        = new Subject();
        Subject actual_node = null;

        //writeln("objectType=", objectType);
        string c_id;
        if (id.length > 8)
            c_id = id[ 0 .. 8 ];
        else
            c_id = id;

        string c_vid;
        if (versionId.length > 8)
            c_vid = versionId[ 0 .. 8 ];
        else
            c_vid = versionId;

        log.trace("objectType=%s, id=%s, c_id=%s, c_vid=%s", objectType, id, c_id, c_vid);

        if (objectType == "TEMPLATE")
        {
            GraphCluster gcl_versioned = new GraphCluster();
            GraphCluster gcl_actual    = new GraphCluster();

            subj_versioned_UID = prefix_tmpl ~ c_id ~ "_" ~ c_vid;

            if (id.indexOf(":") < 3)
                subj_UID = prefix_tmpl ~ id;
            else
                subj_UID = id;

            //writeln(subj_UID);

            node.subject = subj_versioned_UID;
            node.addPredicate(rdfs__subClassOf, docs__Document);
            node.addPredicate(rdf__type, rdfs__Class);
            node.addPredicate(dc__identifier, id);

            node.addPredicate(dc__creator, prefix_doc ~ authorId);
            if (dateCreated != null)
                node.addPredicate(dc__created, dateCreated);

            if (dateLastModified != null)
                node.addPredicate(dc__modified, dateLastModified);

            string name[ 3 ] = split_lang(doc.get_str("name"));

            if (name[ LANG.EN ] !is null)
                node.addPredicate(rdfs__label, name[ LANG.EN ], LANG.EN);

            if (name[ LANG.RU ] !is null)
                node.addPredicate(rdfs__label, name[ LANG.RU ], LANG.RU);

            if (active == "1")
                node.addPredicate(docs__active, "true");
            else
                node.addPredicate(docs__active, "false");

            node.addPredicate(docs__kindOf, "user_template");

            string systemInformation = doc.get_str("systemInformation");
            node.addPredicate(ba__systemInformation, systemInformation);

            string[ string ] systemInformation_els;
            if (systemInformation !is null)
            {
                if (systemInformation.indexOf("$") >= 0)
                {
                    string[] els = systemInformation.split(";");
                    foreach (el; els)
                    {
                        string[] el_els = el.split("=");
                        if (el_els.length == 2)
                            systemInformation_els[ el_els[ 0 ] ] = el_els[ 1 ];
                    }
                }

                if (id == "docs:employee_card")
                {
                    node.addPredicate(link__exportPredicates, docs__position);
                    node.addPredicate(link__exportPredicates, docs__unit);
                    node.addPredicate(link__exportPredicates, gost19__middleName);
                    node.addPredicate(link__exportPredicates, swrc__firstName);
                    node.addPredicate(link__exportPredicates, swrc__lastName);
                }
                else
                {
                    string defaultRepresentation = systemInformation_els.get("$defaultRepresentation", null);
                    if (defaultRepresentation !is null)
                    {
                        string[] defaultRepresentation_els = defaultRepresentation.split("|");
                        foreach (el; defaultRepresentation_els)
                        {
                            string new_code = ba2user_onto(el);
                            node.addPredicate(link__exportPredicates, new_code);
                        }
                    }
                }
            }

            JSONValue[] attributes;

            if (("attributes" in doc.object) !is null)
            {
                attributes = doc.object[ "attributes" ].array;

                if (attributes !is null)
                {
                    foreach (att; attributes)
                    {
                        string code     = att.object[ "code" ].str;
                        string value    = att.get_str("value");
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

                        string att_name[ 3 ] = split_lang(att.get_str("name"));

                        attr_node.addPredicate(rdfs__label, att_name[ LANG.RU ], LANG.RU);
                        attr_node.addPredicate(rdfs__label, att_name[ LANG.EN ], LANG.EN);

                        //						node.addPredicate(rdfs__subClassOf, restrictionId);

                        string description = att.get_str("description");

                        string[ string ] descr_els;
                        if (description.indexOf("$") >= 0)
                        {
                            string[] els = description.split(";");
                            foreach (el; els)
                            {
                                string[] el_els = el.split("=");
                                if (el_els.length == 2)
                                    descr_els[ el_els[ 0 ] ] = el_els[ 1 ];
                            }
                            //writeln(descr_els);
                        }

                        attr_node.addPredicate(ba__description, description);

                        string obligatory = att.get_str("obligatory");
                        if (obligatory == "true")
                            attr_node.addPredicate(owl__minCardinality, "1");

                        string multiSelect = att.get_str("multiSelect");
                        if (multiSelect == "false")
                            attr_node.addPredicate(owl__maxCardinality, "1");

                        string computationalReadonly = att.get_str("computationalReadonly");
                        if (computationalReadonly == "true")
                            attr_node.addPredicate(ba__readOnly, "true");

                        string type = att.get_str("type");

                        if (type == "BOOLEAN")
                        {
                            attr_node.addPredicate(owl__allValuesFrom, xsd__boolean);
                        }
                        else if (type == "TEXT" || type == "STRING")
                        {
                            if (value !is null && value.length > 0)
                                attr_node.addPredicate(docs__defaultValue, value);

                            attr_node.addPredicate(owl__allValuesFrom, xsd__string);
                        }
                        else if (type == "NUMBER")
                        {
                            attr_node.addPredicate(owl__allValuesFrom, xsd__decimal);
                        }
                        else if (type == "DATE")
                        {
                            attr_node.addPredicate(owl__allValuesFrom, xsd__dateTime);
                        }
                        else if (type == "FILE")
                        {
                            attr_node.addPredicate(owl__allValuesFrom, docs__FileDescription);
                        }
                        else if (type == "LINK" || type == "DICTIONARY")
                        {
                            string allValuesFrom;
                            string dc_identifier_val;

                            if (type == "LINK")
                            {
                                string isTable = descr_els.get("$isTable", null);
                                if (isTable !is null)
                                {
                                    allValuesFrom     = prefix_tmpl ~ isTable;
                                    dc_identifier_val = isTable;
                                }
                                else
                                    allValuesFrom = docs__Document;
                            }
                            else if (type == "DICTIONARY")
                            {
                                //docs__defaultValue
                                string dictionaryIdValue = att.get_str("dictionaryIdValue");
                                allValuesFrom     = prefix_tmpl ~ dictionaryIdValue;
                                dc_identifier_val = dictionaryIdValue;

                                string recordIdValue = att.get_str("recordIdValue");
                                if (recordIdValue !is null)
                                    attr_node.addPredicate(docs__defaultValue, prefix_doc ~ recordIdValue);

                                string dictionaryNameValue = att.get_str("dictionaryNameValue");
                                attr_node.addPredicate(rdfs__comment, dictionaryNameValue);
                            }

                            if (allValuesFrom !is null)
                                attr_node.addPredicate(owl__allValuesFrom, allValuesFrom);

                            string composition = descr_els.get("$composition", null);
                            if (composition !is null)
                            {
                                //								// writeln("composition=", composition);
                                string[] composition_els = composition.split("|");
                                foreach (el; composition_els)
                                {
                                    el = ba2user_onto(el);

                                    attr_node.addPredicate(link__importPredicates, el);
                                }
                            }
                            else
                            {
                                // композиция не заданна, берем представление по умолчанию у шаблона на который ссылаемся

                                if (dc_identifier_val !is null && dc_identifier_val.length > 3)
                                {
                                    //writeln("композиция не задана, берем представление по умолчанию у шаблона на который ссылаемся");
                                    DocTemplate _tmpl = getTemplate(dc_identifier_val, null, context);

                                    if (_tmpl !is null)
                                    {
                                        //									// writeln("шаблон найден");
                                        Predicate export_predicates = _tmpl.get_export_predicates();
                                        if (export_predicates !is null)
                                        {
                                            //										// writeln("import predicate", export_predicates);
                                            foreach (el; export_predicates.getObjects())
                                            {
                                                attr_node.addPredicate(link__importPredicates, el);
                                                //											// writeln("import predicate", el);
                                            }
                                        }

                                        //								export_predicates
                                    }
                                    else
                                    {
                                        log.trace(
                                                  "linked template [" ~ dc_identifier_val ~ "] not found [" ~ id ~ "][" ~ code ~ "]");
                                    }
                                }
                            }
                        }
                        else if (type == "ORGANIZATION")
                        {
                            string organizationTag = att.get_str("organizationTag");

                            if (organizationTag !is null && organizationTag.length > 3)
                            {
                                if (organizationTag.indexOf("user") >= 0)
                                {
                                    if (organizationTag.indexOf(";") > 0)
                                        attr_node.addPredicate(owl__someValuesFrom, swrc__Person);
                                    else
                                        attr_node.addPredicate(owl__allValuesFrom, swrc__Person);

                                    attr_node.addPredicate(link__exportPredicates, swrc__lastName);
                                    attr_node.addPredicate(link__exportPredicates, swrc__firstName);
                                    attr_node.addPredicate(link__exportPredicates, gost19__middleName);
                                }
                                if (organizationTag.indexOf("department") >= 0)
                                {
                                    attr_node.addPredicate(link__exportPredicates, swrc__name);

                                    if (organizationTag.indexOf(";") > 0)
                                        attr_node.addPredicate(owl__someValuesFrom, swrc__Department);
                                    else
                                        attr_node.addPredicate(owl__allValuesFrom, swrc__Department);
                                }

                                attr_node.addPredicate(ba__organizationTag, organizationTag);

                                //	пока не целесообразно раскладывать  organizationTag
                            }
                        }

                        if (actual == "1")
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
            if (actual == "1")
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
            bool   isOk;
            string reason;
            store_graphs(gcl_versioned.getArray, null, context, isOk, reason, false);

            if (actual == "1")
            {
                // store actual
                foreach (subject; gcl_actual.getArray)
                {
//					context.ts.removeSubject(subject.subject);
//					context.ts.storeSubject(subject, context);
                }
            }
        }
        else
        {
            //////////////////// D O C U M E N T ///////////////////////

            if (get_str(doc, "is-processed-links") == "N")
                is_processed_links = false;

            if (get_str(doc, "is-cached") == "Y")
                is_cached = true;

            log.trace("#1 id=%s", id);
            string typeId        = doc.get_str("typeId");
            string typeVersionId = doc.get_str("typeVersionId");
            //// writeln ("typeId=", typeId);
            //// writeln ("typeVersionId=", typeVersionId);
            DocTemplate tmplate = getTemplate(typeId, typeVersionId, context);

            if (tmplate !is null)
            {
                //				Subject tmpl_class = tmplate.data.find_subject(rdf__type, rdfs__Class);
                Subject tmpl_class = tmplate.main;

                if (tmpl_class is null)
                {
                    log.trace("документ doc:" ~ id ~ ", не достаточно данных о шаблоне(классе)");
                }
                else
                {
                    log.trace("#2 tmpl_class=%s", tmpl_class);
                    DocTemplate basic_doc_class = getTemplate(null, null, context, docs__Document);

                    subj_versioned_UID = prefix_doc ~ c_id ~ "_" ~ c_vid;
                    subj_UID           = prefix_doc ~ id;

                    node.subject = subj_versioned_UID;
                    node.addPredicate(rdf__type, docs__Document);
                    node.addPredicate(dc__identifier, id);
                    node.exportPredicates = tmplate.get_export_predicates();
                    node.docTemplate      = tmplate.main;
                    node.addPredicate(ba__doctype, objectType);

                    Predicate import_predicate;
                    Subject   _reif;
                    if (is_processed_links == true)
                    {
                        _reif = get_reification_subject_of_link(subj_versioned_UID, dc__creator, prefix_doc ~ authorId,
                                                                context, doc_cache, import_predicate);
                        //writeln ("#3.2.1 _reif=", _reif);
                    }
                    node.addPredicate(dc__creator, prefix_doc ~ authorId, null, _reif);

                    if (lastEditorId !is null)
                    {
                        if (is_processed_links == true)
                        {
                            _reif = get_reification_subject_of_link(subj_versioned_UID, docs__modifier,
                                                                    prefix_doc ~ lastEditorId, context, doc_cache, import_predicate);
                            //writeln ("#3.2.1 _reif=", _reif);
                        }
                        node.addPredicate(docs__modifier, prefix_doc ~ lastEditorId, null, _reif);
                    }

//					if(authorId == "DICTIONARY")
//					{
//						writeln("docid=", id);
//						writeln("pause 100s");
//						core.thread.Thread.sleep(dur!("seconds")(100));
//					}

                    log.trace("#3.3");
                    if (dateCreated != null)
                    {
                        Subject metadata_dc_created;
                        if (basic_doc_class !is null)
                        {
                            metadata_dc_created = basic_doc_class.data.find_subject(owl__onProperty, dc__created);
                        }

                        node.addPredicate(dc__created, dateCreated, metadata_dc_created, null);
                    }
                    log.trace("#3.4");
                    if (dateLastModified != null)
                        node.addPredicate(dc__modified, dateLastModified);

                    node.addPredicate(rdf__type, tmpl_class.subject);

                    // writeln ("#1 ", tmpl_class.subject);
                    // writeln ("#2 ", prefix_tmpl ~ tmpl_class.getFirstLiteral(dc__identifier));

                    node.addPredicate(class__identifier, tmpl_class.getFirstLiteral(dc__identifier));
                    node.addPredicate(class__version, tmpl_class.getFirstLiteral(docs__version));
                    node.addPredicate(docs__label, tmpl_class.getObjects(rdfs__label));

                    JSONValue[] attributes;

                    if (active == "1")
                        node.addPredicate(docs__active, "true");
                    else
                        node.addPredicate(docs__active, "false");

                    // writeln ("#4 doc.object=", doc.object);
                    if (("attributes" in doc.object) !is null)
                    {
                        attributes = doc.object[ "attributes" ].array;

                        // writeln ("#5.0 doc.object['attributes'].array=", doc.object["attributes"].array);
                        if (attributes !is null)
                        {
                            foreach (att; attributes)
                            {
                                // writeln ("#5.1");
                                string      code   = att.object[ "code" ].str;
                                JSONValue[] values = get_array(att, "values");

                                // writeln ("#5 code=", code);
                                // writeln ("#5 value=", value);

                                if (values !is null && values.length > 0)
                                {
                                    //writeln ("#6");
                                    string new_code = ba2user_onto(code);
                                    //writeln("\r\n\r\ndoc:[" ~ code ~ "]->[" ~ new_code ~ "] = ", value);

                                    Subject metadata = tmplate.data.find_subject(owl__onProperty, new_code);
                                    Subject reif;

                                    string  type        = att.get_str("type");
                                    string  description = att.get_str("description");
                                    string[ string ] descr_els;
                                    if (description !is null)
                                    {
                                        if (description.indexOf("$") >= 0)
                                        {
                                            string[] els = description.split(";");
                                            foreach (el; els)
                                            {
                                                string[] el_els = el.split("=");
                                                if (el_els.length == 2)
                                                    descr_els[ el_els[ 0 ] ] = el_els[ 1 ];
                                            }
                                            //// writeln(descr_els);
                                        }
                                    }

                                    foreach (el; values)
                                    {
                                        string value = get_str(el, "value");
                                        if (metadata !is null)
                                        {
                                            //writeln ("#7 metadata=", metadata);

                                            if ((type == "LINK" || type == "ORGANIZATION" || type == "DICTIONARY"))
                                            {
                                                value = prefix_doc ~ value;
                                                if (is_processed_links == true)
                                                {
                                                    reif = get_reification_subject_of_link(subj_versioned_UID, new_code, value,
                                                                                           context, doc_cache, import_predicate, metadata.getPredicate(
                                                                                                                                                       link__exportPredicates));

                                                    if (reif is null)
                                                        log.trace("doc[%s], linked field [%s:%s]=%s not found", id, new_code, type,
                                                                  value);
                                                }
                                                node.addPredicate(new_code, value, metadata, reif);
                                            }
                                            else if (type == "TEXT" || type == "STRING")
                                            {
                                                string att_name[ 3 ] = split_lang(value);

                                                if (att_name[ LANG.RU ] !is null)
                                                    node.addPredicate(new_code, att_name[ LANG.RU ], metadata, reif, LANG.RU);
                                                else if (att_name[ LANG.EN ] !is null)
                                                    node.addPredicate(new_code, att_name[ LANG.EN ], metadata, reif, LANG.EN);

                                                if (att_name[ LANG.RU ] is null && att_name[ LANG.EN ] is null)
                                                    node.addPredicate(new_code, value, metadata, reif, LANG.RU);
                                            }
                                            else
                                            {
                                                node.addPredicate(new_code, value, metadata, reif);
                                            }
                                        }
                                        else
                                        {
                                            node.addPredicate(new_code, value, metadata, reif);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            else
            {
                log.trace("для документа doc:" ~ id ~ ", не найден шаблон(класс)");
                //		// writeln ("pause 20s");
                //	core.thread.Thread.sleep(dur!("seconds")(20));
            }
            //writeln ("#13");

            if (actual == "1")
            {
                actual_node = node.dup();
                actual_node.addPredicate(docs__actual, "true");
                actual_node.subject = subj_UID;
            }

            node.addPredicate(docs__version, versionId);

            //		OutBuffer outbuff = new OutBuffer();
            //		toJson_ld(gcl_versioned.graphs_of_subject.values, outbuff);
            //		outbuff.write(0);
            //		ubyte[] bb = outbuff.toBytes();
            //		log.trace_io(false, cast(byte*) bb, bb.length);

            // store versioned
            bool   isOk;
            string reason;

            if (is_cached == false)
                store_graph(node, null, context, isOk, reason, false);

            if (actual == "1")
            {
                if (is_cached == false)
                    store_graph(actual_node, null, context, isOk, reason, false);
                if (is_cached == true)
                    doc_cache[ actual_node.subject ] = actual_node;
            }

            //			writeln ("pause 10s");
            //			core.thread.Thread.sleep(dur!("seconds")(10));
        }

        log.trace("ba2pacahon, count:%d", ++count);
        //		// writeln ("pause 20s");
        //		core.thread.Thread.sleep(dur!("seconds")(20));
    }
    catch (Exception ex)
    {
        writeln("Ex:" ~ ex.msg);
    }
}

static string ba2user_onto(string code)
{
    if (code.indexOf(":") > 0)
        return code;

    return "uo:" ~ toTranslit(code);
}

static string[ 3 ] split_lang(string src)
{
    string res[ 3 ];
    // пример: "@ru@ru{Аудит ОВА}@@en{Audit}@"
    long   pos = src.indexOf("@ru@ru{");

    if (pos >= 0 && pos < 4)
    {
        string[] name_els = split(src, "@");

        foreach (el; name_els)
        {
            if (el.length > 3)
            {
                if (el[ 0 ] == 'r' && el[ 1 ] == 'u' && el[ 2 ] == '{')
                {
                    res[ LANG.RU ] = el[ 3 .. $ - 1 ];
                }
                else if (el[ 0 ] == 'e' && el[ 1 ] == 'n' && el[ 2 ] == '{')
                {
                    res[ LANG.EN ] = el[ 3 .. $ - 1 ];
                }
            }
        }
    }
    else
    {
        res[ LANG.RU ] = src;
    }
    return res;
}
