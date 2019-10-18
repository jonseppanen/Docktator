; initializing the script:
#SingleInstance force
    #KeyHistory 0
SetWorkingDir A_ScriptDir

global arrayTasks := {}

currentV := 8

IsWindowCloaked(hwnd)
{
    static gwa := DllCall("GetProcAddress", "ptr", DllCall("LoadLibrary", "str", "dwmapi", "ptr"), "astr", "DwmGetWindowAttribute", "ptr")
    return (gwa && DllCall(gwa, "ptr", hwnd, "int", 14, "int*", cloaked, "int", 4) = 0) ? cloaked : 0
}

tasklist := []
getSortedWindowList(){
    ids := WinGetList(,, "NxDock|Program Manager|Task Switching|^$")
    sortstring := ""
    windowarray := []
    Global tasklist
    
    Loop ids.Length()
    {
        WinGetPos(,,, Height,"ahk_id " ids[A_Index])
        if ((WinGetExStyle("ahk_id " ids[A_Index]) & 0x8000088) || !Height || WinGetTitle("ahk_id " ids[A_Index]) = "VirtualDesktopSwitcher" || IsWindowCloaked(ids[A_Index]))
        {
            continue
        }
        sortstring :=  sortstring  WinGetProcessName("ahk_id " ids[A_Index]) ":" ids[A_Index] ","
    }   
    sortarray := StrSplit(Sort(sortstring,"D,"),",")
    Loop sortarray.Length(){
        thisId := StrSplit(sortarray[A_Index],":")
        if(thisId[(thisId.Length())]){
            windowarray.push(thisId[(thisId.Length())])
        }
    } 
    
    tasklist := windowarray
    return tasklist
}

lastasks := []
getWindows()
{
    ids := getSortedWindowList()
    activeid := WinGetID("A")
    Global lastasks
    
    Loop ids.Length()
    {
        thisId := ids[A_Index]
        if(thisId = activeid){
            ;SendRainmeterCommand("!SetVariable ActiveTaskNumber " A_Index )
        }
        
        if(lastasks.Length() > 0){

            if(IsObject(lastasks[A_Index])){
                if(lastasks[A_Index,aid] = thisId){
                    continue
                }
                else{
                    lastasks[A_Index,"aid"] := thisId
                    MsgBox lastasks[A_Index,"hwnd"]
                    MsgBox lastasks[A_Index,"aid"]
                    Thumbnail_Destroy(lastasks[A_Index,"hwnd"])
                    newHwnd := watchWindow(thisId)
                    lastasks[A_Index,"hwnd"] := newHwnd
                }
            }
            else{
                newHwnd := watchWindow(thisId)
                lastasks[A_Index] := {}
                lastasks[A_Index,"aid"] := thisId
                lastasks[A_Index,"hwnd"] := newHwnd
            }
        }
        else{
            newHwnd := watchWindow(thisId)
            lastasks[A_Index] := {}
            lastasks[A_Index,"aid"] := thisId
            lastasks[A_Index,"hwnd"] := newHwnd
            MsgBox lastasks[A_Index, "hwnd"]
        }
        
        /*
        if(lastasks.Length() > 0 && thisId = lastasks[A_Index]){
            continue
        }

        if(lastasks[A_Index] != thisId){
                
            if(hwndMap[lastasks[A_Index]]){
                Thumbnail_Destroy(hwndMap[lastasks[A_Index]])
            }
            newHwnd := watchWindow(thisId)
            lastasks[A_Index] := thisId
            hwndMap[lastasks[A_Index]] := newHwnd
        }
        */
      ;  taskExeFullName := WinGetProcessName("ahk_id " thisId)
       ; taskExeName := StrReplace(taskExeFullName, ".exe", "")
        
        /*
        hicon := getIconHandle(WinGetProcessPath("ahk_id " thisId))
        dominantcolor := getDominantIconColor(colorCache, taskExeName, hicon)
        if(!hasValue(iconCache, taskExeName ".bmp")){
            SaveHICONtoFile( hicon, iconCacheDir taskExeName ".bmp" )
        }
        
        SendRainmeterCommand("!SetOption MeasureTask" A_Index "Exe String `""  taskExeName  "`" ")
        SendRainmeterCommand("!SetOption MeasureTask" A_Index "Color String `""  dominantcolor  "`" ")
        SendRainmeterCommand("!SetOption MeasureTask" A_Index "IconPath String `""  iconCacheDir taskExeName ".bmp"  "`" ")
        SendRainmeterCommand("!SetOption MeasureTask" A_Index "State  String  `""  WinGetMinMax("ahk_id " thisId)  "`" ")
        SendRainmeterCommand("!Updatemeasuregroup measuretask" A_Index "group ")
        SendRainmeterCommand("!Updatemetergroup Task" A_Index "Group ")
        SendRainmeterCommand("!Redrawgroup Task" A_Index "Group ")
        */
        
        
        
        
    }
}

