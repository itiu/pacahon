module az.acl;

private
{
    import core.thread, std.stdio, std.conv, std.concurrency, std.file, std.datetime, std.array, std.outbuffer;

    import onto.individual;
    import onto.resource;

    import bind.lmdb_header;

    import util.logger;
    import util.utils;
    import util.cbor;
    import util.cbor8individual;
    import util.logger;

    import pacahon.context;
    import pacahon.define;
    import pacahon.know_predicates;
    import pacahon.log_msg;
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
byte   err;

logger log;

static this()
{
    log = new logger("pacahon", "log", "acl");
}

class Authorization : LmdbStorage
{
    this(string _path)
    {
        super(_path);
    }

    bool isExistMemberShip(Individual *membership)
    {
        if (membership is null)
            return true;

        bool[ string ] add_memberOf;

        Resources resources = membership.getResources(veda_schema__resource);
        Resources memberOf  = membership.getResources(veda_schema__memberOf);

        foreach (mb; memberOf)
            add_memberOf[ mb.uri ] = true;

        int need_found_count = cast(int)add_memberOf.length;

        if (resources.length > 0)
        {
            string groups_str = find(resources[ 0 ].uri);
            if (groups_str !is null)
            {
                string[] groups = groups_str.split(";");

                foreach (group; groups)
                {
                    if (group.length > 0)
                    {
                        if (add_memberOf.get(group, false) == true)
                        {
                            need_found_count--;
                            if (need_found_count <= 0)
                                break;
                        }
                    }
                }
            }
            else
                return false;
        }

        if (need_found_count == 0)
        {
            //writeln("MemberShip already exist:", *membership);
            return true;
        }
        else
            return false;
    }

    bool isExistPermissionStatement(Individual *prst)
    {
        //writeln ("@  isExistPermissionStatement uri=", prst.uri);

        byte  count_new_bits    = 0;
        byte  count_passed_bits = 0;
        ubyte access;

        void check_access_bit(Resource canXXX, ubyte true_bit_pos, ubyte false_bit_pos)
        {
            if (canXXX !is Resource.init)
            {
                if (canXXX.data == "true")
                {
                    count_new_bits++;
                    if (access & true_bit_pos)
                        count_passed_bits++;
                }
                else
                {
                    count_new_bits++;
                    if (access & false_bit_pos)
                        count_passed_bits++;
                }
            }
        }


        Resource permissionObject  = prst.getFirstResource(veda_schema__permissionObject);
        Resource permissionSubject = prst.getFirstResource(veda_schema__permissionSubject);

        string   str = find(permissionObject.uri ~ "+" ~ permissionSubject.uri);

        if (str !is null && str.length > 0)
        {
            access = cast(ubyte)str[ 0 ];

            check_access_bit(prst.getFirstResource(veda_schema__canCreate), Access.can_create, Access.cant_create);
            check_access_bit(prst.getFirstResource(veda_schema__canDelete), Access.can_delete, Access.cant_delete);
            check_access_bit(prst.getFirstResource(veda_schema__canRead), Access.can_read, Access.cant_read);
            check_access_bit(prst.getFirstResource(veda_schema__canUpdate), Access.can_update, Access.cant_update);
        }
        else
        {
            //writeln ("@ NOT FOUND-> ", permissionObject.uri ~ "+" ~ permissionSubject.uri);
            return false;
        }

        if (count_passed_bits < count_new_bits)
        {
            //writeln ("@ PermissionStatement not exist, count_passed_bits = ", count_passed_bits, ", count_new_bits=", count_new_bits);
            return false;
        }
        else
        {
            //writeln("@ PermissionStatement already exist:", *prst);
            return true;
        }
    }

    bool authorize(string uri, Ticket *ticket, Access request_access)
    {
        if (ticket is null)
            return true;
        
         if (trace_msg[ 111 ] == 1) 
         	log.trace ("authorize %s", uri);    

        bool    isAccessAllow = false;

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

            string[] object_groups;
            string[] subject_groups;

            // 1. читаем группы object (uri)
            MDB_val key;
            key.mv_size = uri.length;
            key.mv_data = cast(char *)uri;

            MDB_val data;
            rc = mdb_get(txn_r, dbi, &key, &data);
            if (rc == 0)
            {
                string groups_str = cast(string)(data.mv_data[ 0..data.mv_size ]);

                object_groups = groups_str.split(";");
            }
            object_groups ~= uri;
            object_groups ~= veda_schema__AllResourcesGroup;


            // 2. читаем группы subject (ticket.user_uri)
            key.mv_size = ticket.user_uri.length;
            key.mv_data = cast(char *)ticket.user_uri;

            rc = mdb_get(txn_r, dbi, &key, &data);
            if (rc == 0)
            {
                string groups_str = cast(string)(data.mv_data[ 0..data.mv_size ]);

                subject_groups = groups_str.split(";");
            }
            subject_groups ~= ticket.user_uri;

            //writeln("------------------------");
            //writeln("@authorize:uri=", uri);
            //writeln("@authorize:user_uri=", ticket.user_uri);
            //writeln("@authorize:subject_groups=", subject_groups);
            //writeln("@authorize:object_groups=", object_groups);

            foreach (subject_group; subject_groups)
            {
                if (isAccessAllow)
                    break;
                if (subject_group.length > 1)
                {
                    foreach (object_group; object_groups)
                    {
                        if (object_group.length > 1)
                        {
                            // 3. поиск подходящего acl
                            string acl_key = object_group ~ "+" ~ subject_group;
                            //writeln("@authorize:acl_key=", acl_key);

                            key.mv_size = acl_key.length;
                            key.mv_data = cast(char *)acl_key;

                            rc = mdb_get(txn_r, dbi, &key, &data);
                            if (rc == 0)
                            {
                                str = cast(string)(data.mv_data[ 0..data.mv_size ]);
                                if (str !is null && str.length > 0 && (str[ 0 ] && request_access) == true)
                                {
                                    isAccessAllow = true;
                                    break;
                                }
                            }
                            isAccessAllow = false;
                        }
                    }
                }
            }
        }catch (Exception ex)
        {
        	writeln ("EX!,", ex.msg);
        }
        finally
        {
            mdb_txn_abort(txn_r);

         if (trace_msg[ 111 ] == 1) 
         	log.trace ("authorize %s, result=%s", uri, text(isAccessAllow));    
        }
                
        return isAccessAllow;
    }
}

