# !/bin/bash 

# author songenjie 

### 这里我们假设 ck 和 zk 端口 没有变动

# ${1} clustername_array  默认会给所有clustername 创建 ${clustername}_sys 的cluster 
# ${2} clickhouseip_fle
# ${3} zookeeperip_file
# ${4} replicacount
# ${5} startportrelica  replica1 8601 8602 8603 8604 8605 relica_n=(n-1)*10+reliace1


OSS="http://storage.jd.local/ssoftware/"
ROOT=`pwd`

if [ ! -d "$ROOT" ]
then
	mkdir -p $ROOT
fi

if [ ! -f "$2" ]
then
	echo "$2 file name not exists"
	exit
fi

if [ ! -f "$3" ]
then
	echo "$3 file name not exists"
	exit
fi

#init my_array = (value1 ... valuen)
#数据大小 ${#my_array[@]} ${#my_array[*]} 
#取某个元素 ${my_array[i]}]
#遍历元素 for i in ${my_array[*]}  ${my_array[@]}]

echo "start disk check"
DATADIRS=(`df -i  |grep /dev/sd | grep data | sort  | grep -v $(df -i  |grep /dev/sd | grep data | sort | head -n 1  | awk '{printf $1 }') | awk '{printf"%s ", $6}'`)

let LASTINDEX=${#DATADIRS[@]}-1

DATALAST=`df -i  |grep /dev/sd | grep data | sort  | tail -n 1 | awk '{print $6}'`
# 磁盘和副本文本问题校验

echo "${DATADIRS[@]}"
echo "${#DATADIRS[@]}"

if [ "${DATADIRS[$LASTINDEX]}" != "${DATALAST}" ]
then
	echo "data mount not correct ! please check it use "
	exit
fi


if [ "${#DATADIRS[@]}" -lt "${4}" ]
then
	echo "replica count ${4} more than disk count ${#DATADIRS[@]}"
	exit
fi 
echo "disk check done"

# on process data count
echo "init strage"
let SINGLEPROCESSDISKCOUNT=${#DATADIRS[@]}/${4}
let SHAREPROCESSDISKCOUNT=${#DATADIRS[@]}%${4}
# single home dir and data dir 

for((i=0;i<${4};i++))
do 
		let HOMEDIR=i*$SINGLEPROCESSDISKCOUNT
		if [ ! -d "/data${HOMEDIR}" ]
		then
			echo "replica count : ${4} ==  disk count ; /data${HOMEDIR} not not exists"
		fi
		if [ -d "/data${HOMEDIR}/songenjie/clickhouse" ]
		then
			\rm -rf /data${HOMEDIR}/songenjie/clickhouse
		fi
		mkdir -p  /data${HOMEDIR}/songenjie/clickhouse/data

        cd  /data${HOMEDIR}/songenjie/clickhouse && \rm -rf  bin  conf  ddl  defaultdata  format_schemas  lib  log  ssl  tmpdata  user_files access
        cd  /data${HOMEDIR}/songenjie/clickhouse && mkdir bin  conf  ddl  defaultdata  format_schemas  lib  log  ssl  tmpdata  user_files access

done

for((i=0;i<${#DATADIRS[@]};i++))
do 
    \rm -rf  /data${i}/songenjie/clickhouse/data
    mkdir -p  /data${i}/songenjie/clickhouse/data
done

# share disk data dir init 
let SHARDISTINDEX=${#DATADIRS[@]}-SHAREPROCESSDISKCOUNT
for((i=$SHARDISTINDEX;i<${#DATADIRS[@]};i++))
do
	# every shar dist need mkdir replicai data	
	for((replica=1;replica<=${4};replica++))
	do 
		if [ ! -d "/data${i}" ]
		then
			echo "replica count : ${4} ==  disk count ; /data${i} not not exists"
		fi

		if [ ! -d "/data${i}/songenjie/clickhouse/${replica}" ]
		then
			\rm -rf /data${i}/songenjie/clickhouse/data${replica}
		fi
		mkdir -p  /data${i}/songenjie/clickhouse/data${replica}
	done
done
echo "storage init done"

#2 ip count check
echo "start ip count check"
COUNT=0
for IP in $(cat  ${ROOT}/${2} )
do
    let COUNT+=1
done

let COUNT=COUNT%${4}
if [ "$COUNT" != 0 ]
then 
    echo "clickhouse ip 数量不对 不是3 的倍数"
    exit
fi  
echo "ip check done"

#3 metrika.xml
# multi cluster 问题

echo "init cluster names"
CLUSTERARRAY=(`echo $1 | tr ',' ' '` ) 
for CLUSTERNAME in ${CLUSTERARRAY[@]};
do
    echo "clustername $CLUSTERNAME"
done
echo "init cluster done"

echo "init metrika xml"
if [ ! -d "${ROOT}/metrika" ]
then
	mkdir -p ${ROOT}/metrika
fi

# 1 metrika_yandex_clickhouse_remote_server_head.xml
# 2 metrika_clustername_header.xml
# 3 metrika_shard_header.xml
# 4 metrika_shard_replica.xml
# 4 metrika_shard_tail.xml
# 4 metrika_clustername_tail.xml
# 5 metrika_yandex_clickhouse_remote_server_tail.xml
# 6 metrika_end.sh

cat > ${ROOT}/metrika/metrika_clickhouse_remote_servers_head.xml << EOF
<yandex>
<clickhouse_remote_servers>
EOF

cat > ${ROOT}/metrika/metrika_clickhouse_remote_servers_tail.xml << EOF
</clickhouse_remote_servers>
EOF

cat > ${ROOT}/metrika/metrika_clustername_header.xml << EOF
    <CLUSTERNAME>
EOF

cat > ${ROOT}/metrika/metrika_clustername_tail.xml << EOF
    </CLUSTERNAME>
EOF

cat > ${ROOT}/metrika/metrika_shard_header.xml << EOF
        <shard>
EOF

cat > ${ROOT}/metrika/metrika_shard_tail.xml << EOF
        </shard>
EOF

cat > ${ROOT}/metrika/metrika_shard_replica.xml << EOF
            <internal_replication>true</internal_replication>
            <!-- <weight>true</weight> -->
            <replica>
                <host>NODE</host>
                <port>PORT</port>
            </replica>
EOF

cat > ${ROOT}/metrika/metrika_end.xml << EOF
<macros>
	<shard>RSHARD</shard>
	<replica>RREPLICA</replica>
</macros>

<zookeeper-servers>
  <node index="1">
    <host>ZK1</host>
    <port>2281</port>
  </node>
  <node index="2">
    <host>ZK2</host>
    <port>2281</port>
  </node>
  <node index="3">
    <host>ZK3</host>
    <port>2281</port>
  </node>
</zookeeper-servers>

<networks>
   <ip>::/0</ip>
</networks>
 
<clickhouse_compression>
<case>
  <min_part_size>10000000000</min_part_size>            
  <min_part_size_ratio>0.01</min_part_size_ratio>
  <method>lz4</method>
</case>
</clickhouse_compression>
</yandex>
EOF


# remote cluster
cat  ${ROOT}/metrika/metrika_clickhouse_remote_servers_head.xml     >   ${ROOT}/metrika/metrika.xml

IPS=(`cat ${ROOT}/${2} | awk '{printf"%s ",$1}'`)

#2 shard clickhouseip count is shardnum
for CLUSTERNAME in ${CLUSTERARRAY[@]};
do
	cat  ${ROOT}/metrika/metrika_clustername_header.xml             >>  ${ROOT}/metrika/metrika.xml
	#ip 
	for((SHARDCOUNT=0;SHARDCOUNT<${#IPS[@]};SHARDCOUNT++)) 
	do
		cat  ${ROOT}/metrika/metrika_shard_header.xml               >>  ${ROOT}/metrika/metrika.xml
		let PORT=${5}+1
		let GROUP=SHARDCOUNT/${4}
		let GROUP=GROUP*${4}
		let IPINDEX=SHARDCOUNT
		for((i=1;i<=${4};i++))
		do
			let IPINDEX=IPINDEX%${4}
			let IPINDEX+=GROUP
				cat  ${ROOT}/metrika/metrika_shard_replica.xml      >>  ${ROOT}/metrika/metrika.xml
				sed -i "s/NODE/${IPS[$IPINDEX]}/g"  ${ROOT}/metrika/metrika.xml
				sed -i "s/PORT/${PORT}/g"      ${ROOT}/metrika/metrika.xml
			let IPINDEX+=1
			let PORT+=10
		done
		cat  ${ROOT}/metrika/metrika_shard_tail.xml                 >>  ${ROOT}/metrika/metrika.xml
    done
	cat  ${ROOT}/metrika/metrika_clustername_tail.xml               >>  ${ROOT}/metrika/metrika.xml

	#clustername
	sed -i "s/CLUSTERNAME/${CLUSTERNAME}/g"   ${ROOT}/metrika/metrika.xml
done

# system_cluster
cat  ${ROOT}/metrika/metrika_clustername_header.xml                 >>  ${ROOT}/metrika/metrika.xml
cat  ${ROOT}/metrika/metrika_shard_header.xml                       >>  ${ROOT}/metrika/metrika.xml
for((i=1;i<=${4};i++))
do
	let PORT=${5}+1
	for IP in $(cat  ${ROOT}/${2} )
	do
		cat  ${ROOT}/metrika/metrika_shard_replica.xml              >>  ${ROOT}/metrika/metrika.xml
		sed -i "s/NODE/${IP}/g"  ${ROOT}/metrika/metrika.xml
		sed -i "s/PORT/${PORT}/g"      ${ROOT}/metrika/metrika.xml
	done
	let PORT+=10
done
cat  ${ROOT}/metrika/metrika_shard_tail.xml                         >>  ${ROOT}/metrika/metrika.xml
cat  ${ROOT}/metrika/metrika_clustername_tail.xml                   >>  ${ROOT}/metrika/metrika.xml
sed -i "s/CLUSTERNAME/system_cluster/g"                             ${ROOT}/metrika/metrika.xml


# remote cluster end
cat  ${ROOT}/metrika/metrika_clickhouse_remote_servers_tail.xml     >>  ${ROOT}/metrika/metrika.xml
cat  ${ROOT}/metrika/metrika_end.xml                                >>  ${ROOT}/metrika/metrika.xml

# zk ip set 
let COUNT=1
for IP in $(cat  ${ROOT}/${3} )
do
	sed -i "s/ZK${COUNT}/${IP}/g"   ${ROOT}/metrika/metrika.xml
	let COUNT+=1
done
# shard replica set 
hostip=`hostname -I | awk '{print $1 }'`
for((i=1;i<=${4};i++))
do
    let j=$i-1
    let j=j*$SINGLEPROCESSDISKCOUNT
    	
	if [ ! -d "/data${i}/songenjie/clickhouse" ]
	then
		echo "process calc err /data${i}/songenjie/clickhouse $i"
		exit
	fi

	IPCOUNT=1
	for IP in $(cat  ${ROOT}/${2} )
	do
		let COUNT=IPCOUNT
		let SHARD=IPCOUNT-1

		let COUNT+=${4}
		let COUNT=COUNT-i
		let COUNT+=1
		let COUNT=COUNT%${4}
		if [ "$COUNT" == 0 ]
		then 
			let COUNT+=${4}
		fi
		
		let SHARD=SHARD/${4}
		let SHARD=SHARD*${4}
		let SHARD+=COUNT
	
		if [ "$IP" != "$hostip" ]
		then 
			let IPCOUNT+=1
			let SHARD+=1
			continue
		fi
		echo "$IP $SHARD $i $j"

		cp  ${ROOT}/metrika/metrika.xml  /data${j}/songenjie/clickhouse/conf/metrika.xml

		sed -i "s/RSHARD/0${SHARD}/g"   /data${j}/songenjie/clickhouse/conf/metrika.xml
		sed -i "s/RREPLICA/0${i}/g"     /data${j}/songenjie/clickhouse/conf/metrika.xml
		
		let IPCOUNT+=1
		let SHARD+=1
	done
done
\rm -rf ${ROOT}/metrika
echo "init metrika xml done"

#clickhouse server
echo "init service"
for((i=1;i<=${4};i++))
do 
	let HOMEDIR=i-1
	let HOMEDIR=HOMEDIR*$SINGLEPROCESSDISKCOUNT

	cat > /etc/systemd/system/clickhouse-server${i}.service << EOF
[Unit]
Description=ClickHouse Server (analytic DBMS for big data)
Requires=network-online.target
After=network-online.target

[Service]
Type=simple
User=clickhouse
Group=clickhouse
Restart=always
RestartSec=30
RuntimeDirectory=clickhouse-server
ExecStart=/data0/songenjie/clickhouse/lib/clickhouse server  --config=/data${HOMEDIR}/songenjie/clickhouse/conf/config.xml --pid-file=/data${HOMEDIR}/songenjie/clickhouse/bin/clickhouse-server.pid
LimitCORE=infinity
LimitNOFILE=500000
CapabilityBoundingSet=CAP_NET_ADMIN CAP_IPC_LOCK CAP_SYS_NICE

[Install]
WantedBy=multi-user.target
EOF

done
echo "init service done"


#config xml
echo "all config xml start"
for((i=1;i<=${4};i++))
do 
	let HOMEDIR=i-1
	let PORT=HOMEDIR*10+${5}
	let HOMEDIR=HOMEDIR*$SINGLEPROCESSDISKCOUNT
	echo " $HOMEDIR  config xml start"

	cp  ${ROOT}/config.xml  /data${HOMEDIR}/songenjie/clickhouse/conf/config.xml

	#set HOMEDIR
    echo "data"
	sed -i "s/HOMEDIR/data${HOMEDIR}/g" /data${HOMEDIR}/songenjie/clickhouse/conf/config.xml

	#set PORT
    echo "port"
	for((j=1;j<=5;j++))
	do
		sed -i "s/PORT${j}/${PORT}/g" /data${HOMEDIR}/songenjie/clickhouse/conf/config.xml
		let PORT+=1
	done

	#set storage
    echo "disk"
	## disk
	for((j=0;j<${SINGLEPROCESSDISKCOUNT};j++))
	do
		let DISKNAME=j+HOMEDIR
        echo "songenjie $DISKNAME"
		cat ${ROOT}/disk.xml                 >> /data${HOMEDIR}/songenjie/clickhouse/conf/disk.xml
		sed -i "s/DISKNAME/disk${DISKNAME}/g"   /data${HOMEDIR}/songenjie/clickhouse/conf/disk.xml
		sed -i "s/PATHDIR/data${DISKNAME}\/songenjie\/clickhouse\/data/g"       /data${HOMEDIR}/songenjie/clickhouse/conf/disk.xml
	done
	for((j=$SHARDISTINDEX;j<${#DATADIRS[@]};j++))
	do
		cat ${ROOT}/disk.xml                 >> /data${HOMEDIR}/songenjie/clickhouse/conf/disk.xml
		sed -i "s/DISKNAME/data${j}/g"   /data${HOMEDIR}/songenjie/clickhouse/conf/disk.xml
		sed -i "s/PATHDIR/data${j}\/songenjie\/clickhouse\/data${i}/g"       /data${HOMEDIR}/songenjie/clickhouse/conf/disk.xml
	done
	DISKCONTENT=`cat /data${HOMEDIR}/songenjie/clickhouse/conf/disk.xml`
	\rm -rf  /data${HOMEDIR}/songenjie/clickhouse/conf/disk.xml
	cat >> /data${HOMEDIR}/songenjie/clickhouse/conf/config.xml << EOF
    <storage_configuration>
        <disks>
${DISKCONTENT}
        </disks>
EOF

    echo "volume"
	#volume	
	cp ${ROOT}/volume.xml                 /data${HOMEDIR}/songenjie/clickhouse/conf/volume.xml
	sed -i "s/VOLUME/hot/g"                  /data${HOMEDIR}/songenjie/clickhouse/conf/volume.xml
	for((j=0;j<${SINGLEPROCESSDISKCOUNT};j++))
	do
		let DISKNAME=j+HOMEDIR
		let LINE=j+1
		sed -i "${LINE}a\                        <disk>disk${DISKNAME}</disk>"  /data${HOMEDIR}/songenjie/clickhouse/conf/volume.xml 
	done

	cat ${ROOT}/volume.xml                >> /data${HOMEDIR}/songenjie/clickhouse/conf/volumecold.xml
	sed -i "s/VOLUME/cold/g"                  /data${HOMEDIR}/songenjie/clickhouse/conf/volumecold.xml
	let LINE=1
	for((j=${SHARDISTINDEX};j<${#DATADIRS[@]};j++))
	do
		sed -i "${LINE}a\                        <disk>disk${j}</disk>"  /data${HOMEDIR}/songenjie/clickhouse/conf/volumecold.xml 
		let LINE+=1
	done
	cat /data${HOMEDIR}/songenjie/clickhouse/conf/volumecold.xml >> /data${HOMEDIR}/songenjie/clickhouse/conf/volume.xml 
	VOLUMECONTENT=`cat /data${HOMEDIR}/songenjie/clickhouse/conf/volume.xml`
	\rm -rf  /data${HOMEDIR}/songenjie/clickhouse/conf/volumecold.xml
	\rm -rf  /data${HOMEDIR}/songenjie/clickhouse/conf/volume.xml
	cat >> /data${HOMEDIR}/songenjie/clickhouse/conf/config.xml << EOF
        <policies>
            <jdob_ha>
                <volumes>
${VOLUMECONTENT}
                </volumes>
                <move_factor>0.25</move_factor>
            </jdob_ha>
        </policies>
    </storage_configuration>
</yandex>
EOF
	echo " $HOMEDIR  config xml done"

done
echo "all config xml done"

# users.xml
echo "all users xml start"
for((i=1;i<=${4};i++))
do 
	let HOMEDIR=i-1
	let PORT=HOMEDIR*10+${5}
	let HOMEDIR=HOMEDIR*$SINGLEPROCESSDISKCOUNT
	echo "$HOMEDIR users config start"

	cp  ${ROOT}/users.xml /data${HOMEDIR}/songenjie/clickhouse/conf/users.xml
	echo "$HOMEDIR users config done"
	
done
echo "all users xml done"


# add user if not exists
echo "start create users"
id clickhouse >& /dev/null
if [ $? -ne 0 ]
then
	useradd -g clickhouse clickhouse
	useradd clickhouse
fi

egrep "^clickhouse" /etc/passwd >& /dev/null
if [ $? -ne 0 ]
then
	useradd -g clickhouse clickhouse
fi
echo "create users done"

# lib 
echo "clickhouse lib"
wget "${OSS}clickhouse_20.5.zip"
unzip clickhouse_20.5.zip  -d /data0/songenjie/clickhouse/lib/clickhouse
rm clickhouse_20.5.zip
echo "init lib done"


echo "start chown -R"
# chown 
systemctl daemon-reload

for((i=0;i<${#DATADIRS[@]};i++))
do
	chown -R clickhouse:clickhouse /data${i}/songenjie/clickhouse
done
echo "chown -R done"

# start 
echo "start service"
for((i=1;i<=${4};i++))
do
	systemctl enable clickhouse-server${i}.service
	systemctl start  clickhouse-server${i};
	systemctl status clickhouse-server${i};

	echo clickhouse-server${i}  done
done
echo "start service done"

echo "$hostip all done \n 3ks use this shell deme"
