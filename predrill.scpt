#!/usr/bin/osascript

# predrill
# Setup Wiretap Studio

property nl: (ASCII character 10)
property prefix: ""

on run argv
    if length of argv < 1 then
        set out to        "Usage:" & nl
        set out to out & "   predrill WiretapFolder" & nl
        return out
    end
    set prefix to item 1 of argv
            
tell application "WireTap Studio" to activate
tell application "System Events"
    tell process "WireTap Studio"
        -- Open the Preferences window
        click menu item "Preferences…" of menu "WireTap Studio" of menu bar item "WireTap Studio" of menu bar 1
        repeat with i from 1 to 5
            try
                set w to window "Preferences"
                exit repeat
            on error emsg
                delay 0.25
                if i = 5 then
                    return emsg
                end
            end
        end
        
        -- Select the "Saving" tab
        click button "Saving" of tool bar 1 of w
        click radio button "Name Automatically" of radio group 1 of group 1 of w
        
        -- Set "Save Files To:" to Library
        set popup1 to pop up button 2 of group 2 of group 1 of w
        perform action "AXPress" of popup1
        click menu item "Library" of menu 1 of popup1
        
        -- Uncheck "Source Name"
        set cbox to checkbox "Source Name" of group 2 of group 1 of w
        if value of cbox = 1 then
            click cbox
        end if
        
        -- Check "Prefix:" 
        set cbox to checkbox "Prefix:" of group 2 of group 1 of w
        if value of cbox = 0 then
            click cbox
        end if
        
        -- Set "Prefix:" text
        -- http://lists.apple.com/archives/automator-dev/2005/Dec/msg00006.html
        set ctxt to text field 1 of group 2 of group 1 of w
        set focused of ctxt to true
        set value of ctxt to prefix
        perform action "AXConfirm" of ctxt
        
        -- Set "Suffix:" to Increment
        set popup to pop up button 1 of group 2 of group 1 of w
        perform action "AXPress" of popup
        click menu item "Increment" of menu 1 of popup
        
        -- Set "Split:" to "Off"
        set pop2 to pop up button 1 of group 1 of w
        perform action "AXPress" of pop2
        click menu item "Off" of menu 1 of pop2
        
        -- Check "Record Lossless Original
        set cbox to checkbox "Record Lossless Original" of group 1 of w
        if value of cbox = 0 then
            click cbox
        end if
        
        -- Unheck "Open Recording in Editor"
        set cbox to checkbox "Open Recording in Editor" of group 1 of w
        if value of cbox = 1 then
            click cbox
        end if

        -- Close the dialog
        set cb to first button of w where description = "close button"
        click cb
        
    end tell
end tell

end
