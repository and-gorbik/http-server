#!/bin/sh
mkdir ./test
perl server.pl -h 127.0.0.1 -p 11111 -d ./test &
cd test
echo "hello file1" > file1
echo "hello file2" > file2
cd -
curl http://127.0.0.1:11111/file1
curl http://127.0.0.1:11111/file2
curl http://127.0.0.1:11111

dd if=/dev/urandom of=file.txt count=50 bs=1048576

curl -T 'file.txt' http://127.0.0.1:11111/file50
curl -T 'file.txt' http://127.0.0.1:11111/copyfile50
curl -X DELETE http://127.0.0.1:11111/file1

echo ""
ls -l test
rm -rf test
rm file.txt