module pacahon.log_msg;

private import util.logger;

byte trace_msg[ 1100 ];

// last id = 71

int m_get_message[]      = [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 61, 62 ];
int m_command_preparer[] = [ 11, 12, 13, 14, 15, 16, 63 ];
int m_foundTicket[]      = [ 17, 18, 19, 20, 21, 22, 23, 24 ];
int m_authorize[]        = [ 25, 26, 27, 28, 29, 30 ];
int m_put[]              = [ 31, 32, 33, 34, 35, 36, 37, 64 ];
int m_get_ticket[]       = [ 38, 39, 40 ];
int m_get[]              = [ 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60 ];

static this()
{
    trace_msg      = 0;
    trace_msg[ 2 ] = 0;
    trace_msg[ 3 ] = 0;

    // basis logging
    trace_msg[ 0 ]  = 1;
    trace_msg[ 10 ] = 1;
    trace_msg[ 68 ] = 1;
    trace_msg[ 69 ] = 1;

    //	trace_msg[64] = 1; // вложенное в команду put turtle сообщения в виде json-ld
    //	trace_msg[3] = 1; // входящее сообщение в виде json-ld

    trace_msg[ 63 ] = 0;   // log.trace("command_preparer, set_message_trace");

    version (trace)
        trace_msg[] = 1;     // полное логгирование

    trace_msg[ 3 ] = 0;
}

void set_message(int idx)
{
    trace_msg[ idx ] = 1;
}

void set_all_messages()
{
    trace_msg = 1;
}

void unset_all_messages()
{
    trace_msg = 0;
}

void unset_message(int idx)
{
    trace_msg[ idx ] = 0;
}


void set_trace(int idx, bool state)
{
    trace_msg[ idx ] = state;
}