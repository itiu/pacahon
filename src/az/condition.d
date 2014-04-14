module az.condition;

private
{
    import std.json, std.stdio, std.string, std.array, std.datetime, std.concurrency, std.conv, std.file;
    import core.thread;

    import onto.sgraph;

    import util.container;
    import util.utils;
    import util.logger;
    import util.cbor;
    import util.cbor8sgraph;
    import util.cbor8individual;

    import pacahon.know_predicates;
    import pacahon.context;
    import pacahon.define;
    import pacahon.thread_context;

    import search.vel;
    import search.vql;

    import az.orgstructure_tree;

    import bind.v8d_header;
}

enum RightType
{
    CREATE = 0,
    READ   = 1,
    WRITE  = 2,
    UPDATE = 3,
    DELETE = 4,
    ADMIN  = 5
}

logger log;

static this()
{
    log = new logger("pacahon", "log", "MandatManager");
}

struct Mandat
{
    string id;
    string whom;
    string right;
    string condition;
    Script script;
}

int     count;
Context context;
Mandat[ string ] mandats;
VQL     vql;

public void condition_thread(P_MODULE name, string props_file_name)
{
	core.thread.Thread tr = core.thread.Thread.getThis();
	tr.name = std.conv.text (name);	
		
    context   = new PThreadContext(null, "condition_thread");
    g_context = context;

    OrgStructureTree ost;

//	ost = new OrgStructureTree(context);
//	ost.load();
    vql = new VQL(context);
    load();

//    writeln("SPAWN: condition_thread");

    try
    {
        // SEND ready
        receive((Tid tid_response_receiver)
                {
                    send(tid_response_receiver, true);
                });

        while (true)
        {
            try
            {
                ScriptVM script_vm = context.get_ScriptVM();

                receive(
                        (CMD cmd, string arg, Tid to)
                        {
                            if (cmd == CMD.RELOAD)
                            {
                                Subject ss = cbor2subject(arg);
                                prepare_condition(ss, script_vm);
                                send(to, true);
                            }
                            send(to, false);
                        },
                        (CMD cmd, Tid to)
                        {
                            if (cmd == CMD.NOP)
                                send(to, true);
                            else
                                send(to, false);
                        },
                        (EVENT type, string msg)
                        {
                            //writeln ("condition_thread: type:", type, ", msg=[", msg, "]");
                            if (msg !is null && msg.length > 3 && script_vm !is null)
                            {
                                //cbor2individual (&g_individual, msg);
                                g_individual.data = cast(char *)msg;
                                g_individual.length = cast(int)msg.length;

                                foreach (mandat; mandats.values)
                                {
                                    if (mandat.script !is null)
                                    {
                                        try
                                        {
                                            //writeln ("exec script : ", mandat.condition);
                                            count++;
                                            script_vm.run(mandat.script);
                                        }
                                        catch (Exception ex)
                                        {
                                            writeln("EX!condition.receive ", ex.msg);
                                        }
                                    }
                                }

//                                writeln("count:", count);

                                //clear_script_data_cache ();
                            }
                        }, (Variant v) { writeln("condition::Received some other type.", v); });
            }
            catch (Exception ex)
            {
                writeln("EX! condition: receive");
            }
        }
    }
    catch (Exception ex)
    {
        writeln("EX! condition: main loop");
    }
    writeln("TERMINATED: condition_thread");
}

public void load()
{
    //writeln ("@1");
    ScriptVM script_vm = context.get_ScriptVM();

    if (script_vm is null)
        return;

    log.trace_log_and_console("start load mandats");

    Subjects res = new Subjects();
    vql.get(null,
            "return { 'veda-schema:script'}
            filter { 'rdf:type' == 'veda-schema:Mandate'}",
            res);

    int count = 0;

    foreach (ss; res.data)
    {
        prepare_condition(ss, script_vm);
    }

    //writeln ("@2");
    log.trace_log_and_console("end load mandats, count=%d ", res.length);
}

private void prepare_condition(Subject ss, ScriptVM script_vm)
{
    writeln("@prepare_condition uri=", ss.subject);
    JSONValue nil;
    try
    {
        string condition_text = ss.getFirstLiteral(veda_schema__script);
        if (condition_text.length <= 0)
            return;

        //writeln("condition_text:", condition_text);

        Mandat mandat = void;
        mandat.id = ss.subject;

        if (condition_text[ 0 ] == '{')
        {
            JSONValue condition_json = parseJSON(condition_text);

            if (condition_json.type == JSON_TYPE.OBJECT)
            {
                JSONValue el = condition_json.object.get("whom", nil);
                if (el != nil)
                    mandat.whom = el.str;

                el = condition_json.object.get("right", nil);
                if (el != nil)
                    mandat.right = el.str;

                el = condition_json.object.get("condition", nil);
                if (el != nil)
                {
                    mandat.condition = el.str;
                    mandat.script    = script_vm.compile(cast(char *)(mandat.condition ~ "\0"));
                    writeln("\nmandat.id=", mandat.id);
                    writeln("str=", mandat.condition);

                    mandats[ ss.subject ] = mandat;
                }
            }
        }
        else
        {
            mandat.condition = condition_text;
            mandat.script    = script_vm.compile(cast(char *)(mandat.condition ~ "\0"));
            writeln("\nmandat.id=", mandat.id);
            writeln("str=", mandat.condition);

            mandats[ ss.subject ] = mandat;
        }

//					found_in_condition_templateIds_and_docFields (mandat.expression, "", cai.templateIds, cai.fields);
    }
    catch (Exception ex)
    {
        writeln("error:load mandat :", ex.msg);
    }
    finally
    {
        //writeln ("@4");
    }
}
