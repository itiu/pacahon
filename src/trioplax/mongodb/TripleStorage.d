module trioplax.mongodb.TripleStorage;

private import pacahon.graph;
private import pacahon.context;
private import std.array;
private import std.conv;
private import std.stdio;
private import std.format;
private import util.Logger;
private import pacahon.know_predicates;
private import mongoc.bson_h;
private import std.outbuffer;
private import std.c.string;

/////////////////////////////////// TRIPLE STORAGE
enum field: byte
{
	GET = 0,
	GET_REIFED = 1
}

interface TripleStorage
{
	public TLIterator getTriples(string s, string p, string o, int MAX_SIZE_READ_RECORDS = 1000, int OFFSET = 0);

	public bool removeSubject(string s);

	public void storeSubject(Subject graph, Context server_context);

	public bool isExistSubject(string subject);

	public void addTripleToReifedData(Triple reif, string p, string o, byte lang);

	public TLIterator getTriplesOfMask(ref Triple[] mask_triples, byte[string] reading_predicates,
			int MAX_SIZE_READ_RECORDS = 1000);

	public int get(Ticket ticket, ref GraphCluster res, bson* query, ref string[string] fields, int render, int limit, int offset,
			Authorizer az);

	public int addTriple(Triple tt, bool isReification = false);
}

interface TLIterator
{
	int opApply(int delegate(ref Triple) dg);

//	int length();
}

class Triple
{
	string S;
	string P;
	string O;
	//	int hhh;

	byte lang;

	this(string _S, string _P, string _O)
	{
		S = cast(string) new char[_S.length];
		P = cast(string) new char[_P.length];

		(cast(char[]) S)[] = _S[];
		(cast(char[]) P)[] = _P[];

		if(_O.length > 2 && _O[$ - 3] == '@')
		{
			O = cast(string) new char[_O.length - 3];
			(cast(char[]) O)[] = _O[0 .. $ - 3];

			if(_O[$ - 2] == 'r')
				lang = _RU;
			else if(_O[$ - 2] == 'e')
				lang = _EN;
		} else
		{
			O = cast(string) new char[_O.length];
			(cast(char[]) O)[] = _O[];
		}
	}

	this(string _S, string _P, string _O, byte _lang)
	{
		S = cast(string) new char[_S.length];
		P = cast(string) new char[_P.length];
		O = cast(string) new char[_O.length];

		(cast(char[]) S)[] = _S[];
		(cast(char[]) P)[] = _P[];
		(cast(char[]) O)[] = _O[];

		//		S = _S;
		//		P = _P;
		//		O = _O;
		lang = _lang;

		//		log.trace ("create triple %s", this);
	}

	~this()
	{
		//		log.trace ("destroy triple %s", this);
	}

	override string toString()
	{
		string sS = S;
		string sP = P;
		string sO = O;

		if(sS is null)
			sS = "";

		if(sP is null)
			sP = "";

		if(sO is null)
			sO = "";

		auto writer = appender!string();

		//		formattedWrite(writer, "%X %d %d<%s>%d<%s>%d<%s>", cast(void*)this, hhh, sS.length, sS, sP.length, sP, sO.length, sO);
		formattedWrite(writer, "<%s><%s><%s>", sS, sP, sO);

		return writer.data;
		//		return "<" ~ sS ~ ">"~sS.length~"<" ~ sP ~ "><" ~ sO ~ ">";
	}
}

string fromStringz(char* s)
{
	char[] res = s ? s[0 .. strlen(s)] : null;
	return cast(string) res;
}

char[] getString(char* s)
{
	return s ? s[0 .. strlen(s)] : null;
}

public void add_fulltext_to_query(string fulltext_param, bson* bb)
{
	_bson_append_start_object(bb, "_keywords");
	_bson_append_start_array(bb, "$all");

	string[] values = split(fulltext_param, ",");
	foreach(val; values)
	{
		_bson_append_regex(bb, " ", val, "imx");
	}

	bson_append_finish_object(bb);
	bson_append_finish_object(bb);
}

char[] bson_to_string(bson* b)
{
	OutBuffer outbuff = new OutBuffer();
	bson_raw_to_string(b, 0, outbuff);
	outbuff.write(0);
	return getString(cast(char*) outbuff.toBytes());
}

void bson_raw_to_string(bson* b, int depth, OutBuffer outbuff, bson_iterator* ii = null)
{
	bson_iterator* i;
	char* key;
	int temp;
	char oidhex[25];

	if(ii is null)
	{
		i = new bson_iterator;
		bson_iterator_init(i, b);
	} else
		i = ii;

	while(bson_iterator_next(i))
	{
		bson_type t = bson_iterator_type(i);
		if(t == 0)
			break;

		key = bson_iterator_key(i);

		for(temp = 0; temp <= depth; temp++)
			outbuff.write('\t');

		outbuff.write(getString(key));
		if(getString(key).length > 0)
			outbuff.write(':');

		switch(t)
		{
			case bson_type.BSON_INT:
				outbuff.write("int ");
				outbuff.write(text(bson_iterator_int(i)));
			break;

			case bson_type.BSON_DOUBLE:
				outbuff.write("double ");
				outbuff.write(bson_iterator_double(i));
			break;

			case bson_type.BSON_DATE:
				outbuff.write(cast(char[]) "date ");
			//				outbuff.write(bson_iterator_date(i));
			break;

			case bson_type.BSON_BOOL:
				outbuff.write(cast(char[]) "bool ");
				outbuff.write((bson_iterator_bool(i) ? cast(char[]) "true" : cast(char[]) "false"));
			break;

			case bson_type.BSON_STRING:
				outbuff.write(cast(char[]) "string ");
				outbuff.write(getString(bson_iterator_string(i)));
			break;

			case bson_type.BSON_REGEX:
				outbuff.write(cast(char[]) "regex ");
				outbuff.write(getString(bson_iterator_regex(i)));
			break;

			case bson_type.BSON_NULL:
				outbuff.write(cast(char[]) "null");
			break;

			//			case bson_type.bson_oid:
			//				bson_oid_to_string(bson_iterator_oid(&i), cast(char*) &oidhex);
			//				printf("%s", oidhex);
			//			break; //@@@ cast (char*)&oidhex)
			case bson_type.BSON_OBJECT:
				outbuff.write('\n');
				for(temp = 0; temp <= depth; temp++)
					outbuff.write('\t');
				outbuff.write("{\n");

				bson_iterator i1;
				bson_iterator_subiterator(i, &i1);
				bson_raw_to_string(null, depth + 1, outbuff, &i1);

				outbuff.write('\n');
				for(temp = 0; temp <= depth; temp++)
					outbuff.write('\t');
				outbuff.write('}');
			break;

			case bson_type.BSON_ARRAY:
				outbuff.write('\n');
				for(temp = 0; temp <= depth; temp++)
					outbuff.write('\t');
				outbuff.write("[\n");
				bson_iterator i1;
				bson_iterator_subiterator(i, &i1);
				bson_raw_to_string(null, depth + 1, outbuff, &i1);
				outbuff.write('\n');
				for(temp = 0; temp <= depth; temp++)
					outbuff.write('\t');
				outbuff.write("]");
			break;

			default:
			break;
			//				fprintf(stderr, "can't print type : %d\n", t);
		}
		outbuff.write(cast(char[]) "\n");
	}
}
