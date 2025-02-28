# autor: marcilio ramos
# data: 12-02-2025
# finalidade: automatizar instalação do agente windows zabbix
# comando para executar o script:
# powershell -ExecutionPolicy Bypass -NoProfile -Command "iwr -UseBasicParsing 'https://raw.githubusercontent.com/monitoring-hdbr/zabbix-automacao/refs/heads/main/install-zabbix-agent2.ps1' | Invoke-Expression"

# Solicitação interativa de parâmetros ao usuário
$HDNUMBER = Read-Host "Informe o HDNUMBER (ex: HD28222, HDCOLO28222, HDVDC11, HDFW319)"
$DC = Read-Host "Informe o DC (SPO ou JPA)"
$CLIENTE = Read-Host "Informe o CLIENTE (ex: MIA, SEBRAE, Hostdime, TRE, CREA)"
$HOSTNAME = Read-Host "Informe o HOSTNAME (ex: Mysql-Prod, AD-Primario, DNS-Primario)"
$TIPO = Read-Host "Informe o TIPO do Host (ex: NODE ou VM)"

# Construção do hostname
$server_name = ("$TIPO.$HDNUMBER.$DC.$CLIENTE.$HOSTNAME.WINDOWS").ToUpper()
Write-Host "Hostname gerado: $server_name"

# Configurações
$server = "127.0.0.1"
$serverActive = "cm.hostdime.com.br:10083"
$hostMetadata = "dimenoc##1223##HDBRASIL"
$install_folder = 'C:\Program Files\Zabbix Agent'
$zabbix_base_url = "https://cdn.zabbix.com/zabbix/binaries/stable/7.0"

# Função auxiliar para obter a versão mais alta
function Get-LatestVersion {
    param(
        [string]$baseUrl
    )
    try {
        $response = Invoke-WebRequest -Uri $baseUrl -UseBasicParsing
        if (-not $response.Content) {
            throw "Conteúdo da página está vazio."
        }

        # Regex para capturar as versões
        $versionMatches = [regex]::Matches($response.Content, "7\.0\.(\d+)")

        if ($versionMatches.Count -eq 0) {
            throw "Nenhuma versão encontrada."
        }

        $latestVersion = 0
        foreach ($match in $versionMatches) {
            $versionNumber = [int]$match.Groups[1].Value
            if ($versionNumber -gt $latestVersion) {
                $latestVersion = $versionNumber
            }
        }

        if ($latestVersion -gt 0) {
            return $latestVersion
        } else {
            throw "Nenhuma versão válida encontrada."
        }
    } catch {
        Write-Host "Erro ao buscar versões: $_"
        return $null
    }
}

# Obter a versão mais recente
$latest_version = Get-LatestVersion -baseUrl $zabbix_base_url

if ($latest_version -ne $null) {
    $latest_version_url_zip = "$zabbix_base_url/7.0.$latest_version/zabbix_agent2-7.0.$latest_version-windows-amd64-openssl-static.zip"
    $latest_version_url_msi = "$zabbix_base_url/7.0.$latest_version/zabbix_agent2-7.0.$latest_version-windows-amd64-openssl.msi"

    Write-Host "Verificando se o arquivo ZIP existe: $latest_version_url_zip"

    # Verificação de arquivos da versão mais recente
    $download_url = $null
    $file_type = $null

    try {
        # Tentar baixar o .zip
        $response_zip = Invoke-WebRequest -Uri $latest_version_url_zip -UseBasicParsing -ErrorAction Stop
        $download_url = $latest_version_url_zip
        $file_type = "zip"
    } catch {
        Write-Host "Arquivo ZIP não encontrado, tentando o arquivo MSI..."
        
        # Se não existia o zip, tentar o MSI
        try {
            $response_msi = Invoke-WebRequest -Uri $latest_version_url_msi -UseBasicParsing -ErrorAction Stop
            $download_url = $latest_version_url_msi
            $file_type = "msi"
        } catch {
            Write-Host "Arquivo MSI não encontrado. Usando versão de fallback."
        }
    }

    # Se não encontrou nem ZIP nem MSI, tente a versão de fallback
    if (-not $download_url) {
        $fallback_version = "9"  # Ajustado para uma versão conhecida, mude conforme necessário
        $fallback_version_url_zip = "$zabbix_base_url/7.0.$fallback_version/zabbix_agent2-7.0.$fallback_version-windows-amd64-openssl-static.zip"
        $fallback_version_url_msi = "$zabbix_base_url/7.0.$fallback_version/zabbix_agent2-7.0.$fallback_version-windows-amd64-openssl.msi"

        Write-Host "Verificando a versão de fallback..."

        try {
            # Tentativa de verificar a existência do .zip na versão de fallback
            $response_fallback_zip = Invoke-WebRequest -Uri $fallback_version_url_zip -UseBasicParsing -ErrorAction Stop
            $download_url = $fallback_version_url_zip
            $file_type = "zip"
            Write-Host "Usando versão de fallback (ZIP): $download_url"
        } catch {
            Write-Host "Fallback ZIP não encontrado, tentando o fallback MSI..."
            try {
                $response_fallback_msi = Invoke-WebRequest -Uri $fallback_version_url_msi -UseBasicParsing -ErrorAction Stop
                $download_url = $fallback_version_url_msi
                $file_type = "msi"
                Write-Host "Usando versão de fallback (MSI): $download_url"
            } catch {
                throw "Nenhum arquivo encontrado para download."
            }
        }
    }

    Write-Host "URL do instalador: $download_url"
} else {
    Write-Host "Nenhuma versão disponível encontrada."
    exit
}