void acl_manager(string thread_name)
{
    core.thread.Thread.getThis().name = thread_name;
//    writeln("SPAWN: acl manager");
    LmdbStorage storage = new LmdbStorage(acl_indexes_db_path);

    // SEND ready
    receive((Tid tid_response_reciever)
            {
                send(tid_response_reciever, true);
            });
    while (true)
    {
        receive(
                (CMD cmd)
                {
                    if (cmd == CMD.COMMIT)
                    {
                        storage.flush(1);
                    }
                },
                (CMD cmd, EVENT type, string msg)
                {
                    if (cmd == CMD.STORE)
                    {
                        Individual ind;
                        cbor2individual(&ind, msg);

                        //writeln ("ACL: ", ind);

                        Resources rdfType = ind.resources[ rdf__type ];

                        if (rdfType.anyExist(veda_schema__PermissionStatement) == true)
                        {
                            Resource permissionObject = ind.getFirstResource(veda_schema__permissionObject);
                            Resource permissionSubject = ind.getFirstResource(veda_schema__permissionSubject);

                            ubyte access;

                            // найдем предыдущие права для данной пары
                            string str = storage.find(permissionObject.uri ~ "+" ~ permissionSubject.uri);
                            if (str !is null && str.length > 0)
                            {
                                access = cast(ubyte)str[ 0 ];
                            }

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

                            if (trace_msg[ 100 ] == 1)
                            	log.trace("[index] ++ ACL: %s+%s", permissionObject.uri, permissionSubject.uri);
                        }
                        else if (rdfType.anyExist(veda_schema__Membership) == true)
                        {
                            bool[ string ] add_memberOf;
                            Resources resource = ind.getResources(veda_schema__resource);
                            Resources memberOf = ind.getResources(veda_schema__memberOf);

                            foreach (mb; memberOf)
                                add_memberOf[ mb.uri ] = true;

                            foreach (rs; resource)
                            {
                                bool[ string ] new_memberOf = add_memberOf.dup;
                                string groups_str = storage.find(rs.uri);
                                if (groups_str !is null)
                                {
                                    string[] groups = groups_str.split(";");
                                    foreach (group; groups)
                                    {
                                        if (group.length > 0)
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

                                if (trace_msg[ 101 ] == 1)
                                	log.trace("[index] ++ MemberShip: %s : %s", rs.uri, outbuff.toString());
                            }
                        }
                    }
                },
                (CMD cmd, Tid tid_response_reciever)
                {
                    if (cmd == CMD.NOP)
                        send(tid_response_reciever, true);
                    else
                        send(tid_response_reciever, false);
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
                },
                (CMD cmd, int arg, bool arg2)
                {
                    if (cmd == CMD.SET_TRACE)
                        set_trace(arg, arg2);
                },
                (Variant v) { writeln(thread_name, "::Received some other type.", v); });
    }
}
