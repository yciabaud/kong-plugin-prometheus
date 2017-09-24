local prometheus    = require "kong.plugins.prometheus.prometheus"
local logger    = require "kong.plugins.prometheus.logger"
local crud = require "kong.api.crud_helpers"

return {
  ["/"] = {
    GET = function(self, dao_factory, helpers)
      -- TODO: fetch config
      prometheus:collect()
    end
  }
}