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

private const string db_path = "data/acl-indexes";

enum
{
    can_create  = 1,
    can_read    = 2,
    can_update  = 4,
    can_delete  = 8,
    cant_create = 16,
    cant_read   = 32,
    cant_update = 64,
    cant_delete = 128
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

void acl_manager()
{
//    writeln("SPAWN: acl manager");
    LmdbStorage storage = new LmdbStorage(db_path);

    // SEND ready
    receive((Tid tid_response_reciever)
            {
                send(tid_response_reciever, true);
            });
    while (true)
    {
        string res = "?";

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
                        if (canCreate.data == "true")
                            access = access | can_create;
                        else
                            access = access | cant_create;

                        Resource canDelete = ind.getFirstResource(veda_schema__canDelete);
                        if (canDelete.data == "true")
                            access = access | can_delete;
                        else
                            access = access | cant_delete;

                        Resource canRead = ind.getFirstResource(veda_schema__canRead);
                        if (canRead.data == "true")
                            access = access | can_read;
                        else
                            access = access | cant_read;

                        Resource canUpdate = ind.getFirstResource(veda_schema__canUpdate);
                        if (canUpdate.data == "true")
                            access = access | can_update;
                        else
                            access = access | cant_update;


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
