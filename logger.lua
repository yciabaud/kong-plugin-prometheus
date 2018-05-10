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
  ngx_log(NGX_DEBUG, string.format("Prometheus: log metric %s (%s)", metric_name, stat_type))

  local metric = metrics[metric_name]
  if metric == nil then
    ngx_log(NGX_ERR, string.format("Prometheus: metrics %s not found", metric_name))
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

function PrometheusLogger:init(config)
  ngx_log(NGX_DEBUG, "Prometheus: initializing metrics...")
  prometheus = require("kong.plugins.prometheus.prometheus").init(config.dict_name, config.prefix .. "_")
  metrics = {}

  for _, metric_config in pairs(config.metrics) do
    ngx_log(NGX_DEBUG, string.format("Prometheus: init metric %s", metric_config.name))
    if metric_config.stat_type == "counter" then
      metrics[metric_config.name] = prometheus:counter(metric_config.name, metric_config.description, metric_config.labels)
    
    elseif metric_config.stat_type == "gauge" then
      metrics[metric_config.name] = prometheus:gauge(metric_config.name, metric_config.description, metric_config.labels)

    elseif metric_config.stat_type == "histogram" then
      metrics[metric_config.name] = prometheus:histogram(metric_config.name, metric_config.description, metric_config.labels, metric_config.buckets )
    end
  end
  ngx_log(NGX_DEBUG, "Prometheus: metrics initialized")
end

function PrometheusLogger:log(message, config)
  ngx_log(NGX_DEBUG, "Prometheus: logging metrics...")

  local api_name
  if message.api == nil then
    api_name = "kong"
  else
    api_name = string_gsub(message.api.name, "%.", "_")
  end
  local stat_value = {
    http_request_size_bytes   = tonumber(message.request.size),
    http_response_size_bytes  = tonumber(message.response.size),
    http_request_duration_ms  = message.latencies.request,
    http_upstream_duration_ms = message.latencies.proxy,
    http_kong_duration_ms     = message.latencies.kong,
    http_requests_total            = 1,
  }

  for _, metric_config in pairs(config.metrics) do
    local stat_value = stat_value[metric_config.name]
    if stat_value ~= nil then
    
      local get_consumer_id = get_consumer_id[metric_config.consumer_identifier]
      local consumer_id
      if get_consumer_id ~= nil then
        consumer_id = get_consumer_id(message.consumer)
      end

      local labels = {
        api      = api_name,
        status   = message.response.status,
        user     = consumer_id or "anonymous"
      }
      local stat_labels = map_labels(metric_config.labels, labels)
      update_metric(metric_config.name, metric_config.stat_type, stat_value, stat_labels)
    end
  end
  ngx_log(NGX_DEBUG, "Prometheus: metrics logged")
end

function PrometheusLogger:logAdmin(config)
  ngx_log(NGX_DEBUG, "Prometheus: logging metrics admin...")

  local stat_value
  local api_name
  local stat_value = {
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

  for _, metric_config in pairs(config.metrics) do
    local stat_value = stat_value[metric_config.name]
    if stat_value ~= nil then
      local labels = {}
      -- handle steps for http_connections
      if type(stat_value) == "table" then
        for _, step in pairs(stat_value) do
            labels[step.label] = step.label_value
            local stat_labels = map_labels(metric_config.labels, labels)
            update_metric(metric_config.name, metric_config.stat_type, step.value, stat_labels)
        end
      else
        local stat_labels = map_labels(metric_config.labels, labels)
        update_metric(metric_config.name, metric_config.stat_type, stat_value, stat_labels)
      end
    end
  end
  ngx_log(NGX_DEBUG, "Prometheus: metrics logged")
end

function PrometheusLogger:collect()
  prometheus:collect()
end

return PrometheusLogger

