DMD=dmd

VERSION_MAJOR=1
VERSION_MINOR=35
VERSION_PATCH=0

#cp -r src/* build/src

git log -1 --pretty=format:"module pacahon.myversion; public static string major=\"$VERSION_MAJOR\"; public static string minor=\"$VERSION_MINOR\"; public static string patch=\"$VERSION_PATCH\"; public static string author=\"%an\"; public static string date=\"%ad\"; public static string hash=\"%h\";">src/pacahon/myversion.d

rm target/Pacahon-$VERSION_MAJOR-$VERSION_MINOR-$VERSION_PATCH-64
rm target/Pacahon-$VERSION_MAJOR-$VERSION_MINOR-$VERSION_PATCH-64-trace
rm *.log
rm *.io
rm *.oi

libs="lib64/libnanomsg.a lib64/libanl.a lib64/liblmdb.a lib64/libxapiand.a lib64/libxapian.a lib64/libxapian-backend.a lib64/libzmq.a lib64/libczmq.a lib64/libstdc++.a lib64/libuuid.a lib64/librabbitmq.a lib64/libutils.a"

$DMD -m64 -O -g -release \
@pacahon-src-list $libs -oftarget/Pacahon-$VERSION_MAJOR-$VERSION_MINOR-$VERSION_PATCH-64

$DMD -m64 -debug -g -version=trace \
@pacahon-src-list $libs -oftarget/Pacahon-$VERSION_MAJOR-$VERSION_MINOR-$VERSION_PATCH-64-trace

rm target/*.o
rm target/*.log
rm target/*.io
rm target/*.oi



#$

#$DMD -m64 -O -Iimport -inline -d -L-Llib64 -L-lluad -L-llua -L-ldl \
