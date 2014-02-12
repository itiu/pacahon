module az.acl;

private
{
    import std.stdio;
    import std.concurrency;
    import std.file;
    import std.array;

    import bind.xapian_d_header;

    import util.logger;
    import util.utils;
    import util.sgraph;
    import util.cbor;
    import util.cbor8sgraph;
    import util.container;

    import pacahon.context;
    import pacahon.define;
}

logger log;

static this()
{
    log = new logger("pacahon", "log", "server");
}

private const string db_path = "data/xapian-acl";

//////////////// ACLManager

/*********************************************************************
   who   [subject_uid]
   whom  [subject_uid]
   what  [subject_uid]
   right [crud]

   индекс:
                токены: (ids групп whom, ids групп what, C, R, U, D)

*********************************************************************/
byte err;

void acl_manager()
{
    XapianWritableDatabase indexer_db;
    XapianTermGenerator    indexer;

    writeln("SPAWN: ALC manager");    

    try
    {
        mkdir("data");
    }
    catch (Exception ex)
    {
    }

    try
    {
        mkdir(db_path);
    }
    catch (Exception ex)
    {
    }


    bool is_exist_db = exists(db_path);

    // Open the database for update, creating a new database if necessary.
    indexer_db = new_WritableDatabase(db_path.ptr, db_path.length, DB_CREATE_OR_OPEN, &err);
    if (err != 0)
    {
        writeln("ALC manager: SPAWN: FAIL: err=", err);
        return;
    }

    indexer = new_TermGenerator(&err);
    XapianEnquire xapian_enquire = indexer_db.new_Enquire(&err);


    while (true)
    {
        string res = "";
        receive((CMD cmd, string msg, Tid tid_sender)
                {
                    try
                    {
                        if (cmd == CMD.AUTHORIZE)
                        {
//                            writeln ("is AUTHORIZE msg=[", msg, "]");
                            Subject sss = decode_cbor(msg, TYPE);

                            send(tid_sender, msg, thisTid);
                        }
                        else if (cmd == CMD.STORE)
                        {
                            string[] ss_msg = split(msg, ";");

                            if (ss_msg !is null && ss_msg.length == 3)
                            {
                                string L = ss_msg[ 0 ];
                                string righr = ss_msg[ 1 ];
                                string R = ss_msg[ 2 ];
                            }
                        }
                        else if (cmd == CMD.FIND)
                        {
//					writeln ("%1 ", msg);

                            //	writeln ("%%0, rc:", rc);
                            send(tid_sender, res);
                            //	writeln ("%%5");
                        }
                        else
                        {
                            writeln("%3 ", msg);
                            send(tid_sender, "");
                        }
                    }
                    catch (Exception ex)
                    {
                        writeln("EX!", ex.msg);
                    }
                });
    }
}
