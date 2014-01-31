module onto.owl;

private import std.stdio;

private import pacahon.know_predicates;
private import pacahon.context;
private import search.vql;
private import util.utils;
private import util.graph;
private import util.container;

class OWL
{
    Subject[ string ] uid_2_subject;
    Subjects[ string ] properties_2_class;

    this()
    {
    }

    public void load(Context context)
    {
        Subjects res = new Subjects();
        context.vql().get(null,
                          "return { '*'}
            filter { 'a' == 'owl:Class' || 'a' == 'owl:ObjectProperty' || 'a' == 'owl:DatatypeProperty' }"                                         ,
                          res);
        set_data_and_relink(res);
    }

    void set_data_and_relink(Subjects _subjs)
    {
        foreach (ss; _subjs.data)
        {
            uid_2_subject[ ss.subject ] = ss;
        }
/*
        foreach (ss; _subjs.data)
        {
            foreach (pp; ss.getPredicates())
            {
                foreach (oo; pp.getObjects())
                {
                    if (oo.type == OBJECT_TYPE.URI)
                    {
                        Subject link = uid_2_subject.get(oo.literal, null);
                        if (link !is null)
                        {
                            oo.type    = OBJECT_TYPE.LINK_SUBJECT;
                            oo.subject = link;
                        }
                    }
                }
            }
        }
 */
        foreach (ss; _subjs.data)
        {
            writeln("\n#2.3 ss=", ss.subject);
            if (ss.isExsistsPredicate(rdf__type, owl__ObjectProperty) == true || ss.isExsistsPredicate(rdf__type, owl__DatatypeProperty))
            {
                Predicate domain = ss.getPredicate(rdfs__domain);
                if (domain !is null)
                {
                    writeln("#2.5 domain=", domain);
                    foreach (dc; domain.getObjects())
                    {
                    	Subject ssi;
                        if (dc.type == OBJECT_TYPE.URI)
                        {
                        writeln("#2.6 dc=", dc);
                            ssi = uid_2_subject.get(dc.literal, null);
                           }
                         else if (dc.type == OBJECT_TYPE.LINK_SUBJECT)
                    	{
                    		ssi = dc.subject;
                    		}
                    	
                            if (ssi !is null)
                            {
                        writeln("#2.7 ssi=", ssi.subject);
                                Predicate unionOf = ssi.getPredicate(owl__unionOf);
                                if (unionOf !is null)
                                {
                        writeln("#2.8 unionOf=", unionOf);
                                    foreach (uo; unionOf)
                                    {
                        writeln("#2.9 uo=", uo);
                                    	
                                    	
                                        Subjects properies = properties_2_class.get(uo.literal, new Subjects());
                        writeln("#2.10 properies=", properies);

                                        if (properies.length == 0)
                                            properties_2_class[ uo.literal ] = properies;

                                        properies.addSubject (ss);
                                    }
                                }
                                if (ssi.subject != "_:_")
                                {
                                    
                                        Subjects properies = properties_2_class.get(ssi.subject, new Subjects());

                                        if (properies.length == 0)
                                            properties_2_class[ ssi.subject] = properies;

                                        properies.addSubject (ss);

                       // writeln("#2.9 properies=", properies);
                                }
                            }
                        }

                        
                }
            }
        }

        writeln("#properties_2_class=", properties_2_class);
    }
}