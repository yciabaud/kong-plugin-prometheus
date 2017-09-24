local metrics = {
  ["http_requests_total"]            = true,
  ["http_request_duration_seconds"]  = true,
  ["http_request_size_bytes"]        = true,
  ["http_response_size_bytes"]       = true,
  ["http_upstream_duration_seconds"] = true,
  ["http_kong_duration_seconds"]     = true,
  ["http_connections"]               = true,
}


local stat_types = {
  ["gauge"]     = true,
  ["counter"]   = true,
  ["histogram"] = true,
}

local stat_labels = {
  ["api"]    = true,
  ["state"]  = true,
  ["status"] = true,
  ["user"] = true,
}

local default_metrics = {
  {
    name        = "http_requests_total",
    description = "Number of HTTP requests",
    stat_type   = "counter",
    labels      = {"api", "status", "user"},
  },
  {
    name        = "http_request_duration_seconds",
    description = "HTTP request latency",
    stat_type   = "histogram",
    labels      = {"api"},
  },
  {
    name        = "http_request_size_bytes",
    description = "Size of HTTP responses",
    stat_type   = "histogram",
    labels      = {"api"},
    buckets     = {10,100,1000,10000,100000,1000000},
  },
  {
    name      = "http_response_size_bytes",
    stat_type = "histogram",
    labels      = {"api"},
    buckets     = {10,100,1000,10000,100000,1000000},
  },
  {
    name      = "http_upstream_duration_seconds",
    stat_type = "histogram",
    labels      = {"api"},
  },
  {
    name      = "http_kong_duration_seconds",
    stat_type = "histogram",
    labels      = {"api"},
  },
  {
    name        = "http_connections",
    description = "Number of HTTP connections",
    stat_type   = "gauge",
    labels      = {"state"},
  }
}


local function check_schema(value)
  for _, entry in ipairs(value) do

    if not entry.name or not entry.stat_type then
      return false, "name and stat_type must be defined for all stats"
    end

    if not metrics[entry.name] then
      return false, "unrecognized metric name: " .. entry.name
    end

    if not stat_types[entry.stat_type] then
      return false, "unrecognized stat_type: " .. entry.stat_type
    end

    for _,label in pairs(entry.labels) do
      if not stat_labels[label] then
        return false, "unrecognized stat_label: " .. label
      end
    end

  end

  return true
end


return {
  fields = {
    metrics = {
      type     = "array",
      default  = default_metrics,
      func     = check_schema,
    },
    dict_name = {
      type     = "string",
      default  = "prometheus_metrics",
    },
    prefix = {
      type     = "string",
      default  = "kong",
    },
  }
}
