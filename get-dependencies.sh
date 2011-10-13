mongo_d_driver__hash=53d3e7f
trioplax__hash=698a06b
zeromq__hash=bbd27d2
fred_hash=f20ef0709c

trioplax__project_name=itiu-trioplax
mongo_d_driver__project_name=itiu-mongo-d-driver
zeromq__project_name=itiu-zeromq-connector
fred__project_name=blackwhale-rfed

mkdir build
cd build
mkdir src

wget --no-check-certificate https://github.com/itiu/mongo-d-driver/zipball/$mongo_d_driver__hash
unzip $mongo_d_driver__hash
rm $mongo_d_driver__hash

wget --no-check-certificate https://github.com/itiu/trioplax/zipball/$trioplax__hash
unzip $trioplax__hash
rm $trioplax__hash

wget --no-check-certificate https://github.com/itiu/zeromq-connector/zipball/$zeromq__hash
unzip $zeromq__hash
rm $zeromq__hash

wget --no-check-certificate --directory-prefix=$fred__project_name/src/fred https://raw.github.com/blackwhale/FReD/$fred_hash/fred_uni.d
wget --no-check-certificate --directory-prefix=$fred__project_name/src/fred https://raw.github.com/blackwhale/FReD/$fred_hash/fred.d

cd ..

cp -v -r build/$trioplax__project_name-$trioplax__hash/src/* build/src
cp -v -r build/$mongo_d_driver__project_name-$mongo_d_driver__hash/src/* build/src
cp -v -r build/$zeromq__project_name-$zeromq__hash/src/* build/src
cp -v -r build/$fred__project_name/src/* build/src

rm build/src/test_recieve.d 
rm build/src/test_send.d


