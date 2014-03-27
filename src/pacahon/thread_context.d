module pacahon.thread_context;

private
{
    import std.json, std.stdio, std.format, std.datetime, std.concurrency, std.conv, std.outbuffer, std.string, std.uuid;

    import io.mq_client;
    import util.container;
    import util.json_ld_parser;
    import util.logger;
    import util.utils;
    import util.cbor;
    import util.cbor8sgraph;
    import util.cbor8individual;

//    import storage.tickets;
    import bind.xapian_d_header;

    import pacahon.know_predicates;
    import pacahon.define;
    import pacahon.context;
    import pacahon.bus_event;
    import pacahon.interthread_signals;

    import onto.owl;
    import onto.individual;
    import onto.sgraph;
    import onto.resource;
    //	import search.vql;
    import storage.lmdb_storage;
    import az.acl;
    
    import bind.v8d_header;
}

logger log;

static this()
{
    log = new logger("pacahon", "log", "server");
}

Tid dummy_tid;

class ThreadContext : Context
{
    /// deprecated vvv
    private Ticket *[ string ] user_of_ticket;
    private          string[ string ] cache__subject_creator;
    private bool     use_caching_of_documents = false;
    private Subjects _ba2pacahon_records;
    /// deprecated ^^^

    // // // authorization
    private Authorization acl_indexes;

    ScriptVM               script_vm;

    private OWL       owl;
    private JSONValue props;

    private int       _count_command;
    private int       _count_message;
    private string    name;

    private           Tid[ string ] tids;

    private string    old_msg_key2slot;
    private int[ string ] old_key2slot;

    private                string[ string ] prefix_map;
    private Subjects       _event_filters;

    private LmdbStorage    inividuals_storage;
    private search.vql.VQL _vql;

    this(string property_file_path, string context_name)
    {
        inividuals_storage = new LmdbStorage(individuals_db_path);
        acl_indexes        = new Authorization(acl_indexes_db_path);

        name = context_name;
        writeln("CREATE NEW CONTEXT:", context_name);

        foreach (tid_name; THREAD_LIST)
        {
            tids[ tid_name ] = locate(tid_name);
        }

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

            _vql = new search.vql.VQL(this);

            //writeln(context_name ~ ": load events");
            //pacahon.event_filter.load_events(this);
            //writeln(context_name ~ ": load events... ok");

            owl = new OWL(this);
            owl.load();
        }
    }

    ScriptVM get_ScriptVM()
    {
        if (script_vm is null)
        {
            try
            {
                script_vm = new_ScriptVM();
            }
            catch (Exception ex)
            {
                writeln("EX!get_ScriptVM ", ex.msg);
            }
        }

        return script_vm;
    }
    
    string execute_script (string str_js)
    {
    	try
    	{
    		auto str_js_script = script_vm.compile(cast(char *)(cast(char[])str_js));
    		if (str_js_script !is null)
    			script_vm.run(str_js_script); 
    		else
    			writeln ("Script is invalid");   	    		
    	}
    	catch (Exception ex)
    	{
                 writeln("EX!executeScript ", ex.msg);   		
    	}
    	return "";
    }    

    bool authorize(string uri, Ticket *ticket, Access request_acess)
    {
        return acl_indexes.authorize(uri, ticket, request_acess);
    }

    public JSONValue get_props()
    {
        return props;
    }

    public string get_name()
    {
        return name;
    }

    public immutable(Class)[ string ] get_owl_classes()
    {
        if (owl !is null)
        {
            owl.check_for_reload();
            return owl.owl_classes;
        }
        else
            return (immutable(Class)[ string ]).init;
    }

/*
    Class *[] owl_classes()
    {
        if (owl !is null)
        {
                owl.check_for_reload();
            return owl.class_2_idx.values;
        }
        else
            return (Class *[]).init;
    }
 */
    public Class *get_class(string uri)
    {
        if (owl !is null)
        {
            owl.check_for_reload();
            return owl.getClass(uri);
        }
        else
            return null;
    }

    public Property *get_property(string uri)
    {
        if (owl !is null)
        {
            owl.check_for_reload();
            return owl.getProperty(uri);
        }
        else
            return null;
    }

    public immutable(Individual)[ string ] get_onto_as_map_individuals()
    {
        if (owl !is null)
        {
            owl.check_for_reload();
            return owl.individuals;
        }
        else
            return (immutable(Individual)[ string ]).init;
    }

