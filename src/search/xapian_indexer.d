//////////////////////////////////////////// USE XAPIAN SEARCH ///////////////////////////////////////////////////////////////

module search.xapian_indexer;

import std.concurrency, std.outbuffer, std.datetime, std.conv, std.typecons, std.stdio, std.string, std.file;

import bind.xapian_d_header;
import util.utils;
import util.cbor;
import util.cbor8individual;
import util.logger;

import onto.resource;
import onto.lang;
import onto.individual;

import pacahon.define;
import pacahon.know_predicates;
import pacahon.context;
import pacahon.log_msg;
import search.vel;
import search.xapian_vql;

//////// logger ///////////////////////////////////////////
import util.logger;
logger _log;
logger log()
{
    if (_log is null)
        _log = new logger("pacahon", "log", "search");
    return _log;
}
//////// ////// ///////////////////////////////////////////

byte err;

public void xapian_thread_context(string thread_name)
{
    core.thread.Thread.getThis().name = thread_name;

    string key2slot_str;
    long   last_update_time;

//    writeln("SPAWN: xapian_thread_io");
    last_update_time = Clock.currTime().stdTime();

    // SEND ready
    receive((Tid tid_response_reciever)
            {
                send(tid_response_reciever, true);
            });
    while (true)
    {
        receive(
                (CMD cmd, CNAME cname, string _key2slot_str)
                {
                    if (cmd == CMD.PUT)
                    {
                        if (cname == CNAME.LAST_UPDATE_TIME)
                        {
                            last_update_time = Clock.currTime().stdTime() / 10000;
                        }
                    }
                },
                (CMD cmd, CNAME cname, Tid tid_sender)
                {
                    if (cmd == CMD.GET)
                    {
                        if (cname == CNAME.LAST_UPDATE_TIME)
                        {
                            //writeln ("GET:\n", last_update_time, ");
                            send(tid_sender, last_update_time);
                        }
                    }
                }, (Variant v) { writeln(thread_name, "::Received some other type.", v); });
    }
}

private void store__key2slot(ref int[ string ] key2slot, Tid tid_subject_manager)
{
//	writeln ("#1 store__key2slot");
    string data = serialize_key2slot(key2slot);

    send(tid_subject_manager, CMD.PUT_KEY2SLOT, xapian_metadata_doc_id, data);
}

private int[ string ] read_key2slot(Tid tid_subject_manager)
{
    int[ string ] key2slot;

    send(tid_subject_manager, CMD.FIND, xapian_metadata_doc_id, thisTid);
    receive((string key, string data, Tid tid)
            {
//    writeln ("@KEY@SLOT=", data);
                key2slot = deserialize_key2slot(data);
            });

//    writeln("slot size=", key2slot.length);
    return key2slot;
}

private void printTid(string tag)
{
    writefln("%s: %s, address: %s", tag, thisTid, &thisTid);
}


