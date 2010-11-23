module pacahon.authorization;

private import core.stdc.stdio;

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
	bool res = false;

	reason = cast(char[]) "ничего разрешающего не было определено";

	if(userId !is null)
		printf("# пользователь [%s]", userId);
	else
		printf("# неизвестный пользователь");

	printf(" запрашивает разрешение на выполнении ");

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

	printf("над субьектом охраны [%s]. \n", targetId.ptr);

	try
	{
		if(ts is null)
			throw new Exception("TripleStorage ts == null");

		if(targetId is null)
			throw new Exception("char[] targetId == null");

		if(userId !is null)
		{
			printf("A 0. пользователь известен, проверка прав для всех операций");
			/*
			 * пользователь известен, проверка прав для всех операций
			 */

			// A 1. проверить, есть ли у охраняемого субьекта, предикат [dc:creator] = [userId]
			printf("A 1. проверить, есть ли у охраняемого субьекта, предикат [dc:creator] = [%s]\n", userId);

			triple_list_element* iterator = ts.getTriples(targetId, dc__creator, userId);

			if(iterator !is null)
			{
				printf("#dc:creator найден\n");

			}
			else
			{
				printf("#dc:creator  не найден\n");
			}
		}
		else
		{
			// если пользователь не указан, то можно только добавление ранее не существовавшего субьекта

			if(ts.isExistSubject(targetId) == true)
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

	}
}