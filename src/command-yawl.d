module pacahon.command.yawl;

private import core.stdc.stdio;
private import core.stdc.stdlib;
private import std.c.string;
private import std.string;

private import std.datetime;

private import std.stdio;
private import std.outbuffer;

private import tango.util.uuid.NamespaceGenV5;
private import tango.util.digest.Sha1;
private import tango.util.uuid.RandomGen;
private import tango.math.random.Twister;

private import std.datetime;

//import luad.all;

private import trioplax.triple;
private import trioplax.TripleStorage;

private import pacahon.graph;

private import pacahon.n3.parser;
private import pacahon.json_ld.parser1;

private import pacahon.authorization;
private import pacahon.know_predicates;
private import pacahon.log_msg;
private import pacahon.utils;
private import pacahon.thread_context;

private import trioplax.Logger;
private import pacahon.zmq_connection;

Logger log;
//LuaState lua;
//LuaFunction l_f;

static this()
{
	log = new Logger("pacahon", "log", "command-yawl");
//	lua = new LuaState;
//	lua.doString (`function ask(question) return 39 end`);
//	l_f = lua.get!LuaFunction ("ask");
}

/*
 * Получение уведомление от движка jawl, о том что элемент запущенного процесса выбран.
 * Определение внешнего скрипта для запуска и его выполнение. 
 */
void yawl_announceItemEnabled(Subject message, Predicate* sender, string userId, ThreadContext server_thread,
		out bool isOk, out string reason)
{
	string result;

	assert(message !is null);
	isOk = true;

	Predicate* args = message.getPredicate(msg__args);
	if(args !is null)
	{
		Subject sargs = args.getFirstSubject();

		if(sargs !is null)
		{
			//			sargs.reindex_predicate();

			string caseTaskId = sargs.subject;

			//			log.trace("yawl_announceItemEnabled %s", caseTaskId);

			// получить тикет [connect(_engineUser,_enginePassword)]
			string ticket = yawl_engine_connect("TestCaseLauncher", "DrBPdG8BEdiaTv9hsGfcO18zRlk=",
					"pacahon:yawl_announceItemEnabled", server_thread);

			// забрать задачу на обработку [checkOut(taskId, ticket)]
			Subject task = yawl_checkOut(caseTaskId, ticket, "pacahon:yawl_announceItemEnabled", server_thread);

			string caseId = task.getFirstObject("yawl:caseId");
			string taskId = task.getFirstObject("yawl:taskId");

			string section_name;
			string command;
			Predicate* data_of_task = task.getPredicate("yawl:data");
			if(data_of_task !is null)
			{
				//				writeln("found yawl:data ");

				Subject s_section = data_of_task.getFirstSubject();
				//				writeln("s_section.edges=", s_section.edges);

				Predicate p_section = s_section.edges[0];
				section_name = p_section.predicate;

				//				writeln("section_name=", section_name);

				//				Subject s_section = p_section.getFirstSubject ();
				Subject vars = p_section.getFirstSubject();

				if(vars !is null)
				{
					command = vars.getFirstObject("command");
				}
			}
		
			//			writeln("command:", command);
			
			// выполним скрипт связанный с коммандой в переменной [command]
//			auto aa = l_f.call!int("sddsgyuyujh vrr");			
//			writeln ("aa=", aa);
			
			// установить переменные задачи
			result = "done +";

			// вернуть задачу движку [checkInWorkItem]
			yawl_checkInWorkItem(taskId, caseId, section_name, result, command ~ ", is Ok",
					"pacahon:yawl_announceItemEnabled", ticket, server_thread);

			reason = "ok";
		}
	}

	return;
}

/*
 * запрос переменных сервиса 
 */
void yawl_ParameterInfoRequest(Subject message, Predicate* sender, string userId, ThreadContext server_thread,
		out bool isOk, out string reason, ref GraphCluster res)
{
	isOk = true;

	//	log.trace("yawl_ParameterInfoRequest");

	reason = "ok";

	res.addTriple("command", rdf__type, process__Input);
	res.addTriple("command", process__parameterType, xsd__string);

	res.addTriple("args", rdf__type, process__Input);
	res.addTriple("args", process__parameterType, xsd__string);

	res.addTriple("result", rdf__type, process__Output);
	res.addTriple("result", process__parameterType, xsd__string);

}

