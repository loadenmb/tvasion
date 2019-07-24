# tvasion - Powershell / C# AES anti virus evasion 

Simple & small anti virus evasion based on file signature change via AES encryption with Powershell and C# evasion templates which support executable and Powershell payloads with Windows executable, Powershell or batch output. Developed with Powershell on Linux for Windows targets :)

# under development see [tests.ps1](tests.ps1) whats working at the moment

Buzzwords: Anti virus evasion, crypter, AES encryption, ReflectivePEInjection, PowerShell execution policy bypass

## Features
- outputs 32 bit executable (.exe), Powershell (.ps1) or batch (.bat)
- works with excutable + Powershell payloads
- AES encryption for file signature change
- Powershell and C# evasion templates available
- EXOTIC: Powershell, mcs based developed on Linux for Windows targets :-)
- simple & small - easy to extend

## Usage
```
tvasion: AES based anti virus evasion
type parameter -t (exe|bat|ps1), argument "payload path" are required, -o "output directory" is optional, -d "debug" is optional
./tvasion -t (exe|bat|ps1) [PAYLOAD (exe|ps1)] OR ./tvasion [PAYLOAD (exe|ps1)] -t (exe|bat|ps1)
Parameter:
[PAYLOAD (exe|ps1)]       input file path. requires: exe, ps1         required
-t (exe|ps1|bat)          output file type: exe, ps1, bat             required
-o (PATH)                 set output directory (default is ./out/)    optional
-d                        generate debug output                       optional
examples:
./tvasion.ps1 -t exe tests/ReverseShell.ps1           # generate windows executable (.exe) from powershell
./tvasion.ps1 -t ps1 tests/ReverseShell_c#amd64.exe   # generate powershell (.ps1) from excecutable
./tvasion.ps1 -t exe tests/ReverseShell_c#amd64.exe   # generate windows executable (.exe) from excecutable
```
Files generated in ./out directory
See more examples in: [test file](tests.ps1)

## Setup Debian Stretch / Kali Linux

Depencies:
- [PowerShell](https://github.com/PowerShell/PowerShell)  
- [mono-mcs](https://www.mono-project.com/docs/about-mono/languages/csharp/) (optional but required for cross plattform executable compilation for executeable payloads)

```shell
# setup Powershell for Linux. see link above, be root

# install compiler depencies (optional, required for executable output)
apt-get install -y mono-mcs

# clone with git
git clone https://github.com/loadenmb/tvasion.git
```
    
## Details & advanced usage

Change AES decryption template source code to make sure evasion output is undetectable by anti virus solutions.

C# and powershell templates from ./templates/ directory basically do: 
```
decode -> decrypt -> launch payload
```
It's input / output type dependent which template needs changes. See here:

| payload type  |  output type  | template from ./templates/ folder |  details |
| ------------- | ------------- | --------------------------------- | -------- |
| powershell    | powershell    | default.ps1                       | Invoke-Expression |
| executable    | powershell    | default_exe.ps1                   | Invoke-Expression + ReflectivePEInjection (*2) |
| executable    | executable    | default_exe.cs                    | PEInjection (*2) |
| powershell    | executable    | default.cs                        | PowerShell execution policy bypass with -enc |
| powershell    | batch         | default.ps1                       | PowerShell execution policy bypass with -enc + Invoke-Expression (*1) |
| executable    | batch         | default_exe.ps1                   | PowerShell execution policy bypass with -enc + Invoke-Expression + ReflectivePEInjection (*1, *2)|

(*1) .exe -> .bat requires pretty small payload because of maximum cmd arguments length.
(*2) not working with all binaries; Meterpreter, mimikatz work

Payload is created like this:
```
                                -> pasted & compiled into 64 bit windows executeable written in C# (.exe -> .exe)
payload -> AES encryption -> base64 encoded 
                                -> pasted into powershell script (.ps1 -> .ps1) 
                                        -> base64 encoded 
                                                -> pasted & into 64 bit windows executeable written in C# (.ps1 -> .exe)             
                                                -> pasted into batch file (.ps1 | .exe -> .bat)       
```

### Tests
Windows C# and powershell reverse shells are included in ./tests/ folder for testing purposes. 

Run tests:
- [setup metasploit framework](https://metasploit.help.rapid7.com/docs/installing-the-metasploit-framework)
- change IP to your IP in ./tests/ReverseShell.ps1 and ./tests/ReverseShell.cs and ./tests.ps1 (we need single configuration)
- run msfconsole in seperate terminal
- run ./tests.ps1 for compilation / test file creation. see ./out/ for results (16 different malicious files at the moment)
- listen for reverse connections on linux machine:
```shell
# listen for reverse shell connections from ./tests/ReverseShell.ps1 and ./tests/ReverseShell.cs.
nc -nvlp 4242
```
```shell
# use msfconsole you opened in seperat terminal, we need this launched before to generate Meterpreter in ./tests.ps1
# listen with metasploit multi handler for windows/meterpreter/reverse_tcp on port 4444 (tests.ps1 generated Meterpreter will connect this port)
cd ./tvasion/tests/
msfconsole
resource msf_multihandler.rc
```
- copy files from ./out/ directory to target Windows machine & execute

## Roadmap / TODO (feel free to work on)
- add more evasion functionality:
    - template obfocusation / randomize variable names, white spaces / line breaks / tabs, call order, hide native method names, + add auto generated useless code
    - payload compression / script comment removement
    - anti virus sandbox escape (maybe via long execution delay or try to allocate many resources until sandbox stops processing)
    - better cloaking for encrypted payload string
- add better C# PEInjection
- add new output types:
    - vcf ouput (local code execution, if working in 2019) 
    - .doc + .xls ouput via DDEAUTO or OLE / Powerquery (local code execution without macro)
- add TCP (HTTPS?) + UDP (DNS?) dropper
- add executable file binder (PE file injection)?
- make ./tvasion.ps1 self run on windows

## Related
- [Powershell ReflectivePEInjection](https://github.com/clymb3r/PowerShell/blob/master/Invoke-ReflectivePEInjection/Invoke-ReflectivePEInjection.ps1) @ github
- [C# PE loader](https://github.com/Arno0x/CSharpScripts/blob/master/peloader.cs) @ github
- [15 ways to bypass PowerShell execution policy](https://blog.netspi.com/15-ways-to-bypass-the-powershell-execution-policy/) @ external blog
