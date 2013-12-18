module bind.libczmq_header;

private import bind.libzmq_header;

public static const byte ZFRAME_MORE     = 1;
public static const byte ZFRAME_REUSE    = 2;
public static const byte ZFRAME_DONTWAIT = 4;

alias long               int64_t;

struct zctx_t
{
    void    *context  = null;       //  Our 0MQ context
    zlist_t *sockets  = null;       //  Sockets held by this thread
    bool    main      = false;      //  TRUE if we're the main thread
    int     iothreads = 1;          //  Number of IO threads, default 1
    int     linger    = 0;          //  Linger timeout, default 0
    int     hwm       = 1;          //  HWM, default 1
};

//  List node, used internally only
struct node_t
{
    node_t *next = null;
    void   *item = null;
};


//  Actual list object
struct zlist_t
{
    node_t *head   = null;
    node_t *tail   = null;
    node_t *cursor = null;
    size_t size    = 0;
};

struct zmsg_t
{
    zlist_t *frames      = null;    //  List of frames
    size_t  content_size = 0;       //  Total content size
};


struct zframe_t
{
    zmq_msg_t zmsg;             //  zmq_msg_t blob for frame
    int       more;             //  More flag, from last read
    int       zero_copy;        //  zero-copy flag
};


//  --------------------------------------------------------------------------
//  Constructor
extern (C)zctx_t * zctx_new();

//  --------------------------------------------------------------------------
//  Destructor
extern (C) void zctx_destroy(zctx_t **self_p);

//  --------------------------------------------------------------------------
//  Return current system clock as milliseconds
extern (C) int64_t zclock_time();

//  --------------------------------------------------------------------------
//  Receive message from socket, returns zmsg_t object or NULL if the recv
//  was interrupted. Does a blocking recv, if you want to not block then use
//  the zloop class or zmq_poll to check for socket input before receiving.
extern (C)zmsg_t * zmsg_recv(void *socket);

//  --------------------------------------------------------------------------
//  Return size of message, i.e. number of frames (0 or more).
extern (C) size_t zmsg_size(zmsg_t *self);

/////////////////// FRAME ////////////////////////////////////////////////////

//  --------------------------------------------------------------------------
//  Return the last frame. If there are no frames, returns NULL.
extern (C)zframe_t * zmsg_last(zmsg_t * self);

//  --------------------------------------------------------------------------
//  Return pointer to frame data.
extern (C) byte *zframe_data(zframe_t * self);

//  --------------------------------------------------------------------------
//  Constructor; if size is >0, allocates frame with that size, and if data
//  is not null, copies data into frame.
extern (C)zframe_t * zframe_new(const void *data, size_t size);

//  --------------------------------------------------------------------------
//  Send frame to socket, destroy after sending unless ZFRAME_REUSE is
//  set or the attempt to send the message errors out.
extern (C) int zframe_send(zframe_t **self_p, void *socket, int flags);

//  --------------------------------------------------------------------------
//  Return size of frame.
extern (C) size_t zframe_size(zframe_t *self);

//  --------------------------------------------------------------------------
//  Set new contents for frame
extern (C) void zframe_reset(zframe_t *self, const void *data, size_t size);

//  --------------------------------------------------------------------------
//  Set cursor to first frame in message. Returns frame, or NULL.
extern (C)zframe_t * zmsg_first(zmsg_t * self);

//  --------------------------------------------------------------------------
//  Return frame data copied into freshly allocated string
//  Caller must free string when finished with it.
extern (C) char *zframe_strdup(zframe_t * self);

//  --------------------------------------------------------------------------
//  Destructor
extern (C) void zframe_destroy(zframe_t **self_p);

//////////////////////////////////////////////////////////////////////////////

//  --------------------------------------------------------------------------
//  Send message to socket, destroy after sending. If the message has no
//  frames, sends nothing but destroys the message anyhow. Safe to call
//  if zmsg is null.
extern (C) int zmsg_send(zmsg_t **self_p, void *socket);

//  --------------------------------------------------------------------------
//  Dump message to stderr, for debugging and tracing
//  Truncates to first 10 frames, for readability; this may be unfortunate
//  when debugging larger and more complex messages. Perhaps a way to hide
//  repeated lines instead?
extern (C) void zmsg_dump(zmsg_t *self);

//  --------------------------------------------------------------------------
//  Destructor
extern (C) void zmsg_destroy(zmsg_t **self_p);

//  --------------------------------------------------------------------------
//  Destroy the socket. You must use this for any socket created via the
//  zsocket_new method.
extern (C) void zsocket_destroy(zctx_t *ctx, void *socket);

//  --------------------------------------------------------------------------
//  Create a new socket within our czmq context, replaces zmq_socket.
//  Use this to get automatic management of the socket at shutdown.
//  Note: SUB sockets do not automatically subscribe to everything; you
//  must set filters explicitly.
extern (C) void *zsocket_new(zctx_t * ctx, int type);

//  --------------------------------------------------------------------------
//  Bind a socket to a formatted endpoint. If the port is specified as
//  '*', binds to any free port from ZSOCKET_DYNFROM to ZSOCKET_DYNTO
//  and returns the actual port number used.  Always returns the
//  port number if successful.
extern (C) int zsocket_bind(void *socket, const char *format, ...);

//  --------------------------------------------------------------------------
//  Add frame to the end of the message, i.e. after all other frames.
//  Message takes ownership of frame, will destroy it when message is sent.
//  Returns 0 on success
extern (C) int zmsg_add(zmsg_t *self, zframe_t *frame);

//  --------------------------------------------------------------------------
//  Pop frame off front of message, caller now owns frame
//  If next frame is empty, pops and destroys that empty frame.
extern (C)zframe_t * zmsg_unwrap(zmsg_t * self);

//  --------------------------------------------------------------------------
//  Constructor
extern (C)zmsg_t * zmsg_new();

//  --------------------------------------------------------------------------
//  Remove first frame from message, if any. Returns frame, or NULL. Caller
//  now owns frame and must destroy it when finished with it.
extern (C)zframe_t * zmsg_pop(zmsg_t * self);
