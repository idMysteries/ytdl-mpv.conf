if (-not $args) {
    Write-Error "Arguments not specified."
    exit 1
}

$drive = "F"

if ($args[0] -match '^[A-Z]$') {
    $drive = $args[0]
    $args = $args[1..$args.Length]

    if (-not $args) {
        Write-Error "URL not specified."
        exit 1
    }
}

$url = $args[0] -replace "watch\?v=.*&list=", "playlist?list="
$args = $args[1..$args.Length]

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ($drive -eq "C") {
    $downloadDirectory = [Environment]::GetFolderPath("MyVideos")
} else {
    $downloadDirectory = "${drive}:\Videos"
}

if (-not (Test-Path $downloadDirectory)) {
    New-Item -ItemType Directory -Path $downloadDirectory -Force
}

$ytdlp = "yt-dlp"
$dateDirectory = Get-Date -Format "\\yyyy-MM-dd\\"

$params = @{
    Uploader = "%(uploader)s"
    Archive = @("--download-archive", "$env:LOCALAPPDATA\mpv\archive.txt")
    MetaTitle = @("--parse-metadata", "title:%(meta_title)s")
    OutputFormat = "%(title).150s [%(id)s].%(ext)s"
    OutputPlaylistFormat = "\%(playlist)s\%(playlist_index)s - "
}

& $ytdlp --update

$metadata = & $ytdlp --print playlist_id,playlist_title,uploader,id,extractor --ignore-no-formats-error --no-download-archive --no-mark-watched --playlist-end 1 $url
Write-Host "yt-dlp metadata:$metadata"

$playlistId, $playlistTitle, $videoUploader, $videoId, $videoExtractor = $metadata -Split "`n"

if ($url -match "twitch.tv/.*/clips") {
    $params.Uploader = $playlistId
}

$outputPath = if (($playlistTitle -eq "Queue") -or ($playlistTitle -eq "Очередь") -or ($playlistTitle -eq "Watch later") -or ($playlistId -eq "WL")) {
    "$($params.Uploader)/%(playlist_index)s - $($params.OutputFormat)"
} else {
    $base = if ($playlistTitle -ne "NA") { $params.OutputPlaylistFormat + $params.OutputFormat } else { $dateDirectory + $params.OutputFormat }
    if ($videoUploader -ne "NA") { $params.Uploader + $base } else { $base }
}

if ($videoExtractor -eq "generic") {
    $params.Archive = "--no-download-archive"
}

$commandArguments = @(
    $params.Archive
    $params.MetaTitle
    "--concurrent-fragments", "4"
    if ($videoExtractor -like "*youtube*") { "--live-from-start" }
    if ($url -match "index=(\d+)") { "-I", "$($matches[1]):" }
    $args
    "-o", "$downloadDirectory\$outputPath"
    $url
) | Where-Object { $_ }

$formattedArgs = $commandArguments | ForEach-Object { 
    if ($_ -match '^-' -or $_ -eq $commandArguments[-1]) { "`n  $_" } else { $_ }
}
Write-Host "yt-dlp arguments:$formattedArgs"

& $ytdlp $commandArguments
