#!/usr/bin/osascript
# vim: set filetype=applescript :
----
-- drill
--   Usage
--      drill file.studycard.txt
--
--   Read a StudyCard data file and speak the question in english
--   and the answer in Italian.
--
--   Currently works around the Cepstral Vittoria bug by invoking 
--   english in a 'do shell script'

property nl: (ASCII character 10)
property tab: (ASCII character 9)
property squote: (ASCII character 39)
property pwd: do shell script "pwd"

on filter(L, crit) 
    script filterer 
        property criterion : crit 
        on filter(L)
            if L = {} then return L 
            if criterion(item 1 of L) then 
                return {item 1 of L} & filter(rest of L) 
            else 
                return filter(rest of L) 
            end if
        end filter
    end script 
    return filterer's filter(L)
end filter 

on isNonEmpty(s) 
    return (length of s) > 0
end isNonEmpty

to split(phrase, sep)
    local keep, fields
    tell AppleScript
        set keep to text item delimiters
        set text item delimiters to sep
        set fields to text items of phrase
        set text item delimiters to keep
    end tell
    return filter(fields, isNonEmpty)
end split    

to join(fields,sep)
    local keep, phrase
    tell AppleScript
        set keep to text item delimiters
        set text item delimiters to sep
        set phrase to fields as string
        set text item delimiters to keep
    end tell
    return phrase
end join

on escq(s)
    -- quoting rules:
    --   a) For the shell, quotes don't quote, they toggle interpretation mode on
    --          and off. Thus:
    --          wrong: echo 'There''s danger'
    --          right: echo 'There'\''s danger'
    --   b) Applescript interpretes \ so it must be quoted by \. Thus:
    --          right: "echo 'There'\\''s danger'"
    -- hence:
    --   set text item delimiters to "'\\''"
    --
    local keep, s2, s3
    set keep to text item delimiters
    set text item delimiters to "'"
    set s2 to text items of s
    set text item delimiters to "'\\''"
    set s3 to s2 as string
    set text item delimiters to keep
    return s3 
end escq

on fileExists(f)
    tell application "Finder" 
        return exists f
    end
end 

on realLine(xline)
    set cs to {}
    repeat with c in characters of xline
        set c to contents of c
        if c is "#" then
            exit repeat
        else
            set end of cs to c
        end if
    end repeat
    return cs as string
end realLine

on usageError()
    local stdout
    set stdout to {}
    set end of stdout to "\nUsage: \n"
    set end of stdout to "   drill args \n"
    set end of stdout to "   drill selftest  \n"
    error (stdout as string) 
end 

script VoiceRegistry
    property voiceTable: {}

    to registerVoice(k,v)
        set end of voiceTable to {k, v}
        return k
    end

    to registerVoices(klist, v)
        local r
        repeat with k in klist
            set r to my registerVoice(contents of k, v)
        end
        return r
    end

    to lookupVoice(k)
        try
            return lookupKey(k, voiceTable)
        on error msg number -50
            -- error "lookupVoice(" & k & ") : " & msg number -50
            error "lookupVoice : " & msg number -50
        end
    end

    on lookupKey(k, l)
        repeat with ent in l
            if contents of item 1 of ent is k then
                return item 2 of ent
            end if
        end repeat
        error number -50
    end lookupKey
end

script AVoice
    property theVoice : missing value
    property voiceVol : 100
    property voiceRate : 100
    property theCommand : missing value
    --- protected
    property openingOpts : missing value
    property closingOpts : missing value
        
    to doSay(m)
        local shellCmd
        set shellCmd to my theCommand & " " & squote & my openingOpts & " " & m & " " & my closingOpts & squote
        -- tell application "Finder" to display dialog shellCmd
        do shell script shellCmd
    end doSay

end script

script VittoriaVoice
    property parent : AVoice
    property theVoice : VoiceRegistry's registerVoices({"Vittoria", "Cepstral Vittoria"}, me)
    property voiceVol : 150
    property theCommand : "swift -n Vittoria"
    property openingOpts : missing value
    property closingOpts : "</prosody>"
        
    on doSay(msg)
        set my openingOpts to ("<prosody volume=\"" & my voiceVol as string) & "\">"
        continue doSay(msg)
    end doSay
end script

