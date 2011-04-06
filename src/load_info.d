module pacahon.load_info;

private import core.thread;
private import std.stdio;

private import pacahon.server;
private import pacahon.utils;

public bool cinfo_exit = false;

class LoadInfoThread: Thread
{
	void delegate(out int cnt) get_count;

	this(void delegate(out int cnt) _get_count)
	{
		get_count = _get_count;
		super(&run);
	}

	private:

		void run()
		{
			//	layout = new Locale;

			int prev_count = 0;
			double prev_total_time = 0;
			long sleep_time = 1;
			bool ff = false;

			while(!cinfo_exit)
			{
				Thread.getThis().sleep(sleep_time * 10_000_000);

				int msg_count = 0;
				get_count(msg_count);

				//		auto tm = WallClock.now;

				int delta_count = msg_count - prev_count;
				//		double delta_working_time = total_time - prev_total_time;

				if(delta_count > 0) // || ff == false)
				{
					int d_delta_count = delta_count / 2 + 1;
					wchar[] sdc = new wchar[d_delta_count];

					for(int i = 0; i < d_delta_count; i++)
					{
						sdc[i] = 'ᚙ';
					}

					writeln(getNowAsString(), " ", sdc, " ", msg_count, " ", delta_count);
				}

				if(delta_count > 0)
					ff = false;
				else
					ff = true;

				prev_count = msg_count;
				//		prev_total_time = total_time;
			}
			writeln("exit form thread cinfo");

		}

}
