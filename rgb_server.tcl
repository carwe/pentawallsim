# + - 7 8 9 0 are keys to zoom the simulator-window

set listenport 1338
set listenip 0.0.0.0
set xdim 16
set ydim 15
set scale 25
set minscale 1
set maxscale 40

set remote_id 1
set remote_akkustate 255
array set remote_keys {
	up     w
	left   a
	down   s
	right  d
	start  h
	select j
	a      k
	b      l
}

# ###################################################################

package require Tcl 8.5
package require Tk

# ###################################################################
# remote functions

# bind keys to button-events
foreach arrayitem [array names remote_keys] {
	bind .   <KeyPress-$remote_keys($arrayitem)>   "remote_KeyPress $arrayitem"
	bind . <KeyRelease-$remote_keys($arrayitem)> "remote_KeyRelease $arrayitem"
}

array set remote_buttoninfo {
	up     {0   1}
	left   {2   4}
	down   {1   2}
	right  {3   8}
	start  {5  32}
	select {4  16}
	a      {6  64}
	b      {7 128}
}

array set remote_buttonstate {
	up     0
	left   0
	down   0
	right  0
	start  0
	select 0
	a      0
	b      0
}

proc remote_KeyPress {keyid} {
	set ::remote_buttonstate($keyid) 1
	remote_updatekeystate
}

proc remote_KeyRelease {keyid} {
	set ::remote_buttonstate($keyid) 0
	remote_updatekeystate
}

proc remote_updatekeystate {} {
	if {! [info exists ::remote_oldkeystate]} { set ::remote_oldkeystate 0 }
	set remote_keystate 0
	
	foreach remote_buttonname [array names ::remote_buttonstate] {
		if { $::remote_buttonstate($remote_buttonname) } {
			set remote_keystate [expr { $remote_keystate + [lindex $::remote_buttoninfo($remote_buttonname) 1] }]
		}
	}
	
	if { $remote_keystate == $::remote_oldkeystate} {
		return
	}

	set ::remote_oldkeystate $remote_keystate
	set remote_keystate [format "09%02x%02x%02x" $::remote_id $remote_keystate $::remote_akkustate]
	foreach clientsocket [array names ::clientconnections] {
		puts $clientsocket $remote_keystate
	}
}

proc remote_subscribe {rgbsocket} {
	set $::clientconnections($rgbsocket) 1
}

proc remote_unsubscribe {rgbsocket} {
	set $::clientconnections($rgbsocket) 0
}

# ###################################################################
# socket functions

array set clientconnections {}

proc incomingconnection {rgbsocket clientaddr clientport} {
	puts "[puttime] $rgbsocket OPENED from ip $clientaddr port $clientport"
	fconfigure $rgbsocket -blocking 0 -translation {crlf crlf}
	fileevent $rgbsocket readable "readrgbsocket $rgbsocket"
	set ::clientconnections($rgbsocket) 0
	return
}

proc readrgbsocket {rgbsocket} {
	set len [gets $rgbsocket line]
	if {$len <= 0} {
		if { [eof $rgbsocket] } {
			puts "[puttime] $rgbsocket CLOSED"
			close $rgbsocket;
			array unset ::clientconnections $rgbsocket
		}
	} else {
		if {! [decodergbsocketline $rgbsocket $line] } {
			puts "[puttime] bad line in $rgbsocket: $line"
			puts $rgbsocket "bad"
		} else {
			puts $rgbsocket "ok"
		}
		
		catch { flush $rgbsocket }
	}
	return
}

