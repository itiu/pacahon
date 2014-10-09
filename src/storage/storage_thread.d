/**
  * процесс отвечающий за хранение
  */
module storage.storage_thread;

private
{
    import core.thread, std.stdio, std.conv, std.concurrency, std.file, std.datetime, std.outbuffer, std.string;

    import bind.lmdb_header;
    import type;
    import util.logger;
    import util.utils;
    import util.cbor;

    import pacahon.context;
    import pacahon.define;
    import pacahon.log_msg;
    import search.vel;
    import storage.lmdb_storage;
}

logger log;

static this()
{
    log = new logger("pacahon", "log", "server");
}

public void individuals_manager(string thread_name, string db_path)
{
    core.thread.Thread.getThis().name = thread_name;
    LmdbStorage storage               = new LmdbStorage(db_path, DBMode.RW, "individuals_manager");
    int         size_bin_log          = 0;
    int         max_size_bin_log      = 10_000_000;
    string      bin_log_name          = get_new_binlog_name(db_path);

    // SEND ready
    receive((Tid tid_response_reciever)
            {
                send(tid_response_reciever, true);
            });

    string last_backup_id = "---";

    bool   is_freeze = false;

    while (true)
    {
        receive(
                (CMD cmd)
                {
                    if (cmd == CMD.COMMIT)
                    {
                        storage.flush(1);
                    }
                    else if (cmd == CMD.UNFREEZE)
                    {
                        is_freeze = false;
                    }
                },
                (CMD cmd, Tid tid_response_reciever)
                {
                    if (cmd == CMD.FREEZE)
                    {
                        is_freeze = true;
                        send(tid_response_reciever, true);
                    }
                    else if (cmd == CMD.NOP)
                        send(tid_response_reciever, true);
                    else
                        send(tid_response_reciever, false);
                },
                (CMD cmd, string key, string msg)
                {
                    if (cmd == CMD.PUT_KEY2SLOT)
                    {
                        storage.put(key, msg);
                    }
                },
                (CMD cmd, string msg, Tid tid_response_reciever)
                {
                    if (cmd == CMD.BACKUP)
                    {
                        try
                        {
                            string backup_id;
                            if (msg.length > 0)
                                backup_id = msg;
                            else
                                backup_id = storage.find(storage.summ_hash_this_db_id);

                            if (backup_id is null)
                                backup_id = "0";

                            if (last_backup_id != backup_id)
                            {
                                Result res = storage.backup(backup_id);
                                if (res == Result.Ok)
                                {
                                    size_bin_log = 0;
                                    bin_log_name = get_new_binlog_name(db_path);
                                    last_backup_id = backup_id;
                                }
                                else if (res == Result.Err)
                                {
                                    backup_id = "";
                                }
                            }
                            send(tid_response_reciever, backup_id);
                        }
                        catch (Exception ex)
                        {
                            send(tid_response_reciever, "");
                        }
                    }
                    else
                    {
                        try
                        {
                            if (cmd == CMD.STORE)
                            {
                                if (is_freeze == true)
                                    send(tid_response_reciever, EVENT.NOT_READY, thisTid);
                                else
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
                                            bin_log_name = get_new_binlog_name(db_path);
                                        }
                                    }
                                    catch (Exception ex)
                                    {
                                        send(tid_response_reciever, EVENT.ERROR, thisTid);
                                    }
                                }
                            }
                            else if (cmd == CMD.FIND)
                            {
                                string res = storage.find(msg);
                                writeln("@FIND msg=", msg, ", $res = ", res);
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

/*
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
 */