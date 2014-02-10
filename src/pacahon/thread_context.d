module pacahon.thread_context;

private
{
    import std.json;
    import std.stdio;
    import std.format;
    import std.datetime;
    import std.concurrency;
    import std.conv;
    import std.outbuffer;

    import mq.mq_client;
    import util.container;
    import util.json_ld_parser;
    import util.logger;
    import util.oi : OI;
    import util.utils;
    import util.graph;
    import util.cbor;

    import storage.ticket;
    import bind.xapian_d_header;

    import pacahon.know_predicates;
    import pacahon.define;
    import pacahon.context;
    import pacahon.event_filter;
    import pacahon.bus_event;
    import onto.owl;

//	import search.vql;
}

logger log;

static this()
{
    log = new logger("pacahon", "log", "server");
}

Tid dummy_tid;

class ThreadContext : Context
{
    private JSONValue props;
    public JSONValue get_props()
    {
        return props;
    }


    bool    use_caching_of_documents = false;
    bool    IGNORE_EMPTY_TRIPLE      = false;

    int     _count_command;
    int     _count_message;

    private Tid[ string ] tids;

    this(string property_file_path, string context_name)
    {
        foreach (tid_name; THREAD_LIST)
        {
            tids[ tid_name ] = locate(tid_name);
        }
        //writeln("context:", tids);

        _event_filters      = new Subjects();
        _ba2pacahon_records = new Subjects();

        if (property_file_path !is null)
        {
            try
            {
                props = read_props(property_file_path);
            } catch (Exception ex1)
            {
                throw new Exception("ex! parse params:" ~ ex1.msg, ex1);
            }

            // использование кеша документов
            if (("use_caching_of_documents" in props.object) !is null)
            {
                if (props.object[ "use_caching_of_documents" ].str == "true")
                    use_caching_of_documents = true;
            }

            JSONValue[] _gateways;
            if (("gateways" in props.object) !is null)
            {
                _gateways = props.object[ "gateways" ].array;
                foreach (gateway; _gateways)
                {
                    if (("alias" in gateway.object) !is null)
                    {
                        string[ string ] params;
                        foreach (key; gateway.object.keys)
                            params[ key ] = gateway[ key ].str;

                        string io_alias = gateway.object[ "alias" ].str;

                        Set!OI empty_set;
                        Set!OI gws = gateways.get(io_alias, empty_set);

                        if (gws.size == 0)
                            gateways[ io_alias ] = empty_set;

                        OI oi = new OI();
                        if (oi.connect(params) == 0)
                            writeln("#A1:", oi.get_alias);
                        else
                            writeln("#A2:", oi.get_alias);

                        if (oi.get_db_type == "xapian")
                        {
                            writeln("gateway [", gateway.object[ "alias" ].str, "] is embeded, tid=", tids[ THREAD.xapian_indexer ]);
                            oi.embedded_gateway = tids[ THREAD.xapian_indexer ];
                        }

                        gws ~= oi;
                        gateways[ io_alias ] = gws;
                    }
                }
            }

            Set!OI empty_set;
            Set!OI from_search = gateways.get("from-search", empty_set);
            _vql               = new search.vql.VQL(from_search, this);

            writeln(context_name ~ ": load events");
            pacahon.event_filter.load_events(this);
            writeln(context_name ~ ": load events... ok");

            OWL owl = new OWL();
            owl.load(this);
        }
    }

    public Tid getTid(THREAD tid_name)
    {
        Tid res = tids.get(tid_name, Tid.init);

        assert(res != Tid.init);
        return res;
    }


