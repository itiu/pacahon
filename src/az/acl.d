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
    this(string _path, DBMode mode)
    {
        super(_path, mode);
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
                if (canXXX == true)
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
            if (trace_msg[ 115 ] == 1)
                log.trace("ACL NOT FOUND -> %s", permissionObject.uri ~ "+" ~ permissionSubject.uri);
            return false;
        }

        if (count_passed_bits < count_new_bits)
        {
            if (trace_msg[ 115 ] == 1)
                log.trace("PermissionStatement not exist, count_passed_bits = %d, count_new_bits=%d", count_passed_bits, count_new_bits);

            return false;
        }
        else
        {
            if (trace_msg[ 115 ] == 1)
                log.trace("PermissionStatement already exist: %s", *prst);
            return true;
        }
    }

    bool authorize(string uri, Ticket *ticket, Access request_access)
    {
        if (ticket is null)
            return true;

        if (trace_msg[ 111 ] == 1)
            log.trace("authorize %s", uri);

        bool    isAccessAllow = false;

        MDB_txn *txn_r;
        MDB_dbi dbi;
        string  str;
        int     rc;

        rc = mdb_txn_begin(env, null, MDB_RDONLY, &txn_r);
        if (rc == MDB_BAD_RSLOT)
        {
            log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ "(%s) ERR:%s", path, fromStringz(mdb_strerror(rc)));
            mdb_txn_abort(txn_r);
            rc = mdb_txn_begin(env, null, MDB_RDONLY, &txn_r);
        }

        if (rc == MDB_MAP_RESIZED)
        {
            log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ "(%s) ERR:%s", path, fromStringz(mdb_strerror(rc)));
            mdb_env_close(env);
            open_db();

            rc = mdb_txn_begin(env, null, MDB_RDONLY, &txn_r);
        }

        if (rc != 0)
            log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ "(%s) ERR:%s", path, fromStringz(mdb_strerror(rc)));

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

            if (trace_msg[ 113 ] == 1)
            {
                log.trace("user_uri=%s", ticket.user_uri);
                log.trace("subject_groups=%s", text(subject_groups));
                log.trace("object_groups=%s", text(object_groups));
            }

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

                            if (trace_msg[ 112 ] == 1)
                                log.trace("look acl_key: [%s]", acl_key);

                            key.mv_size = acl_key.length;
                            key.mv_data = cast(char *)acl_key;

                            rc = mdb_get(txn_r, dbi, &key, &data);
                            if (rc == 0)
                            {
                                str = cast(string)(data.mv_data[ 0..data.mv_size ]);

                                if (trace_msg[ 112 ] == 1)
                                    log.trace("for [%s] found %s", acl_key, str);

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
            writeln("EX!,", ex.msg);
        }
        finally
        {
            mdb_txn_abort(txn_r);

            if (trace_msg[ 111 ] == 1)
                log.trace("authorize %s, result=%s", uri, text(isAccessAllow));
        }

        return isAccessAllow;
    }
}

void acl_manager(string thread_name, string db_path)
{
    int size_bin_log     = 0;
    int max_size_bin_log = 10_000_000;

    core.thread.Thread.getThis().name = thread_name;
//    writeln("SPAWN: acl manager");
    LmdbStorage storage      = new LmdbStorage(acl_indexes_db_path, DBMode.RW);
    string      bin_log_name = get_new_binlog_name(db_path);

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

                        Resources rdfType = ind.resources[ rdf__type ];

                        if (rdfType.anyExist(veda_schema__PermissionStatement) == true)
                        {
                            if (trace_msg[ 114 ] == 1)
                                log.trace("store PermissionStatement: [%s]", ind);

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
                                if (canCreate == true)
                                    access = access | Access.can_create;
                                else
                                    access = access | Access.cant_create;
                            }

                            Resource canDelete = ind.getFirstResource(veda_schema__canDelete);
                            if (canDelete !is Resource.init)
                            {
                                if (canDelete == true)
                                    access = access | Access.can_delete;
                                else
                                    access = access | Access.cant_delete;
                            }

                            Resource canRead = ind.getFirstResource(veda_schema__canRead);
                            if (canRead !is Resource.init)
                            {
                                if (canRead == true)
                                    access = access | Access.can_read;
                                else
                                    access = access | Access.cant_read;
                            }

                            Resource canUpdate = ind.getFirstResource(veda_schema__canUpdate);
                            if (canUpdate !is Resource.init)
                            {
                                if (canUpdate == true)
                                    access = access | Access.can_update;
                                else
                                    access = access | Access.cant_update;
                            }

                            ResultCode res = storage.put(permissionObject.uri ~ "+" ~ permissionSubject.uri, "" ~ access);

                            if (trace_msg[ 100 ] == 1)
                                log.trace("[acl index] (%s) ACL: %s+%s %s", text(res), permissionObject.uri, permissionSubject.uri,
                                          text(access));
                        }
                        else if (rdfType.anyExist(veda_schema__Membership) == true)
                        {
                            if (trace_msg[ 114 ] == 1)
                                log.trace("store Membership: [%s]", ind);

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

                                ResultCode res = storage.put(rs.uri, outbuff.toString());

                                if (trace_msg[ 101 ] == 1)
                                    log.trace("[acl index] (%s) MemberShip: %s : %s", text(res), rs.uri, outbuff.toString());
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
                    if (cmd == CMD.BACKUP)
                    {
                        try
                        {
                            string backup_id;
                            if (msg.length > 0)
                                backup_id = msg;

                            if (backup_id is null)
                                backup_id = "0";

                            Result res = storage.backup(backup_id);
                            if (res == Result.Ok)
                            {
                                size_bin_log = 0;
                                bin_log_name = get_new_binlog_name(db_path);
                            }
                            else if (res == Result.Err)
                            {
                                backup_id = "";
                            }
                            send(tid_response_reciever, backup_id);
                        }
                        catch (Exception ex)
                        {
                            send(tid_response_reciever, "");
                        }
                    }
                    else if (cmd == CMD.AUTHORIZE)
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
