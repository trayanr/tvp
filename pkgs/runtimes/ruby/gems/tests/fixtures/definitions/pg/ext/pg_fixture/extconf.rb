require 'mkmf'

configuration = with_config('pg-config')
abort 'The gem definition did not supply pg_config' unless configuration

def configure_value(configuration, argument)
  value = IO.popen([configuration, argument], &:read).strip
  abort "Selected pg_config failed for #{argument}" unless $?.success?
  value
end

marker = Integer(configure_value(configuration, '--tvp-fixture-marker'))
dir_config('pg', configure_value(configuration, '--includedir'),
                configure_value(configuration, '--libdir'))
abort 'The declared PostgreSQL headers were unavailable' unless have_header('libpq-fe.h')
abort 'The declared PostgreSQL library did not link' unless have_library('pq', 'PQlibVersion')
$defs << "-DTVP_PG_PROVIDER_MARKER=#{marker}"
create_makefile('pg_fixture')
