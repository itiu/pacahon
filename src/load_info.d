module pacahon.load_info;

private import std.array: appender;
private import std.format;

private import core.thread;
private import std.stdio;

private import pacahon.thread_context;
private import pacahon.utils;

private import trioplax.Logger;

private import std.datetime;

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

class LoadInfoThread: Thread
{
	Statistic delegate() get_statistic;

	this(Statistic delegate() _get_statistic)
	{
		get_statistic = _get_statistic;
		super(&run);
	}

	private:

		void run()
		{
			long sleep_time = 1;
			Thread.sleep(dur!("seconds")(sleep_time));

			int prev_count = 0;
			int prev_idle_time = 0;
			int prev_worked_time = 0;

			//			bool ff = false;
			while(!cinfo_exit)
			{
				sleep_time = 1;

				Statistic stat = get_statistic();

				int msg_count = stat.count_message;
				int cmd_count = stat.count_command;
				int idle_time = stat.idle_time;
				int worked_time = stat.worked_time;

				int delta_count = msg_count - prev_count;

				float p100 = 3000;
				
				if(delta_count > 0)
				// || ff == false)
				{
					int delta_idle_time = idle_time - prev_idle_time;
					prev_idle_time = idle_time;
					int delta_worked_time = worked_time - prev_worked_time;
					prev_worked_time = worked_time;

//					int d_delta_count = delta_count / 5 + 1;
//					wchar[] sdc = new wchar[d_delta_count];
//					for(int i = 0; i < d_delta_count; i++)
//					{
//						sdc[i] = ' ';
//					}

					char[] now = cast(char[]) getNowAsString();
					now[10] = ' ';
					now.length = 19;
					
            		auto writer = appender!string();
			        formattedWrite(writer, "%s | msg cnt:%5d | cmd cnt:%5d | delta cnt:%4d | usr of tk:%4d | size csc:%5d | idle time:%7d | work time:%6d", 
			        		now, msg_count, cmd_count, delta_count, stat.size__user_of_ticket, stat.size__cache__subject_creator, delta_idle_time / 1000, delta_worked_time / 1000);
//			                writer.put(cast(char) 0);
			        
			        log.trace ("delta_count_msg:%d", delta_count);
			        
			        string set_bar_color; 
			                
			        if (delta_count < 3000)
			        {
			        	p100 = 3000;
			        	set_bar_color = set_bar_color_1;
			        }
			        else if (delta_count >= 3000 && delta_count < 6000)
			        {
			        	p100 = 6000;
			        	set_bar_color = set_bar_color_2;
			        }
			        else if (delta_count >= 6000 && delta_count < 10000)
			        {
			        	p100 = 10000;
			        	set_bar_color = set_bar_color_3;
			        }
			        else if (delta_count >= 10000 && delta_count < 20000)
			        {
			        	p100 = 20000;
			        	set_bar_color = set_bar_color_4;
			        }
			        
					int d_delta_count = cast(int)((cast(float)writer.data.length / cast(float)p100) * delta_count + 1);															
					writeln(set_bar_color, writer.data[0..d_delta_count], set_all_attribute_off, writer.data[d_delta_count..$]);
				}

				//				if(delta_count > 0)
				//					ff = false;
				//				else
				//					ff = true;

				prev_count = msg_count;
				Thread.sleep(dur!("seconds")(sleep_time));
			}
			writeln("exit form thread cinfo");
		}
}
