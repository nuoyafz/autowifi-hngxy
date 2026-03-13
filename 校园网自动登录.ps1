# 校园网自动登录工具
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$global:scriptPath = $PSScriptRoot
if ([string]::IsNullOrEmpty($global:scriptPath)) { $global:scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path }
if ([string]::IsNullOrEmpty($global:scriptPath)) { $global:scriptPath = Split-Path -Parent $PSCommandPath }
if ([string]::IsNullOrEmpty($global:scriptPath)) { $global:scriptPath = Get-Location }

$global:configPath = Join-Path $global:scriptPath "config.json"
$global:logPath = Join-Path $global:scriptPath "login.log"
$global:shortcutPath = Join-Path ([Environment]::GetFolderPath("Startup")) "校园网自动登录.lnk"

function Write-Log {
    param([string]$message)
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $global:logPath -Value "[$timestamp] $message" -Encoding UTF8
    } catch {}
}

function Show-ToastNotification {
    param([string]$title, [string]$message)
    try {
        $notify = New-Object System.Windows.Forms.NotifyIcon
        $notify.Icon = [System.Drawing.SystemIcons]::Information
        $notify.BalloonTipTitle = $title
        $notify.BalloonTipText = $message
        $notify.Visible = $true
        $notify.ShowBalloonTip(5000)
        Start-Sleep -Seconds 6
        $notify.Dispose()
    } catch {}
}

function Get-CurrentWlanIP {
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect("211.69.15.10", 6060)
        $ip = $tcpClient.Client.LocalEndPoint.Address.ToString()
        $tcpClient.Close()
        return $ip
    } catch { return $null }
}

function Invoke-CampusLogin {
    param([hashtable]$config)
    $ip = Get-CurrentWlanIP
    if (-not $ip) {
        Write-Log "无法获取IP地址"
        if ($config.showNotify) { Show-ToastNotification "登录失败" "无法获取IP地址" }
        return $false
    }
    Write-Log "开始登录，IP: $ip"
    $unixTime = [int](Get-Date -UFormat %s)
    $params = @{
        userid = $config.userId
        passwd = $config.password
        wlanuserip = $ip
        wlanacname = $config.wlanAcName
        wlanacIp = $config.wlanAcIp
        ssid = ""
        vlan = ""
        mac = ""
        version = 0
        portalpageid = $config.portalPageId
        timestamp = ($unixTime * 1000)
        uuid = [guid]::NewGuid().ToString()
        portaltype = 0
        hostname = ""
        bindCtrlId = ""
    }
    for ($i = 1; $i -le 3; $i++) {
        Write-Log "第 $i 次尝试..."
        try {
            $query = ($params.Keys | ForEach-Object { "$_=$([Uri]::EscapeDataString($params[$_]))" }) -join "&"
            $url = "$($config.loginUrl)?$query"
            $response = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec 10 -UseBasicParsing
            $content = $response.Content
            Write-Log "响应: $content"
            try {
                $json = $content | ConvertFrom-Json
                if ($json.code -eq "0" -or $content -match "成功") {
                    Write-Log "登录成功"
                    if ($config.showNotify) { Show-ToastNotification "登录成功" "IP: $ip" }
                    return $true
                }
            } catch {
                if ($content -match "成功") {
                    Write-Log "登录成功"
                    if ($config.showNotify) { Show-ToastNotification "登录成功" "IP: $ip" }
                    return $true
                }
            }
        } catch { Write-Log "请求失败: $_" }
        Start-Sleep -Seconds 2
    }
    Write-Log "登录失败"
    if ($config.showNotify) { Show-ToastNotification "登录失败" "请检查账号密码" }
    return $false
}

