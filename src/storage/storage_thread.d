module storage.storage_thread;

private
{
    import core.thread, std.stdio, std.conv, std.concurrency, std.file, std.datetime;

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

public void individuals_manager(P_MODULE name, string db_path)
{
	Thread tr = Thread.getThis();
	tr.name = text (name);
//    writeln("SPAWN: Subject manager");
    LmdbStorage storage = new LmdbStorage(db_path);

    // SEND ready
    receive((Tid tid_response_reciever)
            {
                send(tid_response_reciever, true);
            });

    while (true)
    {
        receive(
                (CMD cmd)
                {
                    if (cmd == CMD.COMMIT)
                    {
                        storage.flush(1);
                    }
                },
                (CMD cmd, Tid tid_response_reciever)
                {
                    if (cmd == CMD.NOP)
                        send(tid_response_reciever, true);
                    else
                        send(tid_response_reciever, false);
                },
                (CMD cmd, string msg, Tid tid_response_reciever)
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
                                send(tid_response_reciever, EVENT.ERROR, thisTid);
                            }
                        }
                        else if (cmd == CMD.FIND)
                        {
                            string res = storage.find(msg);
                            //writeln ("msg=", msg, ", $res = ", res);
                            send(tid_response_reciever, msg, res, thisTid);
                        }
                        else
                        {
                            //writeln("%3 ", msg);
                            send(tid_response_reciever, msg, "", thisTid);
                        }
                    }
                    catch (Exception ex)
                    {
                        writeln("individuals_manager:EX!", ex.msg);
                    }
                }, (Variant v) { writeln("storage_thread::Received some other type.", v); });
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
