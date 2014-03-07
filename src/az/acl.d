module az.acl;

private
{
    import std.stdio, std.concurrency, std.file, std.datetime, std.array;

    import bind.lmdb_header;

    import onto.sgraph;

    import util.logger;
    import util.utils;
    import util.cbor;
    import util.cbor8sgraph;

    import pacahon.context;
    import pacahon.define;
}

private const string path = "data/acl-indexes";

//////////////// ACLManager

/*********************************************************************
   permissionObject uri
   permissionSubject uri
   permission

   индекс:
                permissionObject + permissionSubject
*********************************************************************/
byte err;


logger log;

static this()
{
    log = new logger("pacahon", "log", "server");
}

//////////////// TicketManager

void acl_manager()
{
//    writeln("SPAWN: acl manager");

    MDB_env *env;
    MDB_dbi dbi;
    MDB_txn *txn;

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
        receive((CMD cmd, string msg, Tid tid_response_reciever)
                {
                    if (cmd == CMD.AUTHORIZE)
                    {
//                            writeln ("is AUTHORIZE msg=[", msg, "]");
                        Subject sss = cbor2subject(msg, TYPE);

                        send(tid_response_reciever, msg, thisTid);
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
                    if (cmd == CMD.STORE)
                    {
                        try
                        {
//                                  writeln ("#b");
                            Subject graph = cbor2subject(msg);

                            MDB_val key;
                            key.mv_data = cast(char *)graph.subject;
                            key.mv_size = graph.subject.length;

                            MDB_val data;

                            // проверим был есть ли такой субьект в базе
                            int rc = mdb_get(txn, dbi, &key, &data);
                            if (rc == 0)
                                res = "U";
                            else
                                res = "C";

                            data.mv_data = cast(char *)msg;
                            data.mv_size = msg.length;

                            rc = mdb_put(txn, dbi, &key, &data, 0);
                            if (rc != 0)
                                throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));

                            rc = mdb_txn_commit(txn);
                            if (rc != 0)
                                throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));

                            rc = mdb_txn_begin(env, null, 0, &txn);
                            if (rc != 0)
                                throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));

                            send(tid_response_reciever, res, thisTid);
//                                  writeln ("#e");
                        }
                        catch (Exception ex)
                        {
                            send(tid_response_reciever, ex.msg, thisTid);
                        }
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
                        send(tid_response_reciever, res);
                    }
                    else
                    {
                        send(tid_response_reciever, "?");
                    }
                });
    }
}
