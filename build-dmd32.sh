DMD=dmd

VERSION_MAJOR=1
VERSION_MINOR=28
VERSION_PATCH=1

cp -v -r src/* build/src

git log -1 --pretty=format:"module myversion; public static string major=\"$VERSION_MAJOR\"; public static string minor=\"$VERSION_MINOR\"; public static string patch=\"$VERSION_PATCH\"; public static string author=\"%an\"; public static string date=\"%ad\"; public static string hash=\"%h\";">src/myversion.d

rm Pacahon-$VERSION_MAJOR-$VERSION_MINOR-$VERSION_PATCH-32
rm *.log
rm *.io
rm *.oi

$DMD -m32 -debug -d \
@pacahon-src-list \
lib32/libzmq.a lib32/libstdc++.a lib32/libuuid.a lib32/libmongoc.a lib32/libbson.a lib32/libchash.o \
-ofPacahon-$VERSION_MAJOR-$VERSION_MINOR-$VERSION_PATCH-32
rm *.o

#$DMD -m64 -O -Iimport -inline -d -L-Llib64 -L-lluad -L-llua -L-ldl \
