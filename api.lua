local logger    = require "kong.plugins.prometheus.logger"
local crud = require "kong.api.crud_helpers"

return {
  ["/prometheus/metrics"] = {
    GET = function(self, dao_factory, helpers)
      -- load our existing plugins to get config
      local plugins, err = dao_factory.plugins:find_all({
        name = "prometheus",
      })
      if err then
        ngx.log(ngx.ERR, "Prometheus: err in fetching plugins: ", err)
      end

      for _, plugin in ipairs(plugins) do
        logger:logAdmin(plugin.config)
      end 

      return logger:collect()
    end
  }
}