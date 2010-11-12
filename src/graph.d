module pacahon.graph;

private import std.c.string;

struct Subject
{
	char* subject = null;
	Predicate*[] edges;
	short count_edges = 0;

	Predicate*[char[]] edges_of_predicate;
}

struct Predicate
{
	char* predicate = null;
	Objectz[] objects; // начальное количество значений objects.length = 1, если необходимо иное, следует создавать новый массив objects 
	short count_objects = 0;

	Objectz*[char[]] objects_of_value;
}

struct Objectz
{
	void* object; // если object_as_literal == false, то здесь будет ссылка на Subject
	bool object_as_literal = true;
}

void set_outGoingEdgesOfPredicate(Subject* ss)
{
	for(short jj = 0; jj < ss.count_edges; jj++)
	{
		Predicate* pp = ss.edges[jj];
		                 
		char[] predicate = fromStringz(pp.predicate);

		ss.edges_of_predicate[predicate] = pp;

		for(short kk = 0; kk < pp.count_objects; kk++)
		{
			if (pp.objects[kk].object_as_literal == true)
			{
				char[] object = fromStringz(cast(char*)pp.objects[kk].object);
				pp.objects_of_value[object] = &pp.objects[kk];
			}
		}

	}
}

char[] fromStringz(char* s)
{
	return s ? s[0 .. strlen(s)] : null;
}
