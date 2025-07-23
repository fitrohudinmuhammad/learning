// camel-k: language=js
// camel-k: trait=logging.color=false
// camel-k: trait=logging.json=false
// camel-k: trait=container.enabled=true
// camel-k: trait=container.auto=true
// camel-k: trait=tracing.enabled=true
// camel-k: trait=tracing.auto=true
// camel-k: trait=tracing.service-name=daco-202305031102510r7xu4
// camel-k: trait=tracing.endpoint=http://host.k3d.internal:14268/api/traces
// camel-k: trait=container.limit-cpu=300m
// camel-k: trait=container.limit-memory=500Mi
// camel-k: dependency=mvn:org.apache.camel.quarkus:camel-quarkus-jdbc
// camel-k: dependency=mvn:io.quarkus:quarkus-jdbc-postgresql
// camel-k: build-property=quarkus.datasource.daco152.db-kind=postgresql
// camel-k: build-property=quarkus.datasource.daco152.username=postgres
// camel-k: build-property=quarkus.datasource.daco152.password=postgres
// camel-k: build-property=quarkus.datasource.daco152.jdbc.url=jdbc:postgresql://host.k3d.internal:5432/daco15
// camel-k: build-property=quarkus.datasource.daco152.jdbc.max-size=15

from("ftp://admin@54.169.177.36:221/tes_udin?password=1234&ignoreFileNotFoundOrPermissionError=true&autoCreate=true&stepwise=false&binary=true&passiveMode=true&streamDownload=true&delete=true&ftpClient.remoteVerificationEnabled=false&fileName=ccoba.csv")
.split().tokenize("\n", 5000, false).streaming()
.process(function(e) {
    var body = e.getIn().getBody()
    // console.log('--', body)
    var rows = body.split("\n")
    var temp_rows = []
    var columns = ["name", "email"]
    rows.forEach(row => {
        var temp_row = {}
        var row_data = row.split(",")
        columns.forEach((col, seq) => {
            if(seq <= row_data.length){
                var temp_val = row_data[seq]
                temp_val = temp_val.replace(/(^"+|^'+|^ +|"+$|'+$| +$)/g, '')
                temp_val[col] = temp_val
            }
        })
        temp_rows.push(temp_row)
    })
    e.getIn().setBody(temp_rows)
})
.to("log:ftp?showBody=false")
.marshal().json()
.process(function(e) {
    var msg = e.getIn()
    var rows = msg.getBody(Java.type("java.lang.String"))
    rows = JSON.parse(rows)
    var msg_body = ""
    console.log("DB Filename --------------- : " + e.getIn().getHeader("CamelFileName"))
    rows.forEach((val, i) => {
        var value = "'" + val.name + "','" + val.email + "','" + e.getIn().getHeader("CamelFileName") +","
        // console.log(" ========INSERT========== ")
        msg_body += "insert into temp_camel (name, email, filename) values ("
        msg_body += value
        msg_body += ");"
    })
    
    console.log("------- FTP---------")
    // console.log(msg_body)
    msg.setBody(msg_body)
})
.to("jdbc:daco152?useHeadersAsParameters=true")