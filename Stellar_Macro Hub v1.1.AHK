#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%

; --- Settings ---
GitHubUser := "stellardev67"
PageSize := 10
CurrentPage := 1

; --- Fetch repos and calculate pages ---
FetchRepos()
CalculateTotalPages()

; --- Build GUI ---
Gui, New, +Resize
Gui, Add, ListView, w1200 h500 vRepoList gOpenRepo Grid, Name|Description|URL|Status
Gui, Add, Button, x+10 yp w100 h30 gPrevPage, Previous
Gui, Add, Button, x+10 yp w100 h30 gNextPage, Next
Gui, Add, Button, x+10 yp w100 h30 gRefresh, Refresh
Gui, Add, Text, x+10 yp vPageInfo, Page %CurrentPage% of %TotalPages%

ShowPage(CurrentPage)
Gui, Show, AutoSize, Stellar Dev 67 Repos
Return

GuiClose:
ExitApp

; --- Show repositories for the current page ---
ShowPage(page) {
    global AllRepos, PageSize, GitHubUser  ; <-- add GitHubUser here
    LV_Delete()
    start := (page-1)*PageSize + 1
    end := Min(page*PageSize, AllRepos.MaxIndex())
    counter := 0
    for index, repo in AllRepos {
        counter++
        if (counter < start)
            continue
        if (counter > end)
            break
        LV_Add("", repo["name"], repo["description"], "https://github.com/" GitHubUser "/" repo["name"], repo["private"] ? "Private" : "Public")
    }
    LV_ModifyCol(1, 250)
    LV_ModifyCol(2, 450)
    LV_ModifyCol(3, 400)
    LV_ModifyCol(4, 100)
    CalculateTotalPages()
    GuiControl,, PageInfo, Page %page% of %TotalPages%
}

PrevPage:
if (CurrentPage > 1) {
    CurrentPage--
    ShowPage(CurrentPage)
}
Return

NextPage:
if (CurrentPage < TotalPages) {
    CurrentPage++
    ShowPage(CurrentPage)
}
Return

OpenRepo:
if (A_GuiEvent = "DoubleClick") {
    LV_GetText(url, A_EventInfo, 3)
    Run, %url%
}
Return

Refresh:
FetchRepos()
CurrentPage := 1
ShowPage(CurrentPage)
Return

; --- Fetch repositories from GitHub ---
FetchRepos() {
    global GitHubUser, AllRepos
    Http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    Http.Open("GET", "https://api.github.com/users/" GitHubUser "/repos?per_page=100", false)
    Http.SetRequestHeader("User-Agent", "AHK")
    Http.Send()
    status := Http.Status
    if (status != 200) {
        MsgBox, Failed to fetch repos! Status: %status%
        return
    }
    RepoData := Http.ResponseText
    AllRepos := JSON_Load(RepoData)
}

CalculateTotalPages() {
    global AllRepos, PageSize, TotalPages
    totalItems := AllRepos.MaxIndex()
    TotalPages := totalItems // PageSize
    if (Mod(totalItems, PageSize) != 0)
        TotalPages += 1
}

; --- JSON parser: top-level braces only ---
JSON_Load(json) {
    obj := []
    pos := 1
    len := StrLen(json)
    ; Skip initial [ and whitespace
    while (pos <= len && InStr("`r`n [`t", SubStr(json, pos, 1)))
        pos++

    ; Parse each top-level {…} object
    while (pos <= len) {
        if SubStr(json, pos, 1) != "{"
        {
            pos++
            continue
        }
        braceCount := 0
        startPos := pos
        while (pos <= len) {
            c := SubStr(json, pos, 1)
            if (c = "{")
                braceCount++
            else if (c = "}")
                braceCount--
            pos++
            if (braceCount = 0)
                break
        }
        repoText := SubStr(json, startPos, pos - startPos)
        repo := {}
        repo["name"] := ExtractField(repoText, "name")
        repo["description"] := ExtractField(repoText, "description")
        repo["html_url"] := ExtractField(repoText, "html_url") ; fixed
        repo["private"] := (ExtractField(repoText, "private")="true")
        obj.Push(repo)
    }
    return obj
}

; --- Extract field from JSON object ---
ExtractField(text, field) {
    if (field = "html_url") {
        ; Capture the full URL correctly
        if RegExMatch(text, """" field """\s*:\s*""([^""]+)""", m)
            return m1
    } else {
        ; Default for other fields
        if RegExMatch(text, """" field """\s*:\s*(""|null)?(.*?)(""|,})", m)
            return m2
    }
    return ""
}
