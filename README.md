# kong-prometheus-plugin
**WIP - not ready yet**

Widely inspired by [nginx-lua-prometheus](https://github.com/knyar/nginx-lua-prometheus/) NGINX module and the [Kong StatsD plugin](https://github.com/Mashape/kong/tree/master/kong/plugins/statsd).


Exposes API [metrics](#metrics) for [Prometheus](https://prometheus.io) monitoring system.

----

## Installation

Install the `luarocks` utility on your system then install it by doing:
```bash
$ luarocks install kong-prometheus-plugin
```

## Configuration

Configuring the plugin is straightforward, you can add it on top of an
API by executing the following
request on your Kong server:

```bash
$ curl -X POST http://kong:8001/apis/{api}/plugins \
    --data "name=prometheus"
```

`api`: The `id` or `name` of the API that this plugin configuration will target

You can also apply it for every API using the `http://kong:8001/plugins/`
endpoint.

parameter                       | default | description
---                             | ---     | ---
`name`                          |         | The name of the plugin to use, in this case: `prometheus`
`config.metrics`<br>*optional*  | All metrics<br>are logged | List of Metrics to be logged. Available values are described under [Metrics](#metrics).
`config.dict_name`<br>*optional*| `prometheus_metrics` | The name of the nginx shared dictionary which will be used to store all metrics.
`config.prefix`<br>*optional*   | `kong` | String to be prefixed to each metric's name.


----

## Metrics

Metrics the plugin can expose in the prometheus format.

Metric                     | description | namespace
---                        | ---         | ---
`request_count`            | tracks api request | kong_http_requests_total
`request_size`             | tracks api request's body size in bytes | kong_http_request_size_bytes
`response_size`            | tracks api response's body size in bytes | kong_http_response_size_bytes
`latency`                  | tracks the time interval between the request started and response received from the upstream server | kong_http_latency
`upstream_latency`         | tracks the time it took for the final service to process the request | kong_http_upstream_latency
`kong_latency`             | tracks the internal Kong latency that it took to run all the plugins | kong_http_kong_latency

### Metric Fields

Plugin can be configured with any combination of [Metrics](#metrics), with each entry containing the following fields.

Field         | description                                             | allowed values
---           | ---                                                     | --- 
`name`          | Prometheus metric's name                              | [Metrics](#metrics)          
`stat_type`     | determines what sort of event the metric represents   | `gauge`, `counter` and `histogram`

## Kong Process Errors

This logging plugin will only log HTTP request and response data. If you are
looking for the Kong process error file (which is the nginx error file), then
you can find it at the following path:
prefix/logs/error.log

## Built-in metrics

The module increments the `kong_metric_errors_total` metric if it encounters an error (for example, when lua_shared_dict becomes full). You might want to configure an alert on that metric.

## Caveats

Please keep in mind that all metrics stored by this library are kept in a
single shared dictionary (`lua_shared_dict`). While exposing metrics the module
has to list all dictionary keys, which has serious performance implications for
dictionaries with large number of keys (in this case this means large number
of metrics OR metrics with high label cardinality). Listing the keys has to
lock the dictionary, which blocks all threads that try to access it (i.e.
potentially all nginx worker threads).

There is no elegant solution to this issue (besides keeping metrics in a
separate storage system external to nginx), so for latency-critical servers you
might want to keep the number of metrics (and distinct metric label values) to
a minimum.

## Credits
- Adapted and maintained by Yoann Ciabaud (@yciabaud)

### Kong StatsD plugin
- Source [Plugin](https://getkong.org/plugins/statsd/) created and maintained by the [Kong](https://getkong.org/) folks at [Mashape](https://www.mashape.com)

### nginx-lua-prometheus
All prometheus implementation credits goes to [nginx-lua-prometheus](https://github.com/knyar/nginx-lua-prometheus/)
- Created and maintained by Anton Tolchanov (@knyar)
- Metrix prefix support contributed by david birdsong (@davidbirdsong)
- Gauge support contributed by Cosmo Petrich (@cosmopetrich)