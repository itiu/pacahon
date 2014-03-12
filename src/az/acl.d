module az.acl;

private
{
    import std.stdio, std.concurrency, std.file, std.datetime, std.array, std.outbuffer;

    import onto.individual;
    import onto.resource;

    import bind.lmdb_header;

    import util.logger;
    import util.utils;
    import util.cbor;
    import util.cbor8individual;

    import pacahon.context;
    import pacahon.define;
    import pacahon.know_predicates;
    import storage.lmdb_storage;
}

//////////////// ACLManager

/*********************************************************************
   permissionObject uri
   permissionSubject uri
   permission

   индекс:
                permissionObject + permissionSubject
*********************************************************************/
byte err;

class Authorization : LmdbStorage
{
    this(string _path)
    {
        super(_path);
    }

    bool authorize(string uri, Ticket *ticket, Access request_acess)
    {
        MDB_txn *txn_r;
        MDB_dbi dbi;
        string  str;
        int     rc;

        rc = mdb_txn_begin(env, null, MDB_RDONLY, &txn_r);
        if (rc == MDB_BAD_RSLOT)
        {
            writeln("LmdbStorage:find #1, mdb_tnx_begin, rc=", rc, ", err=", fromStringz(mdb_strerror(rc)));
            mdb_txn_abort(txn_r);
            rc = mdb_txn_begin(env, null, MDB_RDONLY, &txn_r);
        }

        if (rc != 0)
            writeln("LmdbStorage:find #2, mdb_tnx_begin, rc=", rc, ", err=", fromStringz(mdb_strerror(rc)));

        try
        {
            rc = mdb_dbi_open(txn_r, null, MDB_CREATE, &dbi);
            if (rc != 0)
                throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));

            // 1. читаем группы object
            // 2. читаем группы subject
            // 3. читаем группы acl

            MDB_val key;
            key.mv_size = uri.length;
            key.mv_data = cast(char *)uri;

            MDB_val data;
            rc = mdb_get(txn_r, dbi, &key, &data);
            if (rc == 0)
            {
                str = cast(string)(data.mv_data[ 0..data.mv_size ]);
            }
        }catch (Exception ex)
        {
        }

        mdb_txn_abort(txn_r);


        if (ticket is null)
            return true;

        // группы пользователя
//	ticket.user_uri

        return false;
    }
}

logger log;

static this()
{
    log = new logger("pacahon", "log", "server");
}

void acl_manager()
{
//    writeln("SPAWN: acl manager");
    LmdbStorage storage = new LmdbStorage(acl_indexes_db_path);

    // SEND ready
    receive((Tid tid_response_reciever)
            {
                send(tid_response_reciever, true);
            });
    while (true)
    {
        receive((CMD cmd, EVENT type, string msg)
                {
                    if (cmd == CMD.STORE)
                    {
                        Individual ind;
                        cbor2individual(&ind, msg);

                        Resources rdfType = ind.resources[ rdf__type ];

                        if (rdfType.anyExist(veda_schema__PermissionStatement) == true)
                        {
                            Resource permissionObject = ind.getFirstResource(veda_schema__permissionObject);
                            Resource permissionSubject = ind.getFirstResource(veda_schema__permissionSubject);

                            ubyte access;

                            Resource canCreate = ind.getFirstResource(veda_schema__canCreate);
                            if (canCreate !is Resource.init)
                            {
                                if (canCreate.data == "true")
                                    access = access | Access.can_create;
                                else
                                    access = access | Access.cant_create;
                            }

                            Resource canDelete = ind.getFirstResource(veda_schema__canDelete);
                            if (canDelete !is Resource.init)
                            {
                                if (canDelete.data == "true")
                                    access = access | Access.can_delete;
                                else
                                    access = access | Access.cant_delete;
                            }

                            Resource canRead = ind.getFirstResource(veda_schema__canRead);
                            if (canRead !is Resource.init)
                            {
                                if (canRead.data == "true")
                                    access = access | Access.can_read;
                                else
                                    access = access | Access.cant_read;
                            }

                            Resource canUpdate = ind.getFirstResource(veda_schema__canUpdate);
                            if (canUpdate !is Resource.init)
                            {
                                if (canUpdate.data == "true")
                                    access = access | Access.can_update;
                                else
                                    access = access | Access.cant_update;
                            }

                            storage.put(permissionObject.uri ~ "+" ~ permissionSubject.uri, "" ~ access);

                            writeln("ACL:", permissionObject.uri ~ "+" ~ permissionSubject.uri);
                        }
                        else if (rdfType.anyExist(veda_schema__Membership) == true)
                        {
                            bool[ string ] add_memberOf;
                            Resources resource = ind.getResources(veda_schema__resource);
                            Resources memberOf = ind.getResources(veda_schema__memberOf);

                            foreach (mb; memberOf)
                            {
                                add_memberOf[ mb.uri ] = true;
                            }

                            foreach (rs; resource)
                            {
                                bool[ string ] new_memberOf = add_memberOf.dup;
                                string groups_str = storage.find(rs.uri);
                                if (groups_str !is null)
                                {
                                    string[] groups = groups_str.split(";");
                                    foreach (group; groups)
                                    {
                                        new_memberOf[ group ] = true;
                                    }
                                }

                                OutBuffer outbuff = new OutBuffer();
                                foreach (key; new_memberOf.keys)
                                {
                                    outbuff.write(key);
                                    outbuff.write(';');
                                }

                                storage.put(rs.uri, outbuff.toString());
                                writeln("MemberShip: ", rs.uri, " : ", outbuff.toString());
                            }
                        }
                    }
                },
                (CMD cmd, string msg, Tid tid_response_reciever)
                {
                    if (cmd == CMD.AUTHORIZE)
                    {
//                            writeln ("is AUTHORIZE msg=[", msg, "]");
                        Individual ind;
                        cbor2individual(&ind, msg);

                        send(tid_response_reciever, msg, thisTid);
                    }
                    else
                    {
                        send(tid_response_reciever, "?");
                    }
                });
    }
}
