// from source database
function(e) {
    var query = "WITH update_daco_xxx_event AS (UPDATE daco_xxx_event SET state = 'progress' WHERE seq IN (SELECT seq FROM daco_xxx_event_queue WHERE operation IN  ('INSERT','UPDATE', 'DELETE') ORDER BY seq ASC LIMIT 100) AND state='queue' RETURNING *) SELECT id, seq, tstamp, schemaname, tabname::varchar, operation, who, new_val, old_val, hash_val FROM update_daco_xxx_event;"
    e.getIn().setBody(query)
}

// from destination database
function(e) {
    console.log('---- START ----')
    var msg = e.getIn()
    var msg_jbody = msg.getBody(Java.type("java.lang.String"))
    var rows = JSON.parse(msg_jbody)
    var msg_body = ""

    rows.forEach((vals, i) => {
        console.log(i)
        if (vals.new_val == null){
            var val_json_new = "null"
        } else {
            var val_json_new = "'" + JSON.parse(JSON.stringify(vals.new_val)).value + "'::JSON"
        }
        
        if (vals.old_val == null){
            var val_json_old = "null"
        } else {
            var val_json_old = "'" + JSON.parse(JSON.stringify(vals.old_val)).value + "'::JSON"
        }
        const ndate = new Date(vals.tstamp)
        var tstamp = ndate.getFullYear() + '-' + ndate.getMonth() + '-' + ndate.getDate() + ' ' + ndate.getHours() + ':' + ndate.getMinutes() + ':' + ndate.getSeconds()
        
        var values = "'" + vals.id + "','" + vals.seq + "','" + tstamp + "','" + vals.schemaname + "','" + vals.tabname + "','" + vals.operation + "','" + vals.who + "'," + val_json_new + "," + val_json_old + "" 
        console.log(values)
        
        msg_body += "INSERT INTO daco_xxx_event (id, seq, tstamp, schemaname, tabname, operation, who, new_val, old_val) values ("
        msg_body += values
        msg_body += ");"

        msg_body += "UPDATE daco_xxx_event SET state='progress' WHERE state='queue';"
        
        msg_body += "WITH update_daco_xxx_event AS ( "
        msg_body += "UPDATE daco_xxx_event SET state='done' WHERE seq IN ( "
        msg_body += "SELECT seq FROM daco_xxx_event_progress WHERE operation IN  ('INSERT','UPDATE', 'DELETE') ORDER BY seq ASC LIMIT 100) AND state='progress' RETURNING * "
        msg_body += ") "
        msg_body += "INSERT INTO daco_xxx_sync (data) "
        msg_body += "SELECT row_to_json(a) FROM "
        msg_body += "(SELECT id, seq, tabname, operation, json_build_object('value', new_val::json) as new_val, json_build_object('value', old_val::json) as old_val FROM update_daco_xxx_event ORDER BY seq ASC) AS a; "
        
        msg_body += "SELECT sync_xxx();"

    })
    console.log('================')
    console.log(msg_body)
    console.log('---- FINISH ----')
    msg.setBody(msg_body)
}