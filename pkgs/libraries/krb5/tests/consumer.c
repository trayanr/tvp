#include <gssapi/gssapi_krb5.h>
#include <krb5.h>
#include <stdio.h>

int main(void)
{
    krb5_context context;
    krb5_principal principal;
    char *name;
    gss_OID_set mechanisms;
    OM_uint32 minor;
    int has_kerberos;

    if (gss_indicate_mechs(&minor, &mechanisms) != GSS_S_COMPLETE)
        return 1;
    if (gss_test_oid_set_member(&minor, gss_mech_krb5, mechanisms,
                                &has_kerberos) != GSS_S_COMPLETE || !has_kerberos)
        return 1;
    gss_release_oid_set(&minor, &mechanisms);

    if (krb5_init_context(&context) != 0)
        return 1;
    if (krb5_parse_name(context, "tvp", &principal) != 0
        || krb5_unparse_name(context, principal, &name) != 0)
        return 1;

    puts(name);
    krb5_free_unparsed_name(context, name);
    krb5_free_principal(context, principal);
    krb5_free_context(context);
    return 0;
}
