module storage.lmdb_storage;

private
{
    import std.stdio, std.file, std.datetime;

    import bind.lmdb_header;

    import onto.individual;

    import util.logger;
    import util.utils;
    import util.cbor;
    import util.cbor8individual;

    import pacahon.context;
    import pacahon.define;
}

logger log;

static this()
{
    log = new logger("pacahon", "log", "server");
}

class LmdbStorage
{
    MDB_env *env;

    string  path;

    this(string _path)
    {
        path = _path;

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

        int rc;
        int rrc;
        rrc = mdb_env_create(&env);
        if (rrc != 0)
            writeln("LmdbStorage:ERR! mdb_env_create:", fromStringz(mdb_strerror(rrc)));
        else
        {
            // rrc = mdb_env_set_mapsize(env, 10485760 * 512);
            // if (rrc != 0)
            //     writeln("ERR! mdb_env_set_mapsize:", fromStringz(mdb_strerror(rrc)));
            // else
            {
                rrc = mdb_env_open(env, cast(char *)path, 0, std.conv.octal !664);

                if (rrc != 0)
                    writeln("LmdbStorage:ERR! mdb_env_open:", fromStringz(mdb_strerror(rrc)), " (", rrc, ")");
            }
        }
    }

    public EVENT update_or_create(Individual *ind)
    {
        int     rc;
        MDB_dbi dbi;

        MDB_txn *txn;

        rc = mdb_txn_begin(env, null, 0, &txn);
        if (rc != 0)
            throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));
        rc = mdb_dbi_open(txn, null, MDB_CREATE, &dbi);
        if (rc != 0)
            throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));

        EVENT   ev = EVENT.NONE;
        MDB_val key;

        key.mv_data = cast(char *)ind.uri;
        key.mv_size = ind.uri.length;

        MDB_val data;

        // проверим был есть ли такой субьект в базе
        rc = mdb_get(txn, dbi, &key, &data);
        if (rc == 0)
            ev = EVENT.UPDATE;
        else
            ev = EVENT.CREATE;

        string str = individual2cbor(ind);
        data.mv_data = cast(char *)str;
        data.mv_size = str.length;

        rc = mdb_put(txn, dbi, &key, &data, 0);
        if (rc != 0)
            throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));

        rc = mdb_txn_commit(txn);
        if (rc != 0)
            throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));


        mdb_dbi_close(env, dbi);
        return ev;
    }

    public Individual find(string uri)
    {
        Individual ind;
        int        rc;
        MDB_txn    *txn_r;
        MDB_dbi    dbi;

        rc = mdb_txn_begin(env, null, MDB_RDONLY, &txn_r);
        if (rc != 0)
            writeln("%1 tnx begin:", fromStringz(mdb_strerror(rc)));

        try
        {
            rc = mdb_dbi_open(txn_r, null, MDB_CREATE, &dbi);
            if (rc != 0)
                throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));

            MDB_val key;
            key.mv_size = uri.length;
            key.mv_data = cast(char *)uri;

            MDB_val data;
            rc = mdb_get(txn_r, dbi, &key, &data);
            if (rc == 0)
            {
                string str = cast(string)(data.mv_data[ 0..data.mv_size ]);
                cbor2individual(&ind, str);
            }
        }catch (Exception ex)
        {
        }


        mdb_txn_abort(txn_r);
        return ind;
    }
}


