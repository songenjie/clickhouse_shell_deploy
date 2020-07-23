# !/bin/bash 
set -x

/data0/songenjie/zookeeper/pkg/bin/zkServer.sh stop -y

OSS="http://storage"
# $1 clickhouseip

\rm -rf /data0/songenjie/zookeeper

#jdk
ROOT=/data0/songenjie_deploy
if [ ! -d "/software/servers/jdk1.8.0_121" ]
then
	wget  "${OSS}jdk1.8.0_121.zip"
	unzip jdk1.8.0_121.zip  -d /software/servers/
	\rm   jdk1.8.0_121.zip
fi

# pkg
if [ ! -d "/software/server" ]
then
	mkdir -p $ROOT
fi


wget  "${OSS}zookeeper-3.4.12.zip"
unzip zookeeper-3.4.12.zip  -d /data0/songenjie/zookeeper/
mv /data0/songenjie/zookeeper/zookeeper-3.4.12 /data0/songenjie/zookeeper/pkg
rm zookeeper-3.4.12.zip

# zoo.cfg

cat > /data0/songenjie/zookeeper/pkg/conf/zoo.cfg << EOF
tickTime=2000
initLimit=10
syncLimit=5
dataDir=/data0/songenjie/zookeeper/data
dataLogDir=/data0/songenjie/zookeeper/log
clientPort=2281
autopurge.snapRetainCount=500
autopurge.purgeInterval=24
EOF

# log
mkdir -p /data0/songenjie/zookeeper/log

# data
mkdir -p /data0/songenjie/zookeeper/data

# myid

COUNT=1
hostip=`hostname -I | awk '{print $1}'`
for IP in $(cat  $1 )
do
	echo "server.${COUNT}= ${IP}:2888:3888" >> /data0/songenjie/zookeeper/pkg/conf/zoo.cfg
	if [ "$IP" == "$hostip" ]
	then 
		echo "${COUNT}" > /data0/songenjie/zookeeper/data/myid
	fi
	let COUNT+=1
done


export JAVA_HOME=/software/servers/jdk1.8.0_121
export PATH=/data0/songenjie/zookeeper/pkg/bin:$JAVA_HOME/bin:$PATH

/data0/songenjie/zookeeper/pkg/bin/zkServer.sh stop
/data0/songenjie/zookeeper/pkg/bin/zkServer.sh start
/data0/songenjie/zookeeper/pkg/bin/zkServer.sh status

cat zookeeper.out
echo "$hostip deploy done"
