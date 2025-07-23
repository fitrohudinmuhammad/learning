// camel-k: language=js
// camel-k: trait=logging.color=false
// camel-k: trait=logging.json=false
// camel-k: trait=container.enabled=true
// camel-k: trait=container.auto=true
// camel-k: trait=tracing.enabled=true
// camel-k: trait=tracing.auto=true
// camel-k: trait=tracing.service-name=daco-202309061102510r7xu4
// camel-k: trait=tracing.endpoint=http://172.17.0.1:14268/api/traces
// camel-k: trait=container.limit-cpu=300m
// camel-k: trait=container.limit-memory=500Mi

onException(Java.type("java.lang.Exception"))
.maximumRedeliveries(3)
.handled(true)
.transform().simple("${exception.message}")
.to("log:onExceptionDSL?level=ERROR")

from("file://Downloads/?recursive=true&delete=true")
.log("${header.CamelFileName}")
.to("file://Documents?flatten=true")