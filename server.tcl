namespace eval ::remotemouseWebSocket {
    variable server_port
    variable token
    variable got_client
    variable clSock
    variable clPort
    variable image_format
    variable srvSock
    variable lastRequestedMode   ""
}

proc ::remotemouseWebSocket::setServerPort {port} {
    variable server_port
    set server_port $port
    GidUtils::SetWarnLine "Remote mouse server port $port"
}
proc ::remotemouseWebSocket::setGiDToken {gid_token} {
    variable token
    if {$token == 0} {
        set token $gid_token
        GidUtils::SetWarnLine "Token $token"
    } else {
        GidUtils::SetWarnLine "Someone is trying to hack your token"
    }
}

proc ::remotemouseWebSocket::Init { } {
    variable token
    variable server_port
    variable got_client
    variable image_format

    set token 0

    # Default port
    ::remotemouseWebSocket::setServerPort wait
    set got_client 0
    set image_format "png"

    package require websocket
    # this does nothing:
    # ::websocket::loglevel pollo
    # instead tcllib/logger tree::stdoutcmd and tree::stderrcmd have been modified
}

proc ::remotemouseWebSocket::startIfIsWebsocket {} { 
    variable clSock
    variable srvSock
    set httphead {}
    chan configure $clSock -blocking 0
    set incomingtext [chan read $clSock]
    chan configure $clSock -blocking 1
    foreach linetext [split $incomingtext \n] {
        if [regexp {[A-Z,a-z,-]*:} $linetext result] {           
            lappend httphead [string range $result 0 end-1] [string range $linetext [string length $result] end]        
        }	
    }
    # Must define a protocol for implementation of websocket in tcl to work
    lappend httphead "Sec-WebSocket-protocol" " "    
    if [::websocket::test $srvSock $clSock * $httphead] {
        ::websocket::upgrade $clSock
    }
}

proc ::remotemouseWebSocket::handleConnect {cs addr p} {     
    variable clSock
    variable clPort
    variable got_client
    if {!$got_client} {
        GidUtils::SetWarnLine "handleConnect cs:$cs addr:$addr p:$p"
        set clSock $cs 
        set clPort $p
        incr got_client
        fileevent $clSock readable ::remotemouseWebSocket::startIfIsWebsocket
    }
}

proc ::remotemouseWebSocket::WS_handler { sock type msg } {
    variable clSock
    variable got_client
    #W "pp sock:$sock type:$type msg:$msg"
    # GidUtils::SetWarnLine "WS_handler received type=--$type-- mesg=--$msg--"
    switch -glob -nocase -- $type {
	co* {
	    #W "Connected on $sock"
	}
	te* {
        # msg comes between quotation marks. They should be removed
        if { ( [ string index $msg 0] == "\"") && ( [ string index $msg end] == "\"") } {
            set msg [ string range $msg 1 end-1]
        }
	    set message [::remotemouseWebSocket::processMessage [lindex [split $msg "¬"] end]]
	    if {[llength $message]} {
		# ::websocket::send $clSock text $message
		    #SendContent $message TEXT
	    }
	}
	cl* -
	dis* {
	    incr got_client -1
	}
    }
}

proc ::remotemouseWebSocket::processMessage { msg } {
    variable lastRequestedMode
    set rt ""
    set processed 0
    
    # GidUtils::SetWarnLine "::remotemouseWebSocket::processMessage received $msg"

    # needed for angular call set msg [lindex $msg 0]
    # cutre apaño para tirar adelente   
    if {[lindex [lindex $msg 0] 0] == "GiD_tcl"} {
        GidUtils::SetWarnLine "::remotemouseWebSocket::processMessage GiD_tcl command received:[lrange [lindex $msg 0] 1 end]"
        eval [lrange [lindex $msg 0] 1 end]
        set processed 1
    }
    # fin cutre apaño

    if {[lindex $msg 0] == "GiD_Process"} {
        eval $msg
        set processed 1
    }
    if {[lindex $msg 0] == "Print"} {
        GidUtils::SetWarnLine [lrange $msg 1 end]
        set processed 1
    }
    if {[lindex $msg 0] == "GiD_tcl"} {
        eval [lrange $msg 1 end]
        set processed 1
    }
    if {[lindex $msg 0] == "Register_Event"} {
        set gid_event [lindex $msg 1] 
        set callback [lindex $msg 2]
        set num_args [lindex $msg 3]
        set args ""
        set evalargs ""
        for {set x 0} {$x<$num_args} {incr x} {
            append args "arg$x "
            append evalargs "\$arg$x "
        }
        proc ::$gid_event $args [subst -nocommand {SendContent $evalargs $callback}]        
        set processed 1
    }
    if {[lindex $msg 0] == "ResizeArea"} {
        set width [lindex $msg 1] 
        set height [lindex $msg 2] 
        catch {GidUtils::SetMainDrawAreaSize $width $height}
        set processed 1
    }
    if {$msg eq "DIE"} {
        set processed 1
        exit
    }
    if {$msg eq "LIVE"} {
        SendContent $img_data "true"
        set processed 1
    }
    
    if { !$processed} {
        GidUtils::SetWarnLine "::remotemouseWebSocket::processMessage don't know what is ---$msg---"
    }
    return $rt
}

proc SendContent {str {hdr ""}} {
    if {$::remotemouseWebSocket::got_client > 0} {
	if { $hdr eq ""} { set hdr TEXT}
        # if {$hdr ne ""} {set hdr "$hdr "}
	# ::websocket::send $::remotemouseWebSocket::clSock text [concat $hdr $str]
	::websocket::send $::remotemouseWebSocket::clSock text [ toJSONformat $hdr $str]
    }
}

::remotemouseWebSocket::Init
proc ::remotemouseWebSocket::Start { } {
    set ::remotemouseWebSocket::srvSock [socket -server ::remotemouseWebSocket::handleConnect $::remotemouseWebSocket::server_port]
    ::websocket::server $::remotemouseWebSocket::srvSock
    ::websocket::live $::remotemouseWebSocket::srvSock * ::remotemouseWebSocket::WS_handler
}
#vwait forever

# launch also the http server if present
catch {
    #SRC img_server
}

proc toJSONformat { key value} {
    package require base64
    # JSON does not like splitted strings between ""
    # and base64::encode returns several lines, so removing them
    return "{ \"key\": \"$key\", \"value\": \"[ regsub -all {\n} [ ::base64::encode $value] {} ]\"}"
}



