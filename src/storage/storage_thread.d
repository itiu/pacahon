module storage.storage_thread;

private
{
    import core.thread, std.stdio, std.conv, std.concurrency, std.file, std.datetime, std.outbuffer, std.string;

    import bind.lmdb_header;

    import util.logger;
    import util.utils;
    import util.cbor;
    import util.cbor8sgraph;

    import pacahon.context;
    import pacahon.define;
    import pacahon.log_msg;
    import search.vel;
    import storage.lmdb_storage;
    import onto.sgraph;
}

logger log;

static this()
{
    log = new logger("pacahon", "log", "server");
}

string get_new_binlog_name (string db_path)
{
	string now = Clock.currTime().toISOExtString();
	now = now[0..indexOf(now,'.') + 4];  
	
    return db_path ~ "." ~ now;	
}

public void individuals_manager(string thread_name, string db_path)
{
    core.thread.Thread.getThis().name = thread_name;
    LmdbStorage storage               = new LmdbStorage(db_path, DBMode.RW);
    int 		size_bin_log		  = 0;
    int 		max_size_bin_log	  = 10_000_000;	
    string bin_log_name = get_new_binlog_name (db_path);
    
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
                    if (cmd == CMD.BACKUP)
                    {
                        storage.flush(1);
                        storage.backup();
                       	size_bin_log = 0;
                       	bin_log_name = get_new_binlog_name (db_path);                        
                    }
                    else if (cmd == CMD.COMMIT)
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
                                string new_hash;
                                EVENT ev = storage.update_or_create(msg, new_hash);

                                send(tid_response_reciever, ev, thisTid);
                                long now = Clock.currTime().stdTime();
                                OutBuffer oub = new OutBuffer();
                                oub.write('\n');
                                oub.write(now);
                                oub.write(msg.length);
                                oub.write(new_hash);
                                oub.write(msg);
                                append(bin_log_name, oub.toString);
                                size_bin_log += msg.length + 30;
                                
                                if (size_bin_log > max_size_bin_log)
                                {
                                	size_bin_log = 0;
                                	bin_log_name = get_new_binlog_name (db_path);
                                }
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
                        writeln(thread_name, ":EX!", ex.msg);
                    }
                },
                (CMD cmd, int arg, bool arg2)
                {
                    if (cmd == CMD.SET_TRACE)
                        set_trace(arg, arg2);
                },
                (Variant v) { writeln(thread_name, "::Received some other type.", v); });
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
