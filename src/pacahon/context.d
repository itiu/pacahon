module pacahon.context;

private import std.concurrency, std.datetime, std.json;

private import util.container;
private import util.sgraph;
private import io.oi;
private import search.vel;
private import onto.owl;
private import onto.individual;

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

enum EVENT : byte
{
    CREATE = 1,
    UPDATE = 2,
    REMOVE = 3
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
    xapian_indexer_commiter	   = "xapian_indexer_commiter",
    print_statistic			   = "print_statistic"		
}

static THREAD[ 7 ] THREAD_LIST =
[
    THREAD.ticket_manager, THREAD.subject_manager, THREAD.acl_manager, THREAD.xapian_thread_context,
    THREAD.xapian_indexer, THREAD.statistic_data_accumulator, THREAD.condition
];

interface Context
{
    Class *[] owl_classes();
    Class *get_class(string ur);
    Property *get_property(string ur);
    immutable(Individual)[string] get_onto_as_map_individuals ();    

    public string get_name();
    public JSONValue get_props();

    @property Tid tid_statistic_data_accumulator();
    @property Tid tid_ticket_manager();
    Tid getTid(THREAD tid_name);

//	@property StopWatch sw ();
    @property Ticket *[ string ] user_of_ticket();
    @property Subjects ba2pacahon_records();
    @property Subjects event_filters();
    @property search.vql.VQL vql();

    Ticket *foundTicket(string ticket_id);

    int get_subject_creator_size();
    string get_subject_creator(string pp);
    void set_subject_creator(string key, string value);

    Set!OI get_gateways(string name);

    @property int count_command();
    @property int count_message();
    @property void count_command(int n);
    @property void count_message(int n);

    bool send_on_authorization(string msg);

    ref string[ string ] get_prefix_map();

    Subject get_subject(string uid);
    string get_subject_as_cbor(string uid);

    public int[ string ] get_key2slot();
    public long get_last_update_time();

    public void store_subject(Subject ss, bool prepareEvents = true);
}

enum event_type
{
    EVENT_INSERT,
    EVENT_UPDATE,
    EVENT_DELETE
}

struct Ticket
{
    string   id;
    string   userId;
    string[] parentUnitIds = new string[ 0 ];

    long     end_time;
}
