module pacahon.interthread_signals;

import std.concurrency, std.stdio;
import pacahon.context;
import pacahon.define;

public void interthread_signals_thread()
{
    long[ string ] signals;
    string[ string ] str_signals;

    // SEND ready
    receive((Tid tid_response_reciever)
            {
                send(tid_response_reciever, true);
            });
    while (true)
    {
        receive(
                (CMD cmd, string key, DataType type, Tid tid_sender)
                {
                    if (cmd == CMD.GET && type == DataType.Integer)
                    {
                        long res;
                        res = signals.get(key, 0);
                        //writeln ("@get signal ", key);
                        send(tid_sender, res);
                    }
                    else if (cmd == CMD.GET && type == DataType.String)
                    {
                        string res;
                        res = str_signals.get(key, "");
                        //writeln ("@get signal ", key);
                        send(tid_sender, res);
                    }
                    else
                        send(tid_sender, "unknown command");
                },
                (CMD cmd, string key, long value)
                {
                    if (cmd == CMD.PUT)
                    {
                        signals[ key ] = value;
                        //writeln ("@set signal ", key, "=", value);
                    }
                },
                (CMD cmd, string key, string value)
                {
                    if (cmd == CMD.PUT)
                    {
                        str_signals[ key ] = value;
                        writeln("@set signal ", key, "=", value);
                    }
                }
                );
    }
}
