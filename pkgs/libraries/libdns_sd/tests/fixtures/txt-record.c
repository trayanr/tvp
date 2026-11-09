#include <dns_sd.h>
#include <stdio.h>
#include <string.h>
int main(void) {
  TXTRecordRef record;
  TXTRecordCreate(&record, 0, NULL);
  if (TXTRecordSetValue(&record, "note", 3, "TVP")) return 1;
  if (TXTRecordSetValue(&record, "duplex", 0, NULL)) return 2;
  uint16_t length = TXTRecordGetLength(&record);
  const void *bytes = TXTRecordGetBytesPtr(&record);
  uint8_t size = 0;
  const void *value = TXTRecordGetValuePtr(length, bytes, "note", &size);
  if (!value || size != 3 || memcmp(value, "TVP", 3)) return 3;
  if (TXTRecordGetCount(length, bytes) != 2) return 4;
  if (TXTRecordRemoveValue(&record, "note")) return 5;
  if (TXTRecordContainsKey(TXTRecordGetLength(&record), TXTRecordGetBytesPtr(&record), "note")) return 6;
  TXTRecordDeallocate(&record);
  puts("txt-record-roundtrip");
  return 0;
}
