module pacahon.graph;

struct Subject
{
	char* subject = null;
	PredicateObject*[] outGoingEdges;
	short count_edges = 0;
}

struct PredicateObject
{
	char* predicate = null;
	void* object = null; // если object_as_literal == false, то здесь будет ссылка на Subject 
	bool object_as_literal = true;
}
