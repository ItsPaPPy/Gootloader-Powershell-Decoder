<#
# filename          : GootloaderDecoder.ps1
# description       : Extracts URLs from Gootloader JavaScript
# author            : @ItsPaPPy
# date              : 20210801
# version           : 1.0
# usage             : powershell.exe .\GootloaderDecoder.ps1 -d <directory_to_search>
#==============================================================================

Gootloader decoder and URL extractor
This module tries to deobfuscate Gootloader JavaScript and extract its next stage
URLs. 

Original python script by @stoerchl (patrick.schlapfer@hp.com): https://github.com/hpthreatresearch/tools/blob/main/gootloader/decode.py

#>
param (
    [string]$directory = "c:\temp"
)

IF ( !( Test-Path $directory)) {
    Write-Host "$directory is not a valid path"
    Write-Host "Usage: .\UP_GootloaderDecoder.ps1 -directory <directory_to_search>"
    exit
}

$code_regex = "(?<!\\)(?:\\\\)*'([^'\\]*(?:\\.[^'\\]*)*)'"
$breacket_regex = "\[(.*?)\]"
$url_regex = "(?:https?:\/\/[^=]*)"
$separator_regex = "(['|""].*?['|""])"


function decode_cipher {
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [string]
        $cipher
    )

    $plaintext = ""
    $counter = 0

    while ( $counter -lt $cipher.Length) {
        $decoded_char = $cipher[$counter]

        if ($counter % 2) {
            $plaintext = $plaintext + $decoded_char
        }
        else {
            $plaintext = $decoded_char + $plaintext
        }
        $counter++
    }
    
    return $plaintext

}



$all_domains = @() #Domain collections
$all_urls = @() #URL collections

$all_files = Get-ChildItem -Path $directory -File -Recurse

$encLatin1 = [System.Text.Encoding]::GetEncoding("ISO-8859-1")


foreach ($f in $all_files) {
    try {
        
    
        $content = Get-Content $f.PSPath
        $round = 0
        while ($round -lt 2) {
            $matchs = ( Select-String -InputObject $content -Pattern $code_regex -AllMatches ).Matches
            $longest_match = ""
            foreach ($m in $matchs) {
                if ( $longest_match.Length -lt $m.value.Length ) {
                    $longest_match = $m.value 
                }
            }
            $longest_match = $longest_match.Trim("'")
                                  

            $content = decode_cipher -cipher ([regex]::Unescape( $encLatin1.GetString($encLatin1.GetBytes($longest_match))))

            $round++
        }

        
        $domains = ( Select-String -InputObject $content.Split(";")[0]  -Pattern $breacket_regex -AllMatches ).Matches
        $urls = ( Select-String -InputObject $content -Pattern $url_regex -AllMatches ).Matches
    
        if ( $urls.Length -gt 0 ) {
            $replaceables = ( Select-String -InputObject $urls[0].Value -Pattern $separator_regex -AllMatches ).Matches

            if ($replaceables.Length -eq 2) {
                foreach ($d in $domains) {
                    $doms = $d.Value.replace("""", "").replace("'", "").replace("[","").replace("]","").split(",")
                    foreach ($dom in $doms) {
                        $all_domains += $dom
                        $all_urls += ($urls[0].Value.Replace($replaceables[0].Value, $dom).Replace($replaceables[1].Value, "") + "=") 
                    }
                }
            }
        }

        Write-Host "OK -  $f"
    }
    catch {
        Write-Host "ERROR - Could not decode Gootloader -  $f"
    
    }
}

Write-Host "Found URLs" $all_urls.Length.ToString()

$all_urls > .\urls.txt

Write-Host "Wrote File: urls.txt "

Write-Host "Found Domains" $all_domains.Length.ToString()

$all_domains > .\domains.txt

Write-Host "Wrote File: domains.txt"