function Show-ConfigForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "校园网配置 - By 诺亚 723167066"
    $form.Size = New-Object System.Drawing.Size(400, 380)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 245)

    $titleFont = New-Object System.Drawing.Font("Microsoft YaHei", 14, [System.Drawing.FontStyle]::Bold)
    $labelFont = New-Object System.Drawing.Font("Microsoft YaHei", 10)
    $buttonFont = New-Object System.Drawing.Font("Microsoft YaHei", 10, [System.Drawing.FontStyle]::Bold)

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "校园网自动登录配置"
    $titleLabel.Font = $titleFont
    $titleLabel.Size = New-Object System.Drawing.Size(380, 35)
    $titleLabel.Location = New-Object System.Drawing.Point(10, 15)
    $titleLabel.TextAlign = "MiddleCenter"
    $form.Controls.Add($titleLabel)

    $userLabel = New-Object System.Windows.Forms.Label
    $userLabel.Text = "账号："
    $userLabel.Font = $labelFont
    $userLabel.Size = New-Object System.Drawing.Size(80, 25)
    $userLabel.Location = New-Object System.Drawing.Point(30, 60)
    $form.Controls.Add($userLabel)

    $userTextBox = New-Object System.Windows.Forms.TextBox
    $userTextBox.Font = $labelFont
    $userTextBox.Size = New-Object System.Drawing.Size(250, 25)
    $userTextBox.Location = New-Object System.Drawing.Point(110, 58)
    $form.Controls.Add($userTextBox)

    $passLabel = New-Object System.Windows.Forms.Label
    $passLabel.Text = "密码："
    $passLabel.Font = $labelFont
    $passLabel.Size = New-Object System.Drawing.Size(80, 25)
    $passLabel.Location = New-Object System.Drawing.Point(30, 95)
    $form.Controls.Add($passLabel)

    $passTextBox = New-Object System.Windows.Forms.TextBox
    $passTextBox.Font = $labelFont
    $passTextBox.Size = New-Object System.Drawing.Size(250, 25)
    $passTextBox.Location = New-Object System.Drawing.Point(110, 93)
    $passTextBox.PasswordChar = "*"
    $form.Controls.Add($passTextBox)

    $ispLabel = New-Object System.Windows.Forms.Label
    $ispLabel.Text = "运营商："
    $ispLabel.Font = $labelFont
    $ispLabel.Size = New-Object System.Drawing.Size(80, 25)
    $ispLabel.Location = New-Object System.Drawing.Point(30, 130)
    $form.Controls.Add($ispLabel)

    $ispComboBox = New-Object System.Windows.Forms.ComboBox
    $ispComboBox.Font = $labelFont
    $ispComboBox.Size = New-Object System.Drawing.Size(250, 25)
    $ispComboBox.Location = New-Object System.Drawing.Point(110, 128)
    $ispComboBox.DropDownStyle = "DropDownList"
    $ispComboBox.Items.AddRange(@("校园网(本地)", "移动", "联通", "电信"))
    $ispComboBox.SelectedIndex = 0
    $form.Controls.Add($ispComboBox)

    $autoStartCheckBox = New-Object System.Windows.Forms.CheckBox
    $autoStartCheckBox.Text = "开机自动登录"
    $autoStartCheckBox.Font = $labelFont
    $autoStartCheckBox.Size = New-Object System.Drawing.Size(200, 25)
    $autoStartCheckBox.Location = New-Object System.Drawing.Point(110, 165)
    $autoStartCheckBox.Checked = $true
    $form.Controls.Add($autoStartCheckBox)

    $notifyCheckBox = New-Object System.Windows.Forms.CheckBox
    $notifyCheckBox.Text = "显示登录通知"
    $notifyCheckBox.Font = $labelFont
    $notifyCheckBox.Size = New-Object System.Drawing.Size(200, 25)
    $notifyCheckBox.Location = New-Object System.Drawing.Point(110, 195)
    $notifyCheckBox.Checked = $true
    $form.Controls.Add($notifyCheckBox)

    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Text = "保存并登录"
    $saveButton.Font = $buttonFont
    $saveButton.Size = New-Object System.Drawing.Size(150, 40)
    $saveButton.Location = New-Object System.Drawing.Point(125, 235)
    $saveButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $saveButton.ForeColor = [System.Drawing.Color]::White
    $saveButton.FlatStyle = "Flat"
    $form.Controls.Add($saveButton)

    $global:configResult = $null

    $saveButton.Add_Click({
        $userId = $userTextBox.Text.Trim()
        $password = $passTextBox.Text
        $ispIndex = $ispComboBox.SelectedIndex
        
        if ([string]::IsNullOrEmpty($userId) -or [string]::IsNullOrEmpty($password)) {
            [System.Windows.Forms.MessageBox]::Show("请输入账号和密码！", "提示", "OK", "Warning")
            return
        }
        
        $suffix = switch ($ispIndex) {
            0 { "gxylocal" }
            1 { "gxyyd" }
            2 { "gxylt" }
            3 { "gxydx" }
            default { "gxylocal" }
        }
        
        if ($userId -notmatch "@") { $userId = "$userId@$suffix" }
        
        $global:configResult = @{
            userId = $userId
            password = $password
            ispType = $ispIndex
            autoStart = $autoStartCheckBox.Checked
            showNotify = $notifyCheckBox.Checked
            loginUrl = "http://211.69.15.10:6060/quickauth.do"
            wlanAcName = "HAIT-SR8808"
            wlanAcIp = "172.21.8.73"
            portalPageId = 21
        }
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })

    if (Test-Path $global:configPath) {
        try {
            $existing = Get-Content $global:configPath | ConvertFrom-Json
            $userTextBox.Text = $existing.userId -replace "@.*$", ""
            $passTextBox.Text = $existing.password
            if ($existing.ispType -ne $null) { $ispComboBox.SelectedIndex = $existing.ispType }
            $autoStartCheckBox.Checked = $existing.autoStart
            $notifyCheckBox.Checked = $existing.showNotify
        } catch {}
    }

    $result = $form.ShowDialog()
    return $global:configResult
}

