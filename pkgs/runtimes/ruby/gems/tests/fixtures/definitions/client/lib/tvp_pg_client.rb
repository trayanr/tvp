require 'pg'

module TvpPgClient
  def self.answer
    [PgFixture.marker, PgFixture.client_version]
  end
end