    public void store_subject(Subject ss, bool prepareEvents = true)
    {
        string res;
        string ss_as_cbor = encode_cbor(ss);

        Tid    tid_subject_manager = getTid(THREAD.subject_manager);

        if (tid_subject_manager != Tid.init)
        {
            send(tid_subject_manager, CMD.STORE, ss_as_cbor, thisTid);
            receive((string msg, Tid from)
                    {
                        if (from == tids[ THREAD.subject_manager ])
                        {
                            res = msg;
                            //writeln("context.store_subject:msg=", msg);
                        }
                    });
        }

        if (res.length == 1 && (res == "C" || res == "U"))
        {
            Tid tid_search_manager = getTid(THREAD.xapian_indexer);

            if (tid_search_manager != Tid.init)
            {
                send(tid_search_manager, CMD.STORE, ss_as_cbor);

                if (prepareEvents == true)
                {
                    Predicate type = ss.getPredicate(rdf__type);


                    if (type.isExistLiteral(event__Event))
                    {
                        // если данный субьект - фильтр событий, то дополнительно сохраним его в кеше
                        event_filters.addSubject(ss);

                        writeln("add new event_filter [", ss.subject, "]");
                    }
                    else
                    {
                        EVENT event_type;

                        if (res == "U")
                            event_type = EVENT.UPDATE;
                        else
                            event_type = EVENT.CREATE;

                        processed_events(ss, event_type, this);
                        bus_event(ss, ss_as_cbor, event_type, this);
                    }
                }
            }
        }
        else
        {
            writeln("Ex! store_subject:", res);
        }
    }

    private string old_msg_key2slot;
    int[ string ] old_key2slot;

    public int[ string ] get_key2slot()
    {
        send(tids[ THREAD.xapian_thread_context ], CMD.GET, CNAME.KEY2SLOT, thisTid);
        string msg = receiveOnly!(string)();

        int[ string ] key2slot;

        if (msg != old_msg_key2slot)
        {
            key2slot         = deserialize_key2slot(msg);
            old_msg_key2slot = msg;
            old_key2slot     = key2slot;
        }
        else
            key2slot = old_key2slot;

        return key2slot;
    }

    public long get_last_update_time()
    {
        send(tids[ THREAD.xapian_thread_context ], CMD.GET, CNAME.LAST_UPDATE_TIME, thisTid);
        long tm = receiveOnly!(long)();
        return tm;
    }

    public Subject get_subject(string uid)
    {
        Subject res = null;

        send(tids[ THREAD.subject_manager ], CMD.FIND, uid, thisTid);
        receive((string msg, Tid from)
                {
                    if (from == tids[ THREAD.subject_manager ])
                    {
                        res = decode_cbor(msg);
                    }
                });

        return res;
    }

    public string get_subject_as_cbor(string uid)
    {
        string res;

        send(tids[ THREAD.subject_manager ], CMD.FIND, uid, thisTid);
        receive((string msg, Tid from)
                {
                    if (from == tids[ THREAD.subject_manager ])
                    {
                        res = msg;
                    }
                });

        return res;
    }

    private string[ string ] prefix_map;
    ref     string[ string ] get_prefix_map()
    {
        return prefix_map;
    }

    @property Tid tid_statistic_data_accumulator()
    {
        return tids[ THREAD.statistic_data_accumulator ];
    }

    @property Tid tid_ticket_manager()
    {
        return tids[ THREAD.ticket_manager ];
    }

    private Ticket *[ string ] _user_of_ticket;
    @property Ticket *[ string ] user_of_ticket()
    {
        return _user_of_ticket;
    }

    private Subjects _ba2pacahon_records;
    @property Subjects ba2pacahon_records()
    {
        return _ba2pacahon_records;
    }

    private Subjects _event_filters;
    @property Subjects event_filters()
    {
        return _event_filters;
    }

    private search.vql.VQL _vql;
    @property search.vql.VQL vql()
    {
        return _vql;
    }

    @property int count_command()
    {
        return _count_command;
    }
    @property int count_message()
    {
        return _count_message;
    }
    @property void count_command(int n)
    {
        _count_command = n;
    }
    @property void count_message(int n)
    {
        _count_message = n;
    }

    bool send_on_authorization(string bson_subject)
    {
        send(tids[ THREAD.acl_manager ], CMD.AUTHORIZE, bson_subject, thisTid);
        return true;
    }

/////////////////////////////////////////////////////////
    private string[ string ] cache__subject_creator;
    int get_subject_creator_size()
    {
        return cast(int)cache__subject_creator.length;
    }

