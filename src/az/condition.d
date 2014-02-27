module az.condition;

private
{
    import std.json;
    import std.stdio;
    import std.string;
    import std.array;
    import std.datetime;
    import std.concurrency;

    import util.container;
    import util.oi;
    import util.utils;
    import util.logger;
    import util.sgraph;
    import util.cbor;
    import util.cbor8sgraph;

    import pacahon.know_predicates;
    import pacahon.context;
    import pacahon.thread_context;

    import search.vel;
    import search.vql;

    import az.orgstructure_tree;
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
    TTA    expression;
}


public void condition_thread(string props_file_name)
{
    Context context = new ThreadContext(null, "condition_thread");

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
                receive((EVENT type, string msg)
                        {
//          writeln ("condition_thread: type:", type, ", msg=[", msg, "]");
                            if (msg !is null && msg.length > 3)
                            {
                                Subject doc = decode_cbor(msg);

                                foreach (mandat; mandats)
                                {
                                    string token;
                                    Set!string whom;
                                    eval(mandat.expression, "", doc, token, whom);
                                }
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
            writeln("condition_text:", condition_text);
            JSONValue condition_json = parseJSON(condition_text);
            Mandat    mandat = void;

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
                    mandat.expression = parse_expr(el.str);
                    //writeln ("\nmandat.id=", mandat.id);
                    //writeln ("str=", el.str);
                    //writeln ("TTA=", mandat.expression);
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



public bool eval(TTA tta, string p_op, Subject doc, out string token, ref Set!string whom, int level = 0)
{
    if (tta.op == "==" || tta.op == "!=")
    {
        string A;
        eval(tta.L, tta.op, doc, A, whom, level + 1);
        string B;
        eval(tta.R, tta.op, doc, B, whom, level + 1);
//			writeln ("\ndoc=", doc);
//			writeln ("fields=", fields);
//			writeln (A, " == ", B);

        string ff = A;

        if (B == "$user")
        {
            if (p_op == "||")
            {
                whom ~= A;
            }
            else
            {
                whom.empty();
                whom ~= A;
            }
            return true;
//				B = userId;
        }
        else
        {
            //writeln ("ff=", ff);
            //writeln ("fields.get (ff).items=", doc.getObjects(ff));

            // для всех значений поля ff
            foreach (field_i; doc.getObjects(ff))
            {
                string field = field_i.literal;

                //writeln ("field ", field, " ", tta.op, " ", B, " ", tta.op == "==" && field == B, " ", tta.op == "!=" && field != B);
                if (tta.op == "==" && field == B)
                    return true;

                if (tta.op == "!=" && field != B)
                    return true;
            }
        }

        return false;
    }
    else if (tta.op == "&&")
    {
        bool A = false, B = false;

        if (tta.R !is null)
            A = eval(tta.R, tta.op, doc, token, whom, level + 1);

        if (tta.L !is null)
            B = eval(tta.L, tta.op, doc, token, whom, level + 1);

        return A && B;
    }
    else if (tta.op == "||")
    {
        bool A = false, B = false;

        if (tta.R !is null)
            A = eval(tta.R, tta.op, doc, token, whom, level + 1);

        if (A == true)
            return true;

        if (tta.L !is null)
            B = eval(tta.L, tta.op, doc, token, whom, level + 1);

        return A || B;
    }
    else if (tta.op == "true")
    {
        return true;
    }
    else
    {
        token = tta.op;
    }
    return false;
}

/*
   private static string found_in_condition_templateIds_and_docFields(TTA tta, string p_op, ref HashSet!string templateIds, ref HashSet!string fields, int level = 0)
   {
                if(tta.op == "==" || tta.op == "!=")
                {
                        string A = found_in_condition_templateIds_and_docFields(tta.L, tta.op, templateIds, fields, level + 1);
                        string B = found_in_condition_templateIds_and_docFields(tta.R, tta.op, templateIds, fields, level + 1);
                        //writeln (A, " == ", B);
                        if (A == class__identifier)
                        {
                                templateIds.add (B);
                                fields.add (class__identifier);
                        }
                        else
                                fields.add (A);

                }
                else if(tta.op == "&&" || tta.op == "||")
                {
                        if(tta.R !is null)
                                found_in_condition_templateIds_and_docFields(tta.R, tta.op, templateIds, fields, level + 1);

                        if(tta.L !is null)
                                found_in_condition_templateIds_and_docFields(tta.L, tta.op, templateIds, fields, level + 1);
                }
                else
                {
                        return tta.op;
                }

                return "";
   }
 */
