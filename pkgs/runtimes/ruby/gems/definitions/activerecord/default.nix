{ lib, ... }:
{
  inputs = { };
  configure = final: {
    # Recent PostgreSQL servers reject panic as a client message level. Error
    # retains the adapter's purpose of suppressing lower-priority messages.
    patches = lib.optionals (final.version == "3.2.22.5") [ ./postgresql-client-messages.patch ];
  };
}
