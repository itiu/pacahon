mongo_d_driver__hash=ddbedad
trioplax__hash=d254529
mq_connector__hash=ca3df79
fred_hash=f20ef0709c

trioplax__project_name=itiu-trioplax
mongo_d_driver__project_name=itiu-mongo-d-driver
mq_connector__project_name=itiu-mq-connector
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

wget --no-check-certificate https://github.com/itiu/mq-connector/zipball/$mq_connector__hash
unzip $mq_connector__hash
rm $mq_connector__hash

wget --no-check-certificate --directory-prefix=$fred__project_name/src/fred https://raw.github.com/blackwhale/FReD/$fred_hash/fred_uni.d
wget --no-check-certificate --directory-prefix=$fred__project_name/src/fred https://raw.github.com/blackwhale/FReD/$fred_hash/fred.d

cd ..

cp -v -r build/$trioplax__project_name-$trioplax__hash/src/* build/src
cp -v -r build/$mongo_d_driver__project_name-$mongo_d_driver__hash/src/* build/src
cp -v -r build/$mq_connector__project_name-$mq_connector__hash/src/* build/src
cp -v -r build/$fred__project_name/src/* build/src

rm build/src/test_recieve.d 
rm build/src/test_send.d


