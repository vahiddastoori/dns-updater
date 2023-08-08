#!/bin/bash 

TOKEN="123456789:AAXXAAXXASASFSDAFDGHHGERHER" # Telgram BOT Token 
IDs=("2020202") # Telegram ID users | groups | chanels for send Massage

SUB_DOMAIN="sub.example.com"
JQ_SUB_ID="jq -r --arg SUB_D "$SUB_DOMAIN" '.result |  map(select(.name  == "$SUB_D")) | .[].id'"
PUBLIC_IP=`curl -s ifconfig.me` #Get PUBLIC IP
BASE_URL="https://api.cloudflare.com/client/v4/zones"  # API ADDRESS 
ZONE_ID="XXXXXXXXXXXXXXX" # Cloudflare Zone ID Domain
AUTH_API_EMAIL="example@gmail.com" # Mail account cloudflare
AUTH_API_KEY="gdglkjsgslsjlbgdfjadjkl" #AuthAPI Key account Cloudflare
TIME=`TZ="Asia/Tehran" date +%X_%F` # Time Zone

call_request_get="curl -s -X GET"
call_request_put="curl -s -X PUT"

HEADER="-H 'Content-Type: application/json'"

SUB_DOMAIN_UPDATE_BODY="{
  \"content\": \"${PUBLIC_IP}\",
  \"name\": \"${SUB_DOMAIN}\",
  \"proxied\": false,
  \"type\": \"A\",
  \"comment\": \"update record with script in ${TIME}\",
  \"tags\": [],
  \"ttl\": 1
}"

if [[ ! -e /usr/bin/jq ]] ; then 
    echo "Command Jq not found!!!"
    echo "sudo apt install net-tools jq -y"
    echo "crontab -e #### */2 * * * * /bin/bash /home/ubuntu/dns-update.sh"
    echo "update ENV SUB_DOMAIN"
    exit 0 ;
fi

function Send_Msg_Tlg() {
        Message="$1"
        for ID in ${IDs[@]} ; do
                curl -s -o /dev/null -X GET 'https://api.telegram.org/bot'${TOKEN}'/sendMessage?chat_id='${ID}'&text='"${Message}"'&parse_mode=HTML'
        done
}

#echo $HEADER 
SUB_DOMAIN_ID=$(${call_request_get} ${HEADER} -H "X-Auth-Email: ${AUTH_API_EMAIL}" -H "X-Auth-Key: ${AUTH_API_KEY}"  ${BASE_URL}/${ZONE_ID}/dns_records | jq -r --arg SUB "$SUB_DOMAIN" '.result | map(select(.name == $SUB)) | .[].id' )

SUB_DOMAIN_IP=$(${call_request_get} ${HEADER} -H "X-Auth-Email: ${AUTH_API_EMAIL}" -H "X-Auth-Key: ${AUTH_API_KEY}"  ${BASE_URL}/${ZONE_ID}/dns_records/${SUB_DOMAIN_ID} | jq -r '.result.content' )

echo "${SUB_DOMAIN_ID}"

echo "Server IP is : ${PUBLIC_IP}"

echo "Domain IP is : ${SUB_DOMAIN_IP}"

if [[ "${PUBLIC_IP}" == "${SUB_DOMAIN_IP}" ]]; then

        echo "Domain IP is equal Server IP"

else
        echo "Domain IP is not equal Server IP"
        echo "Update record sub domain ${SUB_DOMAIN}"
        SUB_DOMAIN_UPDATE_RECORD=$(${call_request_put} ${HEADER} -H "X-Auth-Email: ${AUTH_API_EMAIL}" -H "X-Auth-Key: ${AUTH_API_KEY}" -d "${SUB_DOMAIN_UPDATE_BODY}"  ${BASE_URL}/${ZONE_ID}/dns_records/${SUB_DOMAIN_ID})
        echo "${SUB_DOMAIN_UPDATE_RECORD}"
        Send_Msg_Tlg "🔔🔄Update record sub domain ${SUB_DOMAIN} with IP ${SUB_DOMAIN_IP} 🔜 ${PUBLIC_IP}%0A🕰 📅 ${TIME}"
fi