script AlexVoice
    property parent : AVoice
    property theVoice : VoiceRegistry's registerVoice("Alex", me)
    property theCommand : "say -v Alex"
    property openingOpts : ""
    property closingOpts : ""
        
    on doSay(msg)
        continue doSay(msg)
    end doSay
end script

script ASpeaker
    property theRecorder: missing value
    property delayAfter: 1
    property theLine: missing value
    property theFile: missing value
    to doDelay(k)
        -- delay by a scale factor k
        delay (k*my delayAfter)
    end
    to beginTheLine(lineArg)
        set my theLine to lineArg
        tell my theRecorder to startRecording()
    end
    to speakTheLine()
        -- abstract
    end
    to endTheLine()
        tell my theRecorder to stopRecording()
        doDelay(1)
    end
    to beginTheFile(fileArg)
        set my theFile to fileArg
        tell my theRecorder to returnWhenReady()
    end
    to speakTheFile(fileArg)
        -- abstract
    end
    to endTheFile()
        -- abstract
    end
end

on makeFileSpeaker(recorder)
    script FileSpeaker
        property parent: ASpeaker

        to speakTheLine(theLine, voiceList)
            set theLine to realLine(theLine)
            set wordList to split(theLine, tab)
            if length of wordList is 0 then
                return
            end
            beginTheLine(theLine)
            try
                repeat with i from 1 to length of voiceList
                    set phrase to escq(item i of wordList)

                    -- say item i of wordList using item i of voiceList
                    -- do shell script "say -v \"" & item i of voiceList & "\" " & escq(item i of wordList)
                    set voiceName to contents of item i of voiceList
                    set voice to VoiceRegistry's lookupVoice(voiceName)
                    voice's doSay(phrase)
                    doDelay(2.5)
                end repeat
                continue speakTheLine()
            on error msg
                tell application "Finder" to display dialog msg
            end
            endTheLine()
        end speakTheLine

        to speakTheFile(filename)
            local theFile, theRef
            set theFile to POSIX file filename
            set theRef to missing value
            beginTheFile(filename)
            try 
               set theRef to open for access theFile
               repeat
                   set firstLine to (read theRef before nl)
                   set voiceList to split(realLine(firstLine), tab)
                   if length of voiceList > 0 then
                       exit repeat
                   end
               end
               repeat
                   set nextLine to (read theRef before nl)
                   speakTheLine(nextLine, voiceList)
               end repeat
            on error emsg
                if not emsg = "End of file error." then
                end
            end
            if theRef is not missing value then
                close access theRef
            end
            continue speakTheFile(filename)
            endTheFile()
        end speakTheFile
    end script
    copy FileSpeaker to newSpeaker
    set newSpeaker's theRecorder to recorder
    return newSpeaker
end

script ARecorder
    -- Abstraction and interface
    property r : missing value
        -- r is reference to recorder
    on init()
        --
    end init
    on setLibrary()
        -- 
    end
    on returnWhenReady()
        --
    end 
    on startRecording()
        --
    end 
    on stopRecording()
        --
    end 
end script

using terms from application "WireTap Studio"
    on makeWiretap()
        script WiretapRecorder
            property parent : ARecorder
            on init()
                activate
                set my r to get a reference to main recorder ¬
                    of application "WireTap Studio"
            end init
            on returnWhenReady()
                repeat while my r's contents's current state as string is not equal to "Idle"
                    delay 1
                end
            end 
            on startRecording()
                start my r
            end
            on stopRecording()
                stop my r
            end
        end script
        copy WiretapRecorder to result
    end makeWiretap
end 

on run argv
    if length of argv < 1 then
        usageError()
    end if

    if item 1 of argv = "selftest" then
        selftest(argv)
        return result
    end

    repeat with f in argv
        set f to pwd & "/" & f
        if not fileExists(POSIX file f) then
            usageError()
        end
    end

    local recorder
    local fileSpeaker

    set recorder to makeWiretap()
    tell recorder to init()
    set speaker to makeFileSpeaker(recorder)
    repeat with filename in argv
        tell speaker to speakTheFile(contents of filename)
    end
end

on selftest(argv)
    global asunit
    set asunit to load script file ¬
        ((path to scripts folder as string) & "ASUnist.scpt")
end