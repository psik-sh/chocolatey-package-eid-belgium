import-module au

function global:au_BeforeUpdate {
    Get-RemoteFiles -Purge -NoSuffix 
}

function global:au_SearchReplace {
  @{
    ".\tools\chocolateyInstall.ps1" = @{
      "(?i)(^\s*file\s*=\s*`"[$]toolsDir\\).*" = "`${1}$($Latest.FileName32)`""
      "(?i)(^\s*file64\s*=\s*`"[$]toolsDir\\).*" = "`${1}$($Latest.FileName64)`""
    }
    ".\legal\verification.txt" = @{
      "(?i)(32-Bit.+)\<.*\>" = "`${1}<$($Latest.URL32)>"
      "(?i)(64-Bit.+)\<.*\>" = "`${1}<$($Latest.URL64)>"
      "(?i)(checksum type:\s+).*" = "`${1}$($Latest.ChecksumType32)"
      "(?i)(checksum32:\s+).*" = "`${1}$($Latest.Checksum32)"
      "(?i)(checksum64:\s+).*" = "`${1}$($Latest.Checksum64)"
    }
    "eid-belgium.nuspec" = @{
      "\<(releaseNotes)\>.*\<\/releaseNotes\>" = "<`$1>$($Latest.ReleaseNotes)</`$1>"
    }
  }
}

function global:au_GetLatest {

  $tags = Invoke-WebRequest 'https://api.github.com/repos/fedict/eid-mw/tags' -UseBasicParsing | ConvertFrom-Json
  
  foreach ($tag in $tags) {
    try {
      $version32 = $tag.Name -Replace '[^0-9.]'
      $url32 = "https://eid.belgium.be/sites/default/files/software/beidmw_32_$($version32).msi"
      Write-Verbose "Checking: $url32"
      (Invoke-WebRequest -Uri $url32 -UseBasicParsing -DisableKeepAlive -Method HEAD).StatusCode
      break
    } catch [Net.WebException] {
      [int]$_.Exception.Response.StatusCode
      continue
    }
  }
  
  if (!$version32) {
    throw "The URL to the 32 bits installer was not found. This shouldn't happen. Maybe upstream changed their URLs?"
  }
  
  foreach ($tag in $tags) {
    try {
      $version64 = $tag.Name -Replace '[^0-9.]'
      $url64 = "https://eid.belgium.be/sites/default/files/software/beidmw_64_$($version64).msi"
      Write-Verbose "Checking: $url64"
      (Invoke-WebRequest -Uri $url64 -UseBasicParsing -DisableKeepAlive -Method HEAD).StatusCode
      break
    } catch [Net.WebException] {
      [int]$_.Exception.Response.StatusCode
      continue
    }
  }
  
  if (!$version64) {
    throw "The URL to the 64 bits installer was not found. This shouldn't happen. Maybe upstream changed their URLs?"
  }
  
  if ($version32.ToString() -ne $version64.ToString()) {
    throw "The detected 32 and 64 bits installers are not the same version. This shouldn't happen. Maybe upstream changed their URLs?"
  }
  
  # Determine release notes URL
  foreach ($tag in $tags) {
    $version = $tag.Name -Replace '[^0-9.]'
    $urlReleaseNotes = "https://eid.belgium.be/sites/default/files/content/pdf/rn$($version).pdf"
    try {
        Write-Verbose "Checking: $urlReleaseNotes"
        (Invoke-WebRequest -Uri $urlReleaseNotes -UseBasicParsing -DisableKeepAlive -Method HEAD).StatusCode
        break
    } catch [Net.WebException] {
        [int]$_.Exception.Response.StatusCode
        continue
    }
    if (!$urlReleaseNotes) {
      throw "The URL to the release notes was not found. This shouldn't happen. Maybe upstream changed their URLs?"
    }
  }

  return @{
    URL32 = $url32
    URL64 = $url64
    Version = $version64
    ReleaseNotes = $urlReleaseNotes
  }
}

update -ChecksumFor none
