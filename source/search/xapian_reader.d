/**
 *     XAPIAN READER
 */

module search.xapian_reader;

import std.concurrency, std.outbuffer, std.datetime, std.conv, std.typecons, std.stdio, std.string, std.file;

import bind.xapian_d_header;
import util.utils, util.cbor;
import pacahon.define, pacahon.know_predicates, pacahon.context, pacahon.log_msg;
import search.vel, search.xapian_vql, search.indexer_property;

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
    public int get(Ticket *ticket, string str_query, string str_sort, string db_names, int count_authorize,
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
class Database_QueryParser
{
    XapianDatabase    db;
    XapianQueryParser qp;
}


class XapianReader : SearchReader
{
    private               Database_QueryParser[ string[] ]      using_dbqp;

    private               XapianDatabase[ string ]              opened_db;

    private XapianStem    xapian_stemmer;
    private string        xapian_lang = "russian";
    private XapianEnquire xapian_enquire;

    private Context       context;

    this(Context _context)
    {
        context = _context;
    }

    private string dummy;
    private double d_dummy;

    public int get(Ticket *ticket, string str_query, string str_sort, string db_names, int count_authorize,
                   void delegate(string uri) add_out_element)
    {
        context.check_for_reload("search", &reopen_db);

        int[ string ] key2slot = context.get_key2slot();
        //writeln ("@key2slot=", key2slot);

        Database_QueryParser db_qp = get_dbqp(db_names);

        XapianQuery          query;
        TTA                  tta = parse_expr(str_query);

        if (trace_msg[ 321 ] == 1)
            log.trace("[%s][Q:%X] query [%s]", context.get_name(), cast(void *)str_query, str_query);

        if (trace_msg[ 322 ] == 1)
            log.trace("[%s][Q:%X] TTA [%s]", context.get_name(), cast(void *)str_query, tta.toString());

        transform_vql_to_xapian(tta, "", dummy, dummy, query, key2slot, d_dummy, 0, db_qp.qp);

        if (query !is null)
        {
            if (trace_msg[ 323 ] == 1)
                log.trace("[%s][Q:%X] xapian query [%s]", context.get_name(), cast(void *)str_query, get_query_description(query));

            xapian_enquire = db_qp.db.new_Enquire(&err);

            XapianMultiValueKeyMaker sorter = get_sorter(str_sort, key2slot);

            int                      state         = -1;
            int                      attempt_count = 1;
            while (state == -1)
            {
                state = exec_xapian_query_and_queue_authorize(ticket, query, sorter, xapian_enquire, count_authorize, add_out_element,
                                                              context);
                if (state == -1)
                {
                    attempt_count++;
                    reopen_db();
                    log.trace("[%s][Q:%X] exec_xapian_query_and_queue_authorize, attempt=%d",
                              context.get_name(), cast(void *)str_query,
                              attempt_count);

                    if (attempt_count > 10)
                        break;

                    //close_db();
                    //open_db();
                    //xapian_enquire = xapian_base_db.new_Enquire(&err);
                }
            }

            int read_count = 0;

            if (state > 0)
                read_count = state;

            destroy_Enquire(xapian_enquire);
            destroy_Query(query);
            destroy_MultiValueKeyMaker(sorter);

            return read_count;
        }
        else
        {
            log.trace("[%s]invalid query [%s]", context.get_name(), str_query);
        }

        return 0;
    }

////////////////////////////////////////////////////////

    Database_QueryParser get_dbqp(string _db_names)
    {
        string[] db_names;
        if (_db_names !is null)
        {
            db_names = split(_db_names, ',');
            int idx = 0;
            foreach (el; db_names)
            {
                if (el[ 0 ] == ' ' || el[ $ ] == ' ')
                    db_names[ idx ] = strip(el);
                idx++;
            }
        }
        else
            db_names = [ "base" ];

        Database_QueryParser dbqp = using_dbqp.get(db_names, null);

        if (dbqp is null)
        {
            dbqp    = new Database_QueryParser();
            dbqp.db = new_Database(&err);

            foreach (el; db_names)
            {
                XapianDatabase _db = open_db(el);
                dbqp.db.add_database(_db, &err);
                if (err != 0)
                    writeln("xapian_reader:add_database:err", err);
            }

            dbqp.qp = new_QueryParser(&err);
            if (err != 0)
                writeln("xapian_reader:new_QueryParser:err", err);

            xapian_stemmer = new_Stem(cast(char *)xapian_lang, cast(uint)xapian_lang.length, &err);
            dbqp.qp.set_stemmer(xapian_stemmer, &err);
            if (err != 0)
                writeln("xapian_reader:set_stemmer:err", err);

            dbqp.qp.set_database(dbqp.db, &err);
            if (err != 0)
                writeln("xapian_reader:set_database:err", err);

            using_dbqp[ db_names.idup ] = dbqp;
        }

        return dbqp;
    }

    private XapianDatabase open_db(string db_name)
    {
        byte           err;
        XapianDatabase db;

        db = opened_db.get(db_name, null);

        if (db is null)
        {
            string path = xapian_search_db_path.get(db_name, null);

            if (path !is null)
                db = new_Database(path.ptr, cast(uint)path.length, xapian_db_type, &err);

            if (err != 0)
                writeln("xapian_reader:new_Database:err", err);
            else
                opened_db[ db_name ] = db;
        }

        return db;
    }

    public void reopen_db()
    {
        foreach (el; using_dbqp.values)
        {
            el.db.reopen(&err);
            if (err != 0)
                writeln("xapian_reader:reopen_db:err", err);

            el.qp.set_database(el.db, &err);
            if (err != 0)
                writeln("xapian_reader:set_database:err", err);
        }
    }

    private void close_db()
    {
        foreach (el; using_dbqp.values)
        {
            el.db.close(&err);
            if (err != 0)
                writeln("xapian_reader:close database:err", err);
        }
        foreach (db; opened_db.values)
        {
            db.close(&err);
            if (err != 0)
                writeln("xapian_reader:close database:err", err);
        }
    }
}

