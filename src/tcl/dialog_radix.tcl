
package provide dialog_radix 0.1

package require wheredoesthisgo

namespace eval ::dialog_radix:: {
	variable sizes {0 8 10 12 16 24 36}
	namespace export pdtk_radix_dialog
}

# array for communicating the position of the radiobuttons (Tk's
# radiobutton widget requires this to be global)
array set lbl_radio {}

############ pdtk_radix_dialog -- run a radix dialog #########

proc ::dialog_radix::escape {sym} {
	if {[string length $sym] == 0} {
		set ret "_"
	} else {
		if {[string equal -length 1 $sym "_"]} {
			set ret [string replace $sym 0 0 "__"]
		} else {
			set ret $sym
		}
	}
	return [string map {"$" {\$}} [unspace_text $ret]]
}

proc ::dialog_radix::unescape {sym} {
	if {[string equal -length 1 $sym "_"]} {
		set ret [string replace $sym 0 0 ""]
	} else {
		set ret $sym
	}
	return [respace_text $ret]
}

proc ::dialog_radix::apply {toplvl} {
	global lbl_radio

	pdsend "$toplvl param \
		[::dialog_radix::escape [$toplvl.digits.base.entry get]] \
		[::dialog_radix::escape [$toplvl.digits.prec.entry get]] \
		[::dialog_radix::escape [$toplvl.step.axisx.entry get]] \
		[::dialog_radix::escape [$toplvl.step.axisy.entry get]] \
		[::dialog_radix::escape [$toplvl.limits.lower.entry get]] \
		[::dialog_radix::escape [$toplvl.limits.upper.entry get]] \
		[::dialog_radix::escape [$toplvl.width.entry get]] \
		$::dialog_radix::fontsize \
		[::dialog_radix::escape [$toplvl.s_r.recv.entry get]] \
		[::dialog_radix::escape [$toplvl.s_r.send.entry get]] \
		[::dialog_radix::escape [$toplvl.lbl.name.entry get]] \
		$lbl_radio($toplvl) \
	"
}

proc ::dialog_radix::cancel {toplvl} {
	pdsend "$toplvl cancel"
}

proc ::dialog_radix::ok {toplvl} {
	::dialog_radix::apply $toplvl
	::dialog_radix::cancel $toplvl
}

# set up the panel with the info from pd
proc ::dialog_radix::setup { \
	toplvl \
	base prec \
	axisx axisy \
	lower upper \
	wid fontsize \
	rcv snd \
	label where \
} {
	global lbl_radio
	set lbl_radio($toplvl) $where
	set ::dialog_radix::fontsize $fontsize

	if {[winfo exists $toplvl]} {
		wm deiconify $toplvl
		raise $toplvl
		focus $toplvl
	} else {
		create_dialog $toplvl
	}

	$toplvl.width.entry insert 0 $wid
	$toplvl.width.entry selection range 0 end

	$toplvl.digits.base.entry insert 0 $base
	$toplvl.digits.prec.entry insert 0 $prec

	$toplvl.step.axisx.entry insert 0 $axisx
	$toplvl.step.axisy.entry insert 0 $axisy

	if {$lower ne "_"} {
		$toplvl.limits.lower.entry insert 0 [::dialog_radix::unescape $lower]
	}
	if {$upper ne "_"} {
		$toplvl.limits.upper.entry insert 0 [::dialog_radix::unescape $upper]
	}

	if {$snd ne "_"} {
		$toplvl.s_r.send.entry insert 0 [::dialog_radix::unescape $snd]
	}
	if {$rcv ne "_"} {
		$toplvl.s_r.recv.entry insert 0 [::dialog_radix::unescape $rcv]
	}
	if {$label ne "_"} {
		$toplvl.lbl.name.entry insert 0 [::dialog_radix::unescape $label]
	}

	$toplvl.width.entry select range 0 end
	focus $toplvl.width.entry
}

