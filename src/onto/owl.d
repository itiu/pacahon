module onto.owl;

private import std.stdio, std.typecons, std.conv;

private import pacahon.know_predicates;
private import pacahon.context;
private import search.vql;
private import util.utils;
private import util.sgraph;
private import util.container;
private import util.lmultidigraph;

struct Property
{
    string     id;
    Class[]    domain;
    Resource[] label;
    Class[]    range;

    string     toString()
    {
        string res = id;

        //      res ~= text (label);
        return res;
    }
}

struct Restriction
{
    string     id;
    Class[]    onClass;
    Class[]    onProperty;
    Resource[] qualifiedCardinality;
}

struct Class
{
    string        id;
    Class[]       subClassOf;
    Resource[]    label;

    Property[]    properties;
    Property[]    inherited_properties;

    Restriction[] restriction;
    Class[]       disjointWith;

    string        toString()
    {
        string res = "{\n " ~ id ~ "(" ~ text(label) ~ ")";

        res ~= "\n	direct properties: "~ text(properties);
        res ~= "\n	inherited properties: "~ text(inherited_properties);
        res ~= "\n}";
        return res;
    }
}

Class    NilClass    = Class.init;
Property NilProperty = Property.init;

class OWL
{
    LabeledMultiDigraph lmg;

    Class *[ size_t ] class_2_idx;
    Property *[ size_t ] property_2_idx;

    this()
    {
        lmg = new LabeledMultiDigraph();
    }

    public void load(Context context)
    {
        LabeledMultiDigraph lmg = new LabeledMultiDigraph();

//        Subjects res = new Subjects();
//		writeln (context.get_name, ", load onto to graph..");
        context.vql().get(null,
        	"return { '*'}
            filter { 'a' == 'owl:Class' || 'a' == 'owl:ObjectProperty' || 'a' == 'owl:DatatypeProperty' }",
                          lmg);
        set_data(lmg);
//		writeln ("load onto to graph..ok");

//        writeln("# lmg.elements=", lmg.elements);
//        lmg.getEdges1("mondi-schema:AdministrativeDocument");
    }

    void set_data(LabeledMultiDigraph _lmg)
    {
        lmg            = _lmg;
        class_2_idx    = (Class *[ size_t ]).init;
        property_2_idx = (Property *[ size_t ]).init;

        // set classes
        foreach (hh; lmg.getHeads())
        {
            if (lmg.isExsistsEdge(hh, rdf__type, owl__Class))
            {
                Class *in_class = class_2_idx.get(hh.idx, null);
                if (in_class is null)
                {
                    in_class              = new Class;
                    in_class.id           = hh.data;
                    in_class.properties   = new Property[ 0 ];
                    class_2_idx[ hh.idx ] = in_class;
                    Set!Resource label    = lmg.getTail(hh, rdfs__label);
                    in_class.label        = label.items;
                }
            }
        }

        // set direct properties
        foreach (hh; lmg.getHeads())
        {
            if (lmg.isExsistsEdge(hh, rdf__type, owl__ObjectProperty) || lmg.isExsistsEdge(hh, rdf__type, owl__DatatypeProperty))
            {
                Property *prop = property_2_idx.get(hh.idx, null);
                if (prop is null)
                {
                    prop                     = new Property;
                    prop.id                  = hh.data;
                    property_2_idx[ hh.idx ] = prop;
                    Set!Resource label       = lmg.getTail(hh, rdfs__label);
                    prop.label               = label.items;
                }


                Set!Resource domain = lmg.getTail(hh, rdfs__domain);
                foreach (dc; domain)
                {
                    Set!Resource unionOf = lmg.getTail(dc, owl__unionOf);

                    if (unionOf.length > 0)
                    {
                        foreach (uo; unionOf)
                        {
//                            writeln("#head=", hh);
//                            writeln("#domain=", dc);
//                            writeln("#unionOf=", uo);
                            if (uo.data != owl__Thing)
                            {
                                Class *in_class = class_2_idx.get(uo.idx, null);
                                if (in_class is null)
                                {
                                    in_class              = new Class;
                                    in_class.id           = uo.data;
                                    class_2_idx[ uo.idx ] = in_class;
                                }

                                in_class.properties ~= *prop;
                            }
                        }
                    }
                    else
                    {
                        if (dc.data != owl__Thing)
                        {
                            Class *in_class = class_2_idx.get(dc.idx, null);
                            if (in_class is null)
                            {
                                in_class = new Class;

                                in_class.id           = dc.data;
                                class_2_idx[ dc.idx ] = in_class;
                            }
//                            in_class.properties.length += 1;
                            in_class.properties ~= *prop;
                        }
                    }
                }
            }
        }

        // set inherit properties
        foreach (cl; class_2_idx.keys)
        {
            Class *ccl = class_2_idx.get(cl, null);
            if (ccl !is null)
                add_inherit_properies(ccl, cl);
        }

        writeln("#class_2_properties=");
        foreach (th; class_2_idx.values)
        {
            writeln(th.toString());
        }
    }

    private void add_inherit_properies(Class *to_cl, size_t look_cl_idx)
    {
        //writeln ("# add_inherit_properies, to_cl=", to_cl, ", look_cl_idx=", look_cl_idx);
        Set!Resource list_subClassOf = lmg.getTail(look_cl_idx, rdfs__subClassOf);
        foreach (subClassOf; list_subClassOf)
        {
            add_inherit_properies(to_cl, subClassOf.idx);
        }

        //writeln ("#3 add_inherit_properies");
        Class *icl = class_2_idx.get(look_cl_idx, null);
        if (icl !is null && icl != to_cl)
        {
            to_cl.inherited_properties ~= icl.properties;
        }
    }
}