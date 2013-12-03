module bind.nanomsg_header;

/*  SP address families.                                                      */
const AF_SP= 1;
const AF_SP_RAW= 2;

/*  Max size of an SP address.                                                */
const NN_SOCKADDR_MAX= 128;

/*  Socket option levels: Negative numbers are reserved for transports,
    positive for socket types. */
const NN_SOL_SOCKET= 0;

/*  Generic socket options (NN_SOL_SOCKET level).                             */
const NN_LINGER= 1;
const NN_SNDBUF= 2;
const NN_RCVBUF= 3;
const NN_SNDTIMEO= 4;
const NN_RCVTIMEO= 5;
const NN_RECONNECT_IVL= 6;
const NN_RECONNECT_IVL_MAX= 7;
const NN_SNDPRIO= 8;
const NN_SNDFD= 10;
const NN_RCVFD= 11;
const NN_DOMAIN= 12;
const NN_PROTOCOL= 13;
const NN_IPV4ONLY= 14;

/*  Send/recv options.                                                        */
const NN_DONTWAIT= 1;

const NN_PROTO_PAIR= 1;
const NN_PAIR = (NN_PROTO_PAIR * 16 + 0);

const NN_PROTO_REQREP = 3;

const NN_REQ = (NN_PROTO_REQREP * 16 + 0);
const NN_REP = (NN_PROTO_REQREP * 16 + 1);

const NN_REQ_RESEND_IVL = 1;

struct nn_iovec 
{
    void *iov_base;
    size_t iov_len;
}

struct nn_msghdr 
{
    nn_iovec *msg_iov;
    int msg_iovlen;
    void *msg_control;
    size_t msg_controllen;
}

nothrow extern(C) 
{
    void nn_err_abort ();
    int nn_err_errno ();
    const char *nn_err_strerror (int errnum);

    int nn_socket (int domain, int protocol);
    int nn_close (int s);
    int nn_setsockopt (int s, int level, int option, const void *optval, size_t optvallen);
    int nn_getsockopt (int s, int level, int option, void *optval, size_t *optvallen);
    int nn_bind (int s, const char *addr);
    int nn_connect (int s, const char *addr);
    int nn_shutdown (int s, int how);
    int nn_send (int s, const void *buf, size_t len, int flags);
    int nn_recv (int s, void *buf, size_t len, int flags);
    int nn_sendmsg (int s, const nn_msghdr *msghdr, int flags);
    int nn_recvmsg (int s, nn_msghdr *msghdr, int flags);
}
