//////////////////////////////////////////// USE XAPIAN SEARCH ///////////////////////////////////////////////////////////////
module search.xapian_reader;

import std.concurrency, std.outbuffer, std.datetime, std.conv, std.typecons, std.stdio, std.string, std.file;

import bind.xapian_d_header;
import util.utils;
import util.cbor;
import util.cbor8sgraph;

import pacahon.define;
import pacahon.know_predicates;
import pacahon.context;
//import storage.subject;
import search.vel;
import search.xapian_vql;

import onto.sgraph;

byte err;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
interface SearchReader
{
    public int get(Ticket *ticket, string str_query, string fields, string sort, int count_authorize,
                   void delegate(string uri, string cbor_subject) add_out_element);
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
        Tid tid_subject_manager = context.getTid(THREAD.subject_manager);

        send(context.getTid(THREAD.xapian_indexer), CMD.FIND, str_query, fields, sort, count_authorize, thisTid);

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
//    private static long refresh_db_timeout = 10000000 * 20;
    private long   last_time_signal       = 0;
    private long   last_time_check_signal = 0;

    bool check_for_reload()
    {
        long now = Clock.currStdTime() / 10000;

        if (now - last_time_check_signal > 10000 || now - last_time_check_signal < 0)
        {
            last_time_check_signal = now;

            long now_time_signal = context.get_last_update_time();
            if (now_time_signal - last_time_signal > 10000 || now_time_signal - last_time_signal < 0)
            {
                last_time_signal = now_time_signal;
                writeln("REOPEN");
                close_db();
                open_db();
                return true;
            }
        }
        return false;
    }


    public int get(Ticket *ticket, string str_query, string str_fields, string sort, int count_authorize,
                   void delegate(string uri, string cbor_subject) add_out_element)
    {
        //writeln ("SEARCH FROM XAPIAN");
        check_for_reload();

        int[ string ] key2slot = context.get_key2slot();
        //writeln ("key2slot=", key2slot);

        auto        fields = get_fields(str_fields);

        XapianQuery query;
        TTA         tta = parse_expr(str_query);
        transform_vql_to_xapian(tta, "", dummy, dummy, query, key2slot, d_dummy, 0, xapian_qp);

        if (query !is null)
        {
            int count = 0;
            xapian_enquire = xapian_db.new_Enquire(&err);

            XapianMultiValueKeyMaker sorter = get_sorter(sort, key2slot);

            int                      state = -1;
            while (state == -1)
            {
                state = exec_xapian_query_and_queue_authorize(ticket, query, sorter, xapian_enquire, count_authorize, fields,
                                                              add_out_element, context);
                if (state == -1)
                {
                    close_db();
                    open_db();
                    xapian_enquire = xapian_db.new_Enquire(&err);
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

        return 0;
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

        xapian_qp.set_database(xapian_db, &err);
        if (err != 0)
            writeln("VQL:set_database:err", err);
//		xapian_qp.set_stemming_strategy(stem_strategy.STEM_SOME, &err);
    }

    private void close_db()
    {
        xapian_db.close(&err);
    }
}

