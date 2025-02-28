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
$zip_file_pattern = "zabbix_agent2-7.0.{0}-windows-amd64-openssl-static.zip"
$latest_version = 0  # Versão inicial para comparação
$latest_version_url = ""

# Verificação da versão mais recente
try {
    $latest_version_response = Invoke-WebRequest -Uri $zabbix_base_url -UseBasicParsing
    $latest_version_match = Select-String -InputObject $latest_version_response.Content -Pattern "zabbix_agent2-7\.0\.(\d+)-windows" -AllMatches

    foreach ($match in $latest_version_match) {
        $version_number = $match.Matches.Groups[1].Value
        if ([int]$version_number -gt [int]$latest_version) {
            $latest_version = $version_number
            # Ajustando a URL para o formato correto
            $latest_version_url = "$zabbix_base_url/7.0.$latest_version/$($zip_file_pattern -f $latest_version)"
            Write-Host "Encontrada versão: $latest_version"
        }
    }

    if (-not $latest_version_url) {
        throw "Nenhuma versão válida encontrada."
    }

    Write-Host "Versão mais recente do Zabbix Agent 2: $latest_version"
    Write-Host "URL do instalador: $latest_version_url"
} catch {
    Write-Host "Erro ao buscar as versões disponíveis do Zabbix Agent 2: $_"
    # Fallback: Use a versão de fallback que sabe que está disponível.
    $fallback_version = "8"  # Ajuste para uma versão conhecida.
    $latest_version_url = "$zabbix_base_url/7.0.$fallback_version/$($zip_file_pattern -f $fallback_version)"
    Write-Host "Usando versão em fallback: $latest_version_url"
}

# Log
$DataStamp = get-date -Format yyyy.MM.dd-HH.mm.ss
$logFile = "{0}\{1}-{2}.log" -f $env:TEMP,"install-zabbix-agent",$DataStamp

# Download do binário
Write-Host 'Fazendo download do instalador'
try {
    Invoke-WebRequest -Uri $latest_version_url -OutFile "$env:TEMP\zabbix_agent.zip"
} catch {
    Write-Host "Falha ao baixar o arquivo do Zabbix Agent. URL: $latest_version_url"
    throw "Erro: $_"
}

# Extraindo o ZIP
if (Test-Path "$env:TEMP\zabbix_agent.zip") {
    Write-Host 'Extraindo o Zabbix Agent 2'
    Expand-Archive -Path "$env:TEMP\zabbix_agent.zip" -DestinationPath "$env:TEMP\zabbix_agent" -Force
    $msi_path = Get-ChildItem -Path "$env:TEMP\zabbix_agent" -Filter "*.msi" | Select-Object -First 1
} else {
    throw "Falha ao baixar o arquivo do Zabbix Agent."
}

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
Write-Host "\n> Instalation Folder = $install_folder"
