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
 * получение уведомление от движка jawl, о том что элемент запущенного процесса выбран 
 */
Subject yawl_announceItemEnabled(Subject message, Predicate* sender, string userId, ThreadContext server_thread,
		out bool isOk, out string reason)
{
	isOk = true;

//	log.trace("yawl_announceItemEnabled");

	reason = "ok";

	Subject res = new Subject();

	return res;
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
