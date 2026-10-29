#include <dns_sd.h>
#include <stdio.h>
int main(void) {
    char name[kDNSServiceMaxDomainName];
    if(DNSServiceConstructFullName(name,"TVP Printer","_ipp._tcp","local.")!=kDNSServiceErr_NoError) return 1;
    puts(name);return 0;
}
