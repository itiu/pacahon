module test_parser;

import std.string;
import std.c.stdlib;

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

		for(int i = 0; i < 1_000_000; i++)
		{
			sss(cast(char*) buffer, len_file);
		}

	}
	else
	{
		printf("file not open\n");
	}
}

private void sss(char* buffer, int len_file)
{
	char* buff = cast(char*) alloca(len_file);

	buffer[len_file] = 0;
	Subject*[] subjects = parse(cast(char*) buffer, len_file, buff);

	char* ptr = cast(char*) buffer;
	for(int j = 0; j < len_file; j++)
	{
		if(*ptr == 0)
		{
			*ptr = ' ';
		}
		ptr++;
	}

//	printf("read %d graphs\n", subjects.length);

	for(int ii = 0; ii < subjects.length; ii++)
	{
		Subject* ss = subjects[ii];

//		printf("s: %s \n", ss.subject);

		for(int jj = 0; jj < ss.count_edges; jj++)
		{
			Predicate* pp = ss.edges[jj];

//			printf("	p: %s \n", pp.predicate);

			for(int kk = 0; kk < pp.count_objects; kk++)
			{

//				printf("		o: %s \n", cast(char*) pp.objects[kk].object);

			}

		}

		//	  set_outGoingEdgesOfPredicate (triples[i]);			    
	}

}
