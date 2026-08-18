require "json"
require "digest"
require "set"

# inject, not sum: Enumerable#sum arrived in 2.4 and this suite runs on 2.0.
data = JSON.parse('{"a":[1,2,3]}')
print [Digest::SHA256.hexdigest("tvp")[0, 16], Set.new(data["a"]).inject(:+)].join(":")
