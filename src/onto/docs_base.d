module onto.docs_base;

private import std.stdio;
private import std.datetime;

private import util.logger;
private import util.graph;

private import pacahon.know_predicates;
private import pacahon.context;

private import onto.rdf_base;
private import onto.doc_template;

byte[ string ] indexedPredicates;

logger log;

static this()
{
    log = new logger("ba2pacahon", "log", "ba2pacahon");
}

//Logger log;

static this()
{
    //	log = new Logger("pacahon", "log", "command-io");

    indexedPredicates[ owl__onProperty ] = 1;
    indexedPredicates[ rdf__type ]       = 1;
    indexedPredicates[ docs__actual ]    = 1;
}

Subject getDocument(string subject, Objectz[] readed_predicate, Context context, ref Subject[ string ] doc_cache)
{
    if (subject is null)
        return null;

    Subject res = doc_cache.get(subject, null);
    if (res !is null)
        return res;

    byte[ string ] r_predicate;

    if (readed_predicate is null)
    {
        r_predicate[ query__all_predicates ] = 1;
    }
    else
    {
        foreach (el; readed_predicate)
        {
            r_predicate[ el.literal ] = 1;
        }

        r_predicate[ rdf__type ] = 0;
    }
    return _getDocument(subject, r_predicate, context, doc_cache);
}

Subject _getDocument(string subject, byte[ string ] r_predicate, Context context,
                     ref Subject[ string ] doc_cache_for_insert)
{
    //	 writeln("#### getDocument :[", subject, "] ", r_predicate);
    Subject      main_subject = null;
    GraphCluster res          = null;

    if (subject is null)
        return null;

    return main_subject;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
DocTemplate getTemplate(string v_dc_identifier, string v_docs_version, Context context, string uid = null)
{
    DocTemplate res = null;

    if (v_dc_identifier is null && uid is null)
        return null;

    res = context.get_template(uid, v_dc_identifier, v_docs_version);

    if (res is null)
    {
        log.trace("не найдено в кэше [%s][%s]", v_dc_identifier, v_docs_version);
        //				// writeln(templates);

        // в кэше не найдено, ищем в базе
    }
    else
    {
        //				// writeln("найдено в кэше[", v_dc_identifier, "][", v_docs_version, "]");
    }

    if (res is null)
    {
        if (v_docs_version !is null)
        {
            log.trace("шаблон [%s], с указаной версией[%s], не найден, поищем без версии", v_dc_identifier, v_docs_version);
            // попробуем еще раз поискать без версии
            res = getTemplate(v_dc_identifier, null, context);

            if (res !is null)
                context.set_template(res, v_dc_identifier, v_docs_version);
        }
        if (res is null)
            log.trace("template not found:%s", v_dc_identifier);
    }

    return res;
}

Subject get_reification_subject_of_link(string subj_versioned_UID, string new_code, string value, Context context,
                                        ref Subject[ string ] doc_cache, out Predicate real_importPredicates, Predicate importPredicates = null)
{
    //	bool TMP_on_trace = false;

    //	if (value == "zdb:doc_d4a7956e-1382-4c6d-be6b-32d0bd511df3")
    //	{
    //		 writeln("#!!!");
    //		TMP_on_trace = true;
    //	}

    // в случае линка, в исходной ba-json данных не достаточно для реификации ссылки,
    // требуется считать из базы

    //	if (TMP_on_trace)
    //	 writeln("#link value=", value);

    Subject linked_doc = null;
    string  linked_template_uid;

    if (importPredicates !is null)
    {
        //		if (TMP_on_trace)
        //		{
        //		writeln("###1 importPredicates=", importPredicates.getObjects());
        //		writeln("###1 value=", value);
        //		}

        //		linked_doc = getDocument(value, importPredicates.getObjects(), context, doc_cache);
        // TODO: OPTIMIZE IT, конечно, так не экономно считывать весь документ, с другой стороны в кэше лучше хранить полный документ или
        // указание, какие предикаты были считанны
        linked_doc = getDocument(value, null, context, doc_cache);
        // writeln("###1 linked_doc=", linked_doc);

        // найдем @ шаблона
        if (linked_doc !is null)
        {
            Predicate type_in = linked_doc.getPredicate(rdf__type);
            linked_template_uid = type_in.getObjects()[ 0 ].literal;
            if (type_in.getObjects().length > 1 && (linked_template_uid == docs__Document || linked_template_uid == auth__Authenticated || linked_template_uid == docs__unit_card || linked_template_uid == docs__group_card))
                linked_template_uid = type_in.getObjects()[ 1 ].literal;
        }
    }
    else
    {
        //		if (TMP_on_trace)
        //			writeln("###2 new_code=", new_code);
        // импортируемые предикаты не указанны
        // считаем экспортируемые предикаты из шаблона документа
        linked_doc = getDocument(value, null, context, doc_cache);

        //		if (TMP_on_trace)
        //			writeln("###2.0.1 linked_doc=", linked_doc);

        if (linked_doc !is null)
        {
            // найдем @ шаблона
            Predicate type_in = linked_doc.getPredicate(rdf__type);
            linked_template_uid = type_in.getObjects()[ 0 ].literal;
            if (type_in.getObjects().length > 1 && (linked_template_uid == docs__Document || linked_template_uid == auth__Authenticated || linked_template_uid == docs__unit_card || linked_template_uid == docs__group_card))
                linked_template_uid = type_in.getObjects()[ 1 ].literal;

            DocTemplate template_gr = getTemplate(null, null, context, linked_template_uid);

            if (template_gr !is null)
            {
                //				if (TMP_on_trace)
                //				 writeln("###2.5 template_gr.data=", template_gr.data);
                importPredicates = template_gr.get_export_predicates();
                //				if (TMP_on_trace)
                //				writeln("###2.5 importPredicates=", importPredicates);
            }

            //			if (TMP_on_trace)
            //			writeln("###2.6");
        }
    }
    //	if (TMP_on_trace)
    //	writeln("###3");
    if (importPredicates !is null && linked_doc !is null)
    {
        //		if (TMP_on_trace)
        //		writeln("###3.1");
        // создать реифицированный субьект rS к текущему аттрибуту
        Subject rS = create_reifed_info(subj_versioned_UID, new_code, value);

        foreach (el; importPredicates.getObjects())
        {
            Predicate pp = linked_doc.getPredicate(el.literal);
            //			if (TMP_on_trace)
            //				writeln("###3.2 pp=", pp);
            if (pp !is null)
            {
                rS.addPredicate(el.literal, pp.getObjects());
            }
        }

        real_importPredicates = importPredicates;

        if (rS !is null)
        {
            rS.addPredicate(link__importClass, linked_template_uid);
        }

        //		if (TMP_on_trace)
        //			writeln("###3.3 rS=", rS);

        //		if (TMP_on_trace)
        //		{
        //			core.thread.Thread.sleep(dur!("seconds")(10));
        //		}

        return rS;
    }

    return null;
}
