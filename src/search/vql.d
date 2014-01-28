module search.vql;

// VEDA QUERY LANG

private
{
    import std.string;
    import std.array;
    import std.stdio;
    import std.conv;
    import std.datetime;
    import std.json;
    import std.outbuffer;
    import std.c.string;
    import std.concurrency;

    import util.container;
    import util.oi;
    import util.logger;
    import util.utils;
    import util.graph;
    import util.cbor;

    import bind.xapian_d_header;

    import pacahon.context;
    import pacahon.define;
    import pacahon.know_predicates;

    import search.vel;
    import search.xapian;
    
    import storage.subject;
    //import az.condition;
}

logger log;

static this()
{
    log = new logger("pacahon", "log", "VQL");
}

class VQL
{
    const int              RETURN    = 0;
    const int              FILTER    = 1;
    const int              SORT      = 2;
    const int              RENDER    = 3;
    const int              AUTHORIZE = 4;
    const int              SOURCE    = 5;

    const int              XAPIAN = 2;
    const int              LMDB = 3;

    private string[]       sections         = [ "return", "filter", "sort", "render", "authorize", "source" ];
    private bool[]         section_is_found = [ false, false, false, false, false, false ];
    private string[]       found_sections;

    private                Set!OI from_search_points;

    private XapianDatabase xapian_db;
	private XapianStem xapian_stemmer;
    private string         xapian_lang = "russian";
    private XapianEnquire  xapian_enquire;
    private XapianQueryParser xapian_qp;
    
    private int[ string ] key2slot;
    private string transTable1;
    private Context context;

    this(Context _context)
    {
        Set!OI empty_set;
        this(empty_set, _context);
    }

    this(ref Set!OI _from_search_points, Context _context)
    {
    	context = _context;
        from_search_points = _from_search_points;
        found_sections     = new string[ 6 ];

        open_db ();

        transTable1 = makeTrans(":()-,", "_____");

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
    }

    private void open_db ()
    {
        byte err;
		
        xapian_db = new_Database(xapian_search_db_path.ptr, xapian_search_db_path.length, &err);
        if (err != 0)
        	writeln ("VQL:new_Database:err", err);

		xapian_qp = new_QueryParser (&err);
        if (err != 0)
        	writeln ("VQL:new_QueryParser:err", err);
        	
		xapian_stemmer = new_Stem(cast(char*)xapian_lang, xapian_lang.length, &err);
		xapian_qp.set_stemmer(xapian_stemmer, &err);
        if (err != 0)
        	writeln ("VQL:set_stemmer:err", err);
        	
		xapian_qp.set_database(xapian_db, &err);
        if (err != 0)
        	writeln ("VQL:set_database:err", err);
//		xapian_qp.set_stemming_strategy(stem_strategy.STEM_SOME, &err);    	
    }
    
    private void close_db ()
    {
    	xapian_db.close (&err);
    }

    static long refresh_db_timeout = 10000000 * 20;  
    long prev_update_time;
    
    //Clock.currTime().stdTime ()

