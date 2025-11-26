; cPanel %cpversion%
; Zone file for %domain%
; Template: STANDARD (Dedicated IP - Original cPanel Style)
; Description: Domains on a dedicated IP with explicit FTP binding
;
; Key Difference from Shared: FTP has its own A record (%ftpip%)
; Use when: You have a dedicated IP and may run FTP on a separate interface

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
%domain%. %nsttl%  IN NS %nameserver3%.
%domain%. %nsttl%  IN NS %nameserver4%.

; --- Glue Records ---
%nameserverentry%.  IN A %nameservera%
%nameserverentry2%. IN A %nameservera2%
%nameserverentry3%. IN A %nameservera3%
%nameserverentry4%. IN A %nameservera4%

; ----------------------------------------------------------------------
; CORE INFRASTRUCTURE
; ----------------------------------------------------------------------
%domain%. IN A    %ip%
%domain%. IN AAAA %ipv6%
ipv6      IN AAAA %ipv6%

; ----------------------------------------------------------------------
; EMAIL (Explicit A record, not CNAME - RFC Compliant)
; ----------------------------------------------------------------------
%domain%. IN MX 0 mail.%domain%.
mail      IN A    %ip%
mail      IN AAAA %ipv6%

; ----------------------------------------------------------------------
; WEB & FTP ALIASES
; ----------------------------------------------------------------------
; www follows the domain via CNAME
www       IN CNAME %domain%.

; FTP has EXPLICIT A record - this is the key difference from shared hosting
; This allows FTP to run on a separate IP/interface if needed
ftp       IN A    %ftpip%
ftp       IN AAAA %ipv6%

; ----------------------------------------------------------------------
; EMAIL AUTHENTICATION (Modern Requirements)
; ----------------------------------------------------------------------
; SPF: Strict mode for dedicated IPs (you own the reputation)
%domain%. IN TXT "v=spf1 a mx ip4:%ip% ip6:%ipv6% -all"

; DMARC: Quarantine policy (production ready)
_dmarc    IN TXT "v=DMARC1; p=quarantine; pct=100; fo=1; rua=mailto:dmarc@%domain%"

; MTA-STS: Enforce TLS for email
_mta-sts  IN TXT "v=STSv1; id=%serial%;"
mta-sts   IN CNAME %domain%.
_smtp._tls IN TXT "v=TLSRPTv1; rua=mailto:tls-rpt@%domain%"

; DKIM placeholder
default._domainkey IN TXT "v=DKIM1; k=rsa; p=INSERT_PUBLIC_KEY_HERE"

; ----------------------------------------------------------------------
; SECURITY
; ----------------------------------------------------------------------
; CAA: Certificate Authority Authorization
%domain%. IN CAA 0 issue "letsencrypt.org"
%domain%. IN CAA 0 issuewild "letsencrypt.org"
%domain%. IN CAA 0 iodef "mailto:%rpemail%"

; HTTPS/SVCB: HTTP/3 support
%domain%. IN HTTPS 1 . alpn="h3,h2" ipv4hint=%ip% ipv6hint=%ipv6%

; ----------------------------------------------------------------------
; SERVICE DISCOVERY
; ----------------------------------------------------------------------
_imaps._tcp     IN SRV 0 5 993 mail.%domain%.
_submission._tcp IN SRV 0 5 587 mail.%domain%.

autoconfig      IN CNAME %domain%.
autodiscover    IN CNAME %domain%.