# Log
$DataStamp = get-date -Format yyyy.MM.dd-HH.mm.ss
$logFile = "{0}\{1}-{2}.log" -f $env:TEMP,"install-zabbix-agent",$DataStamp

# Download do binário
Write-Host 'Fazendo download do instalador'
try {
    Invoke-WebRequest -Uri $download_url -OutFile "$env:TEMP\zabbix_agent.$file_type"
} catch {
    Write-Host "Falha ao baixar o arquivo do Zabbix Agent. URL: $download_url"
    throw "Erro: $_"
}

# Instalação do Zabbix Agent 2
if ($file_type -eq "msi") {
    $msi_path = "$env:TEMP\zabbix_agent.$file_type"
    Write-Host 'Instalando o Zabbix Agent 2'
    $MSIArguments = @(
        "/passive",
        "/norestart",
        "/l*v `"$logFile`"",
        "/i `"$msi_path`"",
        "ADDLOCAL=`"AgentProgram,MSIPackageFeature`"",
        "LOGTYPE=`"file`"",
        "LOGFILE=`"$install_folder\log\zabbix_agentd.log`"",
        "ENABLEREMOTECOMMANDS=`"1`"",
        "SERVER=`"$server`"",
        "SERVERACTIVE=`"$serverActive`"",
        "HOSTNAME=`"$server_name`"",
        "HOSTMETADATA=`"$hostMetadata`"",
        "TIMEOUT=`"15`"",
        "INSTALLFOLDER=`"$install_folder`"",
        "ENABLEPATH=`"1`"",
        "SKIP=`"fw`""
    )
    Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait
    Remove-Item -Path $msi_path -Recurse
} elseif ($file_type -eq "zip") {
    # Extraindo o ZIP
    Write-Host 'Extraindo o Zabbix Agent 2'
    Expand-Archive -Path "$env:TEMP\zabbix_agent.zip" -DestinationPath "$env:TEMP\zabbix_agent" -Force
    $msi_path = Get-ChildItem -Path "$env:TEMP\zabbix_agent" -Filter "*.msi" | Select-Object -First 1

    # Instalação do Zabbix Agent 2
    if ($msi_path) {
        Write-Host 'Instalando o Zabbix Agent 2'
        $MSIArguments = @(
            "/passive",
            "/norestart",
            "/l*v `"$logFile`"",
            "/i `"$msi_path`"",
            "ADDLOCAL=`"AgentProgram,MSIPackageFeature`"",
            "LOGTYPE=`"file`"",
            "LOGFILE=`"$install_folder\log\zabbix_agentd.log`"",
            "ENABLEREMOTECOMMANDS=`"1`"",
            "SERVER=`"$server`"",
            "SERVERACTIVE=`"$serverActive`"",
            "HOSTNAME=`"$server_name`"",
            "HOSTMETADATA=`"$hostMetadata`"",
            "TIMEOUT=`"15`"",
            "INSTALLFOLDER=`"$install_folder`"",
            "ENABLEPATH=`"1`"",
            "SKIP=`"fw`""
        )
        Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait
    }

    # Limpeza
    Remove-Item -Path "$env:TEMP\zabbix_agent.zip" -Recurse
    Remove-Item -Path "$env:TEMP\zabbix_agent" -Recurse
}

# Configuração do arquivo de configuração do Zabbix Agent
$confFile = "$install_folder\zabbix_agent2.conf"
if (Test-Path $confFile) {
    Write-Host 'Atualizando arquivo de configuração do Zabbix Agent'
    (Get-Content $confFile) |
        ForEach-Object {
            $_ -replace '^Server=.*', "Server=$server" `
               -replace '^ServerActive=.*', "ServerActive=$serverActive" `
               -replace '^Hostname=.*', "Hostname=$server_name" `
               -replace '^HostMetadata=.*', "HostMetadata=$hostMetadata"
        } | Set-Content $confFile
}

# Regras de firewall
Write-Host '>>> Criando regra de firewall'
New-NetFirewallRule -DisplayName "Zabbix Agent" -Direction inbound -Profile Any -Action Allow -LocalPort 10050 -Protocol TCP | Out-File -Append -FilePath "$logFile"

# Iniciar o serviço do Zabbix Agent 2
Write-Host '>>> Iniciando o serviço'
Start-Service -Name "Zabbix Agent 2" | Out-File -Append -FilePath "$logFile"

# Informações finais
Write-Host "\n>>> Instalação concluída! <<<"
Write-Host "\n> Hostname = $server_name"
Write-Host "\n> Install Folder = $install_folder"
