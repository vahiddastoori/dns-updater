#!/bin/bash 

TOKEN="123456789:AAXXAAXXASASFSDAFDGHHGERHER" # Telgram BOT Token 
IDs=("2020202") # Telegram ID users | groups | channels for send Message


SUB_DOMAIN=$1
PROXY=${2:-false}

[[ -z "${SUB_DOMAIN}" ]] && echo "🟠 Input Domain NULL" && exit || echo "🟢 Input Domain is : ${SUB_DOMAIN}"

if [[ ! -e /usr/bin/jq ]] ; then 
    echo "Command Jq not found!!!"
    echo "sudo apt install net-tools jq -y"
    exit 0 ;
fi

path=`pwd`
SERVER_IP=`curl -s -4 ifconfig.me` #https://api.ipify.org , http://checkip.amazonaws.com/ , ifconfig.me  Get Public IP

[[ -z "${SERVER_IP}" ]] && echo "🟠 SERVER_IP NULL" && exit || echo "🟢 Server IP is : ${SERVER_IP}"


API_URL="https://api.cloudflare.com/client/v4/zones"  # API ADDRESS
ZONE_ID="XXXXXXXXXXXXXXX" # Cloudflare Zone ID Domain
AUTH_API_EMAIL="example@gmail.com" # Mail account cloudflare
AUTH_API_KEY="gdglkjsgslsjlbgdfjadjkl" #AuthAPI Key account Cloudflare
TIME=`TZ="Asia/Tehran" date +%X_%F` # Time Zone

call_request_get="curl -s -X GET --max-time 2"
call_request_put="curl -s -X PUT --max-time 2"
call_request_post="curl -s -X POST --max-time 2"

SUB_DOMAIN_UPDATE_BODY="{
  \"content\": \"${SERVER_IP}\",
  \"name\": \"${SUB_DOMAIN}\",
  \"proxied\": ${PROXY},
  \"type\": \"A\",
  \"comment\": \"update record with script in ${TIME}\",
  \"tags\": [],
  \"ttl\": 1
}"  

SUB_DOMAIN_CREATE_BODY="{
  \"content\": \"${SERVER_IP}\",
  \"name\": \"${SUB_DOMAIN}\",
  \"proxied\": ${PROXY},
  \"type\": \"A\",
  \"comment\": \"created record with script in ${TIME}\",
  \"tags\": [],
  \"ttl\": 1
}" 

# Check domain is valid or not !
SUB_DOMAIN_IP=`dig +short ${SUB_DOMAIN} @8.8.8.8`
CREAT_SUB=false # this flag for create sub domain is dosn;t exist
UPDATE_SUB=false  # this flag for update ip sub domain is different

if [[ -z ${SUB_DOMAIN_IP} ]]; then
    echo "🟠 Sub Domain ${SUB_DOMAIN} it doesn't exist"
    CREAT_SUB=true 
else
    # Cheack Domain IP equal with Server IP or not !
    if [[ ${SERVER_IP} == ${SUB_DOMAIN_IP} ]]; then 
        echo "🟢 Server IP  ${SERVER_IP:-NULL} (=)Equel SubDomain IP ${SUB_DOMAIN_IP:-NULL}"

    else 
        echo "🔴 Server IP  ${SERVER_IP:-NULL} (!=)Not-Equel SubDomain IP ${SUB_DOMAIN_IP:-Null}"
        UPDATE_SUB=true
    fi
fi


# crontab schdule script 
croncmd="${path}/${0##*/} ${SUB_DOMAIN} 2>&1 | logger -t dns-updater"
cronjob="*/3 * * * * /bin/bash $croncmd"
( crontab -l | grep -v -F "$croncmd" ; echo "$cronjob" ) | crontab - 

#Function Send Message to telegram 
function Send_Msg_Tlg() {
        Message="$@"
        for ID in ${IDs[@]} ; do
                #-o /dev/null
                echo -e "Message: ${Message}\nID: ${ID}"
                curl -s -o /dev/null --write-out "HTTPSTATUS:%{http_code}\n" -X POST 'https://api.telegram.org/bot'${TOKEN}'/sendMessage' \
                --header 'Content-Type: application/json' \
                --data '
                {
                    "chat_id": "'${ID}'",
                    "text": "'"${Message}"'",
                    "parse_mode": "HTML",
                    "disable_web_page_preview": false,
                    "disable_notification": false,
                }
                '
        done
}

