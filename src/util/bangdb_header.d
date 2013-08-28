module util.bangdb_header;

extern (C++) 
{

enum dbType
{
        EMBED_INMEM_ONLY,                       //one proc, only RAM based, cache enabled (no overflow to disk, ideally overflow to other RAM)
        EMBED_INMEM_PERSIST,            //one proc, disked backed, cache enabled (over flow to disk)
        EMBED_FILE,                                     //many procs one db file, cache disabled
        NETWORK_INMEM_PERSIST           //as a service, cache enabled, default for client connecting over network (tcp)
};

//types of index
enum indexType
{
        HASH,
        EXTHASH,
        BTREE,
        HEAP
};

//how should we access db, various ways
enum dbAccess
{
        OPENCREATE,
        TRUNCOPEN,
        JUSTOPEN
};

//the various state of the db
enum dbState
{
        DBCLOSE,
        DBOPEN
};

//how should db be closed
enum dbClose
{
        DEFAULT,
        CONSERVATIVE,
        OPTIMISTIC,
        CLEANCLOSE,
};

enum insertOptions
{
        INSERT_UNIQUE,          //if non-existing then insert else return
        UPDATE_EXISTING,        //if existing then update else return
        INSERT_UPDATE,          //insert if non-existing else update
        DELETE_EXISTING,        //delete if existing
};

	
  interface BangConnection 
  {
  	int put(char *key, long key_length, char *val, long val_length, short flag);
  	int put(char *key, char *val, short flag);
	int get(void *key, long key_length, void **out_val, uint **out_val_length);
  	char* get(char *key);
  	int closeConnection();
  }
	
  interface BangTable 
  {
  	BangConnection getConnection();
  }
  
  interface BangDatabase 
  {
    BangTable getTable(char *name, indexType idxType, short dbtype, short openflag, short enablelog);
    BangTable getTable(char *name, short openflag);
    void closeDatabase();
  }

  BangDatabase newBangDatabase(char* user);
}

