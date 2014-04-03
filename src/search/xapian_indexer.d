//////////////////////////////////////////// USE XAPIAN SEARCH ///////////////////////////////////////////////////////////////

module search.xapian_indexer;

import std.concurrency, std.outbuffer, std.datetime, std.conv, std.typecons, std.stdio, std.string, std.file;

import bind.xapian_d_header;
import util.utils;
import util.cbor;
import util.cbor8sgraph;

import onto.resource;
import onto.lang;
import onto.sgraph;

import pacahon.define;
import pacahon.know_predicates;
import pacahon.context;
import search.vel;
import search.xapian_vql;

byte err;

public void xapian_thread_context()
{
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
                        if (cname == CNAME.KEY2SLOT)
                        {
//                          writeln ("PUT:\n", _key2slot_str);
                            key2slot_str = _key2slot_str;
                        }
                        else if (cname == CNAME.LAST_UPDATE_TIME)
                        {
                            last_update_time = Clock.currTime().stdTime() / 10000;
                        }
                    }
                },
                (CMD cmd, CNAME cname, Tid tid_sender)
                {
                    if (cmd == CMD.GET)
                    {
                        if (cname == CNAME.KEY2SLOT)
                        {
                            //writeln ("GET:\n", key2slot_str);
                            send(tid_sender, key2slot_str);
                        }
                        else if (cname == CNAME.LAST_UPDATE_TIME)
                        {
                            //writeln ("GET:\n", last_update_time, ");
                            send(tid_sender, last_update_time);
                        }
                    }
                });
    }
}

private void store__key2slot(ref int[ string ] key2slot, ref XapianWritableDatabase indexer_db, ref XapianTermGenerator indexer,
                             Tid tid_xapian_thread_io)
{
//	writeln ("#1 store__key2slot");
    string         data = serialize_key2slot(key2slot);

    XapianDocument doc = new_Document(&err);

    indexer.set_document(doc, &err);

    doc.set_data(data.ptr, data.length, &err);
    string uuid = xapian_metadata_doc_id;
    indexer.index_text(uuid.ptr, uuid.length, &err);
    doc.add_boolean_term(uuid.ptr, uuid.length, &err);
    indexer_db.replace_document(uuid.ptr, uuid.length, doc, &err);
    destroy_Document(doc);

    send(tid_xapian_thread_io, CMD.PUT, CNAME.KEY2SLOT, data);
}

private int[ string ] read_key2slot(XapianWritableDatabase db, XapianQueryParser qp, XapianEnquire enquire, Tid tid_xapian_thread_io)
{
    int[ string ] key2slot;
    string      query_string = xapian_metadata_doc_id;

    XapianQuery query = qp.parse_query(cast(char *)query_string, query_string.length, &err);

    enquire.set_query(query, &err);

    XapianMSet matches = enquire.get_mset(0, 1, &err);

    //writeln("found =", matches.get_matches_estimated(&err));
    //writeln("matches =", matches.size(&err));

    XapianMSetIterator it = matches.iterator(&err);

    if (it.is_next(&err) == true)
    {
        //      writeln ("#15 id=[", it.get_documentid(), "]");
        XapianDocument doc = it.get_document(&err);

        char           *data_str;
        uint           *data_len;
        doc.get_data(&data_str, &data_len, &err);
        string         data = cast(immutable)data_str[ 0..(*data_len) ].dup;
        send(tid_xapian_thread_io, CMD.PUT, CNAME.KEY2SLOT, data);
        //writeln ("data=[", data, "]");

        key2slot = deserialize_key2slot(data);
    }

    //writeln("slot size=", key2slot.length);
    return key2slot;
}

private void printTid(string tag)
{
    writefln("%s: %s, address: %s", tag, thisTid, &thisTid);
}

void xapian_indexer_commiter(Tid tid)
{
    // SEND ready
    receive((Tid tid_response_reciever)
            {
                send(tid_response_reciever, true);
            });

    while (true)
    {
        core.thread.Thread.sleep(dur!("seconds")(20));
        send(tid, CMD.COMMIT, "");
    }
}

