module onto.owl;

private
{
    import std.stdio, std.datetime, std.conv, std.exception : assumeUnique;

    import onto.resource;
    import onto.individual;

    import pacahon.know_predicates;
    import pacahon.context;
    import pacahon.interthread_signals;
    import search.vql;
    import util.utils;
    import util.container;
}

struct Property
{
    string     uri;
    Class[]    domain;
    Resource[] label;
    Class[]    range;

    string     toString()
    {
        string res = uri;

        //      res ~= text (label);
        return res;
    }
}

struct Restriction
{
    string     uri;
    Class[]    onClass;
    Class[]    onProperty;
    Resource[] qualifiedCardinality;
}

struct Class
{
    immutable this(string _uri, immutable(Class[]) _subClassOf, immutable(Resource[]) _label, immutable(Property[]) _properties,
                   immutable(Property[]) _inherited_properties)
    {
        uri                  = _uri;
        subClassOf           = _subClassOf.idup;
        label                = _label.idup;
        properties           = _properties.idup;
        inherited_properties = _inherited_properties.idup;
//        writeln ("@2 label=", label);
    }

    string           uri;
    Class[]          subClassOf;
    Resource[]       label;

    Property[]       properties;
    Property[]       inherited_properties;

    Restriction[]    restriction;
    Class[]          disjointWith;

    immutable string toString()
    {
        string res = "{\n " ~ uri ~ "(" ~ text(label) ~ ")";

        res ~= "\n	subClassOf: "~ text(subClassOf);
        res ~= "\n	direct properties: "~ text(properties);
        res ~= "\n	inherited properties: "~ text(inherited_properties);
        res ~= "\n}";
        return res;
    }

    string toString()
    {
        string res = "{\n " ~ uri ~ "(" ~ text(label) ~ ")";

        res ~= "\n	subClassOf: "~ text(subClassOf);
        res ~= "\n	direct properties: "~ text(properties);
        res ~= "\n	inherited properties: "~ text(inherited_properties);
        res ~= "\n}";
        return res;
    }

    immutable(Class) idup() const
    {
        immutable(Class) result = immutable Class(uri, cast(immutable)subClassOf, cast(immutable)label, cast(immutable)properties,
                                                  cast(immutable)inherited_properties);
        return result;
    }
}

class OWL
{
    private Context context;

    Individual[ string ] individuals;

    immutable(Individual)[ string ] i_individuals;
    private immutable(Class)[ string ] i_owl_classes;

//    private Class[] owl_classes;
    private Class *[ string ] uri_2_class;
    private Property *[ string ] uri_2_property;

    public this(Context _context)
    {
        //interthread_signal_id = "onto";
        context = _context;
    }

    Class *getClass(string uri)
    {
        Class *cc = uri_2_class.get(uri, null);

        return cc;
    }

    Property *getProperty(string uri)
    {
        Property *cc = uri_2_property.get(uri, null);

        return cc;
    }

    immutable(Class)[ string ] iget_classes()
    {
        //writeln ("@#1");

        return i_owl_classes;
    }

    immutable(Individual)[ string ] iget_individuals()
    {
        //writeln ("@$1");

        return i_individuals;
    }


    public void load()
    {
        Individual[] l_individuals;
        writeln("[", context.get_name, "], load onto to graph..");
        context.vql().get(null,
                          "return { '*'}
            filter { 'rdf:type' == 'rdfs:Class' || 'rdf:type' == 'rdf:Property' || 'rdf:type' == 'owl:Class' || 'rdf:type' == 'owl:ObjectProperty' || 'rdf:type' == 'owl:DatatypeProperty' }",
                          l_individuals);
        foreach (indv; l_individuals)
        {
            individuals[ indv.uri ]   = indv;
            i_individuals[ indv.uri ] = indv.idup;
        }

        prepare(individuals);

        foreach (cl; uri_2_class.values())
        {
            i_owl_classes[ cl.uri ] = cl.idup;
        }
    }

