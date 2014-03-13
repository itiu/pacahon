module pacahon.context;

private import std.concurrency, std.datetime, std.json;

private import util.container;
private import search.vel;
private import onto.owl;
private import onto.individual;
private import onto.sgraph;
private import pacahon.define;

enum CMD : byte
{
    STORE     = 1,
    PUT       = 1,
    FIND      = 2,
    GET       = 2,
    EXAMINE   = 4,
    AUTHORIZE = 8,
    COMMIT    = 16,
    END_DATA  = 32
}

enum THREAD : string
{
    ticket_manager             = "ticket_manager",
    subject_manager            = "subject_manager",
    acl_manager                = "acl_manager",
    xapian_thread_context      = "xapian_thread_context",
    xapian_indexer             = "xapian_indexer",
    statistic_data_accumulator = "statistic_data_accumulator",
    condition                  = "condition",
    xapian_indexer_commiter    = "xapian_indexer_commiter",
    print_statistic            = "print_statistic",
    interthread_signals        = "interthread_signals"
}

enum ResultCode
{
    OK                    = 200,
    Created               = 201,
    Bad_Request           = 400,
    Forbidden             = 403,
    Not_Found             = 404,
    Internal_Server_Error = 500,
    Not_Implemented       = 501,
    Service_Unavailable   = 503
}

static THREAD[ 8 ] THREAD_LIST =
[
    THREAD.ticket_manager, THREAD.subject_manager, THREAD.acl_manager, THREAD.xapian_thread_context,
    THREAD.xapian_indexer, THREAD.statistic_data_accumulator, THREAD.condition, THREAD.interthread_signals
];

struct Ticket
{
    string id;
    string user_uri;

//    string[] parentUnitIds = new string[ 0 ];

    long end_time;

    immutable this(string _id, string _user_uri, long _end_time)
    {
        id       = _id;
        user_uri = _user_uri;
        end_time = _end_time;
    }

    immutable(Ticket) idup()
    {
        immutable(Ticket) result = immutable Ticket(id, user_uri, end_time);
        return result;
    }
}

interface Context
{
    immutable(Class)[ string ] get_owl_classes();
    immutable(Individual)[ string ] get_onto_as_map_individuals();
    Class *get_class(string ur);
    Property *get_property(string ur);

    public string get_name();
    public JSONValue get_props();

    @property Tid tid_statistic_data_accumulator();
    @property Tid tid_ticket_manager();
    Tid getTid(THREAD tid_name);

    @property Subjects ba2pacahon_records();
    @property Subjects event_filters();
    @property search.vql.VQL vql();

    int get_subject_creator_size();
    string get_subject_creator(string pp);
    void set_subject_creator(string key, string value);

    @property int count_command();
    @property int count_message();
    @property void count_command(int n);
    @property void count_message(int n);

    bool send_on_authorization(string msg);
    bool authorize(string uri, Ticket *ticket, Access request_acess);

    ref string[ string ] get_prefix_map();

    Subject get_subject(string uid);
    string get_subject_as_cbor(string uid);

    public int[ string ] get_key2slot();
    public long get_last_update_time();

    public void store_subject(Subject ss, bool prepareEvents = true);

    ///////////////////////////////////////////// oykumena ///////////////////////////////////////////////////
    public void push_signal(string key, long value);
    public void push_signal(string key, string value);
    public long look_integer_signal(string key);
    public string look_string_signal(string key);

    //////////////////////////////////////////////////// TICKET //////////////////////////////////////////////
    Ticket authenticate(string login, string password);
    Ticket *get_ticket(string ticket_id);
    bool is_ticket_valid(string ticket_id);

    ////////////////////////////////////////////// INDIVIDUALS IO /////////////////////////////////////
    public immutable(Individual)[] get_individuals_via_query(string query_str, Ticket * ticket, byte level = 0);
    public immutable(Individual)[] get_individuals_via_query(string query_str, string sticket, byte level = 0);

    public Individual get_individual(string uri, Ticket *ticket, byte level = 0);
    public Individual get_individual(string uri, string sticket, byte level = 0);

    public ResultCode put_individual(string uri, Individual individual, string ticket);
    public ResultCode post_individual(Individual individual, string ticket);
}