function Enable-AutoStart {
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($global:shortcutPath)
        $Shortcut.TargetPath = "powershell.exe"
        $Shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$($global:scriptPath)\校园网自动登录.ps1`" -Login"
        $Shortcut.WorkingDirectory = $global:scriptPath
        $Shortcut.Save()
        Write-Log "开机自启已启用: $($global:shortcutPath)"
        Write-Log "快捷方式目标: powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$($global:scriptPath)\校园网自动登录.ps1`" -Login"
        return $true
    } catch { 
        Write-Log "启用开机自启失败: $_"
        return $false 
    }
}

function Disable-AutoStart {
    try {
        if (Test-Path $global:shortcutPath) { Remove-Item $global:shortcutPath -Force }
        Write-Log "开机自启已关闭"
        return $true
    } catch { 
        Write-Log "关闭开机自启失败: $_"
        return $false 
    }
}

function Show-AutoStartMenu {
    $status = Test-Path $global:shortcutPath
    $msg = if ($status) { "当前：已开启开机自启`n是否关闭？" } else { "当前：未开启开机自启`n是否开启？" }
    $result = [System.Windows.Forms.MessageBox]::Show($msg, "开机自启", "YesNo", "Question")
    if ($result -eq "Yes") {
        if ($status) { Disable-AutoStart } else { Enable-AutoStart }
    }
}

function Show-MainMenu {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "校园网自动登录 - By 诺亚 723167066"
    $form.Size = New-Object System.Drawing.Size(350, 280)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 245)

    $titleFont = New-Object System.Drawing.Font("Microsoft YaHei", 14, [System.Drawing.FontStyle]::Bold)
    $buttonFont = New-Object System.Drawing.Font("Microsoft YaHei", 10, [System.Drawing.FontStyle]::Bold)

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "校园网自动登录"
    $titleLabel.Font = $titleFont
    $titleLabel.Size = New-Object System.Drawing.Size(330, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(10, 15)
    $titleLabel.TextAlign = "MiddleCenter"
    $form.Controls.Add($titleLabel)

    $configButton = New-Object System.Windows.Forms.Button
    $configButton.Text = "配置账号"
    $configButton.Font = $buttonFont
    $configButton.Size = New-Object System.Drawing.Size(150, 45)
    $configButton.Location = New-Object System.Drawing.Point(25, 70)
    $configButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $configButton.ForeColor = [System.Drawing.Color]::White
    $configButton.FlatStyle = "Flat"
    $form.Controls.Add($configButton)

    $loginButton = New-Object System.Windows.Forms.Button
    $loginButton.Text = "立即登录"
    $loginButton.Font = $buttonFont
    $loginButton.Size = New-Object System.Drawing.Size(150, 45)
    $loginButton.Location = New-Object System.Drawing.Point(175, 70)
    $loginButton.BackColor = [System.Drawing.Color]::FromArgb(0, 180, 100)
    $loginButton.ForeColor = [System.Drawing.Color]::White
    $loginButton.FlatStyle = "Flat"
    $form.Controls.Add($loginButton)

    $autoStartButton = New-Object System.Windows.Forms.Button
    $autoStartButton.Text = "开机自启"
    $autoStartButton.Font = $buttonFont
    $autoStartButton.Size = New-Object System.Drawing.Size(150, 45)
    $autoStartButton.Location = New-Object System.Drawing.Point(25, 135)
    $autoStartButton.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
    $autoStartButton.ForeColor = [System.Drawing.Color]::White
    $autoStartButton.FlatStyle = "Flat"
    $form.Controls.Add($autoStartButton)

    $exitButton = New-Object System.Windows.Forms.Button
    $exitButton.Text = "退出"
    $exitButton.Font = $buttonFont
    $exitButton.Size = New-Object System.Drawing.Size(150, 45)
    $exitButton.Location = New-Object System.Drawing.Point(175, 135)
    $exitButton.BackColor = [System.Drawing.Color]::FromArgb(150, 150, 150)
    $exitButton.ForeColor = [System.Drawing.Color]::White
    $exitButton.FlatStyle = "Flat"
    $form.Controls.Add($exitButton)

    $global:menuResult = $null

    $configButton.Add_Click({
        $global:menuResult = "Config"
        $form.Close()
    })

    $loginButton.Add_Click({
        $global:menuResult = "Login"
        $form.Close()
    })

    $autoStartButton.Add_Click({
        $global:menuResult = "AutoStart"
        $form.Close()
    })

    $exitButton.Add_Click({
        $global:menuResult = "Exit"
        $form.Close()
    })

    $form.ShowDialog()
    return $global:menuResult
}

