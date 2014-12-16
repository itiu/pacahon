/**
 * выполнение JS скриптов
 */
module pacahon.scripts;

private
{
    import std.json, std.stdio, std.string, std.array, std.datetime, std.concurrency, std.conv, std.file;
    import core.thread;

    import util.container, util.utils, util.logger, util.cbor, util.cbor8individual;

    import type;
    import onto.individual;
    import pacahon.know_predicates, pacahon.context, pacahon.define, pacahon.thread_context, pacahon.log_msg;

    import search.vel, search.vql;

    import bind.v8d_header;
}

logger log;

static this()
{
    log = new logger("pacahon", "log", "condition");
}

struct Mandat
{
    string id;
    string whom;
    string right;
    string str_script;
    Script compiled_script;
}

private int     count;
private Context context;
private         Mandat[ string ] scripts;
private VQL     vql;

public void condition_thread(string thread_name, string props_file_name)
{
    core.thread.Thread.getThis().name = thread_name;

    context   = new PThreadContext(null, thread_name);
    g_context = context;

    vql = new VQL(context);
    load();

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
                                Individual ss;
                                cbor2individual(&ss, arg);
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
                        (EVENT type, string msg, string individual_id, string event_id)
                        {                        		
                            if (msg !is null && msg.length > 3 && script_vm !is null)
                            {                            	
                                //cbor2individual (&g_individual, msg);
                                g_individual.data = cast(char *)msg;
                                g_individual.length = cast(int)msg.length;

                                foreach (script_id, script; scripts)
                                {
                                    if (script.compiled_script !is null)
                                    {
                                    	if (event_id !is null && event_id.length > 1 && event_id == (individual_id ~ script_id))
                                    	{
                                    		writeln ("skip script [", script_id, "], type:", type, ", indiv.:[", individual_id, "]");
                                    		continue;
                                    	}	

                                        try
                                        {
                                            if (trace_msg[ 300 ] == 1)
                                                log.trace("exec script : %s ", script.str_script);

                                            count++;
                                            script_vm.run(script.compiled_script);

                                            if (trace_msg[ 300 ] == 1)
                                                log.trace("end exec script");
                                        }
                                        catch (Exception ex)
                                        {
                                            log.trace_log_and_console("EX!condition.receive : %s", ex.msg);
                                        }
                                    }
                                }

//                                writeln("count:", count);

                                //clear_script_data_cache ();
                            }
                        },
                        (CMD cmd, int arg, bool arg2)
                        {
                            if (cmd == CMD.SET_TRACE)
                                set_trace(arg, arg2);
                        },
                        (Variant v) { log.trace_log_and_console(thread_name ~ "::Received some other type." ~ text(v)); });
            }
            catch (Exception ex)
            {
                writeln(thread_name, "EX!: receive");
            }
        }
    }
    catch (Exception ex)
    {
        writeln(thread_name, "EX!: main loop");
    }
    writeln("TERMINATED: ", thread_name);
}

public void load()
{
    //writeln ("@1");
    ScriptVM script_vm = context.get_ScriptVM();

    if (script_vm is null)
        return;

    if (trace_msg[ 301 ] == 1)
        log.trace("start load scripts");

    Individual[] res;
    vql.get(null,
            "return { 'v-s:script'}
            filter { 'rdf:type' == 'v-s:Event'}",
            res);

    int count = 0;

    foreach (ss; res)
    {
        prepare_condition(ss, script_vm);
    }

    //writeln ("@2");
    if (trace_msg[ 300 ] == 1)
        log.trace("end load scripts, count=%d ", res.length);
}

private void prepare_condition(Individual ss, ScriptVM script_vm)
{
    if (trace_msg[ 310 ] == 1)
        log.trace("prepare_condition uri=%s", ss.uri);

    JSONValue nil;
    try
    {
        string condition_text = ss.getFirstResource(veda_schema__script).literal;
        if (condition_text.length <= 0)
            return;

        //writeln("condition_text:", condition_text);

        Mandat script = void;
        script.id = ss.uri;

        if (condition_text[ 0 ] == '{')
        {
            JSONValue condition_json = parseJSON(condition_text);

            if (condition_json.type == JSON_TYPE.OBJECT)
            {
                JSONValue el = condition_json.object.get("whom", nil);
                if (el != nil)
                    script.whom = el.str;

                el = condition_json.object.get("right", nil);
                if (el != nil)
                    script.right = el.str;

                el = condition_json.object.get("condition", nil);
                if (el != nil)
                {
                    script.str_script      = el.str;
                    script.compiled_script = script_vm.compile(cast(char *)(script.str_script ~ "\0"));

                    if (trace_msg[ 310 ] == 1)
                        log.trace("#1 script.id=%s, text=%s", script.id, script.str_script);

                    scripts[ ss.uri ] = script;
                }
            }
        }
        else
        {
            script.str_script      = condition_text;
            script.compiled_script = script_vm.compile(cast(char *)(script.str_script ~ "\0"));
            if (trace_msg[ 310 ] == 1)
                log.trace("#2 script.id=%s, text=%s", script.id, script.str_script);

            scripts[ ss.uri ] = script;
        }
    }
    catch (Exception ex)
    {
        log.trace_log_and_console("error:load script :%s", ex.msg);
    }
    finally
    {
        //writeln ("@4");
    }
}
