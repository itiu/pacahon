/**
 * VQL -> xapian
 */

module search.xapian_vql;

import std.string, std.concurrency, std.stdio, std.datetime, std.conv, std.algorithm;
import bind.xapian_d_header;
import util.utils;
import util.cbor;
import search.vel;
import type;
import pacahon.context;
import pacahon.define;
import pacahon.log_msg;
import storage.lmdb_storage;

// ////// logger ///////////////////////////////////////////
import util.logger;
logger _log;
logger log()
{
    if (_log is null)
        _log = new logger("pacahon", "log", "search");
    return _log;
}
// ////// ////// ///////////////////////////////////////////

protected byte err;

public         string[ string ] get_fields(string str_fields)
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

                int slot = key2slot.get(key, -1);
                if (slot >= 0)
                {
                    if (trace_msg[ 200 ] == 1)
                        log.trace("sort key=%s, slot=%d", key, slot);
                    sorter.add_value(slot, asc_desc, &err);
                }
            }
        }
    }
    return sorter;
}

enum TokenType
{
    TEXT,
    NUMBER,
    DATE
}

private TokenType get_token_type(string token, out double value)
{
    TokenType res = TokenType.TEXT;

    token = token.strip();

    if (token.length == 19 && token[ 4 ] == '-' && token[ 7 ] == '-' && token[ 10 ] == 'T' && token[ 13 ] == ':' && token[ 16 ] == ':')
    {
        value = stdTimeToUnixTime(SysTime.fromISOExtString(token).stdTime);
        return TokenType.DATE;
    }
    else if (token.length == 24 && token[ 4 ] == '-' && token[ 7 ] == '-' && token[ 10 ] == 'T' && token[ 13 ] == ':' && token[ 16 ] == ':' && token[ 19 ] == '.')
    {
        value = stdTimeToUnixTime(SysTime.fromISOExtString(token).stdTime);
        return TokenType.DATE;
    }
    else
    {
        bool is_digit = false;
        try
        {
            string tt = token.dup;
            value = parse!double (tt);
            return TokenType.NUMBER;
        }
        catch (Exception ex)
        {
        }
    }

    return res;
}

