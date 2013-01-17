DMD=dmd

VERSION_MAJOR=1
VERSION_MINOR=29
VERSION_PATCH=2

cp -v -r src/* build/src

git log -1 --pretty=format:"module myversion; public static string major=\"$VERSION_MAJOR\"; public static string minor=\"$VERSION_MINOR\"; public static string patch=\"$VERSION_PATCH\"; public static string author=\"%an\"; public static string date=\"%ad\"; public static string hash=\"%h\";">src/myversion.d

rm Pacahon-$VERSION_MAJOR-$VERSION_MINOR-$VERSION_PATCH-64
rm *.log
rm *.io
rm *.oi

$DMD -m64 -debug -g \
@pacahon-src-list \
lib64/libzmq.a lib64/libstdc++.a lib64/libuuid.a lib64/libmongoc.a lib64/libbson.a lib64/libchash.o lib64/librabbitmq.a \
-oftarget/Pacahon-$VERSION_MAJOR-$VERSION_MINOR-$VERSION_PATCH-64
rm target/*.o

#$DMD -m64 -O -Iimport -inline -d -L-Llib64 -L-lluad -L-llua -L-ldl \
