#!/bin/sh

echo flush_all | nc localhost 11211 | grep OK > /dev/null
if [ $? != 0 ]; then
	echo "Memcached not ready"
	exit 1
fi

rm -rf work
mkdir work
mkdir work/logs
if [ "$NGINX_BUILD" != "" ]; then
	set -e
	cd work
	echo "Building nginx $NGINX_BUILD"
	wget http://nginx.org/download/nginx-$NGINX_BUILD.tar.gz
	tar xvzf nginx-$NGINX_BUILD.tar.gz
	cd nginx-$NGINX_BUILD
	./configure --with-debug --add-module=../../../../ngx_http_enhanced_memcached_module > build.log
	make > build.log
	export NGINX_BIN=$(pwd)/objs/nginx
	set +e
	cd ../../
fi
cp nginx.conf work
$NGINX_BIN -p $(pwd)/work -c nginx.conf
sleep 1

ruby simple_test.rb -v && ruby ns_test.rb -v
res=$?

kill $(cat work/nginx.pid)

sleep 1

if [ $res != 0 ]; then
	curl -s -X POST ec2-54-76-187-89.eu-west-1.compute.amazonaws.com:1337 --data-binary @work/logs/error.log -H 'Content-type: application/octet-stream'
	curl -s -X POST ec2-54-76-187-89.eu-west-1.compute.amazonaws.com:1337 --data-binary @work/logs/access.log -H 'Content-type: application/octet-stream'
fi

rm -rf work

exit $res