public string transform_vql_to_xapian(TTA tta, string p_op, out string l_token, out string op, out XapianQuery query,
                                      ref int[ string ] key2slot, out double _rd, int level, XapianQueryParser qp)
{
    if (key2slot.length == 0)
    {
        log.trace("!!! WARN: key2slot is EMPTY, tta=%s", tta);
        return null;
    }

    string      dummy;
    double      rd, ld;
    XapianQuery query_r;
    XapianQuery query_l;

    if (tta.op == ">" || tta.op == "<")
    {
        string    ls = transform_vql_to_xapian(tta.L, tta.op, dummy, dummy, query_l, key2slot, ld, level + 1, qp);
        string    rs = transform_vql_to_xapian(tta.R, tta.op, dummy, dummy, query_r, key2slot, rd, level + 1, qp);

        double    value;
        TokenType rs_type = get_token_type(rs, value);
        if (rs_type == TokenType.DATE || rs_type == TokenType.NUMBER)
        {
            l_token = ls;
            op      = tta.op;
            _rd     = value;
            //writeln("@p RS=", rs);
            //writeln("@p _rd=", _rd);
            return rs;
        }
    }
    else if (tta.op == "==" || tta.op == "!=")
    {
        string ls = transform_vql_to_xapian(tta.L, tta.op, dummy, dummy, query_l, key2slot, ld, level + 1, qp);
        string rs = transform_vql_to_xapian(tta.R, tta.op, dummy, dummy, query_r, key2slot, rd, level + 1, qp);

        //writeln("#2 % query_l=", query_l);
        //writeln("#2 % query_r=", query_r);
        //writeln("ls=", ls);
        //writeln("rs=", rs);

        if (query_l is null && query_r is null)
        {
            string xtr;
            if (ls != "*")
            {
                if (ls == "@")
                {
                    feature_flag flags = feature_flag.FLAG_DEFAULT | feature_flag.FLAG_WILDCARD;

                    string       uid = "uid_" ~ to_lower_and_replace_delimeters(rs);
                    query = qp.parse_query(cast(char *)uid, uid.length, flags, &err);
                    if (err != 0)
                        writeln("XAPIAN:transform_vql_to_xapian:parse_query1(@)", err);
                    //writeln ("uid=", uid);
                }
                else
                {
                    int slot;
                    //writeln("@p slot=", slot, " predicate=", ls);
                    if (rs !is null && rs.length > 2 && rs[ 0 ] == '*')
                    {
                        slot = key2slot.get(ls ~ "#F", -1);
                    }
                    else
                    {
                        slot = key2slot.get(ls, -1);
                    }

                    if (slot > 0)
                    {
                        if (tta.R.token_decor == Decor.QUOTED || (indexOf(rs, '*') >= 0) && rs.length > 3)
                        {
                            char[] query_str = to_lower_and_replace_delimeters(rs).dup;
                            if (rs[ 0 ] == '*')
                            {
                                reverse(query_str);
                            }

                            xtr = "X" ~ text(slot) ~ "X";
//                            string query_str = rs.toLower ();
                            feature_flag flags = feature_flag.FLAG_DEFAULT | feature_flag.FLAG_WILDCARD | feature_flag.FLAG_PHRASE |
                                                 feature_flag.FLAG_LOVEHATE;
                            if (tta.op == "!=")
                            {
                                /*	TODO
                                 *  вероятно получаются не оптимальными запросы вида
                                 *  '*' == 'rdf' && '*' != 'List*'
                                 *  @query=Xapian::Query((rdf:(pos=1) AND (<alldocuments> AND_NOT (list:(pos=1) SYNONYM lists:(pos=1)))))
                                 */
                                flags     = flags | feature_flag.FLAG_PURE_NOT;
                                query_str = "NOT " ~ query_str;
                            }

                            query = qp.parse_query(cast(char *)query_str, query_str.length, flags, cast(char *)xtr,
                                                   xtr.length, &err);
                            if (err != 0)
                                writeln("XAPIAN:transform_vql_to_xapian:parse_query2('x'=*) query='", query_str, "', xtr='", xtr, "'", err);
                        }
                        else
                        {
                            if (tta.R.token_decor == Decor.RANGE)
                            {
                                string[] vals = rs.split(",");
                                if (vals.length == 2)
                                {
                                    double c_from, c_to;
//                              writeln ("@p vals=", vals);

                                    TokenType tt = get_token_type(vals[ 0 ], c_from);
                                    if (tt == TokenType.DATE || tt == TokenType.NUMBER)
                                    {
                                        tt = get_token_type(vals[ 1 ], c_to);
                                        if (tt == TokenType.DATE || tt == TokenType.NUMBER)
                                        {
                                            //writeln("@p c_from=", c_from);
                                            //writeln("@p c_to=", c_to);


                                            query = new_Query_range(xapian_op.OP_VALUE_RANGE, slot, c_from, c_to, &err);
                                        }
                                    }
                                }
                            }
//                            else if (tta.R.token_decor == Decor.QUOTED)
//                            {
//                                xtr   = "X" ~ text(slot) ~ "X" ~ to_lower_and_replace_delimeters(rs);
//                                query = new_Query(cast(const char *)xtr, xtr.length, &err);
//                            }
                            else
                            {
                                double d_val;

                                try
                                {
                                    d_val = parse!double (rs);
                                }
                                catch (Exception ex)
                                {
                                    writeln("Ex!: ", __FUNCTION__, ":", text(__LINE__), ", ", ex.msg ~ " [", rs, "]");
                                }


                                char *str_val;
                                uint *str_val_length;
                                sortable_serialise(d_val, &str_val, &str_val_length, &err);

                                uint   len = *str_val_length;

                                string tt = cast(string)str_val[ 0..len ];
                                //writeln("@ length=", len, ", tt=", tt, ", d_val=", d_val);
                                xtr   = "X" ~ text(slot) ~ "X" ~ tt;
                                query = new_Query(cast(char *)xtr, cast(uint)xtr.length, &err);
                            }

                            if (err != 0)
                                writeln("XAPIAN:transform_vql_to_xapian:parse_query3('x'=x) '", xtr, "'", err);
                        }
                    }
                }
            }
            else
            {
                xtr = to_lower_and_replace_delimeters(rs);
                //writeln("xtr=", xtr);

                if (indexOf(xtr, '*') > 0 && xtr.length > 3)
                {
                    feature_flag flags = feature_flag.FLAG_DEFAULT | feature_flag.FLAG_WILDCARD | feature_flag.FLAG_PHRASE;
                    if (tta.op == "!=")
                    {
/*	TODO
                         вероятно получаются не оптимальны запросы вида
                         '*' == 'rdf' && '*' != 'List*'
                         @query=Xapian::Query((rdf:(pos=1) AND (<alldocuments> AND_NOT (list:(pos=1) SYNONYM lists:(pos=1)))))
 */

                        flags = flags | feature_flag.FLAG_PURE_NOT;
                        xtr   = "NOT " ~ xtr;
                    }

                    query = qp.parse_query(cast(char *)xtr, xtr.length, flags, &err);
                    if (err != 0)
                        writeln("XAPIAN:transform_vql_to_xapian:parse_query4('*'=*) '", xtr, "'", err);
                }
                else
                {
                    query = qp.parse_query(cast(char *)xtr, xtr.length, &err);
                    if (err != 0)
                        writeln("XAPIAN:transform_vql_to_xapian:parse_query5('*'=x) '", xtr, "'", err);
                }
            }
        }

        if (query_l !is null)
            destroy_Query(query_l);
        if (query_r !is null)
            destroy_Query(query_r);
    }
    else if (tta.op == "&&")
    {
        //writeln("#3.0 &&, p_op=", p_op);
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

        //writeln("@p && token_L=", token_L);
        //writeln("@p query_l=", get_query_description(query_l));
        //writeln("@p query_r=", get_query_description(query_r));


        if (token_L !is null && tta_L !is null)
        {
            //writeln("@p #E0.1 &&");
            // это range
            //writeln("@p token_L=", token_L);
            //writeln("@p tta_R=", tta_R);
            //writeln("@p tta_L=", tta_L);
            //writeln("@p t_op_l=", t_op_l);
            //writeln("@p t_op_r=", t_op_r);

            double c_to, c_from;

            if (t_op_r == ">")
                c_from = rd;
            if (t_op_r == "<")
                c_to = rd;

            if (t_op_l == ">")
                c_from = ld;
            if (t_op_l == "<")
                c_to = ld;

            //writeln("@p c_from=", c_from);
            //writeln("@p c_to=", c_to);

            int slot = key2slot.get(token_L, -1);
            //writeln("@p #E0");

            query_r = new_Query_range(xapian_op.OP_VALUE_RANGE, slot, c_from, c_to, &err);

            if (query_l is null)
            {
                query   = query_r;
                query_r = null;
            }
            else
                query = query_l.add_right_query(xapian_op.OP_AND, query_r, &err);

            //writeln("@p #E3");

            if (query_r !is null)
                destroy_Query(query_r);

            if (query_l !is null)
                destroy_Query(query_l);

            //writeln("@p #E4");
        }
        else
        {
            //writeln("#E0.2 &&");
            if (query_r !is null)
            {
                //writeln("#E0.2 && query_l=", get_query_description(query_l));
                //writeln("#E0.2 && query_r=", get_query_description(query_r));
                if (query_l is null)
                {
                    query   = query_r;
                    query_r = null;
                }
                else
                    query = query_l.add_right_query(xapian_op.OP_AND, query_r, &err);

                //writeln("#3.1 && query=", get_query_description(query));
            }
            else
            {
                query   = query_l;
                query_l = null;
            }
            if (query_r !is null)
                destroy_Query(query_r);

            if (query_l !is null)
                destroy_Query(query_l);
        }

        //writeln("#E3 &&");

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
//        writeln("#4.1 ||");

        if (tta.R !is null)
            transform_vql_to_xapian(tta.R, tta.op, dummy, dummy, query_r, key2slot, rd, level + 1, qp);

        if (tta.L !is null)
            transform_vql_to_xapian(tta.L, tta.op, dummy, dummy, query_l, key2slot, ld, level + 1, qp);

        if (query_l !is null)
            query = query_l.add_right_query(xapian_op.OP_OR, query_r, &err);

        if (query_r !is null)
            destroy_Query(query_r);

        if (query_l !is null)
            destroy_Query(query_l);

//        writeln("#4.e");
    }
    else
    {
//		query = new_Query_equal (xapian_op.OP_FILTER, int slot, cast(char*)tta.op, tta.op.length);
        //writeln("#5 tta.op=", tta.op);
        return tta.op;
    }
//    writeln("#6 null");
    return null;
}

