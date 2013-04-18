module onto.rdf_base;

private import std.stdio;
private import pacahon.know_predicates;
private import pacahon.graph;

Subject create_reifed_info(string ss, string pp, string oo)
{
	Subject new_subj = new Subject();

	new_subj.subject = "r" ~ oo[8..14];

	new_subj.addPredicate(rdf__type, rdf__Statement);
	new_subj.addPredicate(rdf__subject, ss);
	new_subj.addPredicate(rdf__predicate, pp);
	new_subj.addPredicate(rdf__object, oo);

//	writeln("create_reifed_info s=", ss, ", p=", pp, ", o=", oo);
	return new_subj;
}
