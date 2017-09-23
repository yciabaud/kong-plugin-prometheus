return {
  {
    name = "2017-09-23-160000_prometheus_schema_changes",
    up = function(_, _, dao)

      local plugins, err = dao.plugins:find_all { name = "prometheus" }
      if err then
        return err
      end

      local default_metrics = {
        request_count = {
          name        = "request_count",
          stat_type   = "counter",
        },
        latency = {
          name      = "latency",
          stat_type = "gauge",
        },
        request_size = {
          name      = "request_size",
          stat_type = "gauge",
        },
        response_size = {
          name      = "response_size",
          stat_type = "counter",
        },
        upstream_latency = {
          name      = "upstream_latency",
          stat_type = "gauge",
        },
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
            path      = "/metrics",
            metrics   = new_metrics,
            prefix    = "kong",
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
