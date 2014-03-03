module pacahon.interthread_signals;

import std.concurrency, std.stdio;
import pacahon.context;

public void interthread_signals_thread()
{
    long[ string ] signals;

    // SEND ready
    receive((Tid tid_response_reciever)
            {
                send(tid_response_reciever, true);
            });
    while (true)
    {
        receive(
                (CMD cmd, string key, Tid tid_sender)
                {
                    if (cmd == CMD.GET)
                    {
                        long res;
                        res = signals.get(key, 0);
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
                }
                );
    }
}
