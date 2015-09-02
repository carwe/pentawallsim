set serverip 127.0.0.1
set serverport 1338
set xdim 16
set ydim 15

# ######### please edit below this line, if you feel lucky ############

# for movable single pixel
set x 1
set y 1

# for black2white-fade
set fadestate 0

package require Tcl
package require Tk

proc every {ms body} {
	eval $body
	after $ms [info level 0]
}

proc rgb_nextfade {} {
	# every call to this function fills screen with another gray-tone
	set ::fadestate [expr {($::fadestate + 4) % 256 }]
	rgb_fillscreen $::fadestate $::fadestate $::fadestate
	return
}

proc rgb_putpixel { x y r g b } {
	puts $::rgb_socket "02[format "%02x%02x%02x%02x%02x" $x $y $r $g $b]"
	return
}

proc rgb_putframe { frame } {
	# a frame consist of xdim*ydim pixels, each pixel of 6 characters (3 colors * 2 characters, ascii-representation)
	puts $::rgb_socket "03$frame"
	return
}

proc rgb_fillscreen { r g b } {
	rgb_putpixel 0 0 $r $g $b
	return
}

proc rgb_fadescreenh {r1 g1 b1 r2 g2 b2} {
	# fills the screen with rows of colors, fading from one color to the other
	for {set i 1} {$i <= $::ydim} {incr i} {
		set color [format "%02x%02x%02x" [expr { int( $r1 + max( -$r1,($i * ( ($r2 - $r1) / $::ydim))) ) }] [expr { int( $g1 + max( -$g1,($i * ( ($g2 - $g1) / $::ydim))) ) }] [expr { int( $b1 +   max(-$b1,($i * ( ($b2 - $b1) / $::ydim)) )   ) }]]
		for {set j 1} {$j <= $::xdim} {incr j} {
			append frame $color
		}
	}
	rgb_putframe $frame
	return
}

proc rgb_randomizescreen {} {
	# fills screen with random pixels - uses putframe-function
	for {set i 1} {$i <= [expr {$::xdim*$::ydim}]} {incr i} {
		set color [format "%02x%02x%02x" [rnd 255] [rnd 255] [rnd 255]]
		append frame $color
	}
	rgb_putframe $frame
	return
}

proc rgb_randomfillwithpixels { } {
	# fills screen with random pixels - uses putpixel-function instead putframe
	for {set i 1} {$i <= $::xdim} {incr i} {
		for {set j 1} {$j <= $::ydim} {incr j} {
			rgb_putpixel $i $j [rnd 255] [rnd 255] [rnd 255]
		}
	}
	return
}

proc rgb_init {serverip serverport} {
	set ::rgb_socket [socket $serverip $serverport]
	fconfigure $::rgb_socket -blocking 0 -buffering line -translation {crlf crlf}
	return
}

proc rnd {max} {
	return [expr { int(((rand()*$max)))}]
}

# 16x15
set testpicture "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffff000000000000000000ffffffffffffffffff000000000000000000000000000000000000ffffffffffffffffffffffffffffff000000ffffffffffffffffffffffffffffff000000000000000000000000000000ffffffffffff000000ffffffffffff000000ffffffffffff000000ffffffffffff000000000000000000000000000000ffffffffffff000000ffffffffffff000000ffffffffffff000000000000000000000000000000000000000000000000ffffffffffff000000ffffffffffff000000ffffffffffff000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffff000000ffffffffffff000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffff000000ffffffffffff000000000000000000000000000000000000000000000000ffffffffffff000000ffffffffffff000000ffffffffffff000000000000000000000000000000000000000000000000ffffffffffff000000ffffffffffff000000ffffffffffff00000000000000000000000000000000000000000000000ffffffffffff000000ffffffffffff000000ffffffffffff000000ffffffffffff0000000000000000000000000000000ffffffffffff000000ffffffffffff000000ffffffffffffffffffffffffffffff000000000000000000000000000000ffffffffffff000000ffffffffffff000000000000ffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"

bind . a rgb_randomizescreen
bind . s {rgb_putframe $::testpicture}
bind . d {rgb_fadescreenh [rnd 255] [rnd 255] [rnd 255] [rnd 255] [rnd 255] [rnd 255]}
bind . f {rgb_fillscreen [rnd 255] [rnd 255] [rnd 255] }
bind . g {rgb_nextfade}
bind . h {rgb_randomfillwithpixels}

bind . k {rgb_putpixel $x $y 0 0 0; set y [expr {min($::ydim,($y+1))}]; rgb_putpixel $x $y 0 255 0 }
bind . j {rgb_putpixel $x $y 0 0 0; set x [expr {max(1,($x-1))}]; rgb_putpixel $x $y 0 255 0 }
bind . i {rgb_putpixel $x $y 0 0 0; set y [expr {max(1,($y-1))}]; rgb_putpixel $x $y 0 255 0 }
bind . l {rgb_putpixel $x $y 0 0 0; set x [expr {min($::xdim,($x+1))}]; rgb_putpixel $x $y 0 255 0 }

bind . q {rgb_fillscreen 255 255 255}
bind . w {rgb_fillscreen 255 255   0}
bind . e {rgb_fillscreen 255   0 255}
bind . r {rgb_fillscreen   0 255 255}
bind . t {rgb_fillscreen 255   0   0}
bind . z {rgb_fillscreen   0 255   0}
bind . u {rgb_fillscreen   0   0 255}

rgb_init $serverip $serverport
