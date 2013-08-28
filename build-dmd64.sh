DMD=dmd

VERSION_MAJOR=1
VERSION_MINOR=34
VERSION_PATCH=0

#cp -r src/* build/src

git log -1 --pretty=format:"module pacahon.myversion; public static string major=\"$VERSION_MAJOR\"; public static string minor=\"$VERSION_MINOR\"; public static string patch=\"$VERSION_PATCH\"; public static string author=\"%an\"; public static string date=\"%ad\"; public static string hash=\"%h\";">src/pacahon/myversion.d

rm target/Pacahon-$VERSION_MAJOR-$VERSION_MINOR-$VERSION_PATCH-64
rm target/Pacahon-$VERSION_MAJOR-$VERSION_MINOR-$VERSION_PATCH-64-trace
rm *.log
rm *.io
rm *.oi

$DMD -m64 -debug -O -g \
@pacahon-src-list \
lib64/libzmq.a lib64/libczmq.a lib64/libstdc++.a lib64/libuuid.a lib64/libmongoc.a lib64/libbson.a lib64/libchash.o lib64/librabbitmq.a \
lib64/libutils.a -L-lbangdb lib64/libdbangdb.a \
-oftarget/Pacahon-$VERSION_MAJOR-$VERSION_MINOR-$VERSION_PATCH-64

#$DMD -m64 -debug -g -version=trace \
#@pacahon-src-list \
#lib64/libzmq.a lib64/libczmq.a lib64/libstdc++.a lib64/libuuid.a lib64/libmongoc.a lib64/libbson.a lib64/libchash.o lib64/librabbitmq.a lib64/libutils.a \
#-oftarget/Pacahon-$VERSION_MAJOR-$VERSION_MINOR-$VERSION_PATCH-64-trace

rm target/*.o
rm target/*.log
rm target/*.io
rm target/*.oi



#$

#$DMD -m64 -O -Iimport -inline -d -L-Llib64 -L-lluad -L-llua -L-ldl \
