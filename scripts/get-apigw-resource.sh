#!/bin/bash
mysub=`echo $AWS2TF_ACCOUNT`
myreg=`echo $AWS2TF_REGION`
if [ "$1" == "" ]; then
    echo "must pass rest api id exiting ..."
    exit
fi
if [ "$2" != "" ]; then
    cmd[0]="$AWS apigateway get-resource --rest-api-id $1 --resource-id $2"
else
    cmd[0]="$AWS apigateway get-resources --rest-api-id $1"
    pref[0]="items"
fi

tft[0]="aws_api_gateway_resource"
getp=0
for c in `seq 0 0`; do
 
    cm=${cmd[$c]}
    ttft=${tft[(${c})]}
    echo $cm
    awsout=`eval $cm 2> /dev/null`
    if [ "$awsout" == "" ];then
        echo "$cm : You don't have access for this resource"
        exit
    fi
    count=1
    if [ "$2" != "" ]; then
        count=`echo $awsout | jq ".${pref[(${c})]} | length"`       
    fi
    echo "Count= $count"
    if [ "$count" -gt "0" ]; then
        count=`expr $count - 1`
        for i in `seq 0 $count`; do
            echo $i
            echo $awsout | jq .
    
            if [ "$2" != "" ]; then
                cname=`echo $awsout | jq -r ".id"`             
            else
                cname=`echo $awsout | jq -r ".${pref[(${c})]}[0].id"`
                #cname=`echo $awsout | jq -r ".id"`     
            fi

            fn=`printf "%s__%s__%s.tf" $ttft $1 $cname`
            if [ -f "$fn" ] ; then
                    echo "$fn exists already skipping"
                    continue
            fi

                echo "$ttft $1 $cname"
                printf "resource \"%s\" \"%s__%s\" {}" $ttft $1 $cname > $fn

                terraform import $ttft.$1__$cname $1/$cname | grep Import
                terraform state show $ttft.$1__$cname > t2.txt
                rm -f $fn
                cat t2.txt | perl -pe 's/\x1b.*?[mGKH]//g' > t1.txt

                file="t1.txt"

                echo $aws2tfmess > $fn
                while IFS= read line
                do
                    skip=0
                    # display $line or do something with $line
                    t1=`echo "$line"`
                    if [[ ${t1} == *"="* ]];then
                        tt1=`echo "$line" | cut -f1 -d'=' | tr -d ' '`
                        tt2=`echo "$line" | cut -f2- -d'='`

                        if [[ ${tt1} == "aws:"* ]]; then
                                tt2=`echo $tt2 | tr -d '"'`
                                t1=`printf "\"%s\" = \"%s\"" $tt1 $tt2`
                        fi

                        if [[ ${tt1} == "arn" ]];then skip=1; fi
                        if [[ ${tt1} == "id" ]];then skip=1; fi
                        if [[ ${tt1} == "created_date" ]];then skip=1; fi
                        if [[ ${tt1} == "path" ]];then skip=1; fi
                        #    tt2=`echo $tt2 | tr -d '"'`
                        #    if [[ ${tt2} == "[]" ]];then
                        #        skip=1; 
                        #    fi
                        #fi
                    fi
                    if [ "$skip" == "0" ]; then
                        #echo $skip $t1
                        echo "$t1" >> $fn
                    fi
                    
                done <"$file"   # done while
                # depoyments - no import support
                #../../scripts/752-get-apigw-method.sh $1 $cname
        done # done for i
    fi
done


rm -f t*.txt

