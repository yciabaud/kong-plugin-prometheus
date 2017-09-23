local prometheus    = require "kong.plugins.prometheus.prometheus"

return {
  ["/metrics"] = {
    GET = function(self, dao_factory, helpers)
      prometheus:collect()
    end
  }
}