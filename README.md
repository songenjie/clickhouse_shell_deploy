# clickhouse_shell_deploy


## zookeepip

./zookeep_install zookeepip


## clickhouse

```
$1 clustername1  Separator use `,`
$2 clickhouseipfile 
$3 zookeepeeripfile
$4 replicacount
$5 startport 
```

- eg:
```
./clickhhouse_install cluster1,cluster2 clickhouseip zookeeperip 3 8600
```
