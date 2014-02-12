module onto.owl;

private import std.stdio;
private import std.typecons;

private import pacahon.know_predicates;
private import pacahon.context;
private import search.vql;
private import util.utils;
private import util.sgraph;
private import util.container;

enum SRC : ubyte
{
    direct,
    inherited
}

class OWL
{
    Subject[ string ] uid_2_subject;


    alias Property   = Tuple!(SRC, string);
    alias Properties = Set!Property;

    Properties *[ string ] class_2_properties;
    void add(Properties *[ string ], string class_name, string propery_name)
    {
        Properties *properies = class_2_properties.get(class_name, null);

        if (properies is null)
        {
            properies                        = new Properties;
            class_2_properties[ class_name ] = properies;
        }

        Property pr;
        pr[ 0 ] = SRC.direct;
        pr[ 1 ] = propery_name;
        *properies ~= pr;
    }

    this()
    {
    }

    public void load(Context context)
    {
        Subjects res = new Subjects();

        context.vql().get(null,
                          "return { '*'}
            filter { 'a' == 'owl:Class' || 'a' == 'owl:ObjectProperty' || 'a' == 'owl:DatatypeProperty' }",
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
//            writeln("\n#2.3 ss=", ss.subject);
            if (ss.isExsistsPredicate(rdf__type, owl__ObjectProperty) == true || ss.isExsistsPredicate(rdf__type, owl__DatatypeProperty))
            {
                Predicate domain = ss.getPredicate(rdfs__domain);
                if (domain !is null)
                {
                    foreach (dc; domain.getObjects())
                    {
                        Subject ssi;
                        if (dc.type == OBJECT_TYPE.URI)
                        {
                            ssi = uid_2_subject.get(dc.literal, null);
                        }
                        else if (dc.type == OBJECT_TYPE.LINK_SUBJECT)
                        {
                            ssi = dc.subject;
                        }

                        if (ssi !is null)
                        {
                            Predicate unionOf = ssi.getPredicate(owl__unionOf);
                            if (unionOf !is null)
                            {
                                foreach (uo; unionOf)
                                {
                                    add(class_2_properties, uo.literal, ss.subject);
                                }
                            }
                            if (ssi.subject != "_:_")
                            {
                                add(class_2_properties, ssi.subject, ss.subject);
                            }
                        }
                    }
                }
            }
        }
/*
        writeln("#class_2_properties=");
        foreach (key, value; class_2_properties)
        {
            Properties pt = *value;
            writeln(key, "=>", pt.items);
        }
*/
    }

}