void xapian_indexer(string thread_name, Tid tid_subject_manager, Tid tid_acl_manager, Tid key2slot_accumulator)
{
    core.thread.Thread.getThis().name = thread_name;

    try
    {
        mkdir("data");
    }
    catch (Exception ex)
    {
    }

    try
    {
        mkdir(xapian_search_db_path);
    }
    catch (Exception ex)
    {
    }

    ///////////// XAPIAN INDEXER ///////////////////////////
    XapianWritableDatabase indexer_db;
    XapianTermGenerator    indexer;
    string                 lang    = "russian";
    XapianStem             stemmer = new_Stem(cast(char *)lang, lang.length, &err);

    string                 dummy;
    double                 d_dummy;

    bool                   is_exist_db = exists(xapian_search_db_path);

    // Open the database for update, creating a new database if necessary.
    indexer_db = new_WritableDatabase(xapian_search_db_path.ptr, xapian_search_db_path.length, DB_CREATE_OR_OPEN, &err);
//    indexer_db = new_InMemoryWritableDatabase(&err);
    if (err != 0)
    {
        writeln("!!!!!!! Err in new_WritableDatabase, err=", err);
        return;
    }

    indexer = new_TermGenerator(&err);
    indexer.set_stemmer(stemmer, &err);

    indexer_db.commit(&err);

    XapianEnquire     xapian_enquire = indexer_db.new_Enquire(&err);
    XapianQueryParser xapian_qp      = new_QueryParser(&err);
    xapian_qp.set_stemmer(stemmer, &err);
    xapian_qp.set_database(indexer_db, &err);

    int   counter                         = 0;
    int   last_counter_after_timed_commit = 0;
    ulong last_size_key2slot              = 0;

    int[ string ] key2slot;

    //if (is_exist_db == true)
    key2slot = read_key2slot(tid_subject_manager);

    // SEND ready
    receive((Tid tid_response_reciever)
            {
                send(tid_response_reciever, true);
            });

    while (true)
    {
        receive(
                /*(CMD cmd, string str_query, string str_fields, string sort, int count_authorize, Tid tid_sender)
                   {
                   //writeln (cast(void*)indexer_db, " @0 cmd=", cmd, ", str_query: ", str_query);
                   //writeln ("@xapian_indexer:key2slot=", key2slot);
                   if (cmd == CMD.FIND)
                   {
                   auto fields = get_fields(str_fields);

                   XapianQuery query;
                   TTA tta = parse_expr(str_query);
                   transform_vql_to_xapian(tta, "", dummy, dummy, query, key2slot, d_dummy, 0, xapian_qp);

                   if (query !is null)
                   {
                    int count = 0;
                    xapian_enquire = indexer_db.new_Enquire(&err);

                    XapianMultiValueKeyMaker sorter = get_sorter(sort, key2slot);

                    void delegate(string uri) dg;
                    void collect_subject(string uri)
                    {
                        send(tid_sender, CMD.PUT, msg);
                    }
                    dg = &collect_subject;

                    int state = -1;
                    while (state == -1)
                    {
                        state =
                            exec_xapian_query_and_queue_authorize(null, query, sorter, xapian_enquire, count_authorize, fields, dg,
                                                                  tid_subject_manager,
                                                                  tid_acl_manager);
                        if (state == -1)
                        {
                            writeln("@2 ERR state=", state);
                            xapian_enquire = indexer_db.new_Enquire(&err);
                        }
                    }

                    destroy_Enquire(xapian_enquire);
                    destroy_Query(query);
                    destroy_MultiValueKeyMaker(sorter);
                   }

                   send(tid_sender, CMD.END_DATA);
                   }
                   }, */
                (CMD cmd, string msg, Tid tid_response_reciever)
                {
                    if (key2slot.length - last_size_key2slot > 0)
                    {
                        store__key2slot(key2slot, tid_subject_manager);
                        if (trace_msg[ 210 ] == 1)
                            log.trace("store__key2slot #1");
                        last_size_key2slot = key2slot.length;
                    }
                    indexer_db.commit(&err);

                	if (cmd == CMD.BACKUP)
                	{                		
                	string new_path_backup_xapian = dbs_backup ~ "/" ~ msg ~ "/" ~ "xapian-search";

                	try
                	{
                		mkdir(new_path_backup_xapian);
                	}
                	catch (Exception ex)
                	{
                		writeln ("ex!", ex.msg);
                	}
                		
                		try
                		{
                		auto oFiles = dirEntries(xapian_search_db_path, "*.*", SpanMode.depth);
                		foreach (o; oFiles)
                		{
                			string new_path;
                			string tt[] = o.name.split ("/");
                			if (tt.length > 1)
                				new_path = tt[$-1];
                			else 	 
                				new_path = o.name;
                				
                			new_path = new_path_backup_xapian ~ "/" ~ new_path; 
                				
                			//writeln ("COPY TO:", new_path);
                			copy (o.name, new_path); 
                			//writeln ("OK");
                		}       
                		}
                		catch (Exception ex)
                		{
                			writeln ("ex!", ex.msg);
                			send(tid_response_reciever, "");
                		}         		        
                	}
                	
                    send(tid_response_reciever, msg);
                },
                (CMD cmd, Tid tid_response_reciever)
                {
                    // если ожидают окончания операции для indexer, то вероятнее всего собираются сразу-же читать из поиска
                    // следовательно нужно сделать коммит
                    if (key2slot.length - last_size_key2slot > 0)
                    {
                        store__key2slot(key2slot, tid_subject_manager);
                        if (trace_msg[ 210 ] == 1)
                            log.trace("store__key2slot #2");
                        last_size_key2slot = key2slot.length;
                    }
                    indexer_db.commit(&err);


                    if (cmd == CMD.NOP)
                        send(tid_response_reciever, true);
                    else
                        send(tid_response_reciever, false);
                },
                (CMD cmd, string msg)
                {
                    //writeln (cast(void*)indexer_db, " @1 cmd=", cmd, ", msg: ", msg);
                    if (cmd == CMD.COMMIT)
                    {
                        //writeln ("@@ COMMIT");

                        if (counter - last_counter_after_timed_commit > 0)
                        {
                            if (trace_msg[ 210 ] == 1)
                                log.trace("counter: %d, timer: commit index..", counter);
                            if (key2slot.length - last_size_key2slot > 0)
                            {
                                store__key2slot(key2slot, tid_subject_manager);
                                if (trace_msg[ 210 ] == 1)
                                    log.trace("store__key2slot");
                                last_size_key2slot = key2slot.length;
                            }

                            indexer_db.commit(&err);
//                            printf("ok\n");

                            //indexer_db.close (&err);
                            //indexer_db = new_WritableDatabase(xapian_search_db_path.ptr, xapian_search_db_path.length, DB_CREATE_OR_OPEN, &err);
                            last_counter_after_timed_commit = counter;
                            send(key2slot_accumulator, CMD.PUT, CNAME.LAST_UPDATE_TIME, "");
                        }
                    }
                    else
                    {
                        counter++;

                        Individual ss;

                        cbor2individual(&ss, msg);

                        //writeln("prepare msg counter:", counter, ", subject:", ss.subject);

                        if (ss.uri !is null && ss.resources.length > 0)
                        {
                            OutBuffer all_text = new OutBuffer();

                            XapianDocument doc = new_Document(&err);
                            indexer.set_document(doc, &err);

                            if (trace_msg[ 220 ] == 1)
                                log.trace("index document:[%s]", ss.uri);

                            foreach (predicate, resources; ss.resources)
                            {
                                string prefix;
                                int slot = get_slot_and_set_if_not_found(predicate, key2slot);

                                //all_text.write(escaping_or_uuid2search(pp.predicate));
                                //all_text.write('|');

                                string type = "xsd__string";

//                                if (pp.metadata !is null)
//                                {
//                                    type = pp.metadata.getFirstLiteral(owl__allValuesFrom);
//                                    pp.metadata = null;
//                                }

                                //writeln (pp.predicate, ".type:", type);

                                string p_text_ru = "";
                                string p_text_en = "";

                                foreach (oo; resources)
                                {
                                    if (oo.type == DataType.String)
                                    {
                                        if (resources.length > 1)
                                        {
                                            if (oo.lang == LANG.RU)
                                                p_text_ru ~= oo.literal;
                                            if (oo.lang == LANG.EN)
                                                p_text_en ~= oo.literal;
                                        }

                                        int slot_L1 = get_slot_and_set_if_not_found(predicate, key2slot);
                                        prefix = "X" ~ text(slot_L1) ~ "X";

                                        string data = escaping_or_uuid2search(oo.literal);

                                        if (trace_msg[ 220 ] == 1)
                                            log.trace("index as literal:[%s], lang=%s, prefix=%s", data, oo.lang, prefix);

                                        indexer.index_text(data.ptr, data.length, prefix.ptr, prefix.length, &err);
                                        doc.add_value(slot_L1, oo.literal.ptr, oo.literal.length, &err);

                                        all_text.write(data);
                                        all_text.write('|');
                                    }
                                    else if (oo.type == DataType.Uri)
                                    {
                                        if (oo.literal is null)
                                        {
                                        }
                                        else
                                        {
                                            int slot_L1 = get_slot_and_set_if_not_found(predicate, key2slot);
                                            prefix = "X" ~ text(slot_L1) ~ "X";

                                            string data = to_lower_and_replace_delimeters(oo.literal);

                                            if (trace_msg[ 220 ] == 1)
                                                log.trace("index as resource:[%s], prefix=%s", data, prefix);
                                            indexer.index_text(data.ptr, data.length, prefix.ptr, prefix.length, &err);

                                            doc.add_value(slot_L1, oo.literal.ptr, oo.literal.length, &err);

                                            all_text.write(data);
                                            all_text.write('|');
                                        }
                                    }
                                }

                                if (resources.length > 1)
                                {
                                    if (p_text_ru.length > 0)
                                    {
                                        int slot_L1 = get_slot_and_set_if_not_found(predicate ~ "_ru", key2slot);
                                        prefix = "X" ~ text(slot_L1) ~ "X";

                                        indexer.index_text(p_text_ru.ptr, p_text_ru.length, prefix.ptr, prefix.length, &err);

                                        if (trace_msg[ 220 ] == 1)
                                            log.trace("index as ru text:[%s]", p_text_ru);

                                        doc.add_value(slot_L1, p_text_ru.ptr, p_text_ru.length, &err);
                                        //writeln ("slot:", slot_L1, ", value:", p_text_ru);
                                    }

                                    if (p_text_en.length > 0)
                                    {
                                        int slot_L1 = get_slot_and_set_if_not_found(predicate ~ "_en", key2slot);
                                        prefix = "X" ~ text(slot_L1) ~ "X";

                                        indexer.index_text(p_text_en.ptr, p_text_en.length, prefix.ptr, prefix.length, &err);

                                        if (trace_msg[ 220 ] == 1)
                                            log.trace("index as en text:[%s]", p_text_en);

                                        doc.add_value(slot_L1, p_text_en.ptr, p_text_en.length, &err);
                                        //writeln ("slot:", slot_L1, ", value:", p_text_en);
                                    }
                                }

                                int slot_L1;

                                if (type == xsd__string)
                                {
                                    bool sp = true;
                                    foreach (oo; resources)
                                    {
                                        if (oo.type == DataType.String && (oo.lang == LANG.RU || oo.lang == LANG.NONE))
                                        {
                                            if (sp == true)
                                            {
                                                slot_L1 = get_slot_and_set_if_not_found(predicate ~ ".text_ru", key2slot);
                                                prefix = "X" ~ text(slot_L1) ~ "X";

                                                sp = false;
                                            }

                                            doc.add_value(slot_L1, oo.literal.ptr, oo.literal.length, &err);
                                            indexer.index_text(oo.literal.ptr, oo.literal.length, prefix.ptr, prefix.length, &err);

                                            if (trace_msg[ 220 ] == 1)
                                                log.trace("index as (ru or none) xsd:string [%s]", oo.literal);

                                            all_text.write(oo.literal);
                                            all_text.write('|');

                                            //writeln ("slot:", slot_L1, ", value:", oo.literal);
                                        }
                                    }

                                    sp = true;
                                    foreach (oo; resources)
                                    {
                                        if (oo.type == DataType.String && oo.lang == LANG.EN)
                                        {
                                            if (sp == true)
                                            {
                                                slot_L1 = get_slot_and_set_if_not_found(predicate ~ ".text_en", key2slot);
                                                prefix = "X" ~ text(slot_L1) ~ "X";

                                                sp = false;
                                            }

                                            doc.add_value(slot_L1, oo.literal.ptr, oo.literal.length, &err);
                                            indexer.index_text(oo.literal.ptr, oo.literal.length, prefix.ptr, prefix.length, &err);

                                            if (trace_msg[ 220 ] == 1)
                                                log.trace("index as (en) xsd:string [%s]", oo.literal);

                                            all_text.write(oo.literal);
                                            all_text.write('|');
                                            //writeln ("slot:", slot_L1, ", value:", oo.literal);
                                        }
                                    }
                                }
                                else if (type == xsd__decimal)
                                {
                                    slot_L1 = get_slot_and_set_if_not_found(predicate ~ ".decimal", key2slot);
                                    prefix = "X" ~ text(slot_L1) ~ "X";

                                    foreach (oo; resources)
                                    {
                                        if (oo.type == DataType.String)
                                        {
                                            double data = to!double (oo.literal);
                                            doc.add_value(slot_L1, data, &err);
                                            all_text.write(oo.literal);
                                            all_text.write('|');

                                            indexer.index_data(data, prefix.ptr, prefix.length, &err);
                                        }
                                    }
                                }
                                else if (type == xsd__dateTime)
                                {
                                    slot_L1 = get_slot_and_set_if_not_found(predicate ~ ".dateTime", key2slot);
                                    prefix = "X" ~ text(slot_L1) ~ "X";

                                    foreach (oo; resources)
                                    {
                                        if (oo.type == DataType.String)
                                        {
                                            long data = stringToTime(oo.literal);
                                            doc.add_value(slot_L1, data, &err);
                                            all_text.write(oo.literal);
                                            all_text.write('|');

                                            indexer.index_data(data, prefix.ptr, prefix.length, &err);
                                        }
                                    }
                                }
                                else
                                {
                                    //writeln ("not type for:", pp.predicate);
                                }
                            }
                            string data = all_text.toString;
                            //writeln("@index = ", data);
                            indexer.index_text(data.ptr, data.length, &err);
                            if (trace_msg[ 221 ] == 1)
                                log.trace("index all text [%s]", data);

                            string uuid = "uid_" ~ to_lower_and_replace_delimeters(ss.uri);
                            doc.add_boolean_term(uuid.ptr, uuid.length, &err);
                            doc.set_data(ss.uri.ptr, ss.uri.length, &err);

                            indexer_db.replace_document(uuid.ptr, uuid.length, doc, &err);

                            if (counter % 100 == 0)
                            {
                                if (trace_msg[ 211 ] == 1)
                                    log.trace("prepare msg counter:%d,slot size=%d", counter, key2slot.length);
                            }

                            if (counter % 5000 == 0)
                            {
                                if (trace_msg[ 212 ] == 1)
                                    log.trace("commit index..");

                                if (key2slot.length > 0)
                                    store__key2slot(key2slot, tid_subject_manager);

                                indexer_db.commit(&err);
                            }

                            destroy_Document(doc);
                        }
                    }
                },
                (CMD cmd, int arg, bool arg2)
                {
                    if (cmd == CMD.SET_TRACE)
                        set_trace(arg, arg2);
                },
                (Variant v) { writeln(thread_name, "::Received some other type.", v); });
    }
}

private int get_slot_and_set_if_not_found(string field, ref int[ string ] key2slot)
{
//	writeln ("get_slot:", field);
    int slot = key2slot.get(field, -1);

    if (slot == -1)
    {
        // create new slot
        slot              = cast(int)key2slot.length + 1;
        key2slot[ field ] = slot;
//        send (key2slot_accumulator, PUT, data);
    }

    return slot;
}


