module pacahon.load_info;

private import core.thread;
private import std.stdio;

private import pacahon.server;
private import pacahon.utils;

version(dmd2_053)
{
	private import std.datetime;
}
else
{
	private import std.datetime;
	private import std.date;
}

public bool cinfo_exit = false;

class LoadInfoThread: Thread
{
	Statistic delegate() get_statistic;
	StopWatch sw;

	this(Statistic delegate() _get_statistic)
	{
		get_statistic = _get_statistic;
		super(&run);
	}

	private:

		void run()
		{
			long sleep_time = 1;
			Thread.getThis().sleep(sleep_time * 10_000_000);
			//	layout = new Locale;

			int prev_count = 0;
			int prev_idle_time = 0;
			
			
//			bool ff = false;
			sw.start;

			while(!cinfo_exit)
			{
				Statistic stat = get_statistic();

				int msg_count = stat.count_message;
				int cmd_count = stat.count_command;
				int idle_time = stat.idle_time;


				int delta_count = msg_count - prev_count;

				if(delta_count > 0)
				// || ff == false)
				{
					sw.stop;
					
					version(dmd2_053)
				    	long time_from_last_call = cast(long) sw.peek().usecs;
					else
						long time_from_last_call = cast(long) sw.peek().microseconds;

					sw.reset;
					sw.start;
					
					int delta_idle = idle_time - prev_idle_time;
					prev_idle_time = idle_time;

					int d_delta_count = delta_count / 3 + 1;
					wchar[] sdc = new wchar[d_delta_count];

					for(int i = 0; i < d_delta_count; i++)
					{
						sdc[i] = 'ᚙ';
					}

					char[] now = cast(char[]) getNowAsString();
					now[10] = ' ';
					now.length = 19;
					writeln(now, " ", sdc, " ", msg_count, "/", cmd_count, " ", delta_count, " idle:", delta_idle/1000, " total time:", time_from_last_call/1000);
					
				}

//				if(delta_count > 0)
//					ff = false;
//				else
//					ff = true;

				prev_count = msg_count;
				//		prev_total_time = total_time;
				Thread.getThis().sleep(sleep_time * 10_000_000);
			}
			writeln("exit form thread cinfo");

		}

}