string yawl_engine_connect(string login, string credential, string from, ThreadContext server_thread)
{
	string msg = create_message(from, "yawl-engine", "get_ticket",
			"\"auth:login\" : \"" ~ login ~ "\",\n\"auth:credential\" : \"" ~ credential ~ "\"");

	ZmqConnection gateway = server_thread.getGateway ("yawl-engine"); 	
	
	gateway.send (msg);
	string res = gateway.reciev ();
	
	//	writeln("res=", res);

	Subject[] triples;

	triples = parse_json_ld_string(cast(char*) res, cast(uint)res.length);

	if(triples.length > 0)
	{
		//		triples[0].reindex_predicate();
		//		writeln("edges_of_predicate=", triples[0].edges_of_predicate);
		Predicate* pp = triples[0].getPredicate(msg__result);

		if(pp !is null)
		{
			Subject aa = pp.objects[0].subject;

			if(aa.edges[0].predicate == auth__ticket)
			{
				return aa.edges[0].getFirstObject();
			}
		}
	}

	return null;
}

Subject yawl_checkOut(string taskId, string ticket, string from, ThreadContext server_thread)
{
	//	writeln("yawl_checkOut(taskId=", taskId, ", ticket=", ticket);

	string msg = create_message(from, "yawl-engine", "checkout",
			"\"auth:ticket\" : \"" ~ ticket ~ "\",\n\"yawl:taskId\" : \"" ~ taskId ~ "\"");

	ZmqConnection gateway = server_thread.getGateway ("yawl-engine"); 	
	
	gateway.send (msg);
	string res = gateway.reciev ();

	//	writeln("res=", res);

	Subject[] triples;

	//	writeln("parse...");
	triples = parse_json_ld_string(cast(char*) res, cast(uint)res.length);

	if(triples.length > 0)
	{
		//		writeln("parse is  Ok");
		Predicate* pp = triples[0].getPredicate(msg__result);

		if(pp !is null)
		{
			//			writeln("seek result");
			GraphCluster aa = pp.objects[0].cluster;

			//		aa.reindex_predicate();
			//		writeln("edges_of_predicate=", triples[0].edges_of_predicate);
			if(aa !is null)
			{
				//				writeln("ok");
				return aa.graphs_of_subject.values[0];
			}
		}

	}

	return null;

}

Subject yawl_checkInWorkItem(string taskId, string caseId, string section_name, string result, string reason,
		string ticket, string from, ThreadContext server_thread)
{
	//	writeln("checkInWorkItem(taskId=", taskId, ", ticket=", ticket);

	string args = "\"auth:ticket\" : \"" ~ ticket ~ "\",\n\"yawl:taskId\" : \"" //
			~ taskId ~ "\",\n\"yawl:caseId\" : \"" ~ caseId ~ "\", \"yawl:data\":{\"" ~ section_name ~ "\": \n {\"result\" : \"" ~ result ~ //
			"\"}\n}, \"yawl:reason\" : \"" ~ reason ~ "\"";

	string msg = create_message(from, "yawl-engine", "checkin", args);

	ZmqConnection gateway = server_thread.getGateway ("yawl-engine"); 	
	
	gateway.send (msg);
	string res = gateway.reciev ();


	//	writeln("res=", res);

	Subject[] triples;

	//	writeln("parse...");
	triples = parse_json_ld_string(cast(char*) res, cast(uint)res.length);

	if(triples.length > 0)
	{
		//		writeln("parse is  Ok");
		Predicate* pp = triples[0].getPredicate(msg__result);

		if(pp !is null)
		{
			//			writeln("seek result");
			GraphCluster aa = pp.objects[0].cluster;

			//		aa.reindex_predicate();
			//		writeln("edges_of_predicate=", triples[0].edges_of_predicate);
			if(aa !is null)
			{
				return aa.graphs_of_subject.values[0];
			}
		}

	}

	return null;

}

string create_message(string from, string reciever, string command, string args)
{
	string msg_id = generateMsgId();
	string msg = "{\n\"@\" : \"" ~ msg_id ~ "\", \n\"a\" : \"msg:Message\",\n" ~ "\"msg:sender\" : \"" ~ // 
			from ~ "\",\n\"msg:reciever\" : \"" ~ reciever ~ "\",\n" ~ //
			"\"msg:command\" : \"" ~ command ~ "\",\n\"msg:args\" :\n{\n" ~ args ~ "\n}\n}";

	return msg;
}
