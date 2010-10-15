module test_parser;

import std.string;
import std.c.stdlib;
import std.stdio;

import pacahon.triple;
import pacahon.n3.parser;

void main(string args[])
{
	printf("open file...");

	FILE* file = null;

	file = fopen("test.n3".ptr, "r");

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

		for(int i = 0; i < 2_000_000; i++)
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
	Subject*[] triples = parse(cast(char*) buffer, len_file, buff);

	char* ptr = cast(char*) buffer;
	for(int j = 0; j < len_file; j++)
	{
		if(*ptr == 0)
		{
			*ptr = ' ';
		}
		ptr++;
	}

//	printf("read %d triples\n", triples.length);

	for(int i = 0; i < triples.length; i++)
	{
//		printf("%s \n", triples[i].subject);
	}

}
