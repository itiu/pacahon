module pacahon.context;

private import std.concurrency;
private import std.datetime;
private import std.json;

private import util.container;
private import util.graph;
private import util.oi;
private import search.vel;
private import onto.doc_template;

enum CMD : byte
{
    STORE     = 1,
    PUT       = 1,
    FOUND     = 2,
    GET       = 2,
    EXAMINE   = 4,
    AUTHORIZE = 8
}

enum EVENT : byte
{
    CREATE = 1,
    UPDATE = 2,
    REMOVE = 3
}

enum thread : string
{
    ticket_manager             = "ticket_manager",
    subject_manager            = "subject_manager",
    acl_manager                = "acl_manager",
    xapian_thread_io           = "xapian_thread_io",
    xapian_indexer             = "xapian_indexer",
    statistic_data_accumulator = "statistic_data_accumulator",
    condition                  = "condition"
}

interface Context
{
    public JSONValue get_props();

    Tid get_tid_subject_manager();
    Tid get_tid_search_manager();
    @property Tid tid_statistic_data_accumulator();
    @property Tid tid_ticket_manager();
    Tid getTid(thread tid_name);

//	@property StopWatch sw ();
    @property Ticket *[ string ] user_of_ticket();
    @property GraphCluster ba2pacahon_records();
    @property GraphCluster event_filters();
    @property search.vql.VQL vql();

    DocTemplate get_template(string uid, string v_dc_identifier, string v_docs_version);
    void set_template(DocTemplate tmpl, string tmpl_subj, string v_id);

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
