module libchash_h;

private import std.c.stdio;

/* Copyright (c) 1998 - 2005, Google Inc.
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 * 
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * ---
 * Author: Craig Silverstein
 *
 *  This library is intended to be used for in-memory hash tables,
 *  though it provides rudimentary permanent-storage capabilities.
 *  It attempts to be fast, portable, and small.  The best algorithm
 *  to fulfill these goals is an internal probing hashing algorithm,
 *  as in Knuth, _Art of Computer Programming_, vol III.  Unlike
 *  chained (open) hashing, it doesn't require a pointer for every
 *  item, yet it is still constant time lookup in practice.
 *
 *  Also to save space, we let the contents (both data and key) that
 *  you insert be a union: if the key/data is small, we store it
 *  directly in the hashtable, otherwise we store a pointer to it.
 *  To keep you from having to figure out which, use KEY_PTR and
 *  PTR_KEY to convert between the arguments to these functions and
 *  a pointer to the real data.  For instance:
 *     char key[] = "ab", *key2;
 *     HTItem *bck; HashTable *ht;
 *     HashInsert(ht, PTR_KEY(ht, key), 0);
 *     bck = HashFind(ht, PTR_KEY(ht, "ab"));
 *     key2 = KEY_PTR(ht, bck->key);
 *
 *  There are a rich set of operations supported:
 *     AllocateHashTable() -- Allocates a hashtable structure and
 *                            returns it.
 *        cchKey: if it's a positive number, then each key is a
 *                fixed-length record of that length.  If it's 0,
 *                the key is assumed to be a \0-terminated string.
 *        fSaveKey: normally, you are responsible for allocating
 *                  space for the key.  If this is 1, we make a
 *                  copy of the key for you.
 *     ClearHashTable() -- Removes everything from a hashtable
 *     FreeHashTable() -- Frees memory used by a hashtable
 *
 *     HashFind() -- takes a key (use PTR_KEY) and returns the
 *                   HTItem containing that key, or NULL if the
 *                   key is not in the hashtable.
 *     HashFindLast() -- returns the item found by last HashFind()
 *     HashFindOrInsert() -- inserts the key/data pair if the key
 *                           is not already in the hashtable, or
 *                           returns the appropraite HTItem if it is.
 *     HashFindOrInsertItem() -- takes key/data as an HTItem.
 *     HashInsert() -- adds a key/data pair to the hashtable.  What
 *                     it does if the key is already in the table
 *                     depends on the value of SAMEKEY_OVERWRITE.
 *     HashInsertItem() -- takes key/data as an HTItem.
 *     HashDelete() -- removes a key/data pair from the hashtable,
 *                     if it's there.  RETURNS 1 if it was there,
 *                     0 else.
 *        If you use sparse tables and never delete, the full data
 *        space is available.  Otherwise we steal -2 (maybe -3),
 *        so you can't have data fields with those values.
 *     HashDeleteLast() -- deletes the item returned by the last Find().
 *
 *     HashFirstBucket() -- used to iterate over the buckets in a 
 *                          hashtable.  DON'T INSERT OR DELETE WHILE
 *                          ITERATING!  You can't nest iterations.
 *     HashNextBucket() -- RETURNS NULL at the end of iterating.
 *
 *     HashSetDeltaGoalSize() -- if you're going to insert 1000 items
 *                               at once, call this fn with arg 1000.
 *                               It grows the table more intelligently.
 *
 *     HashSave() -- saves the hashtable to a file.  It saves keys ok,
 *                   but it doesn't know how to interpret the data field,
 *                   so if the data field is a pointer to some complex
 *                   structure, you must send a function that takes a
 *                   file pointer and a pointer to the structure, and
 *                   write whatever you want to write.  It should return
 *                   the number of bytes written.  If the file is NULL,
 *                   it should just return the number of bytes it would
 *                   write, without writing anything.
 *                      If your data field is just an integer, not a
 *                   pointer, just send NULL for the function.
 *     HashLoad() -- loads a hashtable.  It needs a function that takes
 *                   a file and the size of the structure, and expects
 *                   you to read in the structure and return a pointer
 *                   to it.  You must do memory allocation, etc.  If
 *                   the data is just a number, send NULL.
 *     HashLoadKeys() -- unlike HashLoad(), doesn't load the data off disk
 *                       until needed.  This saves memory, but if you look
 *                       up the same key a lot, it does a disk access each
 *                       time.
 *        You can't do Insert() or Delete() on hashtables that were loaded
 *        from disk.
 */


   /* This is what an item is.  Either can be cast to a pointer. */
extern (C) struct  HTItem
{
   uint data;        /* 4 bytes for data: either a pointer or an integer */
   uint key;         /* 4 bytes for the key: either a pointer or an int */
};

extern (C) struct Table;                            /* defined in chash.c, I hope */

   /* for STORES_PTR to work ok, cchKey MUST BE DEFINED 1st, cItems 2nd! */
extern (C) struct HashTable;

   /* Function prototypes */
extern (C) uint HTcopy(char *pul);         /* for PTR_KEY, not for users */

extern (C) HashTable *AllocateHashTable(int cchKey, int fSaveKeys);
extern (C) void ClearHashTable(HashTable *ht);
extern (C) void FreeHashTable(HashTable *ht);

extern (C) HTItem *HashFind(HashTable *ht, uint key);
extern (C) HTItem *HashFind1(HashTable *ht, uint key, uint len);
extern (C) HTItem *HashFindLast(HashTable *ht);
extern (C) HTItem *HashFindOrInsert(HashTable *ht, uint key, uint dataInsert);
extern (C) HTItem *HashFindOrInsertItem(HashTable *ht, HTItem *pItem);

extern (C) HTItem *HashInsert(HashTable *ht, uint key, uint data);
extern (C) HTItem *HashInsertItem(HashTable *ht, HTItem *pItem);

extern (C) int HashDelete(HashTable *ht, uint key);
extern (C) int HashDeleteLast(HashTable *ht);

extern (C) HTItem *HashFirstBucket(HashTable *ht);
extern (C) HTItem *HashNextBucket(HashTable *ht);

extern (C) int HashSetDeltaGoalSize(HashTable *ht, int delta);

extern (C) void HashSave(FILE *fp, HashTable *ht, int (*write)(FILE *, char *));
extern (C) HashTable *HashLoad(FILE *fp, char * (*read)(FILE *, int));
extern (C) HashTable *HashLoadKeys(FILE *fp, char * (*read)(FILE *, int));