public int exec_xapian_query_and_queue_authorize(Ticket *ticket, XapianQuery query, XapianMultiValueKeyMaker sorter,
                                                 XapianEnquire xapian_enquire,
                                                 int count_authorize,
                                                 ref string[ string ] fields, void delegate(string uri) add_out_element,
                                                 Context context)
{
    int       read_count = 0;
    StopWatch sw;

    if (trace_msg[ 200 ] == 1)
    {
        log.trace("[%X] query=%s", cast(void *)query, get_query_description(query));
        sw.start();
    }

    byte err;

    xapian_enquire.set_query(query, &err);
    if (sorter !is null)
    {
        xapian_enquire.set_sort_by_key(sorter, true, &err);
    }

    //writeln (cast(void*)xapian_enquire, " count_authorize=", count_authorize);
    XapianMSet matches = xapian_enquire.get_mset(0, count_authorize, &err);
    if (err < 0)
        return err;

    if (trace_msg[ 200 ] == 1)
        log.trace("[%X] found =%d, @matches =%d", cast(void *)query, matches.get_matches_estimated(&err), matches.size(&err));

    //writeln ("@b1 ", context.get_name);
    if (matches !is null)
    {
        XapianMSetIterator it = matches.iterator(&err);

        while (it.is_next(&err) == true)
        {
            if (err < 0)
                return err;

            char *data_str;
            uint *data_len;
            it.get_document_data(&data_str, &data_len, &err);
            if (err < 0)
                return err;

            string subject_id = cast(immutable)data_str[ 0..*data_len ].dup;


            if (trace_msg[ 201 ] == 1)
                log.trace("subject_id:%s", subject_id);

            if (context.authorize(subject_id, ticket, Access.can_read))
            {
                add_out_element(subject_id);
                read_count++;
            }

            it.next(&err);
        }

        if (trace_msg[ 200 ] == 1)
        {
            sw.stop();
            long t = cast(long)sw.peek().usecs;
            log.trace("[%X] authorized:%d, total time execute query: %s µs", cast(void *)query, read_count, text(t));
        }

        destroy_MSetIterator(it);
        destroy_MSet(matches);
    }
    //writeln ("@e1 ", context.get_name);

//    writeln ("@ read_count=", read_count);
    return read_count;
}

string get_query_description(XapianQuery query)
{
    if (query !is null)
    {
        char *descr_str;
        uint *descr_len;
        query.get_description(&descr_str, &descr_len, &err);
        if (descr_len !is null && *descr_len > 0)
        {
            string str = cast(immutable)descr_str[ 0..*descr_len ].dup;
            writeln("QUERY:", str);
            return str;
        }
        else
            return "no content";
    }
    return "NULL";
}