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

int count;

public void condition_thread(string props_file_name)
{
    Context context = new PThreadContext(null, "condition_thread");
    g_context = context;

    Set!Mandat mandats;
    OrgStructureTree ost;
    VQL              vql;

//	ost = new OrgStructureTree(context);
//	ost.load();
    vql = new VQL(context);
    load(context, vql, mandats);

    string key2slot_str;
    long   last_update_time;

//    writeln("SPAWN: condition_thread");
    last_update_time = Clock.currTime().stdTime();

    try
    {
        // SEND ready
        receive((Tid tid_response_reciever)
                {
                    send(tid_response_reciever, true);
                });

        while (true)
        {
            try
            {
                ScriptVM script_vm = context.get_ScriptVM();

                receive((EVENT type, string msg)
                        {
                            //writeln ("condition_thread: type:", type, ", msg=[", msg, "]");
                            if (msg !is null && msg.length > 3 && script_vm !is null)
                            {
                                //cbor2individual (&g_individual, msg);
                                g_individual.data = cast(char *)msg;
                                g_individual.length = cast(int)msg.length;

                                foreach (mandat; mandats)
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
                        });
            }
            catch (Exception ex)
            {
                writeln("EX! condition: recieve");
            }
        }
    }
    catch (Exception ex)
    {
        writeln("EX! condition: main loop");
    }
    writeln("TERMINATED: condition_thread");
}

public void load(Context context, VQL vql, ref Set!Mandat mandats)
{
    ScriptVM script_vm = context.get_ScriptVM();

    if (script_vm is null)
        return;

    log.trace_log_and_console("start load mandats");

    Subjects res = new Subjects();
    vql.get(null,
            "return { 'veda-schema:script'}
            filter { 'rdf:type' == 'veda-schema:Mandate'}",
            res);

    int       count = 0;
    JSONValue nil;

    foreach (ss; res.data)
    {
        try
        {
            string    condition_text = ss.getFirstLiteral(veda_schema__script);
            //writeln("condition_text:", condition_text);
            JSONValue condition_json = parseJSON(condition_text);
            Mandat    mandat         = void;

            if (condition_json.type == JSON_TYPE.OBJECT)
            {
                mandat.id = ss.subject;
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
                    writeln("str=", el.str);
                }

                mandats ~= mandat;
//					found_in_condition_templateIds_and_docFields (mandat.expression, "", cai.templateIds, cai.fields);
            }
        }
        catch (Exception ex)
        {
            writeln("error:load mandat :", ex.msg);
        }
    }

    log.trace_log_and_console("end load mandats, count=%d ", res.length);
}
