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

private import trioplax.triple;
private import trioplax.TripleStorage;

private import pacahon.graph;

private import pacahon.n3.parser;
private import pacahon.json_ld.parser;

private import pacahon.authorization;
private import pacahon.know_predicates;
private import pacahon.log_msg;
private import pacahon.utils;
private import pacahon.thread_context;

private import trioplax.Logger;

import dmdscript.program;
import dmdscript.script;
import dmdscript.extending;

Logger log;

static this()
{
	log = new Logger("pacahon", "log", "command-yawl");
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

	Predicate* args = message.getEdge(msg__args);
	if(args !is null)
	{
		Subject sargs = args.getFirstSubject();

		if(sargs !is null)
		{
			//			sargs.reindex_predicate();

			string caseTaskId = sargs.subject;

			log.trace("yawl_announceItemEnabled %s", caseTaskId);

			// получить тикет [connect(_engineUser,_enginePassword)]
			string ticket = yawl_engine_connect("TestCaseLauncher", "DrBPdG8BEdiaTv9hsGfcO18zRlk=",
					"pacahon:yawl_announceItemEnabled", server_thread);

			// забрать задачу на обработку [checkOut(taskId, ticket)]
			Subject task = yawl_checkOut(caseTaskId, ticket, "pacahon:yawl_announceItemEnabled", server_thread);

			string caseId = task.getObject("yawl:caseId");
			string taskId = task.getObject("yawl:taskId");

			string command;
			Predicate* data_of_task = task.getEdge("yawl:data");
			if(data_of_task !is null)
			{
				Subject aa1 = data_of_task.objects[0].subject;

				command = aa1.getObject("command");
			}
			writeln("command:", command);

			// установить переменные задачи
			result = "done +";

			// вернуть задачу движку [checkInWorkItem]
			yawl_checkInWorkItem(taskId, caseId, result, command ~ ", is Ok", "pacahon:yawl_announceItemEnabled",
					ticket, server_thread);

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
	server_thread.yawl_check_connect();

	string msg = create_message(from, "yawl-engine", "get_ticket",
			"\"auth:login\" : \"" ~ login ~ "\",\n\"auth:credential\" : \"" ~ credential ~ "\"");

	server_thread.client.send(server_thread.yawl_engine_context, cast(char*) msg, msg.length, false);
	string res = server_thread.client.reciev(server_thread.yawl_engine_context);

	//	writeln("res=", res);

	Subject[] triples;

	triples = parse_json_ld_string(cast(char*) res, res.length);

	if(triples.length > 0)
	{
		//		triples[0].reindex_predicate();
		//		writeln("edges_of_predicate=", triples[0].edges_of_predicate);
		Predicate* pp = triples[0].getEdge(msg__result);

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
	writeln("yawl_checkOut(taskId=", taskId, ", ticket=", ticket);

	string msg = create_message(from, "yawl-engine", "checkout",
			"\"auth:ticket\" : \"" ~ ticket ~ "\",\n\"yawl:taskId\" : \"" ~ taskId ~ "\"");

	server_thread.client.send(server_thread.yawl_engine_context, cast(char*) msg, msg.length, false);
	string res = server_thread.client.reciev(server_thread.yawl_engine_context);

	writeln("res=", res);

	Subject[] triples;

	//	writeln("parse...");
	triples = parse_json_ld_string(cast(char*) res, res.length);

	if(triples.length > 0)
	{
		writeln("parse is  Ok");
		Predicate* pp = triples[0].getEdge(msg__result);

		if(pp !is null)
		{
			writeln("seek result");
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

Subject yawl_checkInWorkItem(string taskId, string caseId, string result, string reason, string ticket, string from,
		ThreadContext server_thread)
{
	writeln("checkInWorkItem(taskId=", taskId, ", ticket=", ticket);

	string args = "\"auth:ticket\" : \"" ~ ticket ~ "\",\n\"yawl:taskId\" : \"" //
			~ taskId ~ "\",\n\"yawl:caseId\" : \"" ~ caseId ~ "\", \"yawl:data\":{\"result\" : \"" ~ result ~ //
			"\"}, \"yawl:reason\" : \"" ~ reason ~ "\"";

	string msg = create_message(from, "yawl-engine", "checkin", args);

	server_thread.client.send(server_thread.yawl_engine_context, cast(char*) msg, msg.length, false);
	string res = server_thread.client.reciev(server_thread.yawl_engine_context);

	writeln("res=", res);

	Subject[] triples;

	//	writeln("parse...");
	triples = parse_json_ld_string(cast(char*) res, res.length);

	if(triples.length > 0)
	{
		writeln("parse is  Ok");
		Predicate* pp = triples[0].getEdge(msg__result);

		if(pp !is null)
		{
			writeln("seek result");
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
