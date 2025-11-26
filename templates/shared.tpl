; cPanel %cpversion%
; Zone file for %domain%
; Template: SHARED / VIRTUAL HOSTING (standardvirtualftp)
; Description: Tenanted hosting on shared IP - relies on CNAMEs over A records
;
; IMPORTANT: This template is for domains that do NOT own their IP reputation.
; The PTR record points to the hosting provider, not your domain.

$TTL %ttl%
@      %nsttl%  IN      SOA     %nameserver%. %rpemail%. (
        %serial%    ; Serial
        3600        ; Refresh
        1800        ; Retry
        1209600     ; Expire
        86400 )     ; Minimum TTL

; ----------------------------------------------------------------------
; 1. CORE INFRASTRUCTURE (The Tenant Model)
; ----------------------------------------------------------------------
; The Root must be an A record (RFC requirement), but we acknowledge
; this IP is likely 'floating' or shared across many domains.
%domain%.       IN A        %ip%
%domain%.       IN AAAA     %ipv6%

; ----------------------------------------------------------------------
; 2. AUTHORITY & DELEGATION
; ----------------------------------------------------------------------
%domain%.       IN NS       %nameserver%.
%domain%.       IN NS       %nameserver2%.

; ----------------------------------------------------------------------
; 3. VIRTUAL FTP & WEB ROUTING (The Critical Difference)
; ----------------------------------------------------------------------
; In shared hosting, services must follow the domain via CNAME.
; If the host migrates your account, CNAMEs automatically follow.
; Using hardcoded A records here would break on migration.

ftp             IN CNAME    %domain%.
www             IN CNAME    %domain%.

; HTTPS / SVCB (RFC 9460) - Accelerates HTTP/3 & TLS 1.3 handshakes
%domain%.       IN HTTPS    1 . alpn="h3,h2" ipv4hint=%ip% ipv6hint=%ipv6%

; ----------------------------------------------------------------------
; 4. EMAIL (Relay Dependent)
; ----------------------------------------------------------------------
; Shared IPs often have poor reputation. The host may route outbound
; mail through a distinct gateway to avoid blocklists.

; MX points to the domain (standard shared setup)
%domain%.       IN MX 0     %domain%.

; In shared hosting, mail is often aliased to follow IP rotation
mail            IN CNAME    %domain%.

; ----------------------------------------------------------------------
; 5. SECURITY & REPUTATION (Defensive Mode)
; ----------------------------------------------------------------------
; SPF: MUST include the host's generic SPF via 'include:'
; Shared hosts often route outbound mail via different IPs
%domain%.       IN TXT      "v=spf1 a mx include:%nameserver% -all"

; DMARC: Essential for shared IPs to distinguish your traffic from neighbours
_dmarc          IN TXT      "v=DMARC1; p=quarantine; rua=mailto:dmarc@%domain%"

; MTA-STS: Even on shared hosting, you can enforce TLS
_mta-sts        IN TXT      "v=STSv1; id=%serial%;"
mta-sts         IN CNAME    %domain%.
_smtp._tls      IN TXT      "v=TLSRPTv1; rua=mailto:tls-rpt@%domain%"

; CAA: Still mandatory for certificate issuance control
%domain%.       IN CAA      0 issue "letsencrypt.org"
%domain%.       IN CAA      0 issuewild ";"

; ----------------------------------------------------------------------
; 6. SERVICE DISCOVERY (Client Auto-Config)
; ----------------------------------------------------------------------
; Crucial in shared environments so users don't need to know the
; confusing hostname of the shared server (e.g., 'server45.hostco.com')

cpcontacts      IN CNAME    %domain%.
cpcalendars     IN CNAME    %domain%.

_imaps._tcp     IN SRV      0 5 993 %domain%.
_submission._tcp IN SRV     0 5 587 %domain%.
_autodiscover._tcp IN SRV   0 1 443 %domain%.

; ----------------------------------------------------------------------
; NOTE ON EXCLUDED RECORDS
; ----------------------------------------------------------------------
; SSHFP and IPSECKEY are NOT included in this template.
; Reason: The host key belongs to the provider, not the tenant.
; If the provider migrates your account, SSH fingerprints change,
; causing "MITM ATTACK" warnings that lock you out.