Write-Log "脚本启动，路径: $global:scriptPath"
Write-Log "配置文件路径: $global:configPath"
Write-Log "PSScriptRoot: $PSScriptRoot"
Write-Log "PSCommandPath: $PSCommandPath"

if ($args -contains "-Login") {
    Write-Log "开机自动登录模式"
    
    Write-Log "等待网络连接..."
    $networkReady = $false
    for ($wait = 1; $wait -le 30; $wait++) {
        try {
            $network = Get-NetConnectionProfile -ErrorAction SilentlyContinue
            if ($network -and $network.Status -eq "Connected") {
                Write-Log "网络已连接 (等待 ${wait} 秒)"
                $networkReady = $true
                break
            }
        } catch {}
        Write-Log "等待网络... ($wait/30)"
        Start-Sleep -Seconds 1
    }
    
    if (-not $networkReady) {
        Write-Log "网络未连接，尝试登录..."
    }
    
    Start-Sleep -Seconds 3
    Write-Log "检查配置文件: $global:configPath"
    if (Test-Path $global:configPath) {
        Write-Log "配置文件存在，读取配置..."
        try {
            $cfg = Get-Content $global:configPath -Raw | ConvertFrom-Json
            Write-Log "配置读取成功，用户: $($cfg.userId)"
            $configHash = @{
                userId = $cfg.userId
                password = $cfg.password
                showNotify = $cfg.showNotify
                loginUrl = $cfg.loginUrl
                wlanAcName = $cfg.wlanAcName
                wlanAcIp = $cfg.wlanAcIp
                portalPageId = $cfg.portalPageId
            }
            Invoke-CampusLogin -config $configHash
        } catch {
            Write-Log "读取配置失败: $_"
        }
    } else {
        Write-Log "配置文件不存在: $global:configPath"
    }
} else {
    if (-not (Test-Path $global:configPath)) {
        $result = Show-ConfigForm
        if ($result) {
            $result | ConvertTo-Json -Depth 10 | Out-File -FilePath $global:configPath -Encoding UTF8
            if ($result.autoStart) { Enable-AutoStart }
            Invoke-CampusLogin -config $result
        }
    } else {
        $choice = Show-MainMenu
        switch ($choice) {
            "Config" {
                $result = Show-ConfigForm
                if ($result) {
                    $result | ConvertTo-Json -Depth 10 | Out-File -FilePath $global:configPath -Encoding UTF8
                    if ($result.autoStart) { Enable-AutoStart } else { Disable-AutoStart }
                    Invoke-CampusLogin -config $result
                }
            }
            "Login" {
                $cfg = Get-Content $global:configPath -Raw | ConvertFrom-Json
                $configHash = @{
                    userId = $cfg.userId
                    password = $cfg.password
                    showNotify = $cfg.showNotify
                    loginUrl = $cfg.loginUrl
                    wlanAcName = $cfg.wlanAcName
                    wlanAcIp = $cfg.wlanAcIp
                    portalPageId = $cfg.portalPageId
                }
                Invoke-CampusLogin -config $configHash
            }
            "AutoStart" { Show-AutoStartMenu }
        }
    }
}
