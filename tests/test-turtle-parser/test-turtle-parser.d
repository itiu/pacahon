module test_parser;

import std.string;
import std.c.stdlib;
import std.date;

version(D1)
{
	import std.stdio;
}

version(D2)
{
	import core.stdc.stdio;
}

import pacahon.graph;
import pacahon.n3.parser;

void main(string args[])
{
	printf("open file...");

	FILE* file = null;

	file = fopen("test.n3", "r");

	if(file !is null)
	{
		printf("ok\n");
		int len;
		int len_file;
		ubyte[4 * 1024] buffer;

		while((len = fread(cast(void*) buffer, 1, buffer.sizeof, file)) != 0)
		{
			//			printf("%s len=%d\n", cast(char*) buffer, len);
			len_file = len;
		}

		fclose(file);

		sss(cast(char*) buffer, len_file, true);

		d_time start_time = getUTCtime();
		int count = 1_000_000;

		printf("execute parsing %d times\n", count);

		for(int i = 0; i < count; i++)
		{
			sss(cast(char*) buffer, len_file);
		}

		d_time end_time = getUTCtime();
		d_time delta = end_time - start_time;
		printf("count: %d, total time: %5.3f sec\n", count, delta / 1000f);

	}
	else
	{
		printf("file not open\n");
	}
}

private void sss(char* buffer, int len_file, bool printing = false)
{
	Subject*[] subjects = parse_n3_string(cast(char*) buffer, len_file);

	char* ptr = cast(char*) buffer;
	for(int j = 0; j < len_file; j++)
	{
		if(*ptr == 0)
		{
			*ptr = ' ';
		}
		ptr++;
	}

	if(printing == true)
	{
		printf("read %d graphs\n", subjects.length);

		for(int ii = 0; ii < subjects.length; ii++)
		{
			print_graph(subjects[ii]);
		}

//		printf("set hash table of graph elements\n");
	}
	
	for(int ii = 0; ii < subjects.length; ii++)
	{
		set_hashed_data(subjects[ii]);
	}
}
