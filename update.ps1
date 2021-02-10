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

function Get-VersionUrl($tags, $versionPatterns, $baseURLs, $filenamePatterns, $filenameArchPatterns) {
  foreach ($tag in $tags) {
    foreach ($versionPattern in $versionPatterns) {
      $version = $tag.Name -Replace $versionPattern
      foreach ($baseUrl in $baseUrls) {
        foreach ($filename in $filenamePatterns) {
          foreach ($archPattern in $filenameArchPatterns) {
            try {
              $baseUrl = $($baseUrl -Replace "\[VERSION\]","$version" -Replace "\[ARCH\]","$archPattern")
              $url = $($filename -Replace "\[VERSION\]","$version" -Replace "\[ARCH\]","$archPattern")
              $url = "$($baseUrl)$($url)"
              Write-Host "Checking: $url"
              Invoke-WebRequest -Uri $url -UseBasicParsing -DisableKeepAlive -Method HEAD | Out-Null
              $versionUrl = @{}
              $versionUrl.version = $version
              $versionUrl.url = $url
              return $versionUrl
            } catch [Net.WebException] {
            }
          }
        }
      }
    }
  }
  return $null
}

function global:au_GetLatest {
  
  $tagsUrl = "https://api.github.com/repos/fedict/eid-mw/tags"
  $baseUrls = @(
    "https://eid.belgium.be/sites/default/files/software/"
  )
  $filenamePatterns = @(
    "beidmw_[ARCH]_[VERSION].msi",
    "BeidMW_[ARCH]_[VERSION].msi"
  )
  $filename64bitsPatterns = @(
    "64"
  )
  $filename32bitsPatterns = @(
    "32"
  )
  $versionPatterns = @(
    '[^0-9.]'
  )
  $releaseNotesBaseUrls = @(
    "https://eid.belgium.be/sites/default/files/content/pdf/"
    "https://dist.eid.belgium.be/releases/[VERSION]/"
  )
  $releaseNotesFilenamePatterns = @(
    "rn[VERSION].pdf",
    "RN[version].pdf"
  )
  $releaseNotesVersionPatterns = @(
    '[^0-9.]',
    '[^0-9]'
  )
  $errorMessage = "[PREFIX]This shouldn't happen. Upstream has likely changed their URLs, manual intervention required."

  $tags = Invoke-WebRequest $tagsUrl -UseBasicParsing | ConvertFrom-Json

  $versionUrl32 = Get-VersionUrl $tags $versionPatterns $baseUrls $filenamePatterns $filename32bitsPatterns
  if (!$versionUrl32) {
    throw $errorMessage -Replace "\[PREFIX\]","The URL to the 32 bits installer was not found. "
  }

  $versionUrl64 = Get-VersionUrl $tags $versionPatterns $baseUrls $filenamePatterns $filename64bitsPatterns
  if (!$versionUrl64) {
    throw $errorMessage -Replace "\[PREFIX\]","The URL to the 64 bits installer was not found. "
  }

  if ($versionUrl32.version -ne $versionUrl64.version) {
    throw $errorMessage -Replace "\[PREFIX\]","The detected 32 and 64 bits installers are not the same version. "
  }
  
  $versionUrlReleaseNotes = Get-VersionUrl $tags $releaseNotesVersionPatterns $releaseNotesBaseUrls $releaseNotesFilenamePatterns @{}
  if (!$versionUrlReleaseNotes) {
    throw $errorMessage -Replace "\[PREFIX\]","The URL to the release notes was not found. "
  }

  return @{
    URL32 = $versionUrl32.url
    URL64 = $versionUrl64.url
    Version = $versionUrl64.version
    ReleaseNotes = $versionUrlReleaseNotes.url
  }
}

update -ChecksumFor none
