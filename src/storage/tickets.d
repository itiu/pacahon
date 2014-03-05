module storage.tickets;

private
{
    import std.stdio, std.concurrency, std.file, std.datetime;

    import bind.lmdb_header;
    
    import onto.sgraph;

    import util.logger;
    import util.utils;
    import util.cbor;    
    import util.cbor8sgraph;

    import pacahon.context;
    import pacahon.define;
}

logger log;

static this()
{
    log = new logger("pacahon", "log", "server");
}

//////////////// TicketManager

void ticket_manager()
{
//    writeln("SPAWN: ticket manager");

    MDB_env *env;
    MDB_dbi dbi;
    MDB_txn *txn;

    string  path = "./data/lmdb-tickets";
//    string  path = "./data/lmdb-subjects";    

    try
    {
        mkdir("data");
    }
    catch (Exception ex)
    {
    }

    try
    {
        mkdir(path);
    }
    catch (Exception ex)
    {
    }

   int rc;
   int rrc;
    rrc = mdb_env_create(&env);
    if (rrc != 0)
        writeln("ERR! mdb_env_create:", fromStringz(mdb_strerror(rrc)));
    else
    {
        // rrc = mdb_env_set_mapsize(env, 10485760 * 512);
        // if (rrc != 0)
        //     writeln("ERR! mdb_env_set_mapsize:", fromStringz(mdb_strerror(rrc)));
        // else
        {
            rrc = mdb_env_open(env, cast(char *)path, MDB_FIXEDMAP, std.conv.octal !664);

            if (rrc != 0)
                writeln("ERR! mdb_env_open:", fromStringz(mdb_strerror(rrc)));
            else
            {
                if (!rrc)
                {
                    rrc = mdb_txn_begin(env, null, 0, &txn);
                    rrc = mdb_dbi_open(txn, null, MDB_CREATE, &dbi);
                }
            }
        }
    }

    // SEND ready
    receive((Tid tid_response_reciever)
            {
                send(tid_response_reciever, true);
            });
    while (true)
    {
        string res = "?";
        receive((CMD cmd, string msg, Tid tid_sender)
                {
                    if (cmd == CMD.STORE)
                    {
                        Subject ticket = decode_cbor(msg);

                        MDB_val key;
                        key.mv_data = cast(char *)ticket.subject;
                        key.mv_size = ticket.subject.length;

                        MDB_val data;
                        data.mv_data = cast(char *)msg;
                        data.mv_size = msg.length;

                        rc = mdb_put(txn, dbi, &key, &data, MDB_NODUPDATA);
                        if (rc == 0)
                            res = "Ok";
                        else
                            res = "Fail:" ~  fromStringz(mdb_strerror(rc));

                        send(tid_sender, res);

                        rc = mdb_txn_commit(txn);
                        rc = mdb_txn_begin(env, null, 0, &txn);
                    }
                    else if (cmd == CMD.FIND)
                    {
                        writeln("%1 ", msg);
                        MDB_txn *txn_r;
                        rc = mdb_txn_begin(env, null, MDB_RDONLY, &txn_r);
                        writeln("%2 tnx begin:", fromStringz(mdb_strerror(rc)));

                        MDB_val key;
                        key.mv_size = msg.length;
                        key.mv_data = cast(char *)msg;

                        MDB_val data;
                        int rc = mdb_get(txn_r, dbi, &key, &data);

                        if (rc == 0)
                            res = cast(string)(data.mv_data[ 0..data.mv_size ]);
                        else
                            res = "?";

                        mdb_txn_abort(txn_r);
                        send(tid_sender, res);
                    }
                    else
                    {
                        send(tid_sender, "?");
                    }
                });
    }
}
