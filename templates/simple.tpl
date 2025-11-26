; cPanel %cpversion%
; Zone file for %domain%
; Template: SIMPLE (Modernized Minimum Viable)
; Description: Basic DNS with modern email deliverability requirements

$TTL %ttl%
@      %nsttl%  IN      SOA     %nameserver%. %rpemail%. (
        %serial%    ; serial, todays date+increment
        3600        ; refresh, seconds
        1800        ; retry, seconds
        1209600     ; expire, seconds
        86400 )     ; minimum, seconds

; ----------------------------------------------------------------------
; NAME SERVERS
; ----------------------------------------------------------------------
%domain%. %nsttl%  IN NS %nameserver%.
%domain%. %nsttl%  IN NS %nameserver2%.

; --- Glue Records (if local NS) ---
%nameserverentry%.  IN A %nameservera%
%nameserverentry2%. IN A %nameservera2%

; ----------------------------------------------------------------------
; CORE WEB RECORDS
; ----------------------------------------------------------------------
%domain%. IN A    %ip%
%domain%. IN AAAA %ipv6%
www       IN CNAME %domain%.

; ----------------------------------------------------------------------
; EMAIL ESSENTIALS (Deliverability)
; Without these, Gmail/Yahoo will reject your mail
; ----------------------------------------------------------------------
; Directing mail traffic (MX should point to A record, not CNAME per RFC 2181)
%domain%. IN MX 0 mail.%domain%.
mail      IN A    %ip%

; SPF: Authorises this server to send email for the domain
; ~all (soft fail) is safer for initial setups than -all (hard fail)
%domain%. IN TXT "v=spf1 a mx ip4:%ip% ~all"

; DMARC: Tells receivers what to do if SPF/DKIM fails
; p=none is monitoring mode - upgrade to quarantine/reject when ready
_dmarc    IN TXT "v=DMARC1; p=none; sp=none; fo=1; ri=3600"

; ----------------------------------------------------------------------
; SECURITY & CERTIFICATE AUTHORITY
; ----------------------------------------------------------------------
; CAA: Only Let's Encrypt (or your CA of choice) can issue certs
%domain%. IN CAA 0 issue "letsencrypt.org"
%domain%. IN CAA 0 issuewild "letsencrypt.org"
%domain%. IN CAA 0 iodef "mailto:%rpemail%"
