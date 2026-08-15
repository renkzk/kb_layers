#Requires AutoHotkey v2.0
#SingleInstance Force

; Self-contained AutoHotkey v2 replacement for the old v1 Dual-library script.
; Space is a dual-purpose key:
;   Tap Space              -> sends Space
;   Hold Space + mapped key -> sends the alternate layer key
; Semicolon is also dual-purpose:
;   Tap ;                  -> sends ;
;   Hold ; + vowel         -> sends an Italian accented character
;
; Options can be passed as command-line arguments, for example:
;   space_layer_ahk_v2.ahk delay=50 timeout=300 swap_backtick_escape=true mode=ijkl

SendMode "Input"

Options := Map(
    "delay", 50,
    "timeout", 300,
    "doublePress", -1,
    "swap_backtick_escape", false,
    "mode", "ijkl"
)

for arg in A_Args {
    parts := StrSplit(arg, "=", , 2)
    if parts.Length < 2
        continue

    name := parts[1]
    value := parts[2]

    if Options.Has(name) {
        if name = "swap_backtick_escape"
            Options[name] := IsTruthy(value)
        else if name = "mode"
            Options[name] := value
        else
            Options[name] := Integer(value)
    }
}

; This implementation does not synthesize a real F22 key state. It tracks the
; physical Space key directly, then intercepts only the mapped layer keys while
; Space is physically held. Mapped keys are sent with {Blind}, so held modifiers
; such as Shift and Ctrl are preserved, e.g. Shift+Space+i sends Shift+Up.
; The old Dual library's double-press behavior is not reproduced; doublePress
; is accepted for config compatibility only.
SpaceIsDown := false
SpaceUsedAsLayer := false
SpaceDownAt := 0
AccentIsDown := false
AccentUsedAsLayer := false
AccentDownAt := 0
AccentShiftAtDown := false

*Space:: {
    global SpaceIsDown, SpaceUsedAsLayer, SpaceDownAt

    if SpaceIsDown
        return

    SpaceIsDown := true
    SpaceUsedAsLayer := false
    SpaceDownAt := A_TickCount
}

*Space Up:: {
    global SpaceIsDown, SpaceUsedAsLayer, SpaceDownAt

    if SpaceIsDown && !SpaceUsedAsLayer
        Send "{Space}"

    SpaceIsDown := false
    SpaceUsedAsLayer := false
    SpaceDownAt := 0
}

; SC027 is the physical semicolon key on the en-US QWERTY layout.
; Do not capture Ctrl/Alt/Win + ;, so application shortcuts can still use them.
#HotIf !IsShortcutModifierDown()
*SC027:: {
    global AccentIsDown, AccentUsedAsLayer, AccentDownAt, AccentShiftAtDown

    if AccentIsDown
        return

    AccentIsDown := true
    AccentUsedAsLayer := false
    AccentDownAt := A_TickCount
    AccentShiftAtDown := GetKeyState("Shift", "P")
}

*SC027 Up:: {
    global AccentIsDown, AccentUsedAsLayer, AccentDownAt, AccentShiftAtDown

    if AccentIsDown && !AccentUsedAsLayer
        SendText(AccentShiftAtDown ? ":" : ";")

    AccentIsDown := false
    AccentUsedAsLayer := false
    AccentDownAt := 0
    AccentShiftAtDown := false
}
#HotIf

IsTruthy(value) {
    normalized := StrLower(Trim(value))
    return (
        normalized = "1"
        || normalized = "true"
        || normalized = "yes"
        || normalized = "on"
    )
}

IsShortcutModifierDown() {
    return (
        GetKeyState("Ctrl", "P")
        || GetKeyState("Alt", "P")
        || GetKeyState("LWin", "P")
        || GetKeyState("RWin", "P")
    )
}

AccentSend(lowerCode, upperCode) {
    global Options, AccentIsDown, AccentUsedAsLayer, AccentDownAt

    if !AccentIsDown || !GetKeyState("SC027", "P")
        return false

    elapsed := A_TickCount - AccentDownAt
    if elapsed < Options["delay"] {
        Sleep Options["delay"] - elapsed
        if !GetKeyState("SC027", "P")
            return false
    }

    AccentUsedAsLayer := true
    SendText(Chr(GetKeyState("Shift", "P") ? upperCode : lowerCode))
    return true
}

LayerSend(target) {
    global Options, SpaceIsDown, SpaceUsedAsLayer, SpaceDownAt

    if !SpaceIsDown || !GetKeyState("Space", "P")
        return false

    elapsed := A_TickCount - SpaceDownAt

    ; delay gives Space a small tap window before layer actions fire.
    if elapsed < Options["delay"] {
        Sleep Options["delay"] - elapsed
        if !GetKeyState("Space", "P")
            return false
    }

    ; timeout is kept compatible with the old config, but intentionally lenient:
    ; after timeout, a held Space can still be used as the layer modifier. This
    ; avoids surprising failures during normal press-and-hold navigation.
    SpaceUsedAsLayer := true
    Send "{Blind}{" target "}"
    return true
}

LayerBacktick() {
    global Options

    if !LayerSendText("``")
        Send ","
}

LayerSendText(text) {
    global Options, SpaceIsDown, SpaceUsedAsLayer, SpaceDownAt

    if !SpaceIsDown || !GetKeyState("Space", "P")
        return false

    elapsed := A_TickCount - SpaceDownAt
    if elapsed < Options["delay"] {
        Sleep Options["delay"] - elapsed
        if !GetKeyState("Space", "P")
            return false
    }

    SpaceUsedAsLayer := true
    SendText text
    return true
}

#HotIf Options["swap_backtick_escape"]
*`:: {
    if !LayerSend("Escape")
        SendText "``"
}
#HotIf

#HotIf AccentIsDown && GetKeyState("SC027", "P")
*a:: AccentSend(0x00E0, 0x00C0) ; a grave
*i:: AccentSend(0x00EC, 0x00CC) ; i grave
*o:: AccentSend(0x00F2, 0x00D2) ; o grave
*u:: AccentSend(0x00F9, 0x00D9) ; u grave
*e:: AccentSend(0x00E8, 0x00C8) ; e grave
*r:: AccentSend(0x00E9, 0x00C9) ; e acute
#HotIf

#HotIf Options["mode"] = "ijkl" && GetKeyState("Space", "P")
*i:: LayerSend("Up")
*j:: LayerSend("Left")
*k:: LayerSend("Down")
*l:: LayerSend("Right")

*u:: LayerSend("Home")
*o:: LayerSend("End")
*h:: LayerSend("PgUp")
*n:: LayerSend("PgDn")

*p:: LayerSend("Backspace")
*m:: LayerSend("Delete")
*,:: LayerBacktick()
#HotIf

#HotIf GetKeyState("Space", "P")
*Backspace:: LayerSend("Delete")
*\:: LayerSend("Insert")
*b:: LayerSend("Space")

*1:: LayerSend("F1")
*2:: LayerSend("F2")
*3:: LayerSend("F3")
*4:: LayerSend("F4")
*5:: LayerSend("F5")
*6:: LayerSend("F6")
*7:: LayerSend("F7")
*8:: LayerSend("F8")
*9:: LayerSend("F9")
*0:: LayerSend("F10")
*-:: LayerSend("F11")
*=:: LayerSend("F12")
#HotIf