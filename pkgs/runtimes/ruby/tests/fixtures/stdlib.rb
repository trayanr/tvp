require "json"
require "digest"
require "set"

data = JSON.parse('{"a":[1,2,3]}')
print [Digest::SHA256.hexdigest("tvp")[0, 16], Set.new(data["a"]).sum].join(":")
