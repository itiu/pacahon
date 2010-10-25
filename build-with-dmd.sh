mongo_d_driver__hash=98aad67
trioplax__hash=4c5e642
zeromq__hash=1230c23

trioplax__project_name=itiu-trioplax
mongo_d_driver__project_name=itiu-mongo-d-driver
zeromq__project_name=itiu-zeromq-connector

mkdir build
rm -r build/src
mkdir build/src


mdir=$PWD

cp -v -r src/* build/src
cp -v -r build/$trioplax__project_name-$trioplax__hash/src/* build/src
cp -v -r build/$mongo_d_driver__project_name-$mongo_d_driver__hash/src/* build/src
cp -v -r build/$zeromq__project_name-$zeromq__hash/src/* build/src




#echo $mdir

#cd $mdir

rm build/src/test_recieve.d 
rm build/src/test_send.d

git log -1 --pretty=format:"module myversion; public static char[] author=cast(char[])\"%an\"; public static char[] date=cast(char[])\"%ad\"; public static char[] hash=cast(char[])\"%h\";">myversion.d

rm Pacahon-*
~/dmd/linux/bin/dmd -version=D1 -debug -g myversion.d build/src/trioplax/memory/*.d build/src/trioplax/mongodb/*.d build/src/trioplax/*.d build/src/*.d lib/libzmq.a lib/libstdc++.a lib/libuuid.a -ofPacahon-D1
~/dmd2/linux/bin/dmd -version=D2 -debug -g myversion.d build/src/trioplax/memory/*.d build/src/trioplax/mongodb/*.d build/src/trioplax/*.d build/src/*.d lib/libzmq.a lib/libstdc++.a lib/libuuid.a -ofPacahon-D2
rm *.o

 