module trioplax.TripleStorage;

private import trioplax.triple;

enum field: byte
{
 GET = 0,
 GET_REIFED = 1
}


interface TripleStorage
{
	// main functions	
	public int addTriple(Triple tt);
	public void addTripleToReifedData(Triple reif, string p, string o, byte lang);
	
	public TLIterator getTriples(string s, string p, string o, int MAX_SIZE_READ_RECORDS = 1000, int OFFSET = 0);
	public TLIterator getTriplesOfMask(ref Triple[] triples, byte[char[]] read_predicates, int MAX_SIZE_READ_RECORDS = 1000);
	
	public bool isExistSubject (string subject); 
	
	public bool removeTriple(string s, string p, string o);
	public bool removeSubject(string s);
	
	// configure functions	
//	public void set_new_index(ubyte index, uint max_count_element, uint max_length_order, uint inital_triple_area_length);
	
	public void define_predicate_as_multiple(string predicate);	
	public void define_predicate_as_multilang(string predicate);
	public void set_fulltext_indexed_predicates(string predicate);

	//	public void setPredicatesToS1PPOO(char[] P1, char[] P2, char[] _store_predicate_in_list_on_idx_s1ppoo);

	public void set_stat_info_logging(bool flag);		
	public void set_log_query_mode (bool on_off);	
	////////////////////////////////////////
		
	public void print_stat();

	////////////////////////////////////////	
//	private void logging_query(char[] op, Triple [] mask, List list);	
}

interface TLIterator
{	
    int opApply(int delegate(ref Triple) dg);
    int length ();
}
