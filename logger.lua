local prometheus    = require "kong.plugins.prometheus.prometheus"

local ngx_log       = ngx.log
local string_gsub   = string.gsub
local NGX_DEBUG     = ngx.DEBUG
local NGX_ERR       = ngx.ERR

local PrometheusLogger = {}
PrometheusLogger.__index = PrometheusLogger

local function map_labels(labels, values)
  mapped = {}
  for _, label in pairs(labels) do
    table.insert(mapped, values[label])
  end

  return mapped
end

local function update_metric(metric_name, stat_type, stat_value, label_values)

  local metric = prometheus:get(metric_name)
  if metric == nil then
    ngx_log(NGX_ERR, fmt("Prometheus: metrics %s not found", metric_name))
    return
  end

  if stat_type == "counter" then
    metric:inc(stat_value, label_values)
    
  elseif stat_type == "gauge" then
    metric:set(stat_value, label_values)

  elseif stat_type == "histogram" then
    metric:observe(stat_value, label_values)
  end
end

function PrometheusLogger:init(config)
  ngx_log(NGX_DEBUG, "Prometheus: initializing metrics...")
  prometheus.init(config.dict_name)

  for _, metric_config in pairs(config.metrics) do
    if metric_config.stat_type == "counter" then
      prometheus:counter(metric_config.name, metric_config.description, metric_config.labels)
    
    elseif metric_config.stat_type == "gauge" then
      prometheus:gauge(metric_config.name, metric_config.description, metric_config.labels)

    elseif metric_config.stat_type == "histogram" then
      prometheus:histogram(metric_config.name, metric_config.description, metric_config.labels, metric_config.buckets )
    end
  end
  ngx_log(NGX_DEBUG, "Prometheus: metrics initialized")
end

function PrometheusLogger:log(message, conf)
  ngx_log(NGX_DEBUG, "Prometheus: logging metrics...")
  local api_name
  if message.api == nil then
    api_name = "kong"
  else
    api_name = string_gsub(message.api.name, "%.", "_")
  end

  local stat_value
  if message ~= nil then
    stat_value = {
        http_request_size_bytes        = message.request.size,
        http_response_size_bytes       = message.response.size,
        http_request_duration_seconds  = message.latencies.request,
        http_upstream_duration_seconds = message.latencies.proxy,
        http_kong_duration_seconds     = message.latencies.kong,
        http_requests_total            = 1,
    }
  else
    stat_value = {
      http_connections = {
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
      }
    }
  end

  for _, metric_config in pairs(conf.metrics) do
    local stat_value = stat_value[metric_config.name]
    if stat_value ~= nil then
      local labels = {
        api      = api_name,
        status   = message.response.status,
        user     = consumer_id
      }
      local metric_name = fmt("%s_%s", config.prefix, metric_config.name)
      local get_consumer_id = get_consumer_id[metric_config.consumer_identifier]
      local consumer_id     = get_consumer_id(message.consumer)

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
  end
  ngx_log(NGX_DEBUG, "Prometheus: metrics logged")
end

return PrometheusLogger

