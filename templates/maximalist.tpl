; cPanel %cpversion%
; Zone file for %domain%
; Template: MAXIMALIST / DEDICATED IP (Comprehensive RFC-Compliant 2025)
; Description: Full DNS capabilities for dedicated infrastructure
;
; This template includes every valid modern record type while strictly
; adhering to OWASP security guidelines (no HINFO, RP, or TXT version leaks).

$TTL %ttl%
@      %nsttl%  IN      SOA     %nameserver%. %rpemail%. (
        %serial%    ; Serial (YYYYMMDDNN)
        3600        ; Refresh
        1800        ; Retry
        1209600     ; Expire
        86400 )     ; Minimum TTL

; ======================================================================
; 1. CORE INFRASTRUCTURE (IPv4 & IPv6)
; ======================================================================
%domain%.       IN A        %ip%
%domain%.       IN AAAA     %ipv6%
mail            IN A        %ip%
mail            IN AAAA     %ipv6%
ns1             IN A        %nameservera%
ns2             IN A        %nameservera2%

; ======================================================================
; 2. AUTHORITY & DELEGATION
; ======================================================================
%domain%.       IN NS       %nameserver%.
%domain%.       IN NS       %nameserver2%.
%domain%.       IN NS       %nameserver3%.
%domain%.       IN NS       %nameserver4%.

; CSYNC: Child-to-Parent Synchronization (RFC 7477)
; Automates updating NS/A/AAAA glue records in the parent zone.
; Format: SOA Serial Flags(1=immediate, 2=soaminimum) TypeBitMap
%domain%.       IN CSYNC    %serial% 3 A AAAA NS

; ======================================================================
; 3. MODERN ROUTING & SERVICE BINDING (RFC 9460)
; ======================================================================
; HTTPS / SVCB: Replaces CNAME+ALPN. Accelerates HTTP/3 & TLS 1.3.
; Format: Priority Target Params(alpn, ipv4hint, ipv6hint, ech)
%domain%.       IN HTTPS    1 . alpn="h3,h2" ipv4hint=%ip% ipv6hint=%ipv6%
www             IN HTTPS    1 . alpn="h3,h2" ipv4hint=%ip% ipv6hint=%ipv6%

; NAPTR (RFC 2915): Regex-based routing (Crucial for SIP/VoIP)
; Order Pref Flags Service Regexp Replacement
%domain%.       IN NAPTR    100 10 "s" "SIP+D2U" "!^.*$!sip:info@%domain%!" .

; URI (RFC 7553): Mapping hostnames directly to URIs
_ftp._tcp       IN URI      10 1 "ftp://ftp.%domain%/"

; ======================================================================
; 4. CRYPTOGRAPHIC IDENTITY (DANE, SSH, PGP)
; ======================================================================
; CAA (RFC 6844): Certificate Authority Authorization (Security Mandatory)
%domain%.       IN CAA      0 issue "letsencrypt.org"
%domain%.       IN CAA      0 issue "digicert.com"
%domain%.       IN CAA      0 issuewild ";"
%domain%.       IN CAA      0 iodef "mailto:security@%domain%"

; TLSA (RFC 6698): DANE - Verifies TLS certs via DNS
; Usage(3=DANE-EE) Selector(1=SPKI) Matching(1=SHA-256) Hash
_443._tcp       IN TLSA     3 1 1 %tls_fingerprint_hash%

; SSHFP (RFC 4255): SSH Fingerprints (Prevents "Trust this host?" warnings)
; Algorithm(4=Ed25519) Type(2=SHA-256) Fingerprint
%domain%.       IN SSHFP    4 2 %ssh_public_key_fingerprint%

; OPENPGPKEY (RFC 7929): Distributes PGP Keys for email encryption
; Subdomain is SHA256 truncated hash of 'local-part' (e.g. 'jonathan')
%user_hash%._openpgpkey IN OPENPGPKEY %base64_pgp_key%

; SMIMEA (RFC 8162): S/MIME Certificate Association
_smimea._tcp    IN SMIMEA   3 0 1 %smime_cert_hash%

; IPSECKEY (RFC 4025): IPsec Keying Material
; Precedence GatewayType(1=IP4) Algorithm(2=RSA) Gateway Key
ipsec           IN IPSECKEY 10 1 2 %ip% %base64_ipsec_key%

