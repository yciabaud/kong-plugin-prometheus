local BasePlugin       = require "kong.plugins.base_plugin"
local basic_serializer = require "kong.plugins.log-serializers.basic"
local prometheus    = require "kong.plugins.prometheus.prometheus"
local singletons = require "kong.singletons"

local ngx_log       = ngx.log
local ngx_timer_at  = ngx.timer.at
local string_gsub   = string.gsub
local pairs         = pairs
local string_format = string.format
local NGX_ERR       = ngx.ERR
local apis_dao = singletons.dao.apis


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

local function update_metric(metric_name, stat_type, stat_value, label_values)
  if stat_type == "counter" then
    local counter = prometheus:get(metric_name)
    counter:inc(stat_value, label_values)
    
  else if stat_type == "gauge" then
    local gauge = prometheus:get(metric_name)
    gauge:set(stat_value, label_values)

  else if stat_type == "histogram" then
    local histogram = prometheus:get(metric_name)
    histogram:observe(stat_value, label_values)
  end
end

local function map_labels(labels, values) {
  mapped = {}
  for _, label in pairs(labels) do
    table.insert(mapped, values[label])
  end

  return mapped
}

local function log(premature, conf, message)
  if premature then
    return
  end

  local api_name   = string_gsub(message.api.name, "%.", "_")
  local get_consumer_id = get_consumer_id[metric_config.consumer_identifier]
  local consumer_id     = get_consumer_id(message.consumer)

  local stat_value = {
    http_request_size_bytes        = message.request.size,
    http_response_size_bytes       = message.response.size,
    http_request_duration_seconds  = message.latencies.request,
    http_upstream_duration_seconds = message.latencies.proxy,
    http_kong_duration_seconds     = message.latencies.kong,
    http_requests_total            = 1,
    http_connections               = {
      {
        label = "state",
        label_value = "reading",
        value = ngx.var.connections_reading,
      },
      {
        label = "state",
        label_value = "waiting",
        value = ngx.var.connections_waiting,
      },
      {
        label = "state",
        label_value = "writing",
        value = ngx.var.connections_writing,
      },
    },
  }


  for _, metric_config in pairs(conf.metrics) do
    local stat_value = stat_value[metric_config.name]
    local labels = {
      api      = api_name,
      status   = message.response.status,
      user     = consumer_id
    }
    local metric_name = fmt("%s_%s", config.prefix, metric_config.name)

    -- handle steps for http_connections
    if type(stat_value) == "table" then
      for _, step in pairs(stat_value) do
        labels[step.label] = step.label_value
        local stat_labels = map_labels(metric_config.labels, labels)
        update_metric(metric_name, stat_value, stat_labels)
      end
    else
      local stat_labels = map_labels(metric_config.labels, labels)
      update_metric(metric_name, stat_value, stat_labels)
    end
  end
  
  prometheus:collect()
end


function PrometheusHandler:new()
  PrometheusHandler.super.new(self, "prometheus")
end

function PrometheusHandler:init_worker(config)
  prometheus.init(config.dict_name)

  for _, metric_config in pairs(conf.metrics) do
    if metric_config.stat_type == "counter" then
      prometheus:counter(metric_config.name, metric_config.description, metric_config.labels)
    
    else if metric_config.stat_type == "gauge" then
      prometheus:gauge(metric_config.name, metric_config.description, metric_config.labels)

    else if metric_config.stat_type == "histogram" then
      prometheus:histogram(metric_config.name, metric_config.description, metric_config.labels, metric_config.buckets )
    end
  end
end

function PrometheusHandler:log(conf)
  PrometheusHandler.super.log(self)

  local message = basic_serializer.serialize(ngx)

  local ok, err = ngx_timer_at(0, log, conf, message)
  if not ok then
    ngx_log(NGX_ERR, "failed to create timer: ", err)
  end
end


return PrometheusHandler
