module storage.lmdb_storage;

private
{
    import std.stdio, std.file, std.datetime, std.conv, std.digest.ripemd, std.bigint, std.string;

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
    log = new logger("pacahon", "log", "lmdb");
}

enum DBMode
{
    R  = true,
    RW = false
}

class LmdbStorage
{
    MDB_env        *env;
    private string summ_hash_this_db_id;
    private BigInt summ_hash_this_db;
    private DBMode mode;
    private string path;
    string         db_name;

    this(string _path, DBMode _mode)
    {
        path                 = _path;
        db_name              = path[ lastIndexOf(path, '/')..$ ];
        summ_hash_this_db_id = "summ_hash_this_db";
        mode                 = _mode;
        open_db();
    }

    public void backup()
    {
        string uid = find(summ_hash_this_db_id);

        if (uid is null)
            uid = "0";

        string backup_db_name = dbs_backup ~ "/" ~ db_name ~ "." ~ uid;

        try
        {
            mkdir(backup_db_name);
        }
        catch (Exception ex)
        {
        }

        int rc = mdb_env_copy(env, cast(char *)backup_db_name);
        if (rc != 0)
            log.trace_log_and_console("%s(%s) ERR:%s", __FUNCTION__, db_name, fromStringz(mdb_strerror(rc)));
    }

    private void open_db()
    {
        int rc;

        rc = mdb_env_create(&env);
        if (rc != 0)
            log.trace_log_and_console("%s(%s) ERR#1:%s", __FUNCTION__, path, fromStringz(mdb_strerror(rc)));
        else
        {
            rc = mdb_env_open(env, cast(char *)path, MDB_NOMETASYNC | MDB_NOSYNC, std.conv.octal !664);
            if (rc != 0)
                log.trace_log_and_console("%s(%s) ERR#2:%s", __FUNCTION__, path, fromStringz(mdb_strerror(rc)));

            if (rc == 0 && mode == DBMode.RW)
            {
                string hash_str = find(summ_hash_this_db_id);

                if (hash_str is null || hash_str.length < 1)
                    hash_str = "0";

                summ_hash_this_db = BigInt("0x" ~ hash_str);
                log.trace("%s summ_hash_this_db=%s", path, hash_str);

                backup();
            }
        }
    }

    private void growth_db(MDB_env *env)
    {
        int         rc;
        MDB_envinfo stat;

        rc = mdb_env_info(env, &stat);
        if (rc == 0)
        {
            size_t map_size = stat.me_mapsize;
            log.trace_log_and_console("prev MAP_SIZE=" ~ text(map_size) ~ ", new MAP_SIZE=" ~ text(map_size + 10_048_576));
            if (map_size < 10_048_576)
            {
                rc = mdb_env_set_mapsize(env, map_size + 10_048_576);
                if (rc != 0)
                {
                    log.trace_log_and_console(__FUNCTION__ ~ "(%s) ERR:%s", path, fromStringz(mdb_strerror(rc)));
                }
            }
        }
    }

    public EVENT update_or_create(string cbor, out string new_hash)
    {
        // TODO не оптимально!
        Individual ind;

        cbor2individual(&ind, cbor);
        return update_or_create(ind.uri, cbor, new_hash);
    }

    public EVENT update_or_create(Individual *ind, out string new_hash)
    {
        string content = individual2cbor(ind);

        return update_or_create(ind.uri, content, new_hash);
    }

    public void put(string _key, string value)
    {
        int     rc;
        MDB_dbi dbi;
        MDB_txn *txn;

        rc = mdb_txn_begin(env, null, 0, &txn);
        if (rc != 0)
        {
            log.trace_log_and_console(__FUNCTION__ ~ "(%s) ERR:%s", path, fromStringz(mdb_strerror(rc)));
            throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));
        }
        rc = mdb_dbi_open(txn, null, MDB_CREATE, &dbi);
        if (rc != 0)
        {
            log.trace_log_and_console(__FUNCTION__ ~ "(%s) ERR:%s", path, fromStringz(mdb_strerror(rc)));
            throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));
        }

        MDB_val key;

        key.mv_data = cast(char *)_key;
        key.mv_size = _key.length;

        MDB_val data;

        data.mv_data = cast(char *)value;
        data.mv_size = value.length;

        rc = mdb_put(txn, dbi, &key, &data, 0);
        if (rc != 0)
        {
            log.trace_log_and_console(__FUNCTION__ ~ "(%s) ERR:%s", path, fromStringz(mdb_strerror(rc)));
            throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));
        }

        rc = mdb_txn_commit(txn);
        if (rc != 0)
        {
            if (rc == MDB_MAP_FULL)
            {
                growth_db(env);

                // retry
                put(_key, value);
                return;
            }

            log.trace_log_and_console(__FUNCTION__ ~ "(%s) ERR:%s", path, fromStringz(mdb_strerror(rc)));
            throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));
        }

        mdb_dbi_close(env, dbi);
    }

    public void flush(int force)
    {
//      writeln ("@FLUSH");
        int rc = mdb_env_sync(env, force);

        if (rc != 0)
        {
            log.trace_log_and_console(__FUNCTION__ ~ "(%s) ERR:%s", path, fromStringz(mdb_strerror(rc)));
        }
    }


    private string get_new_hash(string content)
    {
        ubyte[ 20 ] hash = ripemd160Of(content);
        BigInt msg_hash = "0x" ~ toHexString(hash);
        summ_hash_this_db += msg_hash;
        return toHex(summ_hash_this_db);
    }

    private EVENT update_or_create(string uri, string content, out string new_hash)
    {
//                                      StopWatch sw; sw.start;
        new_hash = get_new_hash(content);

        int     rc;
        MDB_dbi dbi;
        MDB_txn *txn;

        rc = mdb_txn_begin(env, null, 0, &txn);
        if (rc != 0)
        {
            log.trace_log_and_console(__FUNCTION__ ~ "(%s) ERR:%s", path, fromStringz(mdb_strerror(rc)));
            throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));
        }
        rc = mdb_dbi_open(txn, null, MDB_CREATE, &dbi);
        if (rc != 0)
        {
            log.trace_log_and_console(__FUNCTION__ ~ "(%s) ERR:%s", path, fromStringz(mdb_strerror(rc)));
            throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));
        }

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
        {
            log.trace_log_and_console(__FUNCTION__ ~ "(%s) ERR:%s", path, fromStringz(mdb_strerror(rc)));
            mdb_txn_abort(txn);
            throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));
        }

        if (summ_hash_this_db != BigInt.init)
        {   // put current db summ hash
            key.mv_data  = cast(char *)summ_hash_this_db_id;
            key.mv_size  = summ_hash_this_db_id.length;
            data.mv_data = cast(char *)new_hash;
            data.mv_size = new_hash.length;
            rc           = mdb_put(txn, dbi, &key, &data, 0);
            if (rc != 0)
            {
                log.trace_log_and_console(__FUNCTION__ ~ "put summ_hash (%s) ERR:%s", path, fromStringz(mdb_strerror(rc)));
                mdb_txn_abort(txn);
                throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));
            }
        }

        rc = mdb_txn_commit(txn);
        if (rc != 0)
        {
            if (rc == MDB_MAP_FULL)
            {
                growth_db(env);

                // retry
                put(uri, content);
                return ev;
            }

            if (rc != 0)
            {
                log.trace_log_and_console(__FUNCTION__ ~ "(%s) ERR:%s", path, fromStringz(mdb_strerror(rc)));
                mdb_txn_abort(txn);
                throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));
            }
        }
//                                sw.stop;
//                               long t = sw.peek.usecs;
//                                writeln ("@1 store : t=", t);

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
            log.trace_log_and_console("warn:" ~ __FUNCTION__ ~ ":" ~ text(__LINE__) ~ "(%s) ERR:%s", path, fromStringz(mdb_strerror(rc)));
            mdb_txn_abort(txn_r);
            rc = mdb_txn_begin(env, null, MDB_RDONLY, &txn_r);
        }

        if (rc != 0)
        {
            if (rc == MDB_MAP_RESIZED)
            {
                log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ "(%s) ERR:%s", path, fromStringz(mdb_strerror(rc)));
                mdb_env_close(env);
                open_db();

                return find(uri);
            }

            log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ "(%s) ERR:%s", path, fromStringz(mdb_strerror(rc)));
            mdb_txn_abort(txn_r);
            return null;
        }


        try
        {
            rc = mdb_dbi_open(txn_r, null, 0, &dbi);
            if (rc != 0)
            {
                log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ "(%s) ERR:%s", path, fromStringz(mdb_strerror(rc)));
                throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));
            }

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


