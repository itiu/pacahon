module pacahon.authorization;

private import core.stdc.stdio;
private import std.datetime;
private import std.stdio;

private import trioplax.triple;
private import trioplax.TripleStorage;

private import pacahon.graph;
private import pacahon.know_predicates;

enum operation
{
	BROWSE = 0,
	CREATE = 2,
	READ = 4,
	UPDATE = 8,
	DELETE = 16
}

/*
 * вычисление прав
 * userId - запросивший права
 * targetId - обьект охраны
 * op - список запрашиваемых операций
 */
bool authorize(char[] userId, char[] targetId, short op, TripleStorage ts, out char[] reason)
{
	StopWatch sw;
	sw.start();
	
	bool res = false;

	reason = cast(char[]) "ничего разрешающего не было определено";

	if(userId !is null)
		write("# пользователь [", userId, "]");
	else
		write("# неизвестный пользователь");

	writeln(" запрашивает разрешение на выполнении ");

	if(op & operation.BROWSE)
		printf(" BROWSE,");
	if(op & operation.CREATE)
		printf(" CREATE,");
	if(op & operation.READ)
		printf(" READ,");
	if(op & operation.UPDATE)
		printf(" UPDATE,");
	if(op & operation.DELETE)
		printf(" DELETE,");

	writeln("над субьектом охраны [", targetId, "]. \n");

	try
	{
		if(ts is null)
			throw new Exception("TripleStorage ts == null");

		if(targetId is null)
			throw new Exception("char[] targetId == null");

		bool subjectIsExist = ts.isExistSubject(targetId);

		if(userId !is null)
		{
//			printf("A 0. пользователь известен, проверка прав для всех операций\n");
			/*
			 * пользователь известен, проверка прав для всех операций
			 */

			if(subjectIsExist == true)
			{
				// субьект уже существует

				// A 1. проверить, есть ли у охраняемого субьекта, предикат [dc:creator] = [userId]
				writeln("A 1. проверить, есть ли у охраняемого субьекта, предикат [", dc__creator, "] = [", userId, "]");

				triple_list_element* iterator = ts.getTriples(targetId, dc__creator, userId);

				if(iterator !is null)
				{
					printf("#dc:creator найден\n");
					reason = cast(char[]) "пользователь известен, он создатель данного субьекта";
					res = true;
				}
				else
				{
					printf("#dc:creator  не найден\n");
					reason = cast(char[]) "пользователь известен, но не является создателем данного субьекта";
					res = false;
				}
			}
			else
			{
				reason = cast(char[]) "пользователь известен, охраняемый субьект отсутствует в хранилище";
				res = true;
			}
		}
		else
		{
			// если пользователь не указан, то можно только добавление ранее не существовавшего субьекта

			if(subjectIsExist == true)
			{
				// охраняемый субьект уже есть, все операции запрещены
				reason = cast(char[]) "пользователь не известен, охраняемый субьект уже есть, все операции запрещены";
				res = false;
			}
			else if(op & operation.CREATE)
			{
				reason = cast(char[]) "хотя пользователь не известен, однако операция CREATE допустима для ранее не существовавшего субьекта";
				res = true;
			}

			return res;
		}

		return res;
	}
	catch(Exception ex)
	{
		reason = cast(char[]) "ошибка при вычислении прав :" ~ ex.msg;
		res = false;

		return res;
	}
	finally
	{

		printf("	результат:");

		if(res == true)
			printf("разрешено\n");
		else
			printf("отказанно\n");

		printf("	причина: %s\n", reason.ptr);
		sw.stop();
		long t = cast(long) sw.peek().microseconds;

		if (t > 100)
		{		
			printf("total time authorize: %d[µs]\n", t);
		}
	}
}