    private void prepare(ref Individual[ string ])
    {
        uri_2_class    = (Class *[ string ]).init;
        uri_2_property = (Property *[ string ]).init;

        // set classes
        foreach (hh; individuals.values)
        {
            if (hh.isExist(rdf__type, owl__Class) || hh.isExist(rdf__type, rdfs__Class))
            {
                Class *in_class = uri_2_class.get(hh.uri, null);
                if (in_class is null)
                {
                    in_class              = new Class;
                    in_class.uri          = hh.uri;
                    uri_2_class[ hh.uri ] = in_class;
                    Resource[] label = hh.getResources(rdfs__label);
                    in_class.label = label;
                }
            }
        }

        // set direct properties
        foreach (hh; individuals.values)
        {
            if (
                hh.isExist(rdf__type, rdf__Property) ||
                hh.isExist(rdf__type, owl__ObjectProperty) ||
                hh.isExist(rdf__type, owl__DatatypeProperty)
                )
            {
                Property *prop = uri_2_property.get(hh.uri, null);
                if (prop is null)
                {
                    prop                     = new Property;
                    prop.uri                 = hh.uri;
                    uri_2_property[ hh.uri ] = prop;
                    Resource[] label = hh.getResources(rdfs__label);
                    prop.label = label;
                }


                Resource[] domain = hh.getResources(rdfs__domain);
                foreach (dc; domain)
                {
                    Individual ii = individuals.get(dc.uri, Individual.init);

                    Resource[] unionOf = ii.getResources(owl__unionOf);

                    if (unionOf.length > 0)
                    {
                        foreach (uo; unionOf)
                        {
//                            writeln("#head=", hh);
//                            writeln("#domain=", dc);
//                            writeln("#unionOf=", uo);
                            if (uo.uri != owl__Thing)
                            {
                                Class *in_class = uri_2_class.get(uo.uri, null);
                                if (in_class is null)
                                {
                                    in_class              = new Class;
                                    in_class.uri          = uo.uri;
                                    uri_2_class[ uo.uri ] = in_class;
                                }

                                in_class.properties ~= *prop;
                            }
                        }
                    }
                    else
                    {
                        if (dc.uri != owl__Thing)
                        {
                            Class *in_class = uri_2_class.get(dc.uri, null);
                            if (in_class is null)
                            {
                                in_class = new Class;

                                in_class.uri          = dc.uri;
                                uri_2_class[ dc.uri ] = in_class;
                            }
//                            in_class.properties.length += 1;
                            in_class.properties ~= *prop;
                        }
                    }
                }
            }
        }

        // set inherit properties
        foreach (cl; uri_2_class.keys)
        {
            Class *ccl = uri_2_class.get(cl, null);
            if (ccl !is null)
                add_inherit_properies(ccl, cl, 0);
        }
/*
        writeln("#class_2_properties=");
        foreach (key, value; class_2_idx)
        {
                        writeln(key);

                if (value !is null)
                        writeln(value.toString());
        }
 */
    }

    private void add_inherit_properies(Class *to_cl, string look_cl, int level)
    {
        //writeln ("# add_inherit_properies, to_cl=", to_cl, ", look_cl_idx=", look_cl_idx);
        Individual ii = individuals.get(look_cl, Individual.init);

        Resource[] list_subClassOf = ii.getResources(rdfs__subClassOf);
        foreach (subClassOf; list_subClassOf)
        {
            //writeln ("# subClassOf", subClassOf);
            if (level == 0)
            {
                Class *icl = uri_2_class.get(subClassOf.uri, null);
                if (icl !is null)
                    to_cl.subClassOf ~= *icl;
            }
            add_inherit_properies(to_cl, subClassOf.uri, level + 1);
        }

        //writeln ("#3 add_inherit_properies");
        Class *icl = uri_2_class.get(look_cl, null);
        if (icl !is null && icl != to_cl)
        {
            to_cl.inherited_properties ~= icl.properties;
        }
    }
}
