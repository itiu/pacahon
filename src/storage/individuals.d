module storage.individuals;

private
{
    import std.stdio, std.concurrency, std.file;

    import bind.lmdb_header;

    import util.logger;
    import util.utils;
    import util.cbor;
    import util.cbor8sgraph;

    import pacahon.context;
    import pacahon.define;
    import search.vel;

    import onto.sgraph;
}

logger log;

static this()
{
    log = new logger("pacahon", "log", "server");
}

public void individuals_manager()
{
//    writeln("SPAWN: Subject manager");

    MDB_env *env;
    MDB_dbi dbi;

    string  path = individuals_db_path;

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

    int rrc;
    rrc = mdb_env_create(&env);
    if (rrc != 0)
        writeln("individuals_manager:ERR! mdb_env_create:", fromStringz(mdb_strerror(rrc)));
    else
    {
        // rrc = mdb_env_set_mapsize(env, 10485760 * 512);
        // if (rrc != 0)
        //     writeln("ERR! mdb_env_set_mapsize:", fromStringz(mdb_strerror(rrc)));
        // else
        {
            rrc = mdb_env_open(env, cast(char *)path, 0, std.conv.octal !664);

            if (rrc != 0)
                writeln("individuals_manager:ERR! mdb_env_open:", fromStringz(mdb_strerror(rrc)));
        }
    }

    int rc;

    // SEND ready
    receive((Tid tid_response_reciever)
            {
                send(tid_response_reciever, true);
            });

    while (true)
    {
        string res = "";
        receive((CMD cmd, string msg, Tid tid_response_reciever)
                {
                    if (rrc == 0)
                    {
                        try
                        {
                            if (cmd == CMD.STORE)
                            {
                                try
                                {
                                    MDB_txn *txn;
                                    rc = mdb_txn_begin(env, null, 0, &txn);
                                    if (rc != 0)
                                        throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));
                                    rc = mdb_dbi_open(txn, null, MDB_CREATE, &dbi);
                                    if (rc != 0)
                                        throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));

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

                                    mdb_dbi_close(env, dbi);


                                    send(tid_response_reciever, res, thisTid);
                                }
                                catch (Exception ex)
                                {
                                    send(tid_response_reciever, ex.msg, thisTid);
                                }
                            }
                            else if (cmd == CMD.FIND)
                            {
                                int rc;
                                MDB_txn *txn;

                                rc = mdb_txn_begin(env, null, MDB_RDONLY, &txn);
                                if (rc != 0)
                                    throw new Exception("mdb_txn_begin:Fail:" ~  fromStringz(mdb_strerror(rc)));


                                //	writeln ("%%1");
                                MDB_val key;
                                key.mv_size = msg.length;
                                key.mv_data = cast(char *)msg;

                                //	writeln ("%%2");
                                MDB_val data;
                                rc = mdb_get(txn, dbi, &key, &data);

                                if (rc == 0)
                                    res = cast(string)(data.mv_data[ 0..data.mv_size ]);
                                else
                                {
                                    res = "";
//                      writeln ("#1 rc:", rc, ", [", msg, "] , ", fromStringz (mdb_strerror (rc)));
                                }
//                                      writeln ("%%4 msg=", msg , ", res=", res);
                                mdb_txn_abort(txn);

                                send(tid_response_reciever, res, thisTid);
                            }
                            else
                            {
                                //writeln("%3 ", msg);
                                send(tid_response_reciever, "", thisTid);
                            }
                        }
                        catch (Exception ex)
                        {
                            writeln("individuals_manager:EX!", ex.msg);
                        }
                    }
                });
    }
}

public string transform_and_execute_vql_to_lmdb(TTA tta, string p_op, out string l_token, out string op, out double _rd, int level,
                                                ref Subjects res, Context context)
{
    string dummy;
    double rd, ld;

    if (tta.op == "==")
    {
        string ls = transform_and_execute_vql_to_lmdb(tta.L, tta.op, dummy, dummy, ld, level + 1, res, context);
        string rs = transform_and_execute_vql_to_lmdb(tta.R, tta.op, dummy, dummy, rd, level + 1, res, context);
//          writeln ("ls=", ls);
//          writeln ("rs=", rs);
        if (ls == "@")
        {
            string  rr = context.get_subject_as_cbor(rs);
            Subject ss = cbor2subject(rr);
            res.addSubject(ss);
        }
    }
    else if (tta.op == "||")
    {
        if (tta.R !is null)
            transform_and_execute_vql_to_lmdb(tta.R, tta.op, dummy, dummy, rd, level + 1, res, context);

        if (tta.L !is null)
            transform_and_execute_vql_to_lmdb(tta.L, tta.op, dummy, dummy, ld, level + 1, res, context);
    }
    else
    {
//		writeln ("#5 tta.op=", tta.op);
        return tta.op;
    }
    return null;
}
