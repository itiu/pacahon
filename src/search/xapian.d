//////////////////////////////////////////// USE XAPIAN SEARCH ///////////////////////////////////////////////////////////////

module search.xapian;

import std.concurrency;
import std.outbuffer;
import std.csv;
import std.datetime;
import std.conv;
import std.typecons;
import std.stdio;

import bind.xapian_d_header;
import util.utils;

import pacahon.define;
import pacahon.know_predicates;
import pacahon.graph;
import pacahon.context;
import search.vel;

private const string xapian_path            = "xapian-search";
private const string xapian_metadata_doc_id = "ItIsADocumentContainingTheNameOfTheFieldTtheNumberOfSlots";

byte                 err;

private void store__key2slot(ref int[ string ] key2slot, ref XapianWritableDatabase indexer_db, ref XapianTermGenerator indexer)
{
//	writeln ("#1 store__key2slot");
    OutBuffer outbuff = new OutBuffer();

    foreach (key, value; key2slot)
    {
        outbuff.write('"');
        outbuff.write(key);
        outbuff.write('"');
        outbuff.write(',');
        outbuff.write(text(value));
        outbuff.write('\n');
    }

    string         data = outbuff.toString();

    XapianDocument doc = new_Document(&err);
    indexer.set_document(doc, &err);

    doc.set_data(data.ptr, data.length, &err);
    string uuid = xapian_metadata_doc_id;
    indexer.index_text(uuid.ptr, uuid.length, &err);
    doc.add_boolean_term(uuid.ptr, uuid.length, &err);
    indexer_db.replace_document(uuid.ptr, uuid.length, doc, &err);
    destroy_Document(doc);
}

public int[ string ] read_key2slot()
{
    int[ string ] key2slot;
    XapianDatabase db = new_Database(xapian_path.ptr, xapian_path.length, &err);
    if (err == 0)
    {
        string            lang    = "english";
        XapianStem        stemmer = new_Stem(cast(char *)lang, lang.length, &err);
        XapianEnquire     enquire = db.new_Enquire(&err);
        XapianQueryParser qp      = new_QueryParser(&err);

        qp.set_stemmer(stemmer, &err);
        qp.set_database(db, &err);

        qp.set_stemming_strategy(stem_strategy.STEM_SOME, &err);

        string      query_string = xapian_metadata_doc_id;

        XapianQuery query = qp.parse_query(cast(char *)query_string, query_string.length, &err);

        enquire.set_query(query, &err);

        XapianMSet matches = enquire.get_mset(0, 1, &err);

//    writeln ("found =",  matches.get_matches_estimated());
//    writeln ("matches =",  matches.size ());

        XapianMSetIterator it = matches.iterator(&err);

        if (it.is_next(&err) == true)
        {
            //      writeln ("#15 id=[", it.get_documentid(), "]");
            XapianDocument doc = it.get_document(&err);

            char           *data_str;
            uint           *data_len;
            doc.get_data(&data_str, &data_len, &err);
            string         data = cast(immutable)data_str[ 0..(*data_len) ].dup;
            //writeln ("data=[", data, "]");

            int idx = 0;
            foreach (record; csvReader!(Tuple!(string, int))(data))
            {
//              writefln("%d %s -> %d", idx, record[0], record[1]);
                key2slot[ record[ 0 ] ] = record[ 1 ];
                idx++;
                //core.thread.Thread.sleep(dur!("seconds")(1));
            }
        }
        //writeln("******");

        db.close(&err);
    }
    writeln("slot size=", key2slot.length);

    return key2slot;
}

private void printTid(string tag)
{
    writefln("%s: %s, address: %s", tag, thisTid, &thisTid);
}

protected int get_slot(string field, ref int[ string ] key2slot)
{
    int slot = key2slot.get(field, -1);

    if (slot == -1)
    {
        // create new slot
        slot              = cast(int)key2slot.length + 1;
        key2slot[ field ] = slot;
    }

    return slot;
}

void xapian_indexer_commiter(Tid tid)
{
    while (true)
    {
        core.thread.Thread.sleep(dur!("seconds")(20));
        send(tid, "COMMIT");
    }
}

import storage.subject;