    public int get(Ticket *ticket, string query_str, ref GraphCluster res)
    {
        key2slot = context.get_key2slot();
        long last_update_time = context.get_last_update_time();
        if (last_update_time - prev_update_time > refresh_db_timeout)
        {
        	writeln ("REOPEN");
        	close_db ();
        	open_db ();
        }
//    	writeln ("last_update_time=", last_update_time);
//    	writeln ("prev_update_time=", prev_update_time);
    	prev_update_time = last_update_time;
    	
    	//writeln ("key2slot=", key2slot);
        //		if (ticket !is null)
        //		writeln ("userId=", ticket.userId);
        
        //		writeln("VQL:get ticket=", ticket, ", authorizer=", authorizer);
        //		writeln ("query_str=", query_str);
        //		StopWatch sw;
        //		sw.start();

        split_on_section(query_str);
        //		sw.stop();
        //		long t = cast(long) sw.peek().usecs;
        //		writeln ("found_sections", found_sections);
        //		writeln("split:", t, " µs");

        TTA tta;
        tta = parse_expr(found_sections[ FILTER ]);

        int render = 10000;
        try
        {
            if (found_sections[ RENDER ] !is null && found_sections[ RENDER ].length > 0)
                render = parse!int (found_sections[ RENDER ]);
        } catch (Exception ex)
        {
        }

        int authorize = 10000;
        try
        {
            if (found_sections[ AUTHORIZE ] !is null && found_sections[ AUTHORIZE ].length > 0)
                authorize = parse!int (found_sections[ AUTHORIZE ]);
        } catch (Exception ex)
        {
        }

        string[ string ] fields;

        string returns[];

        if (section_is_found[ RETURN ] == true)
        {
            returns = split(found_sections[ RETURN ], ",");

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

        int type_source;
        OI  from_search_point = null;

        if (from_search_points.size > 0)
            from_search_point = from_search_points.items[ 0 ];

        //writeln ("found_sections[SOURCE]=", found_sections[SOURCE]);

        if (found_sections[ SOURCE ] == "xapian")
            type_source = XAPIAN;
        else if (found_sections[ SOURCE ] == "lmdb")
            type_source = LMDB;

        string      dummy;
        double      d_dummy;

        if (type_source == LMDB)
        {
         	transform_and_execute_vql_to_lmdb(tta, "", dummy, dummy, d_dummy, 0, res, context);
        }
        else if (type_source == XAPIAN)
        {
			//writeln ("SEARCH FROM XAPIAN");
            XapianQuery query;

            transform_vql_to_xapian(tta, "", dummy, dummy, query, key2slot, d_dummy, 0, xapian_qp);

            if (query !is null)
            {
                int count = 0;
                xapian_enquire = xapian_db.new_Enquire(&err);

                XapianMultiValueKeyMaker sorter;

                if (section_is_found[ SORT ] == true)
                {
                    sorter = new_MultiValueKeyMaker(&err);
                    foreach (field; split(found_sections[ SORT ], ","))
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

                int state = -1;
                while (state == -1)
                {
                    state = execute_xapian_query(query, sorter, authorize, fields, res, context);
                    if (state == -1)
                    {
                    	close_db ();
                    	open_db ();
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
        return 0;
    }

    private void remove_predicates(Subject ss, ref string[ string ] fields)
    {
        if (ss is null || ("*" in fields) !is null)
            return;

        // TODO возможно не оптимальная фильтрация
        foreach (pp; ss.getPredicates)
        {
//		writeln ("pp=", pp);
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

    int execute_xapian_query(XapianQuery query, XapianMultiValueKeyMaker sorter, int count_authorize, ref string[ string ] fields, ref GraphCluster res, Context context)
    {
        int read_count = 0;

//        writeln ("query=", get_query_description (query));

        byte err;

        xapian_enquire.set_query(query, &err);
        if (sorter !is null)
            xapian_enquire.set_sort_by_key(sorter, true, &err);

        XapianMSet matches = xapian_enquire.get_mset(0, count_authorize, &err);
        if (err < 0)
            return err;

//        	    writeln ("found =",  matches.get_matches_estimated(&err));
//        	    writeln ("matches =",  matches.size (&err));

        if (matches !is null)
        {
            Tid                tid_subject_manager = context.get_tid_subject_manager();

            XapianMSetIterator it = matches.iterator(&err);

            while (it.is_next(&err) == true)
            {
                char   *data_str;
                uint   *data_len;
                it.get_document_data(&data_str, &data_len, &err);
                string subject_str = cast(immutable)data_str[ 0..*data_len ].dup;
//				writeln ("Subject_id:", subject_str);
                send(tid_subject_manager, CMD.FOUND, subject_str, thisTid);

                it.next(&err);
                read_count++;
            }

            destroy_MSetIterator(it);
            destroy_MSet(matches);

            byte[ string ] hash_of_subjects;

            // Фаза I, получим субьекты из хранилища и отправим их на авторизацию, 
            // тут же получение из авторизации и формирование части ответа
            for (int i = 0; i < read_count * 2; i++)
            {
                receive((string msg, Tid from)
                        {
                            if (from == context.get_tid_subject_manager())
                            {
                                context.send_on_authorization(msg);
                            }
                            else
                            {
                                if (msg.length > 16)
                                {                               	
//                                    writeln ("!!!", msg);
                                    Subject sss = decode_cbor(msg, LINKS);

                                    if (sss !is null)
                                    {
                                    	// отправить в исходящий поток
                                    	res.addSubject (decode_cbor(msg));
                                    	
                                    	hash_of_subjects[sss.subject] = 1;

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
                    send(tid_subject_manager, CMD.FOUND, key, thisTid);
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
                            	res.addSubject (decode_cbor(msg));
                            }
                        });
            }
        }

        return read_count;
    }
}