///////////////////////////////////////////// oykumena ///////////////////////////////////////////////////

    public void push_signal(string key, long value)
    {
        Tid tid_interthread_signals = getTid(THREAD.interthread_signals);

        if (tid_interthread_signals != Tid.init)
        {
            send(tid_interthread_signals, CMD.PUT, key, value);
        }
    }

    public void push_signal(string key, string value)
    {
        Tid tid_interthread_signals = getTid(THREAD.interthread_signals);

        if (tid_interthread_signals != Tid.init)
        {
            send(tid_interthread_signals, CMD.PUT, key, value);
        }
    }

    public long look_integer_signal(string key)
    {
        Tid myTid                   = thisTid;
        Tid tid_interthread_signals = getTid(THREAD.interthread_signals);

        if (tid_interthread_signals !is Tid.init)
        {
            send(tid_interthread_signals, CMD.GET, key, DataType.Integer, myTid);

            long res;

            receive((long msg)
                    {
                        res = msg;
                    });

            return res;
        }
        return 0;
    }

    public string look_string_signal(string key)
    {
        Tid myTid                   = thisTid;
        Tid tid_interthread_signals = getTid(THREAD.interthread_signals);

        if (tid_interthread_signals !is Tid.init)
        {
            send(tid_interthread_signals, CMD.GET, key, DataType.String, myTid);

            string res;

            receive((string msg)
                    {
                        res = msg;
                    });

            return res;
        }
        return null;
    }

