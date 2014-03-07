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
    import storage.lmdb_storage;
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
    LmdbStorage storage = new LmdbStorage(individuals_db_path);

    // SEND ready
    receive((Tid tid_response_reciever)
            {
                send(tid_response_reciever, true);
            });

    while (true)
    {
        receive((CMD cmd, string msg, Tid tid_response_reciever)
                {
                    try
                    {
                        if (cmd == CMD.STORE)
                        {
                            try
                            {
                                EVENT ev = storage.update_or_create(msg);
                                send(tid_response_reciever, ev, thisTid);
                            }
                            catch (Exception ex)
                            {
                                send(tid_response_reciever, ex.msg, thisTid);
                            }
                        }
                        else if (cmd == CMD.FIND)
                        {
                            string res = storage.find(msg);
                            //writeln ("msg=", msg, ", $res = ", res);
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
