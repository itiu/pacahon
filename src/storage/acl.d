module storage.acl;

private
{ 
	import std.stdio;
	import std.concurrency;
	import std.file;
	
	import util.logger;
	import util.utils;	

	import bind.lmdb_header;	
	import pacahon.graph;
	import pacahon.context;
	import pacahon.define;
	import ae.utils.container;	
}

logger log;

static this()
{
	log = new logger("pacahon", "log", "server");
}

//////////////// ACLManager

/*********************************************************************
запись ACL: [кто];[кому];[на что];[какие права];[когда];
 
кто - subject
кому - subject
на что - subject
какие права - crud
когда

ключи
1. [кому]+[на что]+[право] : подтверждение права, значение [byte]
2. [кому]+[на что] : уникальные по значению записи о правах

*********************************************************************/

void acl_manager ()
{
    writeln ("SPAWN: ALC manager");
    MDB_env *env;
    MDB_dbi dbi;
    MDB_txn *txn;

    string path = "./data/lmdb-acl";

    try
    {
        mkdir("data");
    }
    catch (Exception ex)
    {
    }

    try
    {
    	mkdir(path);
    }
    catch (Exception ex)
    {    	
    }
     
	int rrc;
    rrc = mdb_env_create(&env); 
	if (rrc != 0)
		writeln ("ERR! mdb_env_create:", fromStringz (mdb_strerror (rrc)));	
	else 
	{	    
		rrc = mdb_env_set_mapsize(env, 10485760*10);
		if (rrc != 0)
			writeln ("ERR! mdb_env_set_mapsize:", fromStringz (mdb_strerror (rrc)));
		else
		{				    
			rrc = mdb_env_open(env, cast(char*)path, MDB_FIXEDMAP, std.conv.octal!664);
		
			if (rrc != 0)
				writeln ("ERR! mdb_env_open:", fromStringz (mdb_strerror (rrc)));
			else
			{	    
				if (!rrc)
				{
					rrc = mdb_txn_begin(env, null, 0, &txn);
					rrc = mdb_dbi_open(txn, null, MDB_CREATE|MDB_DUPSORT, &dbi);				
				}
			}
		}	
	}			
	
	int rc;
	
	while (true)
	{
		string res = "";
		receive((byte cmd, string msg, Tid tid_sender) 
		{
			if (rrc == 0)
			{
			try
			{	
				if (cmd == AUTHORIZE)
				{
//					writeln ("is AUTHORIZE");
					Set!string*[string] sss = get_subject_from_BSON (msg, TYPE);			
//					print_2 (sss);
				
					send(tid_sender, msg, thisTid);										
				}
				else if (cmd == STORE)
				{
					Subject graph = Subject.fromBSON (msg);
					
//					writeln ("#1 graph.subject:", graph.subject);
					MDB_val key;					
					key.mv_data = cast(char*)graph.subject;
					key.mv_size = graph.subject.length;
					
					MDB_val data;
					data.mv_data = cast(char*)msg;
					data.mv_size = msg.length;
					
                    rc = mdb_put(txn, dbi, &key, &data, 0);
                    if (rc == 0)                     
                    	res = "Ok";
                    else
                    {
                    	res = "Fail:" ~  fromStringz (mdb_strerror (rc));
                    	writeln ("#1 rc:", fromStringz (mdb_strerror (rc)));
                   	}
	//				writeln ("#1 key.length:", graph.subject.length);
		//			writeln ("#1 data.length:", msg.length);
                    	
                   // send(tid_sender, res);	
                    	
                    rc = mdb_txn_commit(txn);  
                    rc = mdb_txn_begin(env, null, 0, &txn);
				}
				else if (cmd == FOUND)
				{
//					writeln ("%1 ", msg);
//					MDB_txn *txn_r;
//					rc = mdb_txn_begin(env, null, MDB_RDONLY, &txn_r);

					//	writeln ("%%0, rc:", rc);	                  					
					if (rc != 0)
						writeln ("%2 tnx begin:", fromStringz (mdb_strerror (rc)));
					else
					{
					//	writeln ("%%1");	                  					
					MDB_val key;
					key.mv_size = msg.length;
					key.mv_data = cast(char*)msg;
					
					//	writeln ("%%2");	                  					
					MDB_val data;
					int rc = mdb_get (txn, dbi, &key, &data);
					//	writeln ("%%3");	                  					
							
					if (rc == 0)					
						res = cast(string)(data.mv_data[0..data.mv_size]);
					else
					{	
						res = "";
                    	writeln ("#1 rc:[", msg, "] , ", fromStringz (mdb_strerror (rc)));
                    }	
					//	writeln ("%%4");	                  					
						
					send(tid_sender, res);					
//					mdb_txn_abort(txn_r);
					}	
					//	writeln ("%%5");	                  					
					
				}
				else
				{
					writeln ("%3 ", msg);
					send(tid_sender, "");
				}
			}
			catch (Exception ex)
			{
					writeln ("EX!", ex.msg);
			}
			}
		});
		
	}
}
