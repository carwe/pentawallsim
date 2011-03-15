set serverip 127.0.0.1
#172.22.100.56
set serverport 1338
set xdim 16
set ydim 15

# ########################################

package require Tcl
package require Tk

proc every {ms body} {eval $body; after $ms [info level 0]}

proc rgb_putpixel { x y r g b } {
	puts $::rgb_socket "02[format "%02x%02x%02x%02x%02x" $x $y $r $g $b]"
}

proc rgb_putframe { frame } {
	puts $::rgb_socket "03$frame"
}

proc rgb_init {serverip serverport} {
	set ::rgb_socket [socket $serverip $serverport]
	fconfigure $::rgb_socket -blocking 0 -buffering line -translation {crlf crlf}
}

proc rgb_fillscreen { r g b } {
	rgb_putpixel 0 0 $r $g $b
}

proc rgb_randomizescreen {} {
	for {set i 1} {$i <= [expr {$::xdim*$::ydim}]} {incr i} {
		set color [format "%02x%02x%02x" [expr { int(((rand()*255)))}] [expr { int(((rand()*255)))}] [expr { int(((rand()*255)))}]]
		append frame $color
	}
	rgb_putframe $frame
}

proc rgb_red {} {
	for {set i 1} {$i <= [expr {$::xdim*$::ydim}]} {incr i} {
		set color [format "%02x%02x%02x" [expr { int( $i*(256/($::xdim*$::ydim)))  }] 0 0]
		append frame $color
	}
	rgb_putframe $frame
}

set testbild "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffff000000000000000000000000000000ffffffffffff000000ffffffffffff000000ffffffffffff000000ffffffffffff000000000000000000000000000000ffffffffffff000000ffffffffffff000000ffffffffffff000000000000000000000000000000000000000000000000ffffffffffff000000ffffffffffff000000ffffffffffff000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffff000000ffffffffffff000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffff000000ffffffffffff000000000000000000000000000000000000000000000000ffffffffffff000000ffffffffffff000000ffffffffffff000000000000000000000000000000000000000000000000ffffffffffff000000ffffffffffff000000ffffffffffff00000000000000000000000000000000000000000000000ffffffffffff000000ffffffffffff000000ffffffffffff000000ffffffffffff0000000000000000000000000000000ffffffffffff000000ffffffffffff000000ffffffffffffffffffffffffffffff000000000000000000000000000000ffffffffffff000000ffffffffffff000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"

bind . a rgb_randomizescreen
#bind . s {rgb_fillscreen   0   0   0 }
#bind . d {rgb_fillscreen 255   0   0 }
bind . f {rgb_fillscreen   0 255   0 }
bind . g {rgb_fillscreen   0   0 255 }
bind . h {rgb_fillscreen 255 255   0 }
bind . j {rgb_fillscreen 255   0 255 }
bind . k {rgb_fillscreen   0 255 255 }
bind . l {rgb_fillscreen 255 255 255 }
bind . d {rgb_red}
bind . s {rgb_putframe $::testbild}

rgb_init $serverip $serverport