require 'tvp_support'
require 'mkmf'

abort 'Transitive gem build dependency did not load' unless TvpSupport::ANSWER == 42
$defs << "-DTVP_TRANSITIVE_ANSWER=#{TvpSupport::ANSWER}"
create_makefile('tvp_transitive')