void xapian_indexer(Tid tid_storage_manager)
{
    writeln("SPAWN: Xapian Indexer");

    ///////////// XAPIAN INDEXER ///////////////////////////
    XapianWritableDatabase indexer_db;
    XapianTermGenerator    indexer;

    string                 lang    = "russian";
    XapianStem             stemmer = new_Stem(cast(char *)lang, lang.length, &err);

    // Open the database for update, creating a new database if necessary.
    indexer_db = new_WritableDatabase(xapian_path.ptr, xapian_path.length, DB_CREATE_OR_OPEN, &err);
    if (err != 0)
    {
        writeln("!!!!!!! ERRR O_o");
        return;
    }

    int[ string ] key2slot = read_key2slot();

    indexer = new_TermGenerator(&err);
    indexer.set_stemmer(stemmer, &err);

    int   counter                         = 0;
    int   last_counter_afrer_timed_commit = 0;
    ulong last_size_key2slot              = 0;

    while (true)
    {
        auto msg = receiveOnly!(string)();

        if (msg == "COMMIT")
        {
            if (counter - last_counter_afrer_timed_commit > 0)
            {
                printf("counter: %d, timer: commit index..", counter);
                for (int i = 0; i < 1_000_000; i++)
                    if (key2slot.length - last_size_key2slot > 0)
                    {
                        store__key2slot(key2slot, indexer_db, indexer);
                        printf("..store__key2slot..");
                        last_size_key2slot = key2slot.length;
                    }

                indexer_db.commit(&err);
                printf("ok\n");
//				indexer_db.close ();
//				indexer_db = new_WritableDatabase(xapian_path.ptr, xapian_path.length, DB_CREATE_OR_OPEN);
                last_counter_afrer_timed_commit = counter;
            }
        }
        else
        {
            counter++;

            Subject ss = Subject.fromBSON(msg);

//			writeln ("prepare msg counter:", counter, ", subject:", ss.subject);

            if (ss.subject !is null && ss.count_edges > 0)
            {
                OutBuffer      all_text = new OutBuffer();

                XapianDocument doc = new_Document(&err);
                indexer.set_document(doc, &err);

                foreach (pp; ss.getPredicates())
                {
                    string prefix;
                    int    slot = get_slot(pp.predicate, key2slot);
                    string type = "?";

                    if (pp.metadata !is null)
                    {
                        type        = pp.metadata.getFirstLiteral(owl__allValuesFrom);
                        pp.metadata = null;
                    }

//					writeln (pp.predicate, ".type:", type);

                    string p_text_ru = "";
                    string p_text_en = "";

                    foreach (oo; pp.getObjects())
                    {
                        if (oo.type == OBJECT_TYPE.LITERAL)
                        {
                            if (pp.count_objects > 1)
                            {
                                if (oo.lang == LANG.RU)
                                    p_text_ru ~= oo.literal;
                                if (oo.lang == LANG.EN)
                                    p_text_en ~= oo.literal;
                            }

                            int slot_L1 = get_slot(pp.predicate, key2slot);
                            prefix = "X" ~ text(slot_L1) ~ "X";

                            string data = escaping_or_uuid2search(oo.literal);
                            indexer.index_text(data.ptr, data.length, prefix.ptr, prefix.length, &err);
                            doc.add_value(slot_L1, oo.literal.ptr, oo.literal.length, &err);
                        }
                        else if (oo.type == OBJECT_TYPE.URI)
                        {
                            if (oo.literal is null)
                            {
                            }
                            else
                            {
                                int slot_L1 = get_slot(pp.predicate, key2slot);
                                prefix = "X" ~ text(slot_L1) ~ "X";

                                string data = escaping_or_uuid2search(oo.literal);
                                indexer.index_text(data.ptr, data.length, prefix.ptr, prefix.length, &err);
                                doc.add_value(slot_L1, oo.literal.ptr, oo.literal.length, &err);
                            }
                        }
                        else if (oo.type == OBJECT_TYPE.SUBJECT)
                        {
                            if (oo.subject !is null && oo.subject.count_edges == 0)
                            {
                            }
                            else
                            {
                            }
                        }
                        else if (oo.type == OBJECT_TYPE.CLUSTER)
                        {
                            for (int i = 0; i < oo.cluster.length; i++)
                            {
                            }
                        }
                    }

                    if (pp.count_objects > 1)
                    {
                        if (p_text_ru.length > 0)
                        {
                            int slot_L1 = get_slot(pp.predicate ~ "_ru", key2slot);
                            prefix = "X" ~ text(slot_L1) ~ "X";

                            indexer.index_text(p_text_ru.ptr, p_text_ru.length, prefix.ptr, prefix.length, &err);
                            doc.add_value(slot_L1, p_text_ru.ptr, p_text_ru.length, &err);
                            //writeln ("slot:", slot_L1, ", value:", p_text_ru);
                        }

                        if (p_text_en.length > 0)
                        {
                            int slot_L1 = get_slot(pp.predicate ~ "_en", key2slot);
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
                            if (oo.type == OBJECT_TYPE.LITERAL && (oo.lang == _RU || oo.lang == _NONE))
                            {
                                if (sp == true)
                                {
                                    slot_L1 = get_slot(pp.predicate ~ ".text_ru", key2slot);
                                    prefix  = "X" ~ text(slot_L1) ~ "X";

                                    sp = false;
                                }

                                doc.add_value(slot_L1, oo.literal.ptr, oo.literal.length, &err);
                                indexer.index_text(oo.literal.ptr, oo.literal.length, prefix.ptr, prefix.length, &err);

                                all_text.write(oo.literal);
                                all_text.write("|");
                                //writeln ("slot:", slot_L1, ", value:", oo.literal);
                            }
                        }

                        sp = true;
                        foreach (oo; pp.getObjects())
                        {
                            if (oo.type == OBJECT_TYPE.LITERAL && (oo.lang == _EN))
                            {
                                if (sp == true)
                                {
                                    slot_L1 = get_slot(pp.predicate ~ ".text_en", key2slot);
                                    prefix  = "X" ~ text(slot_L1) ~ "X";

                                    sp = false;
                                }

                                doc.add_value(slot_L1, oo.literal.ptr, oo.literal.length, &err);
                                indexer.index_text(oo.literal.ptr, oo.literal.length, prefix.ptr, prefix.length, &err);

                                all_text.write(oo.literal);
                                all_text.write("|");
                                //writeln ("slot:", slot_L1, ", value:", oo.literal);
                            }
                        }
                    }
                    else if (type == xsd__decimal)
                    {
                        slot_L1 = get_slot(pp.predicate ~ ".decimal", key2slot);
                        prefix  = "X" ~ text(slot_L1) ~ "X";

                        foreach (oo; pp.getObjects())
                        {
                            if (oo.type == OBJECT_TYPE.LITERAL)
                            {
                                double data = to!double (oo.literal);
                                doc.add_value(slot_L1, data, &err);
                                all_text.write(oo.literal);
                                all_text.write("|");

                                indexer.index_data(data, prefix.ptr, prefix.length, &err);
                            }
                        }
                    }
                    else if (type == xsd__dateTime)
                    {
                        slot_L1 = get_slot(pp.predicate ~ ".dateTime", key2slot);
                        prefix  = "X" ~ text(slot_L1) ~ "X";

                        foreach (oo; pp.getObjects())
                        {
                            if (oo.type == OBJECT_TYPE.LITERAL)
                            {
                                long data = stringToTime(oo.literal);
                                doc.add_value(slot_L1, data, &err);
                                all_text.write(oo.literal);
                                all_text.write("|");

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
                indexer.index_text(data.ptr, data.length, &err);

                string uuid = ss.subject;
                doc.add_boolean_term(uuid.ptr, uuid.length, &err);
                string doc_data = uuid;
                doc.set_data(doc_data.ptr, doc_data.length, &err);

                send(tid_storage_manager, STORE, ss.toBSON(), thisTid);

                indexer_db.replace_document(uuid.ptr, uuid.length, doc, &err);

                if (counter % 100 == 0)
                {
                    writeln("prepare msg counter:", counter, " ,slot size=", key2slot.length);
                }

                if (counter % 5000 == 0)
                {
                    printf("commit index..");

                    if (key2slot.length > 0)
                        store__key2slot(key2slot, indexer_db, indexer);

                    indexer_db.commit(&err);
                    printf("ok\n");
                }

                destroy_Document(doc);
            }
        }
    }
}

protected string transform_vql_to_xapian(TTA tta, string p_op, out string l_token, out string op, out XapianQuery query, ref int[ string ] key2slot, out double _rd, int level)
{
//	string eee = "                                                                                       ";
//	string e1 = text(level) ~ eee[0..level*3];

//	writeln (e1, " #1, tta=", tta);
    string      dummy;
    double      rd, ld;
    XapianQuery query_r;
    XapianQuery query_l;

    if (tta.op == ">" || tta.op == "<")
    {
        string ls = transform_vql_to_xapian(tta.L, tta.op, dummy, dummy, query_l, key2slot, ld, level + 1);
        string rs = transform_vql_to_xapian(tta.R, tta.op, dummy, dummy, query_r, key2slot, rd, level + 1);

        if (rs.length == 19 && rs[ 4 ] == '-' && rs[ 7 ] == '-' && rs[ 10 ] == 'T' && rs[ 13 ] == ':' && rs[ 16 ] == ':')
        {
            // это дата
            l_token = ls ~ ".dateTime";
            op      = tta.op;
            _rd     = SysTime.fromISOExtString(rs).stdTime;
//			writeln ("RS=", rs);
//			writeln ("_rd=", _rd);
            return rs;
        }
        else
        {
            bool is_digit = false;
            try
            {
                auto b = parse!double (rs);
                _rd      = b;
                is_digit = true;
            }
            catch (Exception ex)
            {
            }

//			bool is_digit = true;
//			foreach (rr ; rs)
//			{
//				if (isDigit (rr) == false)
//				{
//					is_digit = false;
//					break;
//				}
//			}

            if (is_digit)
            {
                // это число
                l_token = ls ~ ".decimal";
                op      = tta.op;
                return rs;
            }
        }
    }
    else if (tta.op == "==")
    {
        string ls = transform_vql_to_xapian(tta.L, tta.op, dummy, dummy, query_l, key2slot, ld, level + 1);
        string rs = transform_vql_to_xapian(tta.R, tta.op, dummy, dummy, query_r, key2slot, rd, level + 1);
        //writeln ("#2 % query_l=", query_l);
        //writeln ("#2 % query_r=", query_r);
        if (query_l is null && query_r is null)
        {
            int slot = get_slot(ls, key2slot);
            //writeln ("slot=", slot);
            //writeln ("rs=", rs);
            string tr = "X" ~ text(slot) ~ "X" ~ rs;
            query = new_Query(cast(char *)tr, tr.length, &err);
            destroy_Query(query_l);
            destroy_Query(query_r);
        }
    }
    else if (tta.op == "&&")
    {
//	writeln ("#3.0 &&");
        string t_op_l;
        string t_op_r;
        string token_L;

        string tta_R;
        if (tta.R !is null)
            tta_R = transform_vql_to_xapian(tta.R, tta.op, token_L, t_op_r, query_r, key2slot, rd, level + 1);

        if (t_op_r !is null)
            op = t_op_r;

        string tta_L;
        if (tta.L !is null)
            tta_L = transform_vql_to_xapian(tta.L, tta.op, dummy, t_op_l, query_l, key2slot, ld, level + 1);

        if (t_op_l !is null)
            op = t_op_l;

//	writeln (e1, "#E0 && token_L=", token_L);
//	writeln (e1, "#E0 query_l=", get_query_description (query_l));
//	writeln (e1, "#E0 query_r=", get_query_description (query_r));


        if (token_L !is null && tta_L !is null)
        {
//	writeln (e1, "#E0.1 &&");
            // это range
//			writeln ("token_L=", token_L);
//			writeln ("tta_R=", tta_R);
//			writeln ("tta_L=", tta_L);
//			writeln ("t_op_l=", t_op_l);
//			writeln ("t_op_r=", t_op_r);

            double c_to, c_from;

            if (t_op_r == ">")
                c_from = rd;
            if (t_op_r == "<")
                c_to = rd;

            if (t_op_l == ">")
                c_from = ld;
            if (t_op_l == "<")
                c_to = ld;

//			writeln ("c_from=", c_from);
//			writeln ("c_to=", c_to);

            int slot = get_slot(token_L, key2slot);
//			writeln ("#E1");

            query_r = new_Query_range(xapian_op.OP_VALUE_RANGE, slot, c_from, c_to, &err);
            query   = query_l.add_right_query(xapian_op.OP_AND, query_r, &err);
//			writeln ("#E2 query=", get_query_description (query));
            destroy_Query(query_r);
            destroy_Query(query_l);
        }
        else
        {
//	writeln (e1, "#E0.2 &&");
            if (query_r !is null)
            {
//	writeln ("#E0.2 && query_l=", get_query_description (query_l));
//	writeln ("#E0.2 && query_r=", get_query_description (query_r));
                query = query_l.add_right_query(xapian_op.OP_AND, query_r, &err);
                destroy_Query(query_l);
                destroy_Query(query_r);

//			writeln ("#3.1 && query=", get_query_description (query));
            }
            else
            {
                query = query_l;
                destroy_Query(query_r);
            }
        }

//	writeln ("#E3 &&");

        if (tta_R !is null && tta_L is null)
        {
            _rd = rd;
            return tta_R;
        }

        if (tta_L !is null && tta_R is null)
        {
            _rd = ld;
            return tta_L;
        }
    }
    else if (tta.op == "||")
    {
//	writeln ("#4 ||");

        if (tta.R !is null)
            transform_vql_to_xapian(tta.R, tta.op, dummy, dummy, query_r, key2slot, rd, level + 1);

        if (tta.L !is null)
            transform_vql_to_xapian(tta.L, tta.op, dummy, dummy, query_l, key2slot, ld, level + 1);

        query = query_l.add_right_query(xapian_op.OP_OR, query_r, &err);
        destroy_Query(query_l);
        destroy_Query(query_r);
    }
    else
    {
//		query = new_Query_equal (xapian_op.OP_FILTER, int slot, cast(char*)tta.op, tta.op.length);
//		writeln ("#5 tta.op=", tta.op);
        return tta.op;
    }
//		writeln ("#6 null");
    return null;
}

string get_query_description(XapianQuery query)
{
    if (query !is null)
    {
        char *descr_str;
        uint *descr_len;
        query.get_description(&descr_str, &descr_len, &err);
        if (descr_len !is null)
        {
            return cast(immutable)descr_str[ 0..(*descr_len) ];
        }
    }
    return "NULL";
}
