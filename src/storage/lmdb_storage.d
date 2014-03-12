module storage.lmdb_storage;

private
{
    import std.stdio, std.file, std.datetime, std.conv;

    import bind.lmdb_header;

    import onto.individual;
    import onto.sgraph;

    import util.logger;
    import util.utils;
    import util.cbor;
    import util.cbor8individual;
    import util.cbor8sgraph;

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
//              foreach (i ; 1..10)
///             {
                rrc = mdb_env_open(env, cast(char *)path, 0, std.conv.octal !664);
                //               if (rrc == 0)
                //                  break;

//                core.thread.Thread.sleep(dur!("seconds")(1));

                if (rrc != 0)
                    writeln("LmdbStorage(", path, "):ERR! mdb_env_open:", fromStringz(mdb_strerror(rrc)), " (", rrc, ")");
//                    }

/*                MDB_txn *txn_r;
                rc = mdb_txn_begin(env, null, MDB_RDONLY, &txn_r);
                if (rc == MDB_BAD_RSLOT)
                {
                    writeln("LmdbStorage:find #0, mdb_tnx_begin, rc=", rc, ", err=", fromStringz(mdb_strerror(rc)));
                }
                mdb_txn_abort(txn_r);*/
            }
        }
    }

    public EVENT update_or_create(string cbor)
    {
        // TODO не оптимально!
        Individual ind;

        cbor2individual(&ind, cbor);
        return update_or_create(ind.uri, cbor);
    }

    public EVENT update_or_create(Individual *ind)
    {
        string content = individual2cbor(ind);

        return update_or_create(ind.uri, content);
    }

    public void put(string _key, string value)
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

        MDB_val key;

        key.mv_data = cast(char *)_key;
        key.mv_size = _key.length;

        MDB_val data;

        data.mv_data = cast(char *)value;
        data.mv_size = value.length;

        rc = mdb_put(txn, dbi, &key, &data, 0);
        if (rc != 0)
            throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));

        rc = mdb_txn_commit(txn);
        if (rc != 0)
            throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));

        mdb_dbi_close(env, dbi);
    }

    public EVENT update_or_create(string uri, string content)
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

        key.mv_data = cast(char *)uri;
        key.mv_size = uri.length;

        MDB_val data;

        // проверим был есть ли такой субьект в базе
        rc = mdb_get(txn, dbi, &key, &data);
        if (rc == 0)
            ev = EVENT.UPDATE;
        else
            ev = EVENT.CREATE;

        data.mv_data = cast(char *)content;
        data.mv_size = content.length;

        rc = mdb_put(txn, dbi, &key, &data, 0);
        if (rc != 0)
            throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));

        rc = mdb_txn_commit(txn);
        if (rc != 0)
            throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));

        mdb_dbi_close(env, dbi);
        return ev;
    }

    public Subject find_subject(string uri)
    {
        Subject ind;
        string  str = find(uri);

        if (str !is null)
            ind = cbor2subject(str);
        return ind;
    }

    public Individual find_individual(string uri)
    {
        Individual ind;
        string     str = find(uri);

        if (str !is null)
            cbor2individual(&ind, str);
        return ind;
    }

    public string find(string uri)
    {
        string  str;
        int     rc;
        MDB_txn *txn_r;
        MDB_dbi dbi;

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
            rc = mdb_dbi_open(txn_r, null, 0, &dbi);
            if (rc != 0)
                throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));

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

        return str;
    }
}