; ======================================================================
; 5. SERVICE DISCOVERY (SRV Records)
; ======================================================================
; _service._proto.name TTL Class SRV Priority Weight Port Target

; Email Services
_submission._tcp IN SRV     0 5 587 mail.%domain%.
_imap._tcp       IN SRV     0 5 143 mail.%domain%.
_imaps._tcp      IN SRV     0 5 993 mail.%domain%.
_pop3s._tcp      IN SRV     0 5 995 mail.%domain%.

; Calendar & Contacts (CardDAV/CalDAV)
_carddavs._tcp   IN SRV     0 1 2080 %domain%.
_caldavs._tcp    IN SRV     0 1 2080 %domain%.

; Client Auto-Discovery
autoconfig       IN CNAME   %domain%.
autodiscover     IN CNAME   %domain%.
_autodiscover._tcp IN SRV   0 1 443 %domain%.

; Matrix/Federated Chat
_matrix._tcp     IN SRV     10 0 8448 matrix.%domain%.

; XMPP/Jabber
_xmpp-client._tcp IN SRV    5 0 5222 xmpp.%domain%.
_xmpp-server._tcp IN SRV    5 0 5269 xmpp.%domain%.

; ======================================================================
; 6. EMAIL REPUTATION & POLICY (TXT Records)
; ======================================================================
; SPF (Sender Policy Framework) - Hard Fail for strict environments
%domain%.       IN TXT      "v=spf1 a mx ip4:%ip% ip6:%ipv6% -all"

; DMARC (Domain-based Message Authentication, Reporting, and Conformance)
_dmarc          IN TXT      "v=DMARC1; p=quarantine; pct=100; fo=1; rua=mailto:dmarc@%domain%; ruf=mailto:dmarc@%domain%"

; DKIM (DomainKeys Identified Mail) - Placeholder for selector
default._domainkey IN TXT   "v=DKIM1; k=rsa; p=%dkim_public_key%"

; MTA-STS (Strict Transport Security for Email)
; Prevents downgrade attacks on SMTP connections
_mta-sts        IN TXT      "v=STSv1; id=%serial%;"
mta-sts         IN CNAME    %domain%.
_smtp._tls      IN TXT      "v=TLSRPTv1; rua=mailto:tls-rpt@%domain%"

; BIMI (Brand Indicators for Message Identification)
default._bimi   IN TXT      "v=BIMI1; l=https://%domain%/logo.svg; a=;"

; ======================================================================
; 7. METADATA & PHYSICALITY
; ======================================================================
; LOC (RFC 1876): Geographic Location (Lat/Long/Alt/Size/Precision)
; Useful for network topology maps and geo-routing
%domain%.       IN LOC      51 30 12.000 N 0 7 39.000 W 10m 20m 200m 10m

; EUI64 (RFC 7043): MAC Address (For specific hardware binding - IoT)
; iot-device      IN EUI64    00-11-22-33-44-55-66-77

; ======================================================================
; 8. WEB ALIASES (CNAME & DNAME)
; ======================================================================
www             IN CNAME    %domain%.
ftp             IN CNAME    %domain%.
sftp            IN CNAME    %domain%.
webmail         IN CNAME    %domain%.
cpanel          IN CNAME    %domain%.

; DNAME (RFC 6672): Redirects an entire subtree
; USE WITH CAUTION: Redirects all subdomains of 'old' to current domain
; old             IN DNAME    %domain%.

; ======================================================================
; SECURITY NOTES
; ======================================================================
; EXCLUDED RECORDS (OWASP / Security Best Practices):
;
; - HINFO: Excluded. Reveals OS/CPU versions to attackers (information leakage)
; - RP (Responsible Person): Excluded. Spam magnet, leaks email addresses
; - SPF RR Type 99: Excluded. RFC 7208 obsoleted it; use TXT instead
; - A6: Excluded. Obsolete (replaced by AAAA)
; - WKS: Excluded. Obsolete (replaced by SRV)
;
; ENCRYPTED CLIENT HELLO (ECH):
; For maximum privacy, add ECH key to HTTPS record:
; %domain%. IN HTTPS 1 . alpn="h3,h2" ech="<BASE64_ECH_CONFIG>"