///////////////////////////////////////////////////////////////////////////////////////////////

    public Tid getTid(THREAD tid_name)
    {
        Tid res = tids.get(tid_name, Tid.init);

        assert(res != Tid.init);
        return res;
    }

    public void store_subject(Subject ss, bool prepareEvents = true)
    {
        string     ss_as_cbor = subject2cbor(ss);
        Individual indv;

        cbor2individual(&indv, ss_as_cbor);
        store_individual(indv, prepareEvents);
    }

    public int[ string ] get_key2slot()
    {
        int[ string ] key2slot;
        send(tids[ THREAD.xapian_thread_context ], CMD.GET, CNAME.KEY2SLOT, thisTid);
//        string msg = receiveOnly!(string)();
        receive((string msg)
                {
                    if (msg != old_msg_key2slot)
                    {
                        key2slot = deserialize_key2slot(msg);
                        old_msg_key2slot = msg;
                        old_key2slot = key2slot;
                    }
                    else
                        key2slot = old_key2slot;

                    //writeln ("@get_key2slot=", key2slot);
                });

        return key2slot;
    }

    public long get_last_update_time()
    {
        long lut;

        send(tids[ THREAD.xapian_thread_context ], CMD.GET, CNAME.LAST_UPDATE_TIME, thisTid);
        receive((long tm)
                {
                    lut = tm;
                });
//        long tm = receiveOnly!(long)();
        return lut;
    }

    public Subject get_subject(string uri)
    {
        return inividuals_storage.find_subject(uri);
    }

    public string get_subject_as_cbor(string uri)
    {
        return inividuals_storage.find(uri);
    }

    ref string[ string ] get_prefix_map()
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

    @property Subjects ba2pacahon_records()
    {
        return _ba2pacahon_records;
    }

    @property Subjects event_filters()
    {
        return _event_filters;
    }

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
/*
    bool authorize(Ticket *ticket, Subject doc)
    {
        return false;        //mandat_manager.ca;
    }
 */
    ///////////////////////////////////////////////////////// TICKET //////////////////////////////////////////////

    bool is_ticket_valid(string ticket_id)
    {
//        writeln("@is_ticket_valid, ", ticket_id);
        Ticket *ticket = get_ticket(ticket_id);

        if (ticket is null)
        {
            return false;
        }

        SysTime now = Clock.currTime();
        if (now.stdTime < ticket.end_time)
            return true;

        return false;
    }

    Ticket authenticate(string login, string password)
    {
        writeln("@authenticate, login=", login, ", password=", password);

        Ticket                  ticket;
        Ticket                  *sys_ticket;

        immutable(Individual)[] candidate_users = get_individuals_via_query("'" ~ veda_schema__login ~ "' == '" ~ login ~ "'", sys_ticket);
        foreach (user; candidate_users)
        {
            string user_id = user.getFirstResource(veda_schema__owner).uri;
            if (user_id is null)
                continue;

            iResources pass = user.resources.get(veda_schema__password, _empty_iResources);
            if (pass.length > 0 && pass[ 0 ].data == password)
            {
                Subject new_ticket = new Subject;
                new_ticket.addPredicate(rdf__type, ticket__Ticket);

                UUID new_id = randomUUID();
                new_ticket.subject = new_id.toString();

                new_ticket.addPredicate(ticket__accessor, user_id);
                new_ticket.addPredicate(ticket__when, getNowAsString());
                new_ticket.addPredicate(ticket__duration, "40000");

                writeln("@authenticate, ticket__accessor=", user_id);

                // store ticket
                string ss_as_cbor = subject2cbor(new_ticket);

                Tid    tid_ticket_manager = getTid(THREAD.ticket_manager);

                if (tid_ticket_manager != Tid.init)
                {
                    send(tid_ticket_manager, CMD.STORE, ss_as_cbor, thisTid);
                    receive((EVENT ev, Tid from)
                            {
                                if (from == tids[ THREAD.ticket_manager ])
                                {
//                            res = msg;
                                    //writeln("context.store_subject:msg=", msg);
                                    subject2Ticket(new_ticket, &ticket);
                                    user_of_ticket[ ticket.id ] = &ticket;
                                }
                            });
                }

                return ticket;
            }
        }

        return Ticket.init;
    }

    Ticket *get_ticket(string ticket_id)
    {
        Ticket *tt = user_of_ticket.get(ticket_id, null);

        if (tt is null)
        {
            string when     = null;
            int    duration = 0;
            send(tid_ticket_manager, CMD.FIND, ticket_id, thisTid);

            receive((string ticket_str, Tid from)
                    {
                        if (ticket_str !is null && ticket_str.length > 128)
                        {
                            tt = new Ticket;
                            Subject ticket = cbor2subject(ticket_str);
                            subject2Ticket(ticket, tt);
                            user_of_ticket[ tt.id ] = tt;

//				writeln ("Ticket=",ticket);
                        }
                    });
        }
        else
        {
            if (trace_msg[ 17 ] == 1)
                log.trace("тикет нашли в кеше, %s", ticket_id);
        }

        return tt;
    }

    private void subject2Ticket(Subject ticket, Ticket *tt)
    {
        string when;
        long   duration;

        tt.id       = ticket.subject;
        tt.user_uri = ticket.getFirstLiteral(ticket__accessor);
        when        = ticket.getFirstLiteral(ticket__when);
        string dd = ticket.getFirstLiteral(ticket__duration);
        duration = parse!uint (dd);

//				writeln ("tt.userId=", tt.userId);

        if (tt.user_uri is null)
        {
            if (trace_msg[ 22 ] == 1)
                log.trace("найденный сессионный билет не полон, пользователь не найден");
        }

        if (tt.user_uri !is null && (when is null || duration < 10))
        {
            if (trace_msg[ 23 ] == 1)
                log.trace(
                          "найденный сессионный билет не полон, считаем что пользователь не был найден");
            tt.user_uri = null;
        }

        if (when !is null)
        {
            if (trace_msg[ 24 ] == 1)
                log.trace("сессионный билет %s Ok, user=%s, when=%s, duration=%d", tt.id, tt.user_uri, when,
                          duration);

            // TODO stringToTime очень медленная операция ~ 100 микросекунд
            tt.end_time = stringToTime(when) + duration * 10_000_000;                     //? hnsecs?
        }
    }

    ////////////////////////////////////////////// INDIVIDUALS IO /////////////////////////////////////

    immutable(Individual)[] get_individuals_via_query(string query_str, string sticket, byte level = 0)
    {
        Ticket *ticket = get_ticket(sticket);

        return get_individuals_via_query(query_str, ticket, level);
    }

    immutable(Individual)[] get_individuals_via_query(string query_str, Ticket * ticket, byte level = 0)
    {
        immutable(Individual)[] res;
        if (query_str.indexOf(' ') <= 0)
            query_str = "'*' == '" ~ query_str ~ "'";

        //writeln (query_str);
        vql.get(ticket, query_str, null, null, 10, 10000, res);
        return res;
    }

    Individual get_individual(string uri, string sticket, byte level = 0)
    {
        Ticket *ticket = get_ticket(sticket);

        return get_individual(uri, ticket, level);
    }

    Individual get_individual(string uri, Ticket *ticket, byte level = 0)
    {
        Individual individual = Individual();

        string     individual_as_cbor = get_subject_as_cbor(uri);

        if (individual_as_cbor !is null && individual_as_cbor.length > 1)
        {
            cbor2individual(&individual, individual_as_cbor);

            while (level > 0)
            {
                foreach (key, values; individual.resources)
                {
                    Individuals ids = Individuals.init;
                    foreach (ruri; values)
                    {
                        ids ~= get_individual(ruri.uri, ticket, level);
                    }
                    individual.set_individuals (key, ids); 
                }

                level--;
            }
        }

        return individual;
    }

    public void store_individual(Individual indv, bool prepareEvents = true)
    {
        string ss_as_cbor = individual2cbor(&indv);
        EVENT  ev         = EVENT.NONE;

        Tid    tid_subject_manager = getTid(THREAD.subject_manager);

        if (tid_subject_manager != Tid.init)
        {
            send(tid_subject_manager, CMD.STORE, ss_as_cbor, thisTid);
            receive((EVENT _ev, Tid from)
                    {
                        if (from == tids[ THREAD.subject_manager ])
                            ev = _ev;
                    });
        }

        if (ev == EVENT.CREATE || ev == EVENT.UPDATE)
        {
            Tid tid_search_manager = getTid(THREAD.xapian_indexer);

            if (tid_search_manager != Tid.init)
            {
                send(tid_search_manager, CMD.STORE, ss_as_cbor);

                if (prepareEvents == true)
                    bus_event(indv, ss_as_cbor, ev, this);
            }
        }
        else
        {
            writeln("Ex! store_subject:", ev);
        }
    }

    ResultCode put_individual(string uri, Individual individual, string ticket)
    {
        store_individual(individual);
        return ResultCode.OK;
    }

    ResultCode post_individual(Individual individual, string ticket)
    {
        return ResultCode.Not_Implemented;
    }
}
