#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%

; --- Settings ---
GitHubUser := "stellardev67"
PageSize := 10  ; repos per page
CurrentPage := 1

; --- Fetch GitHub JSON ---
FetchRepos()

; --- Calculate total pages ---
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
    global AllRepos, PageSize
    LV_Delete() ; clear previous items
    start := (page-1)*PageSize + 1
    end := Min(page*PageSize, AllRepos.MaxIndex())
    counter := 0
    for index, repo in AllRepos
    {
        counter++
        if (counter < start)
            continue
        if (counter > end)
            break
        LV_Add("", repo["name"], repo["description"], repo["html_url"], repo["private"] ? "Private" : "Public")
    }
    ; adjust column widths
    LV_ModifyCol(1, 200) ; Name
    LV_ModifyCol(2, 400) ; Description
    LV_ModifyCol(3, 400) ; URL
    LV_ModifyCol(4, 100) ; Status

    ; update page info
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

; --- Refresh repositories ---
Refresh:
FetchRepos()
CurrentPage := 1
ShowPage(CurrentPage)
Return

; --- Helper functions ---
FetchRepos() {
    global GitHubUser, AllRepos
    Http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    Http.Open("GET", "https://api.github.com/users/" GitHubUser "/repos", false)
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
    TotalPages := AllRepos.MaxIndex() // PageSize
    if (Mod(AllRepos.MaxIndex(), PageSize) != 0)
        TotalPages += 1
}

; --- JSON parser ---
JSON_Load(json) {
    obj := []
    json := StrReplace(json, "`n", "")
    pattern := "\{(.*?)\}"
    pos := 1
    while RegExMatch(json, pattern, match, pos) {
        repoText := "{" match1 "}"
        repo := {}
        repo["name"] := ExtractField(repoText, "name")
        repo["description"] := ExtractField(repoText, "description")
        repo["html_url"] := ExtractField(repoText, "html_url")
        repo["private"] := (ExtractField(repoText, "private")="true")
        obj.Push(repo)
        pos := match.Pos + StrLen(match.Value)
    }
    return obj
}

ExtractField(text, field) {
    if (RegExMatch(text, """" field """\s*:\s*""?(.*?)""?(,|})", m))
        return m1
    return ""
}
