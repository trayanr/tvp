#define _GNU_SOURCE
#include <libxml/parser.h>
#include <libxml/relaxng.h>
#include <libxml/xmlerror.h>
#include <libxml/xmlversion.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef __linux__
#include <dlfcn.h>
#endif

enum classification { STANDARD, NAME_PROFILE, URI_PROFILE, HISTORICAL_DEFECT };
struct schema_case {
    const char *id;
    const char *xml;
    int compiled;
    enum classification classification;
};
struct instance_case {
    size_t schema;
    const char *id;
    const char *xml;
    int valid;
    int historical_schema;
};
#include "relaxng-corpus-cases.h"

static char last_error[512];
static unsigned errors;
static unsigned unexpected_errors;

static void capture_error(void *context, const xmlError *error) {
    (void) context;
    errors++;
    snprintf(last_error, sizeof(last_error), "%s", error->message ? error->message : "");
    if (error->level == XML_ERR_FATAL ||
        (error->domain != XML_FROM_RELAXNGV &&
         (error->code == XML_ERR_NO_MEMORY || error->code == XML_ERR_INTERNAL_ERROR)) ||
        (error->domain == XML_FROM_RELAXNGV &&
         (error->code == XML_RELAXNG_ERR_MEMORY || error->code == XML_RELAXNG_ERR_INTERNAL)))
        unexpected_errors++;
}

static void fail(const char *id, const char *message) {
    fprintf(stderr, "FAIL %s: %s\n%s", id, message, last_error);
    exit(1);
}

static void check_library(const char *expected) {
#ifdef __linux__
    Dl_info info;
    char actual[PATH_MAX], wanted[PATH_MAX];
    if (!dladdr((void *) xmlRelaxNGParse, &info) ||
        !realpath(info.dli_fname, actual) || !realpath(expected, wanted) ||
        strcmp(actual, wanted))
        fail("loaded-library", "wrong libxml2 loaded");
    printf("PASS loaded %s\n", actual);
#else
    (void) expected;
    puts("SKIP exact loaded-library check: Linux-only probe");
#endif
}

int main(int argc, char **argv) {
    size_t schema_count = sizeof(schemas) / sizeof(schemas[0]);
    size_t instance_count = sizeof(instances) / sizeof(instances[0]);
    unsigned historical_schemas = 0, historical_instances = 0, profile_schemas = 0;
    unsigned schema_checks = 0, instance_checks = 0;
    if (argc != 4)
        return 1;
    check_library(argv[1]);
    if (strcmp(argv[2], LIBXML_DOTTED_VERSION) ||
        strcmp(xmlParserVersion, LIBXML_VERSION_STRING))
        fail("version", "headers and runtime do not match the selected release");
    xmlInitParser();
    xmlSetStructuredErrorFunc(NULL, capture_error);

    for (size_t i = 0; i < schema_count; i++) {
        const struct schema_case *test = &schemas[i];
        errors = 0;
        last_error[0] = 0;
        xmlRelaxNGParserCtxtPtr parser = xmlRelaxNGNewMemParserCtxt(test->xml, (int) strlen(test->xml));
        if (!parser)
            fail(test->id, "cannot allocate schema parser");
        xmlRelaxNGSetParserStructuredErrors(parser, capture_error, NULL);
        xmlRelaxNGPtr schema = xmlRelaxNGParse(parser);
        xmlRelaxNGFreeParserCtxt(parser);
        if (unexpected_errors)
            fail(test->id, "unexpected fatal, memory or internal error");
        if ((schema != NULL) != test->compiled)
            fail(test->id, test->classification == HISTORICAL_DEFECT
                 ? "historical defect changed; review the baseline (possible XPASS)"
                 : "unexpected schema acceptance/rejection");
        if (!schema && !errors)
            fail(test->id, "schema rejected without a diagnostic");
        if (schema && errors)
            fail(test->id, "unexpected diagnostic for a compiled schema");
        schema_checks++;

        if (test->classification == HISTORICAL_DEFECT) {
            historical_schemas++;
            printf("XFAIL schema-correctness %s: expected rejection, observed compilation\n", test->id);
        } else if (test->classification == NAME_PROFILE || test->classification == URI_PROFILE) {
            profile_schemas++;
            printf("PASS %s profile %s\n", test->classification == NAME_PROFILE ? "XML-Fifth-Edition" : "RFC3986", test->id);
        } else {
            printf("PASS schema control %s\n", test->id);
        }

        for (size_t j = 0; j < instance_count; j++) {
            const struct instance_case *instance = &instances[j];
            if (instance->schema != i)
                continue;
            if (!schema)
                fail(instance->id, "instance assigned to a rejected schema");
            errors = 0;
            last_error[0] = 0;
            xmlDocPtr document = xmlReadMemory(instance->xml, (int) strlen(instance->xml), NULL, NULL, 0);
            if (!document || errors)
                fail(instance->id, "instance is not well-formed XML");
            xmlRelaxNGValidCtxtPtr validator = xmlRelaxNGNewValidCtxt(schema);
            if (!validator)
                fail(instance->id, "cannot allocate validator");
            xmlRelaxNGSetValidStructuredErrors(validator, capture_error, NULL);
            int status = xmlRelaxNGValidateDoc(validator, document);
            xmlRelaxNGFreeValidCtxt(validator);
            xmlFreeDoc(document);
            if (unexpected_errors)
                fail(instance->id, "unexpected fatal, memory or internal error");
            if (status != (instance->valid ? 0 : 1))
                fail(instance->id, "unexpected instance validation result");
            if ((instance->valid && errors) || (!instance->valid && !errors))
                fail(instance->id, "validation diagnostics disagree with the result");
            instance_checks++;
            if (instance->historical_schema)
                historical_instances++;
            printf("%s instance %s\n", instance->historical_schema ? "OBSERVED historical-schema" : "PASS", instance->id);
        }
        if (schema)
            xmlRelaxNGFree(schema);
    }

    if (schema_count != 26 || instance_count != 38 || historical_schemas != 3 ||
        historical_instances != 12 || profile_schemas != 6 ||
        schema_checks != schema_count || instance_checks != instance_count || unexpected_errors)
        fail("coverage", "unexpected fixture coverage");
    FILE *result = fopen(argv[3], "w");
    if (!result)
        fail("results", "cannot retain structured results");
    fprintf(result, "{\n  \"version\": \"%s\",\n  \"compatibility\": \"PASS\",\n"
            "  \"strictSchemaConformance\": \"KNOWN_FAILURE\",\n"
            "  \"schemaChecks\": %u,\n  \"instanceChecks\": %u,\n"
            "  \"profileCases\": %u,\n  \"historicalSchemaDefectVariants\": %u,\n"
            "  \"historicalInstanceObservations\": %u\n}\n", argv[2],
            schema_checks, instance_checks, profile_schemas, historical_schemas, historical_instances);
    if (fclose(result))
        fail("results", "cannot finish structured results");
    xmlCleanupParser();
    if (unexpected_errors)
        fail("cleanup", "unexpected fatal, memory or internal error");
    puts("PASS compatibility: 26 schema and 38 instance checks");
    puts("XFAIL strict schema correctness: unrepeated attribute wildcard inside choice");
    return 0;
}