proc ::dialog_radix::create_dialog {toplvl} {
	global lbl_radio

	toplevel $toplvl -class DialogWindow
	wm title $toplvl [_ "Radix Properties"]
	wm group $toplvl .
	wm resizable $toplvl 0 0
	wm transient $toplvl $::focused_window
	::pd_menus::menubar_for_dialog $toplvl
	$toplvl configure -padx 0 -pady 0
	::pd_bindings::dialog_bindings $toplvl "radix"

	#############################################################################
	# Cancel / Apply / Ok
	frame $toplvl.buttonframe -pady 5
	pack $toplvl.buttonframe -side bottom -pady 2m
	button $toplvl.buttonframe.cancel -text [_ "Cancel"] \
		-command "::dialog_radix::cancel $toplvl" -highlightcolor green
	pack $toplvl.buttonframe.cancel -side left -expand 1 -fill x -padx 15 -ipadx 10
	if {$::windowingsystem ne "aqua"} {
		button $toplvl.buttonframe.apply -text [_ "Apply"] \
			-command "::dialog_radix::apply $toplvl"
		pack $toplvl.buttonframe.apply -side left -expand 1 -fill x -padx 15 -ipadx 10
	}
	button $toplvl.buttonframe.ok -text [_ "OK"] \
		-command "::dialog_radix::ok $toplvl" -default active
	pack $toplvl.buttonframe.ok -side left -expand 1 -fill x -padx 15 -ipadx 10

	#############################################################################
	# Send / Receive
	labelframe $toplvl.s_r -text [_ "Messages"] -padx 5 -pady 5 -borderwidth 1
	pack $toplvl.s_r -side bottom -fill x

	frame $toplvl.s_r.recv
	pack $toplvl.s_r.recv -side top -anchor e
	label $toplvl.s_r.recv.label -text [_ "Receive symbol:"]
	entry $toplvl.s_r.recv.entry -width 21
	pack $toplvl.s_r.recv.entry $toplvl.s_r.recv.label -side right

	frame $toplvl.s_r.send
	pack $toplvl.s_r.send -side top -anchor e
	label $toplvl.s_r.send.label -text [_ "Send symbol:"]
	entry $toplvl.s_r.send.entry -width 21
	pack $toplvl.s_r.send.entry $toplvl.s_r.send.label -side right

	#############################################################################
	# Font size
	labelframe $toplvl.fontsize -text [_ "Font Size"] -padx 5 -pady 4 -borderwidth 1 \
		-width [::msgcat::mcmax "Font Size"] -labelanchor n
	pack $toplvl.fontsize -side right -padx 5
	foreach size $::dialog_radix::sizes {
		if {$size eq 0} {
			set sizetext [_ "auto"]
		} else {
			set sizetext $size
		}
		radiobutton $toplvl.fontsize.radio$size -value $size -text $sizetext \
			-variable ::dialog_radix::fontsize
		pack $toplvl.fontsize.radio$size -side top -anchor w
	}

	#############################################################################
	# Width
	frame $toplvl.width -height 7
	pack $toplvl.width -side top
	label $toplvl.width.label -text [_ "Width:"]
	entry $toplvl.width.entry -width 4
	pack $toplvl.width.label $toplvl.width.entry -side left

	#############################################################################
	# Digits
	labelframe $toplvl.digits -text [_ "Digits"] -padx 15 -pady 4 -borderwidth 1
	pack $toplvl.digits -side top -fill x

	frame $toplvl.digits.base
	pack $toplvl.digits.base -side left
	label $toplvl.digits.base.label -text [_ "Base:"]
	entry $toplvl.digits.base.entry -width 7
	pack $toplvl.digits.base.label $toplvl.digits.base.entry -side left

	frame $toplvl.digits.prec
	pack $toplvl.digits.prec -side left
	label $toplvl.digits.prec.label -text [_ "Precision:"]
	entry $toplvl.digits.prec.entry -width 7
	pack $toplvl.digits.prec.label $toplvl.digits.prec.entry -side left

	#############################################################################
	# Pixels per step
	labelframe $toplvl.step -text [_ "Pixels per step"] -padx 15 -pady 4 -borderwidth 1
	pack $toplvl.step -side top -fill x

	frame $toplvl.step.axisx
	pack $toplvl.step.axisx -side left
	label $toplvl.step.axisx.label -text [_ "Axis x:"]
	entry $toplvl.step.axisx.entry -width 7
	pack $toplvl.step.axisx.label $toplvl.step.axisx.entry -side left

	frame $toplvl.step.axisy
	pack $toplvl.step.axisy -side left
	label $toplvl.step.axisy.label -text [_ "Axis y:"]
	entry $toplvl.step.axisy.entry -width 7
	pack $toplvl.step.axisy.label $toplvl.step.axisy.entry -side left

	#############################################################################
	# Limits
	labelframe $toplvl.limits -text [_ "Limits"] -padx 15 -pady 4 -borderwidth 1
	pack $toplvl.limits -side top -fill x

	frame $toplvl.limits.lower
	pack $toplvl.limits.lower -side left
	label $toplvl.limits.lower.label -text [_ "Lower:"]
	entry $toplvl.limits.lower.entry -width 7
	pack $toplvl.limits.lower.label $toplvl.limits.lower.entry -side left

	frame $toplvl.limits.upper
	pack $toplvl.limits.upper -side left
	label $toplvl.limits.upper.label -text [_ "Upper:"]
	entry $toplvl.limits.upper.entry -width 7
	pack $toplvl.limits.upper.label $toplvl.limits.upper.entry -side left

	#############################################################################
	# Label
	labelframe $toplvl.lbl -text [_ "Label"] -padx 5 -pady 5 -borderwidth 1
	pack $toplvl.lbl -side top -fill x -pady 5
	frame $toplvl.lbl.name
	pack $toplvl.lbl.name -side top
	entry $toplvl.lbl.name.entry -width 33
	pack $toplvl.lbl.name.entry -side left
	frame $toplvl.lbl.radio
	pack $toplvl.lbl.radio -side top
	radiobutton $toplvl.lbl.radio.left -value 0 -text [_ "Left"] \
		-variable lbl_radio($toplvl) -justify left -takefocus 0
	radiobutton $toplvl.lbl.radio.right -value 1 -text [_ "Right"] \
		-variable lbl_radio($toplvl) -justify left -takefocus 0
	radiobutton $toplvl.lbl.radio.top -value 2 -text [_ "Top"] \
		-variable lbl_radio($toplvl) -justify left -takefocus 0
	radiobutton $toplvl.lbl.radio.bottom -value 3 -text [_ "Bottom"] \
		-variable lbl_radio($toplvl) -justify left -takefocus 0
	pack $toplvl.lbl.radio.left -side left -anchor w
	pack $toplvl.lbl.radio.right -side right -anchor w
	pack $toplvl.lbl.radio.top -side top -anchor w
	pack $toplvl.lbl.radio.bottom -side bottom -anchor w

	# live widget updates on OSX in lieu of Apply button
	if {$::windowingsystem eq "aqua"} {

		# call apply on radiobutton changes
		$toplvl.lbl.radio.left config -command [ concat ::dialog_radix::apply $toplvl ]
		$toplvl.lbl.radio.right config -command [ concat ::dialog_radix::apply $toplvl ]
		$toplvl.lbl.radio.top config -command [ concat ::dialog_radix::apply $toplvl ]
		$toplvl.lbl.radio.bottom config -command [ concat ::dialog_radix::apply $toplvl ]

		# allow radiobutton focus
		$toplvl.lbl.radio.left config -takefocus 1
		$toplvl.lbl.radio.right config -takefocus 1
		$toplvl.lbl.radio.top config -takefocus 1
		$toplvl.lbl.radio.bottom config -takefocus 1

		# call apply on Return in entry boxes that are in focus & rebind Return to ok button
		bind $toplvl.lbl.name.entry <KeyPress-Return> "::dialog_radix::apply_and_rebind_return $toplvl"
		bind $toplvl.s_r.send.entry <KeyPress-Return> "::dialog_radix::apply_and_rebind_return $toplvl"
		bind $toplvl.s_r.recv.entry <KeyPress-Return> "::dialog_radix::apply_and_rebind_return $toplvl"
		bind $toplvl.digits.base.entry <KeyPress-Return> "::dialog_radix::apply_and_rebind_return $toplvl"
		bind $toplvl.digits.prec.entry <KeyPress-Return> "::dialog_radix::apply_and_rebind_return $toplvl"
		bind $toplvl.limits.lower.entry <KeyPress-Return> "::dialog_radix::apply_and_rebind_return $toplvl"
		bind $toplvl.limits.upper.entry <KeyPress-Return> "::dialog_radix::apply_and_rebind_return $toplvl"
		bind $toplvl.width.entry <KeyPress-Return> "::dialog_radix::apply_and_rebind_return $toplvl"

		# unbind Return from ok button when an entry takes focus
		$toplvl.lbl.name.entry config -validate focusin -vcmd "::dialog_radix::unbind_return $toplvl"
		$toplvl.s_r.send.entry config -validate focusin -vcmd "::dialog_radix::unbind_return $toplvl"
		$toplvl.s_r.recv.entry config -validate focusin -vcmd "::dialog_radix::unbind_return $toplvl"
		$toplvl.digits.base.entry config -validate focusin -vcmd "::dialog_radix::unbind_return $toplvl"
		$toplvl.digits.prec.entry config -validate focusin -vcmd "::dialog_radix::unbind_return $toplvl"
		$toplvl.limits.lower.entry config -validate focusin -vcmd "::dialog_radix::unbind_return $toplvl"
		$toplvl.limits.upper.entry config -validate focusin -vcmd "::dialog_radix::unbind_return $toplvl"
		$toplvl.width.entry config -validate focusin -vcmd "::dialog_radix::unbind_return $toplvl"

		# remove cancel button from focus list since it's not activated on Return
		$toplvl.buttonframe.cancel config -takefocus 0

		# show active focus on the ok button as it *is* activated on Return
		$toplvl.buttonframe.ok config -default normal
		bind $toplvl.buttonframe.ok <FocusIn> "$toplvl.buttonframe.ok config -default active"
		bind $toplvl.buttonframe.ok <FocusOut> "$toplvl.buttonframe.ok config -default normal"

		# since we show the active focus, disable the highlight outline
		$toplvl.buttonframe.ok config -highlightthickness 0
		$toplvl.buttonframe.cancel config -highlightthickness 0
	}

	position_over_window $toplvl $::focused_window
}

# for live widget updates on OSX
proc ::dialog_radix::apply_and_rebind_return {toplvl} {
	::dialog_radix::apply $toplvl
	bind $toplvl <KeyPress-Return> "::dialog_radix::ok $toplvl"
	focus $toplvl.buttonframe.ok
	return 0
}

# for live widget updates on OSX
proc ::dialog_radix::unbind_return {toplvl} {
	bind $toplvl <KeyPress-Return> break
	return 1
}
