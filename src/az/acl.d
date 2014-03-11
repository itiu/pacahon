module az.acl;

private
{
    import std.stdio, std.concurrency, std.file, std.datetime, std.array;

    import onto.individual;
    import onto.resource;

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


logger log;

static this()
{
    log = new logger("pacahon", "log", "server");
}

bool authorize(LmdbStorage storage, string uri, Ticket *ticket, Access request_acess)
{
    if (ticket is null)
        return true;

    // группы пользователя
//	ticket.user_uri

    return false;
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

                        writeln(permissionObject.uri ~ "+" ~ permissionSubject.uri);
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