;global id := WinGetList(,, "NxDock|Program Manager|Task Switching|^$")

SetTimer "getWindows", 200

;SetTimer "checkWindowSizes", 200

checkWindowSizes(){
    Loop id.Length()
    {
        thisId := id[A_Index]
        
        WinGetPos(,,, Height,"ahk_id " thisId)
        
        if ((WinGetExStyle("ahk_id " thisId) & 0x8000088) || !Height || WinGetTitle("ahk_id " thisId) = "VirtualDesktopSwitcher" || IsWindowCloaked(thisId))
        {
            continue
        }
        
        taskExeName := WinGetProcessName("ahk_id " thisId)
        taskExePath := WinGetProcessPath("ahk_id " thisId)
        
        if (!arrayTasks[thisId]){
            arrayTasks[thisId] := thisId
            watchWindow(thisId)
        }        
    }
}

/**************************************************************************************************************
title: Thumbnail functions
wrapped by maul.esel

Credits:
    - skrommel for example how to show a thumbnail (http://www.autohotkey.com/forum/topic34318.html)
        - RaptorOne & IsNull for correcting some mistakes in the code
        
NOTE:
    *This requires Windows Vista or Windows7* (tested on Windows 7)
Quick-Tutorial:
    To add a thumbnail to a gui, you must know the following:
    - the hwnd / id of your gui
    - the hwnd / id of the window to show
    - the coordinates where to show the thumbnail
    - the coordinates of the area to be shown
    1. Create a thumbnail with Thumbnail_Create()
    2. Set its regions with Thumbnail_SetRegion()
    a. optionally query for the source windows width and height before with <Thumbnail_GetSourceSize()>
        3. optionally set the opacity with <Thumbnail_SetOpacity()>
    4. show the thumbnail with <Thumbnail_Show()>
    ***************************************************************************************************************
    */
    
    
    /**************************************************************************************************************
    Function: Thumbnail_Create()
    creates a thumbnail relationship between two windows
    
params:
    handle hDestination - the window that will show the thumbnail
    handle hSource - the window whose thumbnail will be shown
returns:
    handle hThumb - thumbnail id on success, false on failure
    
Remarks:
    To get the Hwnds, you could use WinExist()
    ***************************************************************************************************************
    */
    Thumbnail_Create(hDestination, hSource) {
        VarSetCapacity(thumbnail, 4, 0)
        if DllCall("dwmapi.dll\DwmRegisterThumbnail", "UInt", hDestination, "UInt", hSource, "UInt", &thumbnail){
            return false
        }
        
        return NumGet(thumbnail)
    }
    
    
    /**************************************************************************************************************
    Function: Thumbnail_SetRegion()
    defines dimensions of a previously created thumbnail
    
params:
handle hThumb - the thumbnail id returned by <Thumbnail_Create()>
int xDest - the x-coordinate of the rendered thumbnail inside the destination window
int yDest - the y-coordinate of the rendered thumbnail inside the destination window
int wDest - the width of the rendered thumbnail inside the destination window
int hDest - the height of the rendered thumbnail inside the destination window
int xSource - the x-coordinate of the area that will be shown inside the thumbnail
int ySource - the y-coordinate of the area that will be shown inside the thumbnail
int wSource - the width of the area that will be shown inside the thumbnail
int hSource - the height of the area that will be shown inside the thumbnail
returns:
    bool success - true on success, false on failure
    ***************************************************************************************************************
    */
    Thumbnail_SetRegion(hThumb, xDest, yDest, wDest, hDest, xSource, ySource, wSource, hSource) {
        dwFlags := 0x00000001 | 0x00000002
        
        VarSetCapacity(dskThumbProps, 45, 0)
        
        NumPut(dwFlags, dskThumbProps, 0, "UInt")
        NumPut(xDest, dskThumbProps, 4, "Int")
        NumPut(yDest, dskThumbProps, 8, "Int")
        NumPut(wDest+xDest, dskThumbProps, 12, "Int")
        NumPut(hDest+yDest, dskThumbProps, 16, "Int")
        
        NumPut(xSource, dskThumbProps, 20, "Int")
        NumPut(ySource, dskThumbProps, 24, "Int")
        NumPut(wSource+xSource, dskThumbProps, 28, "Int")
        NumPut(hSource+ySource, dskThumbProps, 32, "Int")
        
        return DllCall("dwmapi.dll\DwmUpdateThumbnailProperties", "UInt", hThumb, "UInt", &dskThumbProps) ? false : true
    }
    
    
    /**************************************************************************************************************
    Function: Thumbnail_Show()
    shows a previously created and sized thumbnail
    
params:
handle hThumb - the thumbnail id returned by <Thumbnail_Create()>
returns:
    bool success - true on success, false on failure
    ***************************************************************************************************************
    */
    Thumbnail_Show(hThumb) {
        static dwFlags := 0x00000008, fVisible := 1
        
        VarSetCapacity(dskThumbProps, 45, 0)
        NumPut(dwFlags, dskThumbProps, 0, "UInt")
        NumPut(fVisible, dskThumbProps, 37, "Int")
        
        return DllCall("dwmapi.dll\DwmUpdateThumbnailProperties", "UInt", hThumb, "UInt", &dskThumbProps) ? false : true
    }
    
    
    /**************************************************************************************************************
    Function: Thumbnail_Hide()
    hides a thumbnail. It can be shown again without recreating
    
params:
handle hThumb - the thumbnail id returned by <Thumbnail_Create()>
returns:
    bool success - true on success, false on failure
    ***************************************************************************************************************
    */
    Thumbnail_Hide(hThumb) {
        static dwFlags := 0x00000008, fVisible := 0
        
        VarSetCapacity(dskThumbProps, 45, 0)
        NumPut(dwFlags, dskThumbProps, 0, "Uint")
        NumPut(fVisible, dskThumbProps, 37, "Int")
        return DllCall("dwmapi.dll\DwmUpdateThumbnailProperties", "UInt", hThumb, "UInt", &dskThumbProps) ? false : true
    }
    
    
    /**************************************************************************************************************
    Function: Thumbnail_Destroy()
    destroys a thumbnail relationship
    
params:
handle hThumb - the thumbnail id returned by <Thumbnail_Create()>
returns:
    bool success - true on success, false on failure
    ***************************************************************************************************************
    */
    Thumbnail_Destroy(hThumb) {
        return DllCall("dwmapi.dll\DwmUnregisterThumbnail", "UInt", hThumb) ? false : true
    }
    
    
    /**************************************************************************************************************
    Function: Thumbnail_GetSourceSize()
    gets the width and height of the source window - can be used with <Thumbnail_SetRegion()>
    
params:
handle hThumb - the thumbnail id returned by <Thumbnail_Create()>
ByRef int width - receives the width of the window
ByRef int height - receives the height of the window
returns:
    bool success - true on success, false on failure
    ***************************************************************************************************************
    */
    Thumbnail_GetSourceSize(hThumb, ByRef width, ByRef height) {
        VarSetCapacity(Size, 8, 0)
        if DllCall("dwmapi.dll\DwmQueryThumbnailSourceSize", "Uint", hThumb, "Uint", &Size){
            return false
        }
        
        width := NumGet(&Size + 0, 0, "int")
        height := NumGet(&Size + 0, 4, "int")
        return true
    }
    
    
    
    watchWindow(winid){
        ; get target window id
        WinGetPos  , , Rwidth, Rheight, "ahk_id " . winid
        start_x := 0
        start_y := 0
        
        ThumbWidth := 180
        ThumbHeight := 180
        thumbID := mainCode(winid,ThumbWidth,ThumbHeight,start_x,start_y,Rwidth,Rheight)
        return thumbID
    }
    
    mainCode(winid,windowWidth,windowHeight,RegionX,RegionY,RegionW,RegionH)
    {
        targetName := "ahk_id " . winid
        
        Global currentV
        GuiObj%winid% := GuiCreate("+LastFound +AlwaysOnTop +ToolWindow -caption","gg" . winid)
        hDestination := WinExist() ; ... to our GUI...
        hSource := WinExist(targetName) ;
        hThumb := Thumbnail_Create(hDestination, hSource) ; you must get the return value here!
        Thumbnail_GetSourceSize(hThumb, width, height)
        windowHeight := (regionH / regionW) * windowWidth
        Thumbnail_SetRegion(hThumb, 0, 0 , windowWidth, windowHeight, 8 , 8 ,(RegionW - 16), (RegionH - 16))
        Thumbnail_Show(hThumb) ; but it is not visible now...
        
        GuiObj%winid%.Show("W" . windowWidth . " H" . windowHeight . " X8 Y" . currentV) ; ... until we show the GUI
        
        currentV := currentV + windowHeight + 8
        
        return hThumb
        
    }
    ;--- Script to monitior a window or section of a window (such as a progress bar, or video) in a resizable live preview window
    
    ;--- This is an update (in terms of functionality) to the original livewindows ahk script by Holomind http://www.autohotkey.com/forum/topic11588.html
    ;--- which takes advantage of windows vista/7 Aeropeak. The script relies on Thumbnail.ahk, a great script by relmaul.esel, http://www.autohotkey.com/forum/topic70839.html
    ;--------------------------------------------------------------------------------------------
    
    ;Hotkey, ^+LButton , start_defining_region
    ;Hotkey "#w", watchWindow
    
    
    ;msgbox, Press win+w to watch the entire active window `n`nOr hold down ctrl+shift and drag a box around the `narea you are interested in to watch a specific region
    ;return
    
    ;--------------------------------------------------------------------------------------------
    
    
    
    
    
    