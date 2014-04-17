module util.load_info;

private
{
    import core.thread;
    import std.array : appender;
    import std.format;
    import std.stdio;
    import std.datetime;
    import std.concurrency;
    import std.datetime;

    import util.utils;
    import util.logger;

    import pacahon.context;
    import pacahon.define;
}

public bool    cinfo_exit = false;

private string set_bar_color_1 = "\x1B[41m";
private string set_bar_color_2 = "\x1B[43m";
private string set_bar_color_3 = "\x1B[45m";
private string set_bar_color_4 = "\x1B[46m";
private string set_bar_color_5 = "\x1B[40m";

private string set_text_color_green       = "\x1B[32m";
private string set_text_color_blue        = "\x1B[34m";
private string set_all_attribute_off      = "\x1B[0m";
private string set_cursor_in_begin_string = "\x1B[0E";

logger         log;

static this()
{
    log = new logger("server-statistics", "log", "");
}

void statistic_data_accumulator(string thread_name)
{
    core.thread.Thread.getThis().name = thread_name;

    long[] stat = new long[ 3 ];
//    writeln("SPAWN: statistic_data_accumulator");

    // SEND ready
    receive((Tid tid_response_reciever)
            {
                send(tid_response_reciever, true);
            });
    while (true)
    {
        receive(
                (CMD cmd, CNAME idx, int delta)
                {
                    if (cmd == CMD.PUT)
                    {
                        stat[ idx ] += delta;
                    }
                },
                (CMD cmd, Tid tid_sender)
                {
                    if (cmd == CMD.GET)
                    {
                        send(tid_sender, cast(immutable)stat.dup);
                    }
                }, (Variant v) { writeln(thread_name, "::Received some other type.", v); });
    }
}

void print_statistic(string thread_name, Tid _statistic_data_accumulator)
{
    core.thread.Thread.getThis().name = thread_name;

    long sleep_time = 1;
//    Thread.sleep(dur!("seconds")(sleep_time));

    long prev_read_count  = 0;
    long prev_write_count = 0;
    long prev_worked_time = 0;

    // SEND ready
    receive((Tid tid_response_reciever)
            {
                send(tid_response_reciever, true);
            });
    while (!cinfo_exit)
    {
        sleep_time = 1;

        send(_statistic_data_accumulator, CMD.GET, thisTid);
        const_long_array stat = receiveOnly!(const_long_array);

        long read_count  = stat[ CNAME.COUNT_GET ];
        long write_count = stat[ CNAME.COUNT_PUT ];
        long worked_time = stat[ CNAME.WORKED_TIME ];

        long delta_count_read = read_count - prev_read_count;
        long delta_count_write = write_count - prev_write_count;
        
        prev_read_count = read_count;
        prev_write_count = write_count;

        float p100 = 3000;

        if (delta_count_read > 0 || delta_count_write)
        {
            long delta_worked_time = worked_time - prev_worked_time;
            prev_worked_time = worked_time;

            char[] now = cast(char[]) getNowAsString();
            now[ 10 ]  = ' ';
            now.length = 19;

            float cps = 0.1f;
            float wt  = cast(float)delta_worked_time;
            float dc  = cast(float)(delta_count_read + delta_count_write);
            if (wt > 0)
                cps = (dc / wt) * 1000 * 1000;

            auto writer = appender!string();
            formattedWrite(writer, "%s | r/w :%7d/%5d | cps/thr:%9.1f | work time:%7d µs | processed r/w: %7d/%5d | t.w.t. : %7d ms",
                           now, read_count, write_count, cps, delta_worked_time, delta_count_read, delta_count_write, worked_time / 1000);

            log.trace("cps:%6.1f", cps);

            string set_bar_color;

            if (cps < 3000)
            {
                p100          = 3000;
                set_bar_color = set_bar_color_1;
            }
            else if (cps >= 3000 && cps < 6000)
            {
                p100          = 6000;
                set_bar_color = set_bar_color_2;
            }
            else if (cps >= 6000 && cps < 10000)
            {
                p100          = 10000;
                set_bar_color = set_bar_color_3;
            }
            else if (cps >= 10000 && cps < 20000)
            {
                p100          = 20000;
                set_bar_color = set_bar_color_4;
            }
            else if (cps >= 20000)
            {
                p100          = 30000;
                set_bar_color = set_bar_color_5;
            }

            int d_cps_count = cast(int)((cast(float)writer.data.length / cast(float)p100) * cps + 1);

            if (d_cps_count > 0)
            {
                if (d_cps_count >= writer.data.length)
                    d_cps_count = cast(int)(writer.data.length - 1);

                writeln(set_bar_color, writer.data[ 0..d_cps_count ], set_all_attribute_off, writer.data[ d_cps_count..$ ]);
            }
        }

        Thread.sleep(dur!("seconds")(sleep_time));
    }

    writeln("exit form thread ", thread_name);
}
