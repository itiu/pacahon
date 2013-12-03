module pacahon.load_info;

private 
{
	import core.thread;
	import std.array: appender;
	import std.format;
	import std.stdio;
	import std.datetime;
	import std.concurrency;
	import std.datetime;

	import util.utils;
	import util.Logger;

	import pacahon.context;
	import pacahon.define;
}  

public bool cinfo_exit = false;

private string set_bar_color_1 = "\x1B[41m";
private string set_bar_color_2 = "\x1B[43m";
private string set_bar_color_3 = "\x1B[45m";
private string set_bar_color_4 = "\x1B[46m";

private string set_text_color_green = "\x1B[32m";
private string set_text_color_blue = "\x1B[34m";
private string set_all_attribute_off = "\x1B[0m";
private string set_cursor_in_begin_string = "\x1B[0E";

Logger log;

static this()
{
	log = new Logger("server-statistics", "log", "");
}
	
void statistic_data_accumulator ()
{
	long[] stat = new long[3];
	writeln ("START THREAD: statistic_data_accumulator");
	while (true)
	{
		receive(
			(byte cmd, byte idx, int delta) 
			{
				if (cmd == PUT)
				{
					stat[idx] += delta;
				}
			},		
			(byte cmd, Tid tid_sender) 
			{
				if (cmd == GET)
				{
					 send(tid_sender, cast (immutable) stat.dup);	
				}								
			});
	}
}

void print_statistic (Tid _statistic_data_accumulator)
{
	writeln ("START THREAD: print_statistic");
	
	long sleep_time = 1;
	Thread.sleep(dur!("seconds")(sleep_time));

	long prev_count = 0;
	long prev_worked_time = 0;

	while(!cinfo_exit)
	{
		sleep_time = 1;

		send(_statistic_data_accumulator, GET, thisTid);
		const_long_array stat = receiveOnly!(const_long_array);

		long msg_count = stat[COUNT_MESSAGE];
		long cmd_count = stat[COUNT_COMMAND];
		long worked_time = stat[WORKED_TIME];

		long delta_count = msg_count - prev_count;

		float p100 = 3000;
				
		if(delta_count > 0)
		{
			long delta_worked_time = worked_time - prev_worked_time;
			prev_worked_time = worked_time;

			char[] now = cast(char[]) getNowAsString();
			now[10] = ' ';
			now.length = 19;
					
			float cps = 0.1f;
			float wt = (cast(float)delta_worked_time)/1000/1000;
			if (wt > 0)
				cps = delta_count/wt;
					
					
       		auto writer = appender!string();
	        formattedWrite(writer, "%s | msg/cmd :%5d/%5d | cps:%6.1f | work time:%6d µs | t.w.t. : %7d ms", 
			        		now, msg_count, cmd_count, cps, delta_worked_time, worked_time/1000);
			        
	        log.trace ("cps:%6.1f", cps);
			        
	        string set_bar_color; 
		                
	        if (cps < 3000)
	        {
	        	p100 = 3000;
	        	set_bar_color = set_bar_color_1;
	        }
	        else if (cps >= 3000 && cps < 6000)
	        {
	        	p100 = 6000;
	        	set_bar_color = set_bar_color_2;
	        }
	        else if (cps >= 6000 && cps < 10000)
	        {
	        	p100 = 10000;
	        	set_bar_color = set_bar_color_3;
	        }
	        else if (cps >= 10000 && cps < 20000)
	        {
	        	p100 = 20000;
	        	set_bar_color = set_bar_color_4;
	        }
			        
			int d_cps_count = cast(int)((cast(float)writer.data.length / cast(float)p100) * cps + 1);
				
			if (d_cps_count > 0)
			{
				if (d_cps_count >= writer.data.length)
					d_cps_count = cast(int)(writer.data.length - 1);
					
				writeln(set_bar_color, writer.data[0..d_cps_count], set_all_attribute_off, writer.data[d_cps_count..$]);
			}	
		}

		prev_count = msg_count;
		Thread.sleep(dur!("seconds")(sleep_time));
	}
	
	writeln("exit form thread print_statistic");
		
}