# Function Sub Domain created if it doesn't exist (Check flag Create_Domain)
function CreateSubDomain() {

    # store the whole response with the status at the and
    HTTP_RESPONSE=`${call_request_post} --write-out "HTTPSTATUS:%{http_code}" ${API_URL}/${ZONE_ID}/dns_records \
        --header "Content-Type: application/json" \
        --header "X-Auth-Email: ${AUTH_API_EMAIL}" \
        --header "X-Auth-Key: ${AUTH_API_KEY}" \
        --data "${SUB_DOMAIN_CREATE_BODY}"`

    # extract the body
    HTTP_BODY=$(echo $HTTP_RESPONSE | sed -e 's/HTTPSTATUS\:.*//g')

    # extract the status
    HTTP_STATUS=$(echo $HTTP_RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

    # print the body
    echo "$HTTP_BODY"

    # example using the status
    if [ ! $HTTP_STATUS -eq 200  ]; then
    echo "Error Created SubDomain [HTTP status: $HTTP_STATUS]"
    exit 1
    fi
        
}

# Function Change IP if it is different (Check flag )
function UpdateSubDomain() {

    SUB_DOMAIN_ID="$1"

    # store the whole response with the status at the and
    HTTP_RESPONSE=`${call_request_put} --write-out "HTTPSTATUS:%{http_code}" ${API_URL}/${ZONE_ID}/dns_records/${SUB_DOMAIN_ID} \
        --header "Content-Type: application/json" \
        --header "X-Auth-Email: ${AUTH_API_EMAIL}" \
        --header "X-Auth-Key: ${AUTH_API_KEY}" \
        --data "${SUB_DOMAIN_UPDATE_BODY}"`

    # extract the body
    HTTP_BODY=$(echo $HTTP_RESPONSE | sed -e 's/HTTPSTATUS\:.*//g')

    # extract the status
    HTTP_STATUS=$(echo $HTTP_RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

    # print the body
    echo "$HTTP_BODY" | jq '.'

    # example using the status
    if [ ! $HTTP_STATUS -eq 200  ]; then
    echo "Error Update SubDomain [HTTP status: $HTTP_STATUS]"
    exit 1
    fi
        
}

# Function Get Sub Domain ID
function IDSubDomain() {

    # store the whole response with the status at the and
    HTTP_RESPONSE=`${call_request_get} --write-out "HTTPSTATUS:%{http_code}" ${API_URL}/${ZONE_ID}/dns_records \
        --header "Content-Type: application/json" \
        --header "X-Auth-Email: ${AUTH_API_EMAIL}" \
        --header "X-Auth-Key: ${AUTH_API_KEY}"`

    # extract the body
    HTTP_BODY=$(echo $HTTP_RESPONSE | sed -e 's/HTTPSTATUS\:.*//g')

    # extract the status
    HTTP_STATUS=$(echo $HTTP_RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

    # print the body 
    echo "$HTTP_BODY" | jq -r --arg SUB "$SUB_DOMAIN" '.result | map(select(.name == $SUB)) | .[].id'

    # example using the status
    if [ ! $HTTP_STATUS -eq 200  ]; then
    echo "Error ID SubDomain [HTTP status: $HTTP_STATUS]"
    exit 1
    fi

}

# Main 

if ${CREAT_SUB} ; then

    Resp=$(CreateSubDomain)
    echo $Resp

    MSG="<b>Antinone Monitoring🤖🗣</b>\n\n
    <b>🔔✳️ SUB Domain Created</b>\n\n
    📌🗃Created record sub domain ${SUB_DOMAIN} with IP ${SERVER_IP}\n
    ⏰ ${TIME}"
    Send_Msg_Tlg $MSG

elif ${UPDATE_SUB} ; then
     
    SubID=$(IDSubDomain)
    echo "Sub ID ===>> $SubID"
    UpdateSubDomain ${SubID}
    echo "Action SUB Update : $?"

    MSG="<b>Antinone Monitoring🤖🗣</b>\n\n
    <b>🔔☢️ SUB Domain Updated</b>\n\n
    📌♻️Update record sub domain ${SUB_DOMAIN:-NULL} with IP ${SUB_DOMAIN_IP:-NULL} 🔜 ${SERVER_IP:-NULL}\n
    ⏰ ${TIME}"
    Send_Msg_Tlg $MSG

fi
