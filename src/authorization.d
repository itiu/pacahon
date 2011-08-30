module pacahon.authorization;

private import core.stdc.stdio;
private import std.datetime;
private import std.stdio;

private import trioplax.triple;
private import trioplax.TripleStorage;

private import pacahon.graph;
private import pacahon.know_predicates;
private import pacahon.log_msg;
private import pacahon.thread_context;

private import trioplax.Logger;

Logger log;

static this()
{
	log = new Logger("pacahon", "log", "authorization");
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

bool authorize(string userId, string targetId, short op, ThreadContext server_thread, out string reason)
{
	StopWatch sw;
	sw.start();

	bool res = false;

	reason = "ничего разрешающего не было определено";

	if(trace_msg[25] == 1)
	{
		string _user;
		string _op;

		if(userId !is null)
			_user = "пользователь [" ~ userId ~ "]";
		else
			_user = "неизвестный пользователь";

		if(op & operation.BROWSE)
			_op = "BROWSE";
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
		if(server_thread.ts is null)
			throw new Exception("TripleStorage ts == null");

		if(targetId is null)
			throw new Exception("char[] targetId == null");

		if (targetId[0] == '_' && targetId[1] == ':' && targetId[2] == 'R' && operation.READ)
		{
			// TODO для доп части у реифицированных фактов следует сделать нормальную проверку
			return true;
		}
		
		if(trace_msg[25] == 1)
			log.trace("проверим, существует-ли охраняемый субьект [%s]", targetId);

		string subject_creator = null;

		bool subjectIsExist = false;
		if((targetId in server_thread.cache__subject_creator) !is null)
		{
			subjectIsExist = true;
			subject_creator = server_thread.cache__subject_creator[targetId];
			if(trace_msg[25] == 1)
				log.trace("субьект найден в кэше");
		} else
		{
			subjectIsExist = server_thread.ts.isExistSubject(targetId);

			if(trace_msg[25] == 1)
			{
				if(subjectIsExist == true)
					log.trace("субьект найден в хранилище");
				else
					log.trace("субьект не найден в хранилище");
			}
		}

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
					log.trace("A 1. проверить, есть ли у охраняемого субьекта [%s], предикат [%s] = [%s]", targetId,
							dc__creator, userId);

				if(subject_creator is null)
				{
					TLIterator it = server_thread.ts.getTriples(targetId, dc__creator, userId);

					if(it !is null)
					{
						if(trace_msg[27] == 1)
							log.trace("dc:creator найден");

						reason = "пользователь известен, он создатель данного субьекта";

						server_thread.cache__subject_creator[targetId] = userId;
						res = true;
					} else
					{
						if(trace_msg[28] == 1)
							log.trace("creator  не найден");

						reason = "пользователь известен, но не является создателем данного субьекта";
						res = false;
					}
				} else
				{
					if(subject_creator == userId)
					{
						if(trace_msg[27] == 1)
							log.trace("dc:creator найден в кэше");

						reason = "пользователь известен, он создатель данного субьекта";
						res = true;
					} else
					{
						if(trace_msg[28] == 1)
							log.trace("в кэше creator не найден");

						reason = "пользователь известен, но не является создателем данного субьекта";
						res = false;
					}
				}
			} else
			{
				reason = "пользователь известен, охраняемый субьект отсутствует в хранилище";

				if(op & operation.READ)
					return false;
				
				res = true;
			}
		} else
		{
			// если пользователь не указан, то можно только добавление ранее не существовавшего субьекта

			if(subjectIsExist == true)
			{
				// охраняемый субьект уже есть, все операции запрещены
				reason = "пользователь не известен, охраняемый субьект уже есть, все операции запрещены";
				res = false;
			} else if(op & operation.CREATE)
			{
				reason = "хотя пользователь не известен, однако операция CREATE допустима для ранее не существовавшего субьекта";
				res = true;
			}

			return res;
		}

		return res;
	} catch(Exception ex)
	{
		reason = "ошибка при вычислении прав :" ~ ex.msg;
		res = false;

		return res;
	} finally
	{

		if(trace_msg[29] == 1)
		{
			if(res == true)
				log.trace("результат: разрешено, причина: %s", reason);
			else
				log.trace("результат: отказанно, причина: %s", reason);
		}

		sw.stop();
		long t = cast(long) sw.peek().usecs;

		if(t > 10000 || trace_msg[30] == 1)
		{
			log.trace("total time authorize: %d[µs]", t);
		}

	}
}
