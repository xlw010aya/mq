#!/bin/sh
#===========================================
#*
#* Copyright ITS
#* All rights reserved.
#* Abstract: RealTimePutFtp.sh
#* FileName: RealTimePutFtp.sh
#* Author: 70795
#* Create Time: 2015-07-01
#* Mender: 70795
#* Mender Time: 
#* Modify content: 
#*
#============================================



##########################################################################
# Function Name:  WriteInfo
# Function Desc:  打印正常日志信息
# Inputs:         正常日志信息
# Return:         
##########################################################################

WriteInfo()
{
    echo -e "$(date +"%Y-%m-%d") $(date +"%H:%M:%S")[INFO] $1" |tee -a ${LOGFILE}
}

##########################################################################
# Function Name:  WriteError
# Function Desc:  打印错误日志
# Inputs:         错误日志信息
# Return:         
##########################################################################
WriteError()
{
    Time=`date +"%Y%m%d"`
    ERRORLOGFILE=$LOCAL/$LOG/RealTimeQuery_$Time.log
    echo -e "$(date +"%Y-%m-%d") $(date +"%H:%M:%S")[ERROR] $1" |tee -a $ERRORLOGFILE
}

##########################################################################
# Function Name:  ftpput
# Function Desc:  上传本地文件到FTP
# Inputs:         上传本地文件到FTP
# Return:         
##########################################################################
local2ftp()
{
    #存放该时间段内的文件时间列表
    WriteInfo "move ${FileLocalOutput}/ files to $FileLocalCombinBackup/"
    mv ${FileLocalOutput}/*_*.txt $FileLocalCombinBackup/
    cd $FileLocalCombinBackup/
    while [ 1 ]
    do
        combtxtnum=`ls *_*.txt|wc -l`
        if [ "$combtxtnum" -ne "0" ] || [ ! -n "$combtxtnum" ];then
           FileList=`ls *_*.txt|head -n 10`
           GZFileTime=`echo ${FileList} |head -n 1|awk -F '_' '{print $2}'`
           WriteInfo "tar data_$GZFileTime.tar.gz "
           tar -cvzf data_$GZFileTime.tar.gz ${FileList} --remove-files
           WriteInfo "ftp put  data_$GZFileTime.tar.gz "

ftp_log=`ftp -i -v -n <<EOF
open $UpFtpIP
user $UpUserName $UpPassWord
binary
passive
lcd $FileLocalCombinBackup/
put data_$GZFileTime.tar.gz
close
bye
EOF
`
           WriteInfo "FTP put success"
           WriteInfo "move data_$GZFileTime.tar.gz to $FileLocalBackup/"
           mv data_$GZFileTime.tar.gz $FileLocalBackup/
        else
           break
        fi
        sleep 2
    done
}

##########################################################################
# Function Name:  ftpput
# Function Desc:  上传本地文件到FTP
# Inputs:         上传本地文件到FTP
# Return:         
##########################################################################
localcombdir2ftp()
{
cd ${FileLocalCombinBackup}
ls data_*.tar.gz
WriteInfo "FTP put data_*.tar.gz"

ftp_log=`ftp -i -v -n <<EOF
open $UpFtpIP
user $UpUserName $UpPassWord
binary
passive
lcd $FileLocalCombinBackup/
mput data_*.tar.gz
close
bye
EOF
`

WriteInfo "FTP put success"
WriteInfo "move data_*.tar.gz to $FileLocalBackup/"
mv data_*.tar.gz $FileLocalBackup/
}


##########################################主程序#######################

#上传文件ftp的ip
tmp=`cat UpFtp | grep FtpIP`
echo $tmp > tmp
UpFtpIP=`awk -F = '{print $2}' tmp`
#上传文件ftp的用户名
tmp=`cat UpFtp | grep UserName`
echo $tmp > tmp
UpUserName=`awk -F = '{print $2}' tmp`
#上传文件ftp的密码
tmp=`cat UpFtp | grep PassWord`
echo $tmp > tmp
UpPassWord=`awk -F = '{print $2}' tmp`
#查询后结果存放在本地的路径
tmp=`cat UpFtp | grep LocalDir`
echo $tmp > tmp
LocalDir=`awk -F = '{print $2}' tmp`

#本地磁盘数据目录
FileLocalOutput=$LocalDir/data

#本地备份上传ftp文件目录
FileLocalBackup=$LocalDir/ftpbackup

#本地备份合并文件目录
FileLocalCombinBackup=$LocalDir/combbackup

#本地备份TXT未压缩文件目录
######FileLocalTxtBackup=$LocalDir/txtbackup

#文件时间截取
TimeBegin=4
TimeLength=10

####公共变量声明####
#日志文件

FileTime=`date +"%Y%m%d"`
LOGFILE=$LocalDir/logs/RealTimeFtpPut_$FileTime.log
#错误日志文件
ERRORLOGFILE=$LocalDir/logs/RealTimeFtpPutError_$FileTime.log

echo "UpFtpIP is $UpFtpIP,UpUserName is $UpUserName, UpPassWord is $UpPassWord,LocalDir is $LocalDir,FileLocalOutput is $FileLocalOutput"

echo "FileLocalOutput is $FileLocalOutput"
echo "FileLocalBackup is $FileLocalBackup"
echo "FileLocalCombinBackup is $FileLocalCombinBackup"

mkdir -p $FileLocalBackup
mkdir -p $FileLocalCombinBackup

#上传文件

txtnum=`ls ${FileLocalOutput}/*_*.txt|wc -l`
targznum=`ls ${FileLocalCombinBackup}/data_*.tar.gz|wc -l`
##有未压缩或者未上传ftp的压缩文件时
if [ "$txtnum" -ne "0" -o  ! -n "$txtnum" ]  ||  [ "$targznum" -ne "0" -o ! -n "$targznum" ];then
   ##有未上传ftp的文件
   if [ "$targznum" -ne "0" ] || [ ! -n "$targznum" ] ;then
   WriteInfo  "localcombdir2ftp begin"
   localcombdir2ftp
   WriteInfo "localcombdir2ftp end"
   else
   WriteInfo  "local2ftp begin"
   local2ftp
   WriteInfo "local2ftp end"
   fi
else
WriteInfo "TxtFile not exist"
echo $ftp_log|grep "230 Login successful"
   if [ $? -ne 0 ]; then
         currentTime=`date +'%Y-%m-%d-%H:%M:%S'`
         WriteInfo "sh -x businessMetric.sh -i '192.168.0.10' -k 'business_yd_ftp'  -v '99' -t '云砥FTP连接情况监控' -u '个/天' -g '4' -d '云砥FTP连接情况监控' -m ${currentTime}"
         sh -x businessMetric.sh -i '192.168.0.10' -k 'business_yd_ftp'  -v '99' -t '云砥FTP连接情况监控' -u '个/天' -g '4' -d '云砥FTP连接情况监控' -m ${currentTime}
   fi
fi

while [ 1 ]
do
  txtnum=`ls ${FileLocalOutput}/*_*.txt|wc -l`
  targznum=`ls ${FileLocalCombinBackup}/data_*.tar.gz|wc -l`
  ##有未压缩或者未上传ftp的压缩文件时
  if [ "$txtnum" -ne "0" -o  ! -n "$txtnum" ]  ||  [ "$targznum" -ne "0" -o ! -n "$targznum" ];then
     ##有未上传ftp的文件
     if [ "$targznum" -ne "0" ] || [ ! -n "$targznum" ] ;then
        WriteInfo  "localcombdir2ftp begin"
        localcombdir2ftp
        WriteInfo "localcombdir2ftp end"
     else
        WriteInfo  "local2ftp begin"
        local2ftp
        WriteInfo "local2ftp end"
     fi
  else
     WriteInfo "TxtFile not exist"
  fi
  sleep 2
  echo $ftp_log|grep "230 Login successful"
  if [ $? -ne 0 ]; then
         currentTime=`date +'%Y-%m-%d-%H:%M:%S'`
         WriteInfo "sh -x businessMetric.sh -i '192.168.0.10' -k 'business_yd_ftp'  -v '99' -t '云砥FTP连接情况监控' -u '个/天' -g '4' -d '云砥FTP连接情况监控' -m ${currentTime}"
         sh -x businessMetric.sh -i '192.168.0.10' -k 'business_yd_ftp'  -v '99' -t '云砥FTP连接情况监控' -u '个/天' -g '4' -d '云砥FTP连接情况监控' -m ${currentTime}
  fi
done