    string get_subject_creator(string pp)
    {
        return cache__subject_creator.get(pp, null);
    }

    void set_subject_creator(string key, string value)
    {
        cache__subject_creator[ key ] = value;
    }
/////////////////////////////////////////////////////////

    mq_client client;

    private   Set!OI[ string ] gateways;

    Set!OI empty_set;
    Set!OI get_gateways(string name)
    {
        return gateways.get(name, empty_set);
    }


    bool authorize(Ticket *ticket, Subject doc)
    {
        return false;        //mandat_manager.ca;
    }

    Ticket *foundTicket(string ticket_id)
    {
        Ticket *tt = user_of_ticket.get(ticket_id, null);

        //	trace_msg[2] = 0;

        if (tt is null)
        {
            string when     = null;
            int    duration = 0;
            send(tid_ticket_manager, CMD.FIND, ticket_id, thisTid);
            string ticket_str = receiveOnly!(string);

            if (ticket_str !is null && ticket_str.length > 128)
            {
                tt = new Ticket;
                Subject ticket = decode_cbor(ticket_str);
//				writeln ("Ticket=",ticket);
                tt.id     = ticket.subject;
                tt.userId = ticket.getFirstLiteral(ticket__accessor);
                when      = ticket.getFirstLiteral(ticket__when);
                string dd = ticket.getFirstLiteral(ticket__duration);
                duration = parse!uint (dd);

//				writeln ("tt.userId=", tt.userId);
            }

            //////////////////////////////
/*
                        tt.id = ticket_id;

                        if(trace_msg[18] == 1)
                        {
                                log.trace("найдем пользователя по сессионному билету ticket=%s", ticket_id);
                                //			printf("T count: %d, %d [µs] start get data\n", count, cast(long) sw.peek().microseconds);
                        }

                        string when = null;
                        int duration = 0;

                        // найдем пользователя по сессионному билету и проверим просрочен билет или нет
                        if(ticket_id !is null && ticket_id.length > 10)
                        {
                                TLIterator it = ts.getTriples(ticket_id, null, null);

                                if(trace_msg[19] == 1)
                                        if(it is null)
                                                log.trace("сессионный билет не найден");

                                foreach(triple; it)
                                {
                                        if(trace_msg[20] == 1)
                                                log.trace("foundTicket: %s %s %s", triple.S, triple.P, triple.O);

                                        if(triple.P == ticket__accessor)
                                        {
                                                tt.userId = triple.O;
                                        }
                                        else if(triple.P == ticket__when)
                                        {
                                                when = triple.O;
                                        }
                                        else if(triple.P == ticket__duration)
                                        {
                                                duration = parse!uint(triple.O);
                                        }
                                        else if(triple.P == ticket__parentUnitOfAccessor)
                                        {
                                                tt.parentUnitIds ~= triple.O;
                                        }

   //					if(tt.userId !is null && when !is null && duration > 10)
   //						break;
                                }

                                delete (it);
                        }
 */
            if (trace_msg[ 20 ] == 1)
                log.trace("foundTicket end");

            if (tt.userId is null)
            {
                if (trace_msg[ 22 ] == 1)
                    log.trace("найденный сессионный билет не полон, пользователь не найден");
            }

            if (tt.userId !is null && (when is null || duration < 10))
            {
                if (trace_msg[ 23 ] == 1)
                    log.trace("найденный сессионный билет не полон, считаем что пользователь не был найден");
                tt.userId = null;
            }

            if (when !is null)
            {
                if (trace_msg[ 24 ] == 1)
                    log.trace("сессионный билет %s Ok, user=%s, when=%s, duration=%d, parentUnitIds=%s", ticket_id, tt.userId, when, duration, text(tt.parentUnitIds));

                // TODO stringToTime очень медленная операция ~ 100 микросекунд
                tt.end_time = stringToTime(when) + duration * 100_000_000_000;                 //? hnsecs?

                _user_of_ticket[ ticket_id ] = tt;
            }
        }
        else
        {
            if (trace_msg[ 17 ] == 1)
                log.trace("тикет нашли в кеше, %s", ticket_id);
        }

        return tt;
    }
}
