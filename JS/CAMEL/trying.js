// camel-k: language=js
// camel-k: trait=logging.color=false
// camel-k: trait=logging.json=false
// camel-k: trait=container.enabled=true
// camel-k: trait=container.auto=true
// camel-k: trait=tracing.enabled=true
// camel-k: trait=tracing.auto=true
// camel-k: trait=tracing.service-name=daco-202305031102510r7xu4
// camel-k: trait=tracing.endpoint=http://172.17.0.1:14268/api/traces
// camel-k: trait=container.limit-cpu=300m
// camel-k: trait=container.limit-memory=500Mi
// camel-k: dependency=mvn:org.apache.camel.quarkus:camel-quarkus-jdbc
// camel-k: dependency=mvn:io.quarkus:quarkus-jdbc-postgresql

from("ftp://admin@54.169.177.36:221/tes_udin?password=1234&fileName=ddoba.csv&ignoreFileNotFoundOrPermissionError=true&autoCreate=true&stepwise=false&binary=true&passiveMode=true&streamDownload=true&delete=true&ftpClient.remoteVerificationEnabled=false")
.log("File uploaded 1: ${header.CamelFileName}")
.to("ftp://admin@54.169.177.36:221/tes_udin/inbound?password=1234&fileName=ss-${header.CamelFileName}&ignoreFileNotFoundOrPermissionError=true&autoCreate=true&stepwise=false&binary=true&passiveMode=true&streamDownload=true&delete=true&ftpClient.remoteVerificationEnabled=false")
.to("Done - Success")