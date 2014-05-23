module storage.lmdb_storage;

private
{
    import std.stdio, std.file, std.datetime, std.conv, std.digest.ripemd, std.bigint, std.string;

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
    log = new logger("pacahon", "log", "lmdb");
}

enum DBMode
{
    R  = true,
    RW = false
}

enum Result
{
    Ok,
    Err,
    Nothing
}

class LmdbStorage
{
    MDB_env             *env;
    public const string summ_hash_this_db_id;
    private BigInt      summ_hash_this_db;
    private DBMode      mode;
    private string      _path;
    string              db_name;

    this(string _path_, DBMode _mode)
    {
        _path                = _path_;
        db_name              = _path[ (lastIndexOf(path, '/') + 1)..$ ];
        summ_hash_this_db_id = "summ_hash_this_db";
        mode                 = _mode;

        create_folder_struct();
        open_db();
    }

    @property
    string path()
    {
        return this._path;
    }

    public Result backup(string backup_id)
    {
        string backup_path    = dbs_backup ~ "/" ~ backup_id;
        string backup_db_name = dbs_backup ~ "/" ~ backup_id ~ "/" ~ db_name;

        try
        {
            mkdir(backup_path);
        }
        catch (Exception ex)
        {
        }

        try
        {
            mkdir(backup_db_name);
        }
        catch (Exception ex)
        {
        }

        try
        {
            remove(backup_db_name ~ "/" ~ "data.mdb");
        }
        catch (Exception ex)
        {
        }

        flush(1);

        int rc = mdb_env_copy(env, cast(char *)backup_db_name);

        if (rc != 0)
        {
            log.trace_log_and_console("%s(%s) ERR:%s CODE:%d", __FUNCTION__ ~ ":" ~ text(__LINE__), backup_db_name,
                                      fromStringz(mdb_strerror(rc)), rc);
            return Result.Err;
        }

        return Result.Ok;
    }

    public void open_db()
    {
        int rc;

        rc = mdb_env_create(&env);
        if (rc != 0)
            log.trace_log_and_console("%s(%s) ERR#1:%s", __FUNCTION__ ~ ":" ~ text(__LINE__), _path, fromStringz(mdb_strerror(rc)));
        else
        {
            rc = mdb_env_open(env, cast(char *)_path, MDB_NOMETASYNC | MDB_NOSYNC, std.conv.octal !664);
            if (rc != 0)
                log.trace_log_and_console("%s(%s) ERR#2:%s", __FUNCTION__ ~ ":" ~ text(__LINE__), _path, fromStringz(mdb_strerror(rc)));

            if (rc == 0 && mode == DBMode.RW)
            {
                string hash_str = find(summ_hash_this_db_id);

                if (hash_str is null || hash_str.length < 1)
                    hash_str = "0";

                summ_hash_this_db = BigInt("0x" ~ hash_str);
                log.trace("%s summ_hash_this_db=%s", _path, hash_str);
            }
        }
    }

    private void growth_db(MDB_env *env, MDB_txn *txn)
    {
        int         rc;
        MDB_envinfo stat;

        if (txn !is null)
            mdb_txn_abort(txn);

        rc = mdb_env_info(env, &stat);
        if (rc == 0)
        {
            size_t map_size     = stat.me_mapsize;
            size_t new_map_size = map_size + 10_048_576;

            log.trace_log_and_console("Growth database (%s) prev MAP_SIZE=" ~ text(map_size) ~ ", new MAP_SIZE=" ~ text(new_map_size),
                                      _path);

            rc = mdb_env_set_mapsize(env, new_map_size);
            if (rc != 0)
            {
                log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ ", (%s) ERR:%s", _path, fromStringz(mdb_strerror(rc)));
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

    public ResultCode put(string _key, string value)
    {
        if (_key is null || _key.length < 1)
            return ResultCode.No_Content;

        if (value is null || value.length < 1)
            return ResultCode.No_Content;

        int     rc;
        MDB_dbi dbi;
        MDB_txn *txn;

        rc = mdb_txn_begin(env, null, 0, &txn);
        if (rc != 0)
        {
            log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ ", (%s) ERR:%s, key=%s", _path, fromStringz(mdb_strerror(
                                                                                                                                     rc)),
                                      _key);
            return ResultCode.Fail_Open_Transaction;
        }
        rc = mdb_dbi_open(txn, null, MDB_CREATE, &dbi);
        if (rc != 0)
        {
            log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ ", (%s) ERR:%s, key=%s", _path, fromStringz(mdb_strerror(
                                                                                                                                     rc)),
                                      _key);
            return ResultCode.Fail_Open_Transaction;
        }

        MDB_val key;

        key.mv_data = cast(char *)_key;
        key.mv_size = _key.length;

        MDB_val data;

        data.mv_data = cast(char *)value;
        data.mv_size = value.length;

        rc = mdb_put(txn, dbi, &key, &data, 0);
        if (rc == MDB_MAP_FULL)
        {
            growth_db(env, txn);

            // retry
            return put(_key, value);
        }
        if (rc != 0)
        {
            log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ ", (%s) ERR:%s, key=%s", _path, fromStringz(mdb_strerror(
                                                                                                                                     rc)),
                                      _key);
            return ResultCode.Fail_Store;
        }

        rc = mdb_txn_commit(txn);
        if (rc == MDB_MAP_FULL)
        {
            growth_db(env, null);

            // retry
            return put(_key, value);
        }

        if (rc != 0)
        {
            log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ ", (%s) ERR:%s, key=%s", _path, fromStringz(mdb_strerror(
                                                                                                                                     rc)),
                                      _key);
            return ResultCode.Fail_Commit;
        }

        mdb_dbi_close(env, dbi);
        return ResultCode.OK;
    }

    public void flush(int force)
    {
//      writeln ("@FLUSH");
        int rc = mdb_env_sync(env, force);

        if (rc != 0)
        {
            log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ ", (%s) ERR:%s", _path, fromStringz(mdb_strerror(rc)));
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
            log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ ", (%s) ERR:%s", _path, fromStringz(mdb_strerror(rc)));
            throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));
        }
        rc = mdb_dbi_open(txn, null, MDB_CREATE, &dbi);
        if (rc != 0)
        {
            log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ ", (%s) ERR:%s", _path, fromStringz(mdb_strerror(rc)));
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
            log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ ", (%s) ERR:%s", _path, fromStringz(mdb_strerror(rc)));
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

            if (rc == MDB_MAP_FULL)
            {
                growth_db(env, txn);

                // retry
                return update_or_create(uri, content, new_hash);
            }

            if (rc != 0)
            {
                log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ ", put summ_hash (%s) ERR:%s", _path,
                                          fromStringz(mdb_strerror(rc)));
                mdb_txn_abort(txn);
                throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));
            }
        }

        rc = mdb_txn_commit(txn);

        if (rc == MDB_MAP_FULL)
        {
            growth_db(env, null);

            // retry
            return update_or_create(uri, content, new_hash);
        }

        if (rc != 0)
        {
            log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ "(%s) ERR:%s", _path, fromStringz(mdb_strerror(rc)));
            mdb_txn_abort(txn);
            throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));
        }
//                                sw.stop;
//                               long t = sw.peek.usecs;
//                                writeln ("@1 store : t=", t);

        mdb_dbi_close(env, dbi);

        return ev;
    }

//    public Subject find_subject(string uri)
//    {
//        Subject ind;
//        string  str = find(uri);

//        if (str !is null)
//            ind = cbor2subject(str);
//        return ind;
//    }

    public Individual find_individual(string uri)
    {
        Individual ind;
        string     str = find(uri);

        if (str !is null)
            cbor2individual(&ind, str);
        return ind;
    }

    public long count_entries()
    {
        long    count = -1;
        int     rc;

        MDB_txn *txn_r;
        MDB_dbi dbi;

        rc = mdb_txn_begin(env, null, MDB_RDONLY, &txn_r);
        if (rc == MDB_BAD_RSLOT)
        {
            log.trace_log_and_console("warn:" ~ __FUNCTION__ ~ ":" ~ text(__LINE__) ~ "(%s) ERR:%s", _path, fromStringz(mdb_strerror(rc)));
            mdb_txn_abort(txn_r);
            rc = mdb_txn_begin(env, null, MDB_RDONLY, &txn_r);
        }

        if (rc != 0)
        {
            if (rc == MDB_MAP_RESIZED)
            {
                log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ "(%s) ERR:%s", _path, fromStringz(mdb_strerror(rc)));
                mdb_env_close(env);
                open_db();

                return count_entries();
            }

            log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ "(%s) ERR:%s", _path, fromStringz(mdb_strerror(rc)));
            mdb_txn_abort(txn_r);
            return -1;
        }


        try
        {
            rc = mdb_dbi_open(txn_r, null, 0, &dbi);
            if (rc != 0)
            {
                log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ "(%s) ERR:%s", _path, fromStringz(mdb_strerror(rc)));
                throw new Exception("Fail:" ~  fromStringz(mdb_strerror(rc)));
            }

            MDB_stat stat;
            rc = mdb_stat(txn_r, dbi, &stat);

            if (rc == 0)
            {
                count = stat.ms_entries;
            }
        }catch (Exception ex)
        {
        }

        mdb_txn_abort(txn_r);

        return count;
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
            log.trace_log_and_console("warn:" ~ __FUNCTION__ ~ ":" ~ text(__LINE__) ~ "(%s) ERR:%s", _path, fromStringz(mdb_strerror(rc)));
            mdb_txn_abort(txn_r);
            rc = mdb_txn_begin(env, null, MDB_RDONLY, &txn_r);
        }

        if (rc != 0)
        {
            if (rc == MDB_MAP_RESIZED)
            {
                log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ "(%s) ERR:%s", _path, fromStringz(mdb_strerror(rc)));
                mdb_env_close(env);
                open_db();

                return find(uri);
            }

            log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ "(%s) ERR:%s", _path, fromStringz(mdb_strerror(rc)));
            mdb_txn_abort(txn_r);
            return null;
        }


        try
        {
            rc = mdb_dbi_open(txn_r, null, 0, &dbi);
            if (rc != 0)
            {
                log.trace_log_and_console(__FUNCTION__ ~ ":" ~ text(__LINE__) ~ "(%s) ERR:%s", _path, fromStringz(mdb_strerror(rc)));
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

string get_new_binlog_name(string db_path)
{
    string now = Clock.currTime().toISOExtString();

    now = now[ 0..indexOf(now, '.') + 4 ];

    return db_path ~ "." ~ now;
}


