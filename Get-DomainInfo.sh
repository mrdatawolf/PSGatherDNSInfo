
#!/bin/bash

# Usage: ./get-domain-info.sh domain1.com domain2.com ...
# Optional: Set EXPORT_CSV=output.csv to export results

EXPORT_CSV=""
VERBOSE=false

# Parse arguments
for arg in "$@"; do
    if [[ "$arg" == "--csv="* ]]; then
        EXPORT_CSV="${arg#*=}"
    elif [[ "$arg" == "--verbose" ]]; then
        VERBOSE=true
    else
        DOMAINS+=("$arg")
    fi
done

function log() {
    if $VERBOSE; then
        echo "$1"
    fi
}

function get_registrar() {
    local domain=$1
    whois "$domain" 2>/dev/null | grep -iE "Registrar:|Sponsoring Registrar:|Registrar Name:" | head -n 1 | awk -F: '{print $2}' | xargs
}

function get_dns_servers() {
    local domain=$1
    dig NS "$domain" +short | awk -F. '{print $(NF-2)"."$(NF-1)"."$(NF)}' | sort -u
}

function get_a_record() {
    local domain=$1
    dig A "$domain" +short
}

function get_mx_records() {
    local domain=$1
    dig MX "$domain" +short | awk '{print $2}' | sed 's/\.$//'
}

function get_spf_record() {
    local domain=$1
    dig TXT "$domain" +short | grep -o '"[^"]*"' | grep "v=spf1" | tr -d '"'
}

function get_dkim_info() {
    local domain=$1
    local selectors=("default" "selector1" "selector2")
    for selector in "${selectors[@]}"; do
        local dkim_domain="${selector}._domainkey.${domain}"
        local record=$(dig TXT "$dkim_domain" +short | grep -o '"[^"]*"' | grep "v=DKIM1" | tr -d '"')
        if [[ -n "$record" ]]; then
            echo "$selector: $record"
        else
            echo "$selector: DKIM record not found"
        fi
    done
}

function get_dmarc_info() {
    local domain=$1
    dig TXT "_dmarc.$domain" +short | grep -o '"[^"]*"' | grep "v=DMARC1" | tr -d '"'
}

# Output header if exporting
if [[ -n "$EXPORT_CSV" ]]; then
    echo "Domain,Registrar,DNS_Servers,MX_Records,A_Record,SPF,DKIM,DMARC" > "$EXPORT_CSV"
fi

for domain in "${DOMAINS[@]}"; do
    log "Processing $domain..."

    registrar=$(get_registrar "$domain")
    dns_servers=$(get_dns_servers "$domain" | paste -sd "," -)
    mx_records=$(get_mx_records "$domain" | paste -sd "," -)
    a_record=$(get_a_record "$domain" | paste -sd "," -)
    spf=$(get_spf_record "$domain")
    dkim=$(get_dkim_info "$domain" | paste -sd ";" -)
    dmarc=$(get_dmarc_info "$domain")

    echo -e "\nDomain:     $domain"
    echo "Registrar:  $registrar"
    echo "DNS:        $dns_servers"
    echo "MX:         $mx_records"
    echo "A Record:   $a_record"
    echo "SPF:        $spf"
    echo "DKIM:       $dkim"
    echo "DMARC:      $dmarc"

    if [[ -n "$EXPORT_CSV" ]]; then
        echo "\"$domain\",\"$registrar\",\"$dns_servers\",\"$mx_records\",\"$a_record\",\"$spf\",\"$dkim\",\"$dmarc\"" >> "$EXPORT_CSV"
    fi
done
