#!/bin/bash
cmd[0]="$AWS rds describe-db-instances"
pref[0]="DBInstances"
tft[0]="aws_db_instance"


for c in `seq 0 0`; do
   
    cm=${cmd[$c]}
	ttft=${tft[(${c})]}
	#echo $cm
    awsout=`eval $cm 2> /dev/null`
    if [ "$awsout" == "" ];then
        echo "$cm : You don't have access for this resource"
        exit
    fi
    count=`echo $awsout | jq ".${pref[(${c})]} | length"`
    if [ "$count" -gt "0" ]; then
        count=`expr $count - 1`
        for i in `seq 0 $count`; do
            #echo $i
            cname=`echo $awsout | jq ".${pref[(${c})]}[(${i})].DBInstanceIdentifier" | tr -d '"'`
            echo "$ttft $cname"
            printf "resource \"%s\" \"%s\" {" $ttft $cname > $ttft.$cname.tf
            printf "}" >> $ttft.$cname.tf
            terraform import $ttft.$cname "$cname" | grep Import
            terraform state show $ttft.$cname > t2.txt
            rm $ttft.$cname.tf
            cat t2.txt | perl -pe 's/\x1b.*?[mGKH]//g' > t1.txt
            #	for k in `cat t1.txt`; do
            #		echo $k
            #	done
            file="t1.txt"
            fn=`printf "%s__%s.tf" $ttft $cname`
            echo $aws2tfmess > $fn
            sgs=()
            while IFS= read line
            do
				skip=0
                # display $line or do something with $line
                t1=`echo "$line"` 
                if [[ ${t1} == *"="* ]];then
                    tt1=`echo "$line" | cut -f1 -d'=' | tr -d ' '` 
                    tt2=`echo "$line" | cut -f2- -d'='`
                    if [[ ${tt1} == "arn" ]];then skip=1; fi                
                    if [[ ${tt1} == "id" ]];then skip=1; fi          
                    if [[ ${tt1} == "role_arn" ]];then skip=1;fi
                    if [[ ${tt1} == "owner_id" ]];then skip=1;fi
                    if [[ ${tt1} == "availability_zone" ]];then skip=1;fi
                    if [[ ${tt1} == "endpoint" ]];then skip=1;fi
                    if [[ ${tt1} == "replicas" ]];then 
                        tt2=`echo $tt2 | tr -d '"'` 
                        skip=1
                        while [ "$t1" != "]" ] && [ "$tt2" != "[]" ] ;do
                            read line
                            t1=`echo "$line"`
                            #echo $t1
                        done
                    fi
                    if [[ ${tt1} == "address" ]];then skip=1;fi
                    if [[ ${tt1} == "hosted_zone_id" ]];then skip=1;fi
                    if [[ ${tt1} == "status" ]];then skip=1;fi
                    if [[ ${tt1} == "resource_id" ]];then skip=1;fi
                    if [[ ${tt1} == "latest_restorable_time" ]];then skip=1;fi
                    if [[ ${tt1} == "engine_version_actual" ]];then skip=1;fi

                    if [[ ${tt1} == "monitoring_role_arn" ]]; then
                        tarn=`echo $tt2 | tr -d '"'`
                        tanam=$(echo $tarn | rev | cut -f1 -d'/' | rev)
                        tlarn=${tarn//:/_} && tlarn=${tlarn//./_} && tlarn=${tlarn//\//_}
                        t1=`printf "%s = aws_iam_role.%s.arn" $tt1 $tanam`
                    fi 


                    if [[ ${tt1} == "kms_key_id" ]];then 
                        kid=`echo $tt2 | rev | cut -f1 -d'/' | rev | tr -d '"'`                            
                        kmsarn=$(echo $tt2 | tr -d '"')
                        km=`$AWS kms describe-key --key-id $kid --query KeyMetadata.KeyManager | jq -r '.' 2>/dev/null`
                            #echo $t1
                        if [[ $km == "AWS" ]];then
                            t1=`printf "%s = data.aws_kms_key.k_%s.arn" $tt1 $kid`
                        else
                            t1=`printf "%s = aws_kms_key.k_%s.arn" $tt1 $kid`
                        fi 
                                           
                    fi

                    if [[ ${tt1} == "performance_insights_kms_key_id" ]];then 
                        pkid=`echo $tt2 | rev | cut -f1 -d'/' | rev | tr -d '"'`                            
                        pkmsarn=$(echo $tt2 | tr -d '"')
                        km=`$AWS kms describe-key --key-id $pkid --query KeyMetadata.KeyManager | jq -r '.' 2>/dev/null`
                        if [[ $km == "AWS" ]];then
                            t1=`printf "%s = data.aws_kms_key.k_%s.arn" $tt1 $pkid`
                        else
                            t1=`printf "%s = aws_kms_key.k_%s.arn" $tt1 $pkid`
                        fi 
                 
                    fi
              
                else
                    if [[ "$t1" == *"sg-"* ]]; then
                        t1=`echo $t1 | tr -d '"|,'`
                        sgs+=`printf "\"%s\" " $t1`
                        t1=`printf "aws_security_group.%s.id," $t1`
                    fi               
                
                fi



                if [ "$skip" == "0" ]; then
                    #echo $skip $t1
                    echo "$t1" >> $fn
                fi
                
            done <"$file"


            for sg in ${sgs[@]}; do
                #echo "therole=$therole"
                sg1=`echo $sg | tr -d '"'`
                echo "calling for $sg1"
                if [ "$sg1" != "" ]; then
                    ../../scripts/110-get-security-group.sh $sg1
                fi
            done 

            if [ "$tarn" != "" ]; then
                echo "getting role $tarn"
                ../../scripts/050-get-iam-roles.sh $tarn
            fi           

            if [ "$kmsarn" != "" ]; then
                echo "getting key $kid"
                ../../scripts/080-get-kms-key.sh $kid
            fi

            if [ "$pkmsarn" != "" ]; then
                echo "getting key $pkid"
                ../../scripts/080-get-kms-key.sh $pkid
            fi

            
        done
    fi
done

rm -f t*.txt

