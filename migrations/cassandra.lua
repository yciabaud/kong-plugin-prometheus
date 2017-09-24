return {
  {
    name = "2017-09-23-160000_prometheus_schema_changes",
    up = function(_, _, dao)

      local plugins, err = dao.plugins:find_all { name = "prometheus" }
      if err then
        return err
      end

            local default_metrics = {
        http_requests_total = {
          name        = "http_requests_total",
          description = "Number of HTTP requests",
          stat_type   = "counter",
          labels      = {"api", "status", "user"},
        },
        http_request_duration_ms = {
          name        = "http_request_duration_ms",
          description = "HTTP request latency",
          stat_type   = "histogram",
          labels      = {"api"},
        },
        http_request_size_bytes = {
          name        = "http_request_size_bytes",
          description = "Size of HTTP responses",
          stat_type   = "histogram",
          labels      = {"api"},
          buckets     = {10,100,1000,10000,100000,1000000},
        },
        http_response_size_bytes = {
          name      = "http_response_size_bytes",
          stat_type = "histogram",
          labels      = {"api"},
          buckets     = {10,100,1000,10000,100000,1000000},
        },
        http_upstream_duration_ms = {
          name      = "http_upstream_duration_ms",
          stat_type = "histogram",
          labels      = {"api"},
        },
        http_kong_duration_ms = {
          name      = "http_kong_duration_ms",
          stat_type = "histogram",
          labels      = {"api"},
        },
        http_connections = {
          name        = "http_connections",
          description = "Number of HTTP connections",
          stat_type   = "gauge",
          labels      = {"state"},
        }
      }

      for i = 1, #plugins do
        local prometheus = plugins[i]
        local _, err = dao.plugins:delete(prometheus)
        if err then
          return err
        end

        local new_metrics = {}
        if prometheus.config.metrics then
          for _, metric in ipairs(prometheus.config.metrics) do
            local new_metric = default_metrics[metric]
            if new_metric then
              table.insert(new_metrics, new_metric)
            end
          end
        end

        local _, err = dao.plugins:insert {
          name    = "prometheus",
          api_id  = prometheus.api_id,
          enabled = prometheus.enabled,
          config  = {
            metrics = new_metrics,
            prefix  = "kong",
            dict_name = "prometheus_metrics",
          }
        }

        if err then
          return err
        end
      end
    end
  },
  down = function()
  end,
}