proc decodergbsocketline {rgbsocket line} {
	set type [string range $line 0 1]
	set paket [string range $line 2 end]
	#puts "[puttime] recieved: $type $paket"
	switch $type {
		01 { # keep alive - not implemented
			return 1
		}
		02 { # single pixel
			if { [string length $paket] != 10 } {
				puts $rgbsocket "bad type-02-paket recieved, expected 10 bytes (XXYYRRGGBB), got [string length $paket] bytes"
				puts "[puttime] bad type-02-paket recieved, expected 10 bytes (XXYYRRGGBB), got [string length $paket] bytes"
				return 0
			}
			scan $paket "%02x%02x%02x%02x%02x" x y r g b
			set color [format "#%02x%02x%02x" $r $g $b]

			if { $x==0 && $y==0 } {
				paintframe $color
				updatesurface
			} elseif { $x==0 } {
				puts "[puttime] warning: malformed type-02-paket, x==0 (expected (x==0 AND y==0) OR (x!=0 AND y!=0))"
			} elseif { $y==0 } {
				puts "[puttime] warning: malformed type-02-paket, y==0 (expected (x==0 AND y==0) OR (x!=0 AND y!=0))"
			} else {
				paintpixel $x $y $color
			}
			return 1
		}
		03 { # full frame
			if { [string length $paket] != [expr {$::xdim*$::ydim*3*2}] } {
				puts $rgbsocket "bad type-03-paket recieved, expected [expr {$::xdim*$::ydim*3*2}] bytes (for $::xdim * $::ydim pixels), got [string length $paket] bytes"
				puts  "[puttime] bad type-03-paket recieved, expected [expr {$::xdim*$::ydim*3*2}] bytes (for $::xdim * $::ydim pixels), got [string length $paket] bytes"
				return 0
			}
			set frame {}
			for {set j 1} {$j <= $::ydim} {incr j} {
				set row [string range $paket [expr {($j-1) * $::xdim * 3 * 2}] [expr {(($j) * $::xdim * 3 * 2)-1}]]
				set temprow ""
				for {set i 1} {$i <= $::xdim} {incr i} {
					set pixel [string range $row [expr {($i-1) * 3 * 2}] [expr {(($i) * 3 * 2)-1}]]
					scan $pixel "%02x%02x%02x" r g b
					append temprow "[format "#%02x%02x%02x" $r $g $b] "
				}
				lappend frame $temprow
			}
			paintframe $frame
			updatesurface
			return 1
		}
		04 { # set layer - not implemented
			return 1
		}
		05 { # start recording - not implemented
			return 1
		}
		06 { # stop recording - not implemented
			return 1
		}
		07 { # play recorded file - not implemented
			return 1
		}
		08 { # stop play - not implemented
			return 1
		}
		09 { # (un)subscribe for keyevents
			scan $paket "%02x" request
			if { $request == 0 } {
				remote_unsubscribe $rgbsocket
				return 1
			} elseif {$request == 1 } {
				remote_subscribe $rgbsocket
				return 1
			} else {
				return 0
			}
		}
		default {
			return 0
		}
	}
	return 1
}

# ###################################################################
# drawing functions

proc paintpixel {x y color} {
	$::hiddensurface put $color -to [expr { $x+1 }] [expr { $y+1 }] [expr { $x+2 }] [expr { $y+2 }]
	return
}

proc paintframe {frame} {
	# takes a whole frame - or a single color, which it spreads to fullscreen
	$::hiddensurface put $frame -to 2 2 [expr { $::xdim +2 }] [expr { $::ydim +2 }]
	return
}

# ###################################################################
# window managing functions

wm resizable . 0 0

bind . ? {catch {console show}}
bind . + {changescale +5}
bind . - {changescale -1}
bind . 7 {changescale -5}
bind . 8 {changescale -1}
bind . 9 {changescale +1}
bind . 0 {changescale +5}

proc changescale {amount} {
	set oldscale $::scale
	set ::scale [expr { min($::maxscale,max($::minscale,($::scale + $amount))) }]
	if { $oldscale != $::scale} {
		updatewindow
	}
	return
}

proc updatewindow {} {
	deletewindow
	createwindow
	updatesurface
}

proc createwindow {} {
	set width [expr {$::xdim * $::scale}]
	set height [expr {$::ydim * $::scale}]
	pack [canvas .screen -bg black -width $width -height $height] -fill both -expand 1
	# Zeichenbereich erstellen
	set ::displaysurface [image create photo -width [expr {$width+2}] -height [expr {$height+2}] -palette 256/256/256]
	# Zeichenbereich auf Bildschirm bringen
	.screen create image 0 0 -anchor nw -image $::displaysurface
	wm title . "rgbwall scale $::scale"
	return
}

proc deletewindow {} {
	.screen delete ::displaysurface
	destroy .screen
	return
}

proc updatesurface {} {
	$::displaysurface copy $::hiddensurface -zoom $::scale $::scale -from 2 2 [expr {$::xdim + 2}] [expr {$::ydim + 2}] -to 2 2
	update idletasks
	return
}

# ###################################################################
# helper functions

if {! [info exists ::starttime]} {set ::starttime [clock clicks -milliseconds]}

proc puttime {} {
	puts -nonewline "[expr {([clock clicks -milliseconds] - $::starttime) / 1000}]"
}

proc every {ms body} {
	eval $body
	after $ms [info level 0]
	return
}

# ###################################################################

proc init {} {
	set ::hiddensurface [image create photo -width [expr {$::xdim+2}] -height [expr {$::ydim+2}] -palette 256/256/256]
	createwindow
	socket -server incomingconnection -myaddr $::listenip $::listenport
	return
}

# here we go:
init
every 100 updatesurface ;# otherwise, singlepixel-updates wouldn't be visible - and updatesurface after every incoming pixel is too slow