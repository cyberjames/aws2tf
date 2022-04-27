#!/bin/bash
mysub=`echo $AWS2TF_ACCOUNT`
myreg=`echo $AWS2TF_REGION`
#echo "globals = $mysub $myreg"
if [ "$1" != "" ]; then
    cmd[0]="$AWS iam list-role-policies --role-name $1"
else
    exit
fi
c=0
cm=${cmd[$c]}

pref[0]="PolicyNames"
tft[0]="aws_iam_role_policy"

for c in `seq 0 0`; do
    
    cm=${cmd[$c]}
    ttft=${tft[(${c})]}
    #echo $cm
    awsout=`eval $cm 2> /dev/null`
    if [ "$awsout" == "" ];then
        echo "$cm : You don't have access for this resource"
        exit
    fi
    #echo "awsout $awsout"

    count=`echo $awsout | jq ".${pref[(${c})]} | length"`
    if [ "$count" -gt "0" ]; then
        count=`expr $count - 1`
        #echo $count
        for i in `seq 0 $count`; do
            pname=`echo $awsout | jq ".${pref[(${c})]}[(${i})]" | tr -d '"'`     
            awsout2=`$AWS iam get-role-policy --role-name ${1} --policy-name ${pname}`
            cname=`echo $awsout2 | jq ".PolicyName" | tr -d '"'`
            ocname=`echo $cname`
            cname=${cname//./_}
            cname=`printf "%s__%s" $1 $cname`
            echo "$ttft $cname"
            
            printf "resource \"%s\" \"%s\" {" $ttft $cname > $ttft.$cname.tf
            printf "}" >> $ttft.$cname.tf
            terraform import $ttft.$cname $1:$pname | grep Import
            terraform state show $ttft.$cname > t2.txt
            rm $ttft.$cname.tf
            cat t2.txt | perl -pe 's/\x1b.*?[mGKH]//g' > t1.txt
            #	for k in `cat t1.txt`; do
            #		echo $k
            #	done
            file="t1.txt"
            fn=`printf "%s__%s.tf" $ttft $cname`
            echo $aws2tfmess > $fn
            while IFS= read line
            do
                skip=0
                # display $line or do something with $line
                t1=`echo "$line"`
                if [[ ${t1} == *"="* ]];then
                    tt1=`echo "$line" | cut -f1 -d'=' | tr -d ' '`
                    tt2=`echo "$line" | cut -f2- -d'='`
                    if [[ ${tt1} == *":"* ]];then
                        tt1=`echo $tt1 | tr -d '"'`
                        t1=`printf "\"%s\"=%s" $tt1 $tt2`
                    fi
                    if [[ ${tt1} == "arn" ]];then skip=1; fi
                    if [[ ${tt1} == "id" ]];then skip=1; fi
                    if [[ ${tt1} == "role_arn" ]];then skip=1;fi
                    if [[ ${tt1} == "role" ]];then 
                        tsel=`echo $tt2 |  tr -d '"'`
                        t1=`printf "%s = aws_iam_role.%s.id" $tt1 $tsel`
                        skip=0;
                    fi
                    if [[ ${tt1} == "owner_id" ]];then skip=1;fi
                    if [[ ${tt1} == "association_id" ]];then skip=1;fi
                    if [[ ${tt1} == "unique_id" ]];then skip=1;fi
                    if [[ ${tt1} == "create_date" ]];then skip=1;fi
                    #if [[ ${tt1} == "public_ip" ]];then skip=1;fi
                    if [[ ${tt1} == "private_ip" ]];then skip=1;fi
                    if [[ ${tt1} == "accept_status" ]];then skip=1;fi

                    if [[ ${tt1} == "Resource" ]];then
                            tt2=`echo $tt2 | tr -d '"'`
                            if [[ "$tt2" != *"*"* ]];then
                               
                                
                                if [[ "$tt2" == *"${mysub}:role/"* ]];then
                                    echo "in role/ match"
                                    if [[ "$tt2" != *"${mysub}:role/aws-service-role"* ]];then
                                        
                                        rarn=`echo $tt2 | tr -d '"'` 
                                        trole=`echo "$tt2" | cut -f2- -d'/' | tr -d '"'`                       
                                        t1=`printf "%s = aws_iam_role.%s.arn" $tt1 $trole`
                                    fi
                                elif [[ "$tt2" == "arn:aws:sns:${myreg}:${mysub}:"* ]];then
                                  
                                    rsns=`echo $tt2 | tr -d '"'` 
                                   
                                    trole=${rsns//:/_} && trole=${trole//./_} && trole=${trole//\//_} && trole=${trole/${mysub}/}                    
                                
                                    t1=`printf "%s = aws_sns_topic.%s.arn" $tt1 $trole`
                                elif [[ "$tt2" == *"arn:aws:dynamodb:${myreg}:${mysub}:table/"* ]];then
                                    
                                    rdyn=`echo $tt2 | rev | cut -f1 -d'/' | rev`
                                                      
                                    t1=`printf "%s = aws_dynamodb_table.%s.arn" $tt1 $rdyn`

                                else   # check tt2 for $
                                    tt2=${tt2//$/&} 
                                    if [[ "$tt2" != "[" ]];then
                                        t1=`printf "%s=\"%s\"" $tt1 "$tt2"`
                                    else
                                       t1=`printf "%s=%s" $tt1 "$tt2"` 
                                    fi
                                fi
                            fi
                    fi
                fi
                if [ "$skip" == "0" ]; then
                    #echo $skip $t1
                    echo "$t1" >> $fn
                fi
                
            done <"$file"   # done while
            
        done # done for i
    fi
done


rm -f t*.txt

