local BasePlugin       = require "kong.plugins.base_plugin"
local basic_serializer = require "kong.plugins.log-serializers.basic"
local logger           = require "kong.plugins.prometheus.logger"

local ngx_log       = ngx.log
local ngx_timer_at  = ngx.timer.at
local string_gsub   = string.gsub
local pairs         = pairs
local string_format = string.format
local NGX_ERR       = ngx.ERR


local PrometheusHandler = BasePlugin:extend()
PrometheusHandler.PRIORITY = 11

local function log(premature, conf, message)
  if premature then
    return
  end

  logger:log(message, conf)
end


function PrometheusHandler:new()
  PrometheusHandler.super.new(self, "prometheus")
end

function PrometheusHandler:init_worker()
  PrometheusHandler.super.init_worker(self)
  
  local singletons    = require "kong.singletons"
  local dao_factory   = singletons.dao

  -- load our existing plugins to get config
  local plugins, err = dao_factory.plugins:find_all({
    name = "prometheus",
  })
  if err then
    ngx.log(ngx.ERR, "Prometheus: err in fetching plugins: ", err)
  end

  for _, plugin in ipairs(plugins) do
    logger:init(plugin.config)
  end
end

function PrometheusHandler:log(config)
  PrometheusHandler.super.log(self)
  if (config == nil) then
    ngx_log(NGX_ERR, "Prometheus: no configuration in log")
    return
  end

  local message = basic_serializer.serialize(ngx)

  local ok, err = ngx_timer_at(0, log, config, message)
  if not ok then
    ngx_log(NGX_ERR, "Prometheus: failed to create timer: ", err)
  end
end


return PrometheusHandler
