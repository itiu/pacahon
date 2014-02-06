module search.xapian_vql;

import std.string;
import std.concurrency;
import std.stdio;
import std.datetime;
import std.conv;

import bind.xapian_d_header;
import util.utils;
import util.graph;
import util.cbor;
import search.vel;
import pacahon.context;

public const string xapian_search_db_path  = "data/xapian-search";
public const string xapian_metadata_doc_id = "ItIsADocumentContainingTheNameOfTheFieldTtheNumberOfSlots";

byte                err;

public int get_slot(string field, ref int[ string ] key2slot)
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

public string[ string ] get_fields(string str_fields)
{
    string[ string ] fields;

    if (str_fields !is null)
    {
        string[] returns = split(str_fields, ",");

        foreach (field; returns)
        {
            long bp = indexOf(field, '\'');
            long ep = lastIndexOf(field, '\'');
            long rp = lastIndexOf(field, " reif");
            if (ep > bp && ep - bp > 0)
            {
                string key = field[ bp + 1 .. ep ];
                if (rp > ep)
                    fields[ key ] = "reif";
                else
                    fields[ key ] = "1";
            }
        }
    }
    return fields;
}

public XapianMultiValueKeyMaker get_sorter(string sort, ref int[ string ] key2slot)
{
    XapianMultiValueKeyMaker sorter;

    if (sort != null)
    {
        sorter = new_MultiValueKeyMaker(&err);
        foreach (field; split(sort, ","))
        {
            bool asc_desc;

            long bp = indexOf(field, '\'');
            long ep = lastIndexOf(field, '\'');
            long dp = lastIndexOf(field, " desc");

            if (ep > bp && ep - bp > 0)
            {
                string key = field[ bp + 1 .. ep ];

                if (dp > ep)
                    asc_desc = false;
                else
                    asc_desc = true;

                int slot = get_slot(key, key2slot);
                sorter.add_value(slot, asc_desc, &err);
            }
        }
    }
    return sorter;
}

public string transform_vql_to_xapian(TTA tta, string p_op, out string l_token, out string op, out XapianQuery query,
                                      ref int[ string ] key2slot, out double _rd, int level, XapianQueryParser qp)
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
        string ls = transform_vql_to_xapian(tta.L, tta.op, dummy, dummy, query_l, key2slot, ld, level + 1, qp);
        string rs = transform_vql_to_xapian(tta.R, tta.op, dummy, dummy, query_r, key2slot, rd, level + 1, qp);

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
        string ls = transform_vql_to_xapian(tta.L, tta.op, dummy, dummy, query_l, key2slot, ld, level + 1, qp);
        string rs = transform_vql_to_xapian(tta.R, tta.op, dummy, dummy, query_r, key2slot, rd, level + 1, qp);
        //writeln ("#2 % query_l=", query_l);
        //writeln ("#2 % query_r=", query_r);
//          writeln ("ls=", ls);
//          writeln ("rs=", rs);
        if (query_l is null && query_r is null)
        {
            string xtr;
            if (ls != "*")
            {
                if (ls == "@")
                {
                    string uid = "uid_" ~ to_lower_and_replace_delimeters(rs);
                    query = qp.parse_query(cast(char *)uid, uid.length, &err);
                    if (err != 0)
                        writeln("XAPIAN:transform_vql_to_xapian:parse_query(@)", err);
                    //writeln ("uid=", uid);
                }
                else
                {
                    int slot = get_slot(ls, key2slot);
                    //writeln ("slot=", slot);
                    if (indexOf(rs, '*') > 0 && rs.length > 3)
                    {
//                  xtr = "X" ~ text(slot) ~ "X" ~ to_lower_and_replace_delimeters(rs);
                        string query_str = to_lower_and_replace_delimeters(rs);
                        xtr   = "X" ~ text(slot) ~ "X";
                        query = qp.parse_query(cast(char *)query_str, query_str.length, feature_flag.FLAG_WILDCARD, cast(char *)xtr,
                                               xtr.length, &err);
                        if (err != 0)
                            writeln("XAPIAN:transform_vql_to_xapian:parse_query('x'=*)", err);
//                  query = qp.parse_query(cast(char *)xtr, xtr.length, feature_flag.FLAG_WILDCARD, &err);
                    }
                    else
                    {
                        xtr   = "X" ~ text(slot) ~ "X" ~ to_lower_and_replace_delimeters(rs);
                        query = new_Query(cast(char *)xtr, xtr.length, &err);
                        if (err != 0)
                            writeln("XAPIAN:transform_vql_to_xapian:parse_query('x'=x)", err);
                    }
                }
            }
            else
            {
                xtr = to_lower_and_replace_delimeters(rs);
//              writeln ("xtr=", xtr);

                if (indexOf(xtr, '*') > 0 && xtr.length > 3)
                {
                    query = qp.parse_query(cast(char *)xtr, xtr.length, feature_flag.FLAG_WILDCARD, &err);
                    if (err != 0)
                        writeln("XAPIAN:transform_vql_to_xapian:parse_query('*'=*)", err);
                }
                else
                {
                    query = qp.parse_query(cast(char *)xtr, xtr.length, &err);
                    if (err != 0)
                        writeln("XAPIAN:transform_vql_to_xapian:parse_query('*'=x)", err);
                }
            }

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
            tta_R = transform_vql_to_xapian(tta.R, tta.op, token_L, t_op_r, query_r, key2slot, rd, level + 1, qp);

        if (t_op_r !is null)
            op = t_op_r;

        string tta_L;
        if (tta.L !is null)
            tta_L = transform_vql_to_xapian(tta.L, tta.op, dummy, t_op_l, query_l, key2slot, ld, level + 1, qp);

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
            transform_vql_to_xapian(tta.R, tta.op, dummy, dummy, query_r, key2slot, rd, level + 1, qp);

        if (tta.L !is null)
            transform_vql_to_xapian(tta.L, tta.op, dummy, dummy, query_l, key2slot, ld, level + 1, qp);

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

public int exec_xapian_query_and_queue_authorize(XapianQuery query, XapianMultiValueKeyMaker sorter, XapianEnquire xapian_enquire,
                                                 int count_authorize,
                                                 ref string[ string ] fields, void delegate(string cbor_subject) add_out_element,
                                                 Tid tid_subject_manager,
                                                 Tid tid_acl_manager)
{
    int read_count = 0;

    //StopWatch sw;
    //sw.start();

    //    writeln ("query=", get_query_description (query));

    byte err;

    xapian_enquire.set_query(query, &err);
    if (sorter !is null)
        xapian_enquire.set_sort_by_key(sorter, true, &err);

    XapianMSet matches = xapian_enquire.get_mset(0, count_authorize, &err);
    if (err < 0)
        return err;

    //  writeln ("found =",  matches.get_matches_estimated(&err));
    //  writeln ("matches =",  matches.size (&err));

    if (matches !is null)
    {
        XapianMSetIterator it = matches.iterator(&err);

        while (it.is_next(&err) == true)
        {
            char   *data_str;
            uint   *data_len;
            it.get_document_data(&data_str, &data_len, &err);
            string subject_id = cast(immutable)data_str[ 0..*data_len ].dup;
            //	writeln ("Subject_id:", subject_id);
            if (tid_subject_manager != Tid.init)
            {
                send(tid_subject_manager, CMD.GET, subject_id, thisTid);
                read_count++;
            }

            it.next(&err);
        }

        //sw.stop();
        //long t = cast(long) sw.peek().usecs;
        //writeln("1 execute:", t, " µs");

        destroy_MSetIterator(it);
        destroy_MSet(matches);

        byte[ string ] hash_of_subjects;

        // Фаза I, получим субьекты из хранилища и отправим их на авторизацию,
        // тут же получение из авторизации и формирование части ответа
        for (int i = 0; i < read_count * 2; i++)
        {
            receive((string msg, Tid from)
                    {
                        if (from == tid_subject_manager)
                        {
                            send(tid_acl_manager, CMD.AUTHORIZE, msg, thisTid);
                        }
                        else
                        {
                            if (msg.length > 16)
                            {
//                                    writeln ("!!!", msg);
                                Subject sss = decode_cbor(msg, LINKS);

                                if (sss !is null)
                                {
                                    // добавим в исходящий поток
                                    add_out_element(msg);

                                    hash_of_subjects[ sss.subject ] = 1;

                                    foreach (objz; sss)
                                    {
                                        foreach (id; objz)
                                        {
                                            if (hash_of_subjects.get(id.literal, -1) == -1)
                                            {
                                                hash_of_subjects[ id.literal ] = 2;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    });
        }

        // Фаза II, дочитать если нужно
        int count_inner;
        foreach (key; hash_of_subjects.keys)
        {
            byte vv = hash_of_subjects[ key ];
            if (vv == 2)
            {
                send(tid_subject_manager, CMD.GET, key, thisTid);
                count_inner++;
            }
        }

        for (int i = 0; i < count_inner; i++)
        {
            receive((string msg, Tid from)
                    {
                        if (msg.length > 16)
                        {
                            //writeln (msg);
                            // отправить в исходящий поток
                            add_out_element(msg);
                        }
                    });
        }
    }

//    writeln ("@ read_count=", read_count);
    return read_count;
}

