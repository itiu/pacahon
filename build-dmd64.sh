#bash
DMD=dmd

VERSION_MAJOR=1
VERSION_MINOR=38
VERSION_PATCH=1

#cp -r src/* build/src

git log -1 --pretty=format:"module pacahon.myversion; public static string major=\"$VERSION_MAJOR\"; public static string minor=\"$VERSION_MINOR\"; public static string patch=\"$VERSION_PATCH\"; public static string author=\"%an\"; public static string date=\"%ad\"; public static string hash=\"%h\";">src/pacahon/myversion.d

rm target/Pacahon-$VERSION_MAJOR-$VERSION_MINOR-$VERSION_PATCH-64
rm target/Pacahon-$VERSION_MAJOR-$VERSION_MINOR-$VERSION_PATCH-64-trace
rm *.log
rm *.io
rm *.oi

m_static="lib64/libnanomsg.a lib64/libanl.a lib64/liblmdb.a lib64/libxapiand.a lib64/libxapian-main.a lib64/libxapian-backend.a lib64/libzmq.a lib64/libczmq.a lib64/libstdc++.a lib64/libuuid.a lib64/librabbitmq.a"
m_shared="-L-lzmq -L-lxapiand -L-lxapian -L-lnanomsg -L-llmdb -L-lczmq -L-lrabbitmq"

$DMD -m64 -O -g -release -inline @pacahon-src-list $m_static -oftarget/Pacahon-$VERSION_MAJOR-$VERSION_MINOR-$VERSION_PATCH-64-sl
$DMD -m64 -O -g -release -inline @pacahon-src-list $m_shared -oftarget/Pacahon-$VERSION_MAJOR-$VERSION_MINOR-$VERSION_PATCH-64

#$DMD -m64 -debug -g -version=trace \
#@pacahon-src-list $libs -oftarget/Pacahon-$VERSION_MAJOR-$VERSION_MINOR-$VERSION_PATCH-64-trace

rm target/*.o
rm target/*.log
rm target/*.io
rm target/*.oi
