/**
 *     XAPIAN READER
 */

module search.xapian_reader;

import std.concurrency, std.outbuffer, std.datetime, std.conv, std.typecons, std.stdio, std.string, std.file;

import bind.xapian_d_header;
import util.utils;
import util.cbor;

import pacahon.define;
import pacahon.know_predicates;
import pacahon.context;
import pacahon.log_msg;

import search.vel;
import search.xapian_vql;

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

// /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
interface SearchReader
{
    public int get(Ticket *ticket, string str_query, string fields, string sort, int count_authorize,
                   void delegate(string uri) add_out_element);

    public void reopen_db();
}

/*
   class XapianSynchronizedReader : SearchReader
   {
    private Context context;

    this(Context _context)
    {
        context = _context;
    }

    public int get(Ticket *ticket, string str_query, string fields, string sort, int count_authorize,
                   void delegate(string uri, string cbor_subject) add_out_element)
    {
        if (str_query is null)
            return 0;

   //      writeln ("@ XapianSynchronizedReader.get #1");
        Tid tid_subject_manager = context.getTid(P_MODULE.subject_manager);

        send(context.getTid(P_MODULE.xapian_indexer), CMD.FIND, str_query, fields, sort, count_authorize, thisTid);

        bool next_recieve = true;
        int  read_count;
        while (next_recieve)
        {
            receive(
                    (CMD cmd)
                    {
                        if (cmd == CMD.END_DATA)
                        {
                            next_recieve = false;
                        }
                    },
                    (CMD cmd, string msg)
                    {
                        if (cmd == CMD.PUT)
                        {
                            if (tid_subject_manager != Tid.init)
                            {
                                // writeln("msg:", msg);
                                add_out_element(uri, msg);
                                read_count++;
                            }
                        }
                    });
        }

   //      writeln ("@ XapianSynchronizedReader.get #end");
        return read_count;
    }
   }
 */

class XapianReader : SearchReader
{
    private XapianDatabase    xapian_db;
    private XapianStem        xapian_stemmer;
    private string            xapian_lang = "russian";
    private XapianEnquire     xapian_enquire;
    private XapianQueryParser xapian_qp;

    private Context           context;

    this(Context _context)
    {
        context = _context;
        open_db();
    }

    private string dummy;
    private double d_dummy;

    public int get(Ticket *ticket, string str_query, string str_fields, string sort, int count_authorize,
                   void delegate(string uri) add_out_element)
    {
        context.check_for_reload("search", &reopen_db);

        int[ string ] key2slot = context.get_key2slot();
        //writeln ("@key2slot=", key2slot);

        auto        fields = get_fields(str_fields);

        XapianQuery query;
        TTA         tta = parse_expr(str_query);

        if (trace_msg[ 321 ] == 1)
            log.trace("[%s][DB:%X][Q:%X] query [%s]", context.get_name(), cast(void *)xapian_db, cast(void *)str_query, str_query);

        if (trace_msg[ 322 ] == 1)
            log.trace("[%s][Q:%X] TTA [%s]", context.get_name(), cast(void *)str_query, tta.toString());

        transform_vql_to_xapian(tta, "", dummy, dummy, query, key2slot, d_dummy, 0, xapian_qp);

        if (query !is null)
        {
            if (trace_msg[ 323 ] == 1)
                log.trace("[%s][Q:%X] xapian query [%s]", context.get_name(), cast(void *)str_query, get_query_description(query));

            int count = 0;
            xapian_enquire = xapian_db.new_Enquire(&err);

            XapianMultiValueKeyMaker sorter = get_sorter(sort, key2slot);

            int                      state         = -1;
            int                      attempt_count = 1;
            while (state == -1)
            {
                state = exec_xapian_query_and_queue_authorize(ticket, query, sorter, xapian_enquire, count_authorize, fields,
                                                              add_out_element, context);
                if (state == -1)
                {
                    attempt_count++;
                    reopen_db();
                    log.trace("[%s][Q:%X] exec_xapian_query_and_queue_authorize, attempt=%d",
                              context.get_name(), cast(void *)str_query,
                              attempt_count);

                    //close_db();
                    //open_db();
                    //xapian_enquire = xapian_db.new_Enquire(&err);
                }
            }

            int read_count = 0;

            if (state > 0)
                read_count = state;

            destroy_Enquire(xapian_enquire);
            destroy_Query(query);
            destroy_MultiValueKeyMaker(sorter);

            //writeln ("read count:", read_count, ", count:", count);
            return read_count;
        }
        else
        {
            log.trace("[%s]invalid query [%s]", context.get_name(), str_query);
        }

        return 0;
    }

    public void reopen_db()
    {
        byte err;

        if (trace_msg[ 324 ] == 1)
            log.trace("[%s] xapian reader: reopen [DB:%X]", context.get_name(), cast(void *)xapian_db);

//      xapian_db.close(&err);
//      destroy_Database (xapian_db);
//      xapian_db = new_Database(xapian_search_db_path.ptr, xapian_search_db_path.length, &err);
//      if (err != 0)
//          writeln("VQL:reopen_db:err", err);

//      close_db();
//      open_db();

        xapian_db.reopen(&err);
        if (err != 0)
            writeln("VQL:reopen_db:err", err);

        xapian_qp.set_database(xapian_db, &err);
        if (err != 0)
            writeln("VQL:set_database:err", err);
    }

    private void open_db()
    {
        byte err;

        xapian_db = new_Database(xapian_search_db_path.ptr, xapian_search_db_path.length, &err);
        if (err != 0)
            writeln("VQL:new_Database:err", err);

        xapian_qp = new_QueryParser(&err);
        if (err != 0)
            writeln("VQL:new_QueryParser:err", err);

        xapian_stemmer = new_Stem(cast(char *)xapian_lang, xapian_lang.length, &err);
        xapian_qp.set_stemmer(xapian_stemmer, &err);
        if (err != 0)
            writeln("VQL:set_stemmer:err", err);

        //xapian_qp.set_stemming_strategy(stem_strategy.STEM_NONE, &err);

        xapian_qp.set_database(xapian_db, &err);
        if (err != 0)
            writeln("VQL:set_database:err", err);
    }

    private void close_db()
    {
        xapian_db.close(&err);
    }
}

