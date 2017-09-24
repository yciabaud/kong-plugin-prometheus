local BasePlugin       = require "kong.plugins.base_plugin"
local basic_serializer = require "kong.plugins.log-serializers.basic"
local logger           = require "kong.plugins.prometheus.logger"
local prometheus       = require "kong.plugins.prometheus.prometheus"

local ngx_log       = ngx.log
local ngx_timer_at  = ngx.timer.at
local string_gsub   = string.gsub
local pairs         = pairs
local string_format = string.format
local NGX_ERR       = ngx.ERR


local PrometheusHandler = BasePlugin:extend()
PrometheusHandler.PRIORITY = 11

local get_consumer_id = {
  consumer_id = function(consumer)
    return consumer and string_gsub(consumer.id, "-", "_")
  end,
  custom_id   = function(consumer)
    return consumer and consumer.custom_id
  end,
  username    = function(consumer)
    return consumer and consumer.username
  end
}

local function log(premature, conf, message)
  if premature then
    return
  end

  logger:log(message, conf)
end


function PrometheusHandler:new()
  PrometheusHandler.super.new(self, "prometheus")
end

function PrometheusHandler:init_worker(config)
  PrometheusHandler.super.init_worker(self)
  if (config == nil) then
    ngx_log(NGX_ERR, "Prometheus: no configuration in init_worker")
    return
  end
  logger:init(config)
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
