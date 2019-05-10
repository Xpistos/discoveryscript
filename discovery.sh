#!/bin/bash
#######################################
# This script is designed to retrieve #
# total system info for techincal     #
# discoveries. will retrieve cores,   #
# ram, amount of calls per day, and   #
# average load                        #
# Creator: jamie charlton             #
#######################################

#create the variable so that it doesnt complain if flag is not used
sftpstatus='false'

while getopts ":hs" opt; do 
  case ${opt} in
    h )
      echo -s
      echo used to specify to use sftp after running script
      echo if server does not allow outside sftp do not use
      echo
      echo
      exit 0
      ;;
    s ) 
      unset sftpstatus
      sftpstatus='true' 
			
			;;
    /?)
      echo not a valid command,
      echo only valid commands are -s and -h
      echo which -h just tells you -s is the only command.
      echo so you might as well just use -s or nothing at all.
      exit 0
      ;;
  esac
done

#write cpu info
echo CPU INFO: > ~/sysinfo.txt
echo ---------------------------------------------------- >> ~/sysinfo.txt
uptime >> ~/sysinfo.txt
lscpu  >> ~/sysinfo.txt
echo >> ~/sysinfo.txt

#write storage info
echo STORAGE: >> ~/sysinfo.txt
echo ---------------------------------------------------- >> ~/sysinfo.txt
df -H --output=source,size,used,avail  >> ~/sysinfo.txt
echo >> ~/sysinfo.txt

#write psql db info
echo PSQL ENTRIES: >> ~/sysinfo.txt  
echo ---------------------------------------------------- >> ~/sysinfo.txt
psql -U callrec -c "SELECT schemaname,relname,n_live_tup 
  FROM pg_stat_user_tables 
  ORDER BY n_live_tup DESC;" >> ~/sysinfo.txt
echo Database Size: >> ~/sysinfo.txt
du -ch /opt/callrec/data/psql | tail -n 1 >> ~/sysinfo.txt
echo   >> ~/sysinfo.txt

#write memory info
echo MEMORY: >> ~/sysinfo.txt
echo ----------------------------------------------------- >> ~/sysinfo.txt
free -m | awk {'print $2 "   "  $3'} | head -n 2 >> ~/sysinfo.txt
echo       >> ~/sysinfo.txt

#write info for concurrent calls max
echo LICENSE:  >> ~/sysinfo.txt
echo ----------------------------------------------------- >> ~/sysinfo.txt
echo Maximum concurrent calls >> ~/sysinfo.txt
echo
/opt/callrec/bin/callrec-status -state all -name remoteJTAPI1 -verbosity 5 | grep Licensed | awk {'print $11'} | sed -e 's/(.*//g' >> ~/sysinfo.txt
echo   >> ~/sysinfo.txt

#write info related to call space/usage and amount
echo AVERAGE DAY: >> ~/sysinfo.txt
echo ----------------------------------------------------- >> ~/sysinfo.txt
cd /opt/callrec/data/calls
largestday="$(du | sort -n -k1 | tail -n 2 | head -n 1 | awk {'print $2'})"
cd $largestday
echo "Calls Per Day (estimate): " >> ~/sysinfo.txt
ls -l | wc -l >> ~/sysinfo.txt
echo >> ~/sysinfo.txt

#were going to go get the mlm delete info in xml, and chop it up real good with some sed and some awk, it'll be great! trust me
echo MLM DELETE INFO: >>~/sysinfo.txt
echo ----------------------------------------------------- >> ~/sysinfo.txt
echo -e 'Data Type \t Interval \t If Archived \t Enabled   If Synchronized   Interval if custom   Delete DB Entry' >> ~/sysinfo.txt
echo ----------------------------------------------------------------------------------------------------------------------- >> ~/sysinfo.txt    
cat /opt/callrec/etc/tools.xml | grep -A 78 'name="delete"' | awk 'function getName(){match($0, /name="[^"]+"/); s=substr($0,RSTART+6,RLENGTH-7); return s}; function getVal(){match($0,/>[^<]*<\//); s=substr($0,RSTART+1,RLENGTH-3); return s}; /<Group name/{group=getName(); next}; /<Value name/{kv[getName()]=getVal(); next}; /<\/Group>/{s = group; for (k in kv) s = s sprintf("\"%s\" \"%s\"", k, kv[k]); print s; split("",kv); group=s=""; next}' | sed -e 's/"/\ /g' | sed -e 's/ interval.*plugins\./\ :/g' | sed -e 's/true/\ true;  /g' | sed -e 's/false/\ false; /g' | sed -e 's/onlyIfArchived/\ \t/g' | sed -e 's/enabled//g' | sed -e 's/onlyIfSynchronized//g' | sed -e 's/today/\ today \t \t /g' | sed -e 's/time/\    /g' | sed -e 's/deleteDatabase/\ \t/g' >> ~/sysinfo.txt
#create directory to store the files in for easy sftp or off transfer
cd
mkdir ~/techInfo
mv ~/sysinfo.txt ~/techInfo/sysinfo.txt

#run cmdb and write it to that folder
/opt/callrec/bin/scripts/cmdb.sh -d ~/techInfo

cd ~/

#handles the sftp declared by flag
if [ $sftpstatus == 'true' ];  then
    read -p "Enter Your Name: "  username
    read -p "Enter Server Url eg. file.zoomint.com: "  fileUrl
    sftp "$username"@"$fileUrl"
fi