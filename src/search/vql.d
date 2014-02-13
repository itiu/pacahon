module search.vql;

// VEDA QUERY LANG

private
{
    import std.string, std.array, std.stdio, std.conv, std.datetime, std.json, std.outbuffer, std.c.string, std.concurrency;

    import util.container;
    import util.oi;
    import util.logger;
    import util.utils;
    import util.sgraph;
    import util.cbor;
    import util.cbor8sgraph;
    import util.lmultidigraph;
    import util.cbor8lmultidigraph;

    import pacahon.context;
    import pacahon.define;
    import pacahon.know_predicates;

    import search.vel;
    import search.xapian_reader;

    import storage.subject;
}

logger log;

static this()
{
    log = new logger("pacahon", "log", "VQL");
}

static const int RETURN    = 0;
static const int FILTER    = 1;
static const int SORT      = 2;
static const int RENDER    = 3;
static const int AUTHORIZE = 4;
static const int SOURCE    = 5;

static const int XAPIAN = 2;
static const int LMDB   = 3;

class VQL
{
    private string[]                 sections         = [ "return", "filter", "sort", "render", "authorize", "source" ];
    private bool[]                   section_is_found = [ false, false, false, false, false, false ];
    private string[]                 found_sections;

    private                          Set!OI from_search_points;

    private string                   transTable1;
    private Context                  context;
    private XapianSynchronizedReader xr;

    this(Context _context)
    {
        context = _context;
        Set!OI empty_set;
        this(empty_set, _context);
        xr = new XapianSynchronizedReader(_context);
    }

    this(ref Set!OI _from_search_points, Context _context)
    {
        context            = _context;
        xr                 = new XapianSynchronizedReader(_context);
        from_search_points = _from_search_points;
        found_sections     = new string[ 6 ];

        transTable1 = makeTrans(":()-,", "_____");
    }


    public int get(Ticket *ticket, string query_str, LabeledMultiDigraph lmg)
    {
        		StopWatch sw;
        		sw.start();
    	
        split_on_section(query_str);
        int render = 10000;
        try
        {
            if (found_sections[ RENDER ] !is null && found_sections[ RENDER ].length > 0)
                render = parse!int (found_sections[ RENDER ]);
        } catch (Exception ex)
        {
        }
        int count_authorize = 10000;
        try
        {
            if (found_sections[ AUTHORIZE ] !is null && found_sections[ AUTHORIZE ].length > 0)
                count_authorize = parse!int (found_sections[ AUTHORIZE ]);
        } catch (Exception ex)
        {
        }
        string sort;
        if (section_is_found[ SORT ] == true)
            sort = found_sections[ SORT ];
        int type_source = XAPIAN;
        if (found_sections[ SOURCE ] == "xapian")
            type_source = XAPIAN;
        else if (found_sections[ SOURCE ] == "lmdb")
            type_source = LMDB;

        string dummy;
        double d_dummy;
        int    res_count;

        if (type_source == XAPIAN)
        {
            void delegate(string msg) dg;
            void collect_subject(string msg)
            {
            	//writeln ("lmg=", cast(void*)lmg);
                add_cbor_to_lmultidigraph(lmg, msg);
            }
            dg = &collect_subject;

            res_count = xr.get(found_sections[ FILTER ], found_sections[ RETURN ], sort, count_authorize, dg);
        }

          sw.stop();
          long t = cast(long) sw.peek().usecs;
          writeln("execute:", t, " µs");

        return res_count;
    }

    public int get(Ticket *ticket, string query_str, ref Subjects res)
    {
        //		if (ticket !is null)
        //		writeln ("userId=", ticket.userId);

        //		writeln ("@ query_str=", query_str);
        //		StopWatch sw;
        //		sw.start();

        split_on_section(query_str);
        int render = 10000;
        try
        {
            if (found_sections[ RENDER ] !is null && found_sections[ RENDER ].length > 0)
                render = parse!int (found_sections[ RENDER ]);
        } catch (Exception ex)
        {
        }
        int count_authorize = 10000;
        try
        {
            if (found_sections[ AUTHORIZE ] !is null && found_sections[ AUTHORIZE ].length > 0)
                count_authorize = parse!int (found_sections[ AUTHORIZE ]);
        } catch (Exception ex)
        {
        }
        string sort;
        if (section_is_found[ SORT ] == true)
            sort = found_sections[ SORT ];
        int type_source = XAPIAN;
        if (found_sections[ SOURCE ] == "xapian")
            type_source = XAPIAN;
        else if (found_sections[ SOURCE ] == "lmdb")
            type_source = LMDB;

//        OI  from_search_point = null;

//        if (from_search_points.size > 0)
//            from_search_point = from_search_points.items[ 0 ];

        //writeln ("found_sections[SOURCE]=", found_sections[SOURCE]);

        string dummy;
        double d_dummy;
        int    res_count;

        if (type_source == LMDB)
        {
            TTA tta = parse_expr(found_sections[ FILTER ]);
            transform_and_execute_vql_to_lmdb(tta, "", dummy, dummy, d_dummy, 0, res, context);
        }
        else if (type_source == XAPIAN)
        {
            void delegate(string msg) dg;
            void collect_subject(string msg)
            {
                res.addSubject(decode_cbor(msg));
            }
            dg = &collect_subject;

            res_count = xr.get(found_sections[ FILTER ], found_sections[ RETURN ], sort, count_authorize, dg);
        }

//          sw.stop();
//          long t = cast(long) sw.peek().usecs;
//          writeln("execute:", t, " µs");

        return res_count;
    }

    private void remove_predicates(Subject ss, ref string[ string ] fields)
    {
        if (ss is null || ("*" in fields) !is null)
            return;

        // TODO возможно не оптимальная фильтрация
        foreach (pp; ss.getPredicates)
        {
//			writeln ("pp=", pp);
            if ((pp.predicate in fields) is null)
            {
                pp.count_objects = 0;
            }
        }
    }

    private void split_on_section(string query)
    {
        section_is_found[] = false;
        for (int pos = 0; pos < query.length; pos++)
        {
            for (int i = 0; i < sections.length; i++)
            {
                char cc = query[ pos ];
                if (section_is_found[ i ] == false)
                {
                    int j     = 0;
                    int t_pos = pos;
                    while (sections[ i ][ j ] == cc && t_pos < query.length && j < sections[ i ].length)
                    {
                        j++;
                        t_pos++;

                        if (t_pos >= query.length || j >= sections[ i ].length)
                            break;

                        cc = query[ t_pos ];
                    }

                    if (j == sections[ i ].length)
                    {
                        pos = t_pos;
                        // нашли
                        section_is_found[ i ] = true;

                        while (query[ pos ] != '{' && pos < query.length)
                            pos++;
                        pos++;

                        while (query[ pos ] == ' ' && pos < query.length)
                            pos++;

                        int bp = pos;
                        while (query[ pos ] != '}' && pos < query.length)
                            pos++;
                        pos--;

                        while (query[ pos ] == ' ' && pos > bp)
                            pos--;
                        int ep = pos + 1;

                        found_sections[ i ] = query[ bp .. ep ];
                    }
                }
            }
        }
    }
}
