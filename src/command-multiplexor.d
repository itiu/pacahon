module pacahon.command.multiplexor;

private import core.stdc.stdio;
private import std.c.string;
private import core.stdc.stdlib;

private import pacahon.graph;
private import pacahon.n3.parser;

Subject*[] put(Subject* message, Predicate* sender)
{
	Subject*[] res;
	//	printf("command put\n");

	Predicate* args = message.getEdge("msg:args");

	for(short i; i < args.count_objects; i++)
	{
		char* args_text = cast(char*) args.objects[i].object;
		//		printf("arg [%s]\n", args_text);

		int arg_size = strlen(args_text);

		Subject*[] triples_on_put = parse_n3_string(cast(char*) args_text, arg_size);

		// цикл по всем добавляемым субьектам
		/* Doc 2. если создается новый субъект, то ограничений по умолчанию нет
		 * Doc 3. если добавляются факты на уже созданного субъекта, то разрешено добавлять если добавляющий автор субъекта 
		 * или может быть вычислено разрешающее право на U данного субъекта. */

		// A 1. проверить, есть ли у данного субьекта, предикат [creator] значение которого [выполняющий операцию]  
		//   
		
		
		// A 1.1 если нет, то следует скриптами вычислять права
		
		// A 1.2 если да, то сохраняем все факты
		
		//		printf("parse ok \n");
		//		printf(triples_on_put[0].toString());
		return triples_on_put;
		//		print_graph(triples_on_put[0]);
		//		triples_on_put[0].toString();
	}

	return res;
}

Subject*[] get(Subject* message, Predicate* sender)
{
	Subject*[] res;
	printf("command get\n");

	return res;
}

Subject*[] get_ticket(Subject* message, Predicate* sender)
{
	Subject*[] res;
	printf("command get-ticket\n");

	return res;
}