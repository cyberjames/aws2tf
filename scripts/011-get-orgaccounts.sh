#!/bin/bash
if [ "$1" != "" ]; then
    cmd[0]="$AWS organizations list-accounts" 
else
    cmd[0]="$AWS organizations list-accounts" 
fi

pref[0]="Accounts"
tft[0]="aws_organizations_account"
idfilt[0]="Id"

#rm -f ${tft[0]}.tf

for c in `seq 0 0`; do
    
    cm=${cmd[$c]}
	ttft=${tft[(${c})]}
	echo $cm
    awsout=`eval $cm 2> /dev/null`
    if [ "$awsout" == "" ];then
        echo "This is either not an AWS organizations account or you don't have access"
        exit
    fi
    count=1    
    count=`echo $awsout | jq ".${pref[(${c})]} | length"`
    #echo $count
    if [ "$count" -gt "0" ]; then
        count=`expr $count - 1`
        for i in `seq 0 $count`; do
            #echo $i
            cname=`echo $awsout | jq ".${pref[(${c})]}[(${i})].${idfilt[(${c})]}" | tr -d '"'`
            rname=${cname//:/_} && rname=${rname//./_} && rname=${rname//\//_}
            rname=$(printf "a-%s" $rname)

            echo "$ttft $cname import"
            fn=`printf "%s__%s.tf" $ttft $rname`

            if [ -f "$fn" ] ; then
                echo "$fn exists already skipping"
                continue
            fi
            printf "resource \"%s\" \"%s\" {" $ttft $rname > $ttft.$rname.tf
            printf "}"  >> $ttft.$rname.tf
            printf "terraform import %s.%s %s" $ttft $rname "$cname" > data/import_$ttft_$rname.sh
            terraform import $ttft.$rname "$cname" | grep Import
            terraform state show $ttft.$rname > t2.txt
            tfa=`printf "%s.%s" $ttft $rname`
            terraform show  -json | jq --arg myt "$tfa" '.values.root_module.resources[] | select(.address==$myt)' > data/$tfa.json
            #echo $awsj | jq . 
            rm $ttft.$rname.tf
            cat t2.txt | perl -pe 's/\x1b.*?[mGKH]//g' > t1.txt
            #	for k in `cat t1.txt`; do
            #		echo $k
            #	done
            file="t1.txt"
            iddo=0
            echo $aws2tfmess > $fn
            while IFS= read line
            do
				skip=0
                # display $line or do something with $line
                t1=`echo "$line"` 
                #echo $t1

                if [[ ${t1} == *"="* ]];then
                    tt1=`echo "$line" | cut -f1 -d'=' | tr -d ' '` 
                    tt2=`echo "$line" | cut -f2- -d'='`
                    
                    if [[ ${tt1} == "arn" ]];then skip=1; fi                
                    if [[ ${tt1} == "id" ]];then skip=1; fi

                    if [[ ${tt1} == "status" ]];then skip=1;fi
                    if [[ ${tt1} == "joined_method" ]];then skip=1;fi
                    if [[ ${tt1} == "joined_timestamp" ]];then skip=1;fi

               
                fi
                if [ "$skip" == "0" ]; then
                    #echo $skip $t1
                    echo "$t1" >> $fn

                fi
                
            done <"$file"

        done

    fi
done

rm -f t*.txt

