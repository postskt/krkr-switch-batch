#Requires -RunAsAdministrator
# krkr-Switch 移植项目: WSL2 环境一次性引导脚本 (Windows 10 22H2)
# 作用: 启用 WSL/虚拟机平台功能 -> 安装 WSL2 内核 -> 设默认 WSL2
# 运行后需要重启电脑一次, 重启后的发行版安装由 ZCode 会话继续完成 (无需再次提权)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host '== 1/4 启用 "适用于 Linux 的 Windows 子系统" =='
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

Write-Host '== 2/4 启用 "虚拟机平台" =='
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

Write-Host '== 3/4 下载并安装 WSL2 内核更新包 =='
$msi = Join-Path $env:TEMP 'wsl_update_x64.msi'
$proxy = 'http://127.0.0.1:7890'
$ok = $false
try {
    Invoke-WebRequest -Uri 'https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi' -OutFile $msi -Proxy $proxy -UseBasicParsing
    $ok = $true
    Write-Host '   (经本地代理 127.0.0.1:7890 下载)'
} catch {
    Write-Host "   代理下载失败, 回退直连: $($_.Exception.Message)"
}
if (-not $ok) {
    Invoke-WebRequest -Uri 'https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi' -OutFile $msi -UseBasicParsing
}
Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn" -Wait
Write-Host '   内核已安装'

Write-Host '== 4/4 设置默认 WSL 版本为 2 =='
wsl.exe --set-default-version 2

Write-Host ''
Write-Host '引导完成。请重启电脑 (重启完成后回到 ZCode 会话说"已重启"即可继续)。'
$r = Read-Host '是否现在自动重启? 输入 y 重启, 其他任意键手动稍后重启'
if ($r -eq 'y') { shutdown.exe /r /t 10 /c "WSL2 环境配置完成, 系统重启" }