//		foreach (key, value; key2slot)
//		{
//			string field = translate (key, transTable1);
/*
                        string[] fff = split (field, ".");
                        if (fff.length == 2)
                        {
                                if (fff[1] == "decimal" || fff[1] == "dateTime")
                                {
                                        string str = field ~ "_range:";

                                XapianNumberValueRangeProcessor vrp_num = new_NumberValueRangeProcessor (value, cast (const char *)str, str.length, true);
                                xapian_qp.add_valuerangeprocessor(vrp_num);
                                }
                        }
 */
//			string prefix = "X" ~ text (value) ~ "X";
//			writeln (field, " -> ", prefix);
//			xapian_qp.add_prefix (cast(char*)field, field.length, cast(char*)prefix, prefix.length);
//		}
void xapian_indexer(Tid tid_subject_manager, Tid tid_acl_manager, Tid key2slot_accumulator)
{
//    writeln("SPAWN: Xapian Indexer");

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
    key2slot = read_key2slot(indexer_db, xapian_qp, xapian_enquire, key2slot_accumulator);

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
                (CMD cmd, string msg)
                {
                    //writeln (cast(void*)indexer_db, " @1 cmd=", cmd, ", msg: ", msg);
                    if (cmd == CMD.COMMIT)
                    {
                        //writeln ("@@ COMMIT");

                        if (counter - last_counter_after_timed_commit > 0)
                        {
                            printf("counter: %d, timer: commit index..\n", counter);
                            if (key2slot.length - last_size_key2slot > 0)
                            {
                                store__key2slot(key2slot, indexer_db, indexer, key2slot_accumulator);
                                printf("..store__key2slot..\n");
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

                        Subject ss = cbor2subject(msg);

                        //writeln("prepare msg counter:", counter, ", subject:", ss.subject);

                        if (ss.subject !is null && ss.count_edges > 0)
                        {
                            OutBuffer all_text = new OutBuffer();

                            XapianDocument doc = new_Document(&err);
                            indexer.set_document(doc, &err);

                            foreach (pp; ss.getPredicates())
                            {
                                string prefix;
                                int slot = get_slot_and_set_if_not_found(pp.predicate, key2slot);

                                //all_text.write(escaping_or_uuid2search(pp.predicate));
                                //all_text.write('|');

                                string type = "?";

                                if (pp.metadata !is null)
                                {
                                    type = pp.metadata.getFirstLiteral(owl__allValuesFrom);
                                    pp.metadata = null;
                                }

                                //writeln (pp.predicate, ".type:", type);

                                string p_text_ru = "";
                                string p_text_en = "";

                                foreach (oo; pp.getObjects())
                                {
                                    if (oo.type == OBJECT_TYPE.TEXT_STRING)
                                    {
                                        if (pp.count_objects > 1)
                                        {
                                            if (oo.lang == LANG.RU)
                                                p_text_ru ~= oo.literal;
                                            if (oo.lang == LANG.EN)
                                                p_text_en ~= oo.literal;
                                        }

                                        int slot_L1 = get_slot_and_set_if_not_found(pp.predicate, key2slot);
                                        prefix = "X" ~ text(slot_L1) ~ "X";

                                        string data = escaping_or_uuid2search(oo.literal);

//                          writeln ("index as literal:[", data, "], lang=", oo.lang);
                                        indexer.index_text(data.ptr, data.length, prefix.ptr, prefix.length, &err);
                                        doc.add_value(slot_L1, oo.literal.ptr, oo.literal.length, &err);

                                        all_text.write(data);
                                        all_text.write('|');
                                    }
                                    else if (oo.type == OBJECT_TYPE.URI)
                                    {
                                        if (oo.literal is null)
                                        {
                                        }
                                        else
                                        {
                                            int slot_L1 = get_slot_and_set_if_not_found(pp.predicate, key2slot);
                                            prefix = "X" ~ text(slot_L1) ~ "X";

                                            string data = to_lower_and_replace_delimeters(oo.literal);
//                                writeln ("index as resource:[", data, "]");
                                            indexer.index_text(data.ptr, data.length, prefix.ptr, prefix.length, &err);
                                            doc.add_value(slot_L1, oo.literal.ptr, oo.literal.length, &err);

                                            all_text.write(data);
                                            all_text.write('|');
                                        }
                                    }
                                }

                                if (pp.count_objects > 1)
                                {
                                    if (p_text_ru.length > 0)
                                    {
                                        int slot_L1 = get_slot_and_set_if_not_found(pp.predicate ~ "_ru", key2slot);
                                        prefix = "X" ~ text(slot_L1) ~ "X";

                                        indexer.index_text(p_text_ru.ptr, p_text_ru.length, prefix.ptr, prefix.length, &err);
                                        doc.add_value(slot_L1, p_text_ru.ptr, p_text_ru.length, &err);
                                        //writeln ("slot:", slot_L1, ", value:", p_text_ru);
                                    }

                                    if (p_text_en.length > 0)
                                    {
                                        int slot_L1 = get_slot_and_set_if_not_found(pp.predicate ~ "_en", key2slot);
                                        prefix = "X" ~ text(slot_L1) ~ "X";

                                        indexer.index_text(p_text_en.ptr, p_text_en.length, prefix.ptr, prefix.length, &err);
                                        doc.add_value(slot_L1, p_text_en.ptr, p_text_en.length, &err);
                                        //writeln ("slot:", slot_L1, ", value:", p_text_en);
                                    }
                                }

                                int slot_L1;

                                if (type == xsd__string)
                                {
                                    bool sp = true;
                                    foreach (oo; pp.getObjects())
                                    {
                                        if (oo.type == OBJECT_TYPE.TEXT_STRING && (oo.lang == LANG.RU || oo.lang == LANG.NONE))
                                        {
                                            if (sp == true)
                                            {
                                                slot_L1 = get_slot_and_set_if_not_found(pp.predicate ~ ".text_ru", key2slot);
                                                prefix = "X" ~ text(slot_L1) ~ "X";

                                                sp = false;
                                            }

                                            doc.add_value(slot_L1, oo.literal.ptr, oo.literal.length, &err);
                                            indexer.index_text(oo.literal.ptr, oo.literal.length, prefix.ptr, prefix.length, &err);

                                            all_text.write(oo.literal);
                                            all_text.write('|');

                                            //writeln ("slot:", slot_L1, ", value:", oo.literal);
                                        }
                                    }

                                    sp = true;
                                    foreach (oo; pp.getObjects())
                                    {
                                        if (oo.type == OBJECT_TYPE.TEXT_STRING && (oo.lang == LANG.EN))
                                        {
                                            if (sp == true)
                                            {
                                                slot_L1 = get_slot_and_set_if_not_found(pp.predicate ~ ".text_en", key2slot);
                                                prefix = "X" ~ text(slot_L1) ~ "X";

                                                sp = false;
                                            }

                                            doc.add_value(slot_L1, oo.literal.ptr, oo.literal.length, &err);
                                            indexer.index_text(oo.literal.ptr, oo.literal.length, prefix.ptr, prefix.length, &err);

                                            all_text.write(oo.literal);
                                            all_text.write('|');
                                            //writeln ("slot:", slot_L1, ", value:", oo.literal);
                                        }
                                    }
                                }
                                else if (type == xsd__decimal)
                                {
                                    slot_L1 = get_slot_and_set_if_not_found(pp.predicate ~ ".decimal", key2slot);
                                    prefix = "X" ~ text(slot_L1) ~ "X";

                                    foreach (oo; pp.getObjects())
                                    {
                                        if (oo.type == OBJECT_TYPE.TEXT_STRING)
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
                                    slot_L1 = get_slot_and_set_if_not_found(pp.predicate ~ ".dateTime", key2slot);
                                    prefix = "X" ~ text(slot_L1) ~ "X";

                                    foreach (oo; pp.getObjects())
                                    {
                                        if (oo.type == OBJECT_TYPE.TEXT_STRING)
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

                            string uuid = "uid_" ~ to_lower_and_replace_delimeters(ss.subject);
                            doc.add_boolean_term(uuid.ptr, uuid.length, &err);
                            doc.set_data(ss.subject.ptr, ss.subject.length, &err);

                            indexer_db.replace_document(uuid.ptr, uuid.length, doc, &err);

                            if (counter % 100 == 0)
                            {
                                writeln("prepare msg counter:", counter, " ,slot size=", key2slot.length);
                            }

                            if (counter % 5000 == 0)
                            {
                                printf("commit index..");

                                if (key2slot.length > 0)
                                    store__key2slot(key2slot, indexer_db, indexer, key2slot_accumulator);

                                indexer_db.commit(&err);
                                printf("ok\n");
                            }

                            destroy_Document(doc);
                        }
                    }
                }, (Variant v) { writeln("xapian_indexer::Received some other type."); });
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


