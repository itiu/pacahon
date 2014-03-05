module storage.individuals;

private
{
    import std.stdio;
    import std.concurrency;
    import std.file;

    import bind.lmdb_header;

    import util.logger;
    import util.utils;
    import util.sgraph;
    import util.cbor;
    import util.cbor8sgraph;

    import pacahon.context;
    import pacahon.define;
    import search.vel;
}

logger log;

static this()
{
    log = new logger("pacahon", "log", "server");
}


public void subject_manager()
{
//    writeln("SPAWN: Subject manager");

    MDB_env *env;
    MDB_dbi dbi;
    MDB_txn *txn;

    string  path = "./data/lmdb-subjects";

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
//                                	writeln ("#b");
                                    Subject graph = decode_cbor(msg);

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
//                                	writeln ("#e");
                                }
                                catch (Exception ex)
                                {
                                    send(tid_response_reciever, res, thisTid);
                                }
                            }
                            else if (cmd == CMD.FIND)
                            {
//					writeln ("%1 ", msg);
//					MDB_txn *txn_r;
//					rc = mdb_txn_begin(env, null, MDB_RDONLY, &txn_r);

                                //	writeln ("%%0, rc:", rc);
                                //if (rc != 0)
                                   // writeln("%2 tnx begin:", fromStringz(mdb_strerror(rc)));
                                //else
                                {
                                    //	writeln ("%%1");
                                    MDB_val key;
                                    key.mv_size = msg.length;
                                    key.mv_data = cast(char *)msg;

                                    //	writeln ("%%2");
                                    MDB_val data;
                                    int rc = mdb_get(txn, dbi, &key, &data);

                                    if (rc == 0)
                                        res = cast(string)(data.mv_data[ 0..data.mv_size ]);
                                    else
                                    {
                                        res = "";
//                      writeln ("#1 rc:", rc, ", [", msg, "] , ", fromStringz (mdb_strerror (rc)));
                                    }
//                                      writeln ("%%4 msg=", msg , ", res=", res);

                                    send(tid_response_reciever, res, thisTid);
//					mdb_txn_abort(txn_r);
                                }
//                                  writeln ("%%5");
                            }
                            else
                            {
                                writeln("%3 ", msg);
                                send(tid_response_reciever, "", thisTid);
                            }
                        }
                        catch (Exception ex)
                        {
                            writeln("EX!", ex.msg);
                        }
                    }
                });
    }
}

public string transform_and_execute_vql_to_lmdb(TTA tta, string p_op, out string l_token, out string op, out double _rd, int level, ref Subjects res, Context context)
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
            Subject ss = decode_cbor(rr);
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
