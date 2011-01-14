module pacahon.authorization;

private import core.stdc.stdio;
private import std.datetime;
private import std.stdio;

private import trioplax.triple;
private import trioplax.TripleStorage;

private import pacahon.graph;
private import pacahon.know_predicates;

private import trioplax.Logger;

private import log_msg;

Logger log;

static this()
{
	log = new Logger("pacahon.log", "authorization");
}

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

	if(trace_msg[25] == 1)
	{
		char[] _user;
		char[] _op;

		if(userId !is null)
			_user = "пользователь [" ~ userId ~ "]";
		else
			_user = cast(char[])"неизвестный пользователь";

		if(op & operation.BROWSE)
			_op = cast(char[])"BROWSE";
		if(op & operation.CREATE)
			_op = _op ~ ", CREATE";
		if(op & operation.READ)
			_op = _op ~ ", READ";
		if(op & operation.UPDATE)
			_op = _op ~ ", UPDATE";
		if(op & operation.DELETE)
			_op = _op ~ ", DELETE";

		log.trace("%s запрашивает разрешение на выполнение операции %s над субьектом охраны [%s]", _user, _op, targetId);
	}

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
				if(trace_msg[26] == 1)
					log.trace("A 1. проверить, есть ли у охраняемого субьекта, предикат [%s] = [%s]", dc__creator, userId);

				triple_list_element iterator = ts.getTriples(targetId, dc__creator, userId);

				if(iterator !is null)
				{
					if(trace_msg[27] == 1)
						log.trace("dc:creator найден");

					reason = cast(char[]) "пользователь известен, он создатель данного субьекта";
					res = true;
				}
				else
				{
					if(trace_msg[28] == 1)
						log.trace("creator  не найден");

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

		if(trace_msg[29] == 1)
		{
			if(res == true)
				log.trace("результат: разрешено, причина: %s", reason);
			else
				log.trace("результат: отказанно, причина: %s", reason);
		}

		sw.stop();
		long t = cast(long) sw.peek().microseconds;

		if(t > 300 || trace_msg[30] == 1)
		{
			log.trace("total time authorize: %d[µs]", t);
		}

	}
}