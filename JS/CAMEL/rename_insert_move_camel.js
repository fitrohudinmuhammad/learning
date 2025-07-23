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
// camel-k: build-property=quarkus.datasource.daco162.db-kind=postgresql
// camel-k: build-property=quarkus.datasource.daco162.username=postgres
// camel-k: build-property=quarkus.datasource.daco162.password=postgres
// camel-k: build-property=quarkus.datasource.daco162.jdbc.url=jdbc:postgresql://172.17.0.1:5432/daco16
// camel-k: build-property=quarkus.datasource.daco162.jdbc.max-size=1

from("ftp://admin@54.169.177.36:221/tes_udin?password=1234&fileName=ddoba.csv&ignoreFileNotFoundOrPermissionError=true&autoCreate=true&stepwise=false&binary=true&passiveMode=true&streamDownload=true&delete=true&ftpClient.remoteVerificationEnabled=false")
.log("File uploaded 1: ${header.CamelFileName}")
.process(function(e) {
    console.log("Rename and Move to Inbound")
    var oldFileName = e.getIn().getHeader("CamelFileName")
    console.log("Old Filename : " + oldFileName)
    var TimeZone = Java.type("java.util.TimeZone")
    
    var dateformat = new java.text.SimpleDateFormat("yyyyMMddHHmmss")
    dateformat.setTimeZone(TimeZone.getTimeZone("GMT+7"))
    var timestamp = dateformat.format(new Date())

    var newFileName = oldFileName.substring(0, oldFileName.lastIndexOf('.')) + "-" + timestamp + ".csv"
    e.getIn().setHeader("CamelFileName", newFileName)
    console.log("New Filename : " + e.getIn().getHeader("CamelFileName"))
})
.to("ftp://admin@54.169.177.36:221/tes_udin/inbound?password=1234&fileName=${header.CamelFileName}&ignoreFileNotFoundOrPermissionError=true&autoCreate=true&stepwise=false&binary=true&passiveMode=true&streamDownload=true&delete=true&ftpClient.remoteVerificationEnabled=false")
.split().tokenize("\n", 5000, false).streaming()
.process(function(e) {
    var body = e.getIn().getBody()
    var rows = body.split("\n")
    var temp_rows = []
    var columns = ["name", "email"]
    rows.forEach(row => {
        var temp_row = {}
        var row_data = row.split(",")
        columns.forEach((col, seq) => {
            var temp_val = row_data[seq]
            temp_val = temp_val.replace(/(^"+|^'+|^ +|"+$|'+$| +$)/g, '')
            temp_row[col] = temp_val
        })
        temp_rows.push(temp_row)
    })
    e.getIn().setBody(temp_rows)
})
.to("log:ftp?showBody=false")
.marshal().json()
.process(function(e) {
    console.log('Insert into table')
    var msg = e.getIn()
    var rows = msg.getBody(Java.type("java.lang.String"))
    rows = JSON.parse(rows)
    var msg_body = ""
    console.log("Filename : " + e.getIn().getHeader("CamelFileName"))

    rows.forEach((val, i) => {
        console.log(i, val, JSON.stringify(val))
        var value = "'" + val.name + "','" + val.email + "','" + e.getIn().getHeader("CamelFileName") +"'"
        console.log(value)
        msg_body += "insert into temp_camel (name, email, filename) values ("
        msg_body += value
        msg_body += ");"
    })
    
    console.log("------- FTP DONE ---------")
    msg.setBody(msg_body)
})
.to("jdbc:daco162?useHeadersAsParameters=true")
.log("File uploaded 1: ${header.CamelFileName}")
.process(function(e){
    console.log("Move to Success")
    var oldFileName = e.getIn().getHeader("CamelFileName")
    console.log("Old Filename : " + oldFileName)

    var newFileName = "success-" + oldFileName
    e.getIn().setHeader("CamelFileName", newFileName)
    console.log("New Filename : " + e.getIn().getHeader("CamelFileName"))
})
.to("ftp://admin@54.169.177.36:221/tes_udin/success?password=1234&fileName=${header.CamelFileName}&ignoreFileNotFoundOrPermissionError=true&autoCreate=true&stepwise=false&binary=true&passiveMode=true&streamDownload=true&delete=false&ftpClient.remoteVerificationEnabled=false")
.to("log:ftp?showBody=false")
.marshal().json()
.process(function(e){
    console.log("Update stage")
    var msg = e.getIn()
    var msg_body = ""
    msg_body += "UPDATE temp_camel SET stage = 2 WHERE stage = 1;"
    msg.setBody(msg_body)
})
.to("jdbc:daco162?useHeadersAsParameters=true")
.to("Process DONE")