Set-ExecutionPolicy Bypass -Scope Process -Force

$tpm = Get-Tpm
if(!$tpm.TpmPresent){
    'Agent does not have TPM.'
    break
}

Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

if(-not (Get-Module -ListAvailable -Name PSAtera)){
    'Installing PSAtera...'
    Install-Module PSAtera -Force
}

Import-Module PSAtera -Force
Set-AteraAPIKey -APIKey {your_api_key_here}

$agent = Get-AteraAgent
$blVolume = Get-BitLockerVolume -MountPoint C

if($blVolume.VolumeStatus -eq "FullyEncrypted"){
    'Drive already encrypted!'
    $key = $blVolume.KeyProtector.RecoveryPassword
    if($key.Length -le 1){
        $cmdOutput = "manage-bde -protectors -add -rp C:" | cmd
        $newBlVolume = Get-BitLockerVolume -MountPoint C
        $key = $newBlVolume.KeyProtector.RecoveryPassword
        Write-Output($cmdOutput)
        'Sending recovery key to Atera...'
        Set-AteraCustomValue -ObjectType Agent -ObjectID $agent.AgentID -FieldName "Bitlocker Key 1" -Value "C:\ $key"
        break
    }
    if($key.Length -gt 1){
        Write-Output($key)
        'Sending recovery key to Atera...'
        Set-AteraCustomValue -ObjectType Agent -ObjectID $agent.AgentID -FieldName "Bitlocker Key 1" -Value "C:\ $key"
        break
    }
}

if(!$tpm.TpmReady){
    if (-not ((Get-WmiObject win32_bios).Manufacturer -like "Dell*")) {
        'Agent is not a Dell computer, so the TPM cannot be enabled.'
        break
    }
    if (-not (Get-Module -ListAvailable -Name DellBIOSProvider)) {
        'Installing DellBIOSProvider Module...'
        Install-Module -Name DellBIOSProvider -Force
        Import-Module -Name DellBIOSProvider -Force

        $adminPassStatus = Get-Item -Path DellSmbios:\Security\IsAdminPasswordSet

        if($adminPassStatus){
            'Setting attributes...'
            Set-Item -Path DellSmbios:\TpmSecurity\TpmSecurity "Enabled" -Password {your_bios_password_here} -ErrorAction SilentlyContinue
            Set-Item -Path DellSmbios:\TpmSecurity\TPMActivation "Enabled" -Password {your_bios_password_here} -ErrorAction SilentlyContinue
            Set-Item -Path DellSmbios:\TpmSecurity\TpmActivation "Enabled" -Password {your_bios_password_here} -ErrorAction SilentlyContinue
        }

        if(!$adminPassStatus){
            'Admin password disabled! Setting attributes...'
            Set-Item -Path DellSmbios:\TpmSecurity\TpmSecurity "Enabled" -ErrorAction SilentlyContinue
            Set-Item -Path DellSmbios:\TpmSecurity\TPMActivation "Enabled" -ErrorAction SilentlyContinue
            Set-Item -Path DellSmbios:\TpmSecurity\TpmActivation "Enabled" -ErrorAction SilentlyContinue
        }
    } 
}

$blComplete = 0

if($blVolume.VolumeStatus -eq "FullyDecrypted"){
    'Encryption in progress...'
    Enable-BitLocker C: -EncryptionMethod Aes128 -StartupKeyProtector -StartupKeyPath C: -SkipHardwareTest | Out-Null
    $cmdOutput = "manage-bde -protectors -add -rp C:" | cmd
    Write-Output($cmdOutput)

    do{
        $blProgress = Get-BitLockerVolume -MountPoint C
        $blVolume = Get-BitLockerVolume -MountPoint C
        if($blProgress.VolumeStatus -eq "FullyEncrypted"){
            $key = $blVolume.KeyProtector.RecoveryPassword
            if($key.Length -gt 1){
                'Sending recovery key to Atera...'
                Set-AteraCustomValue -ObjectType Agent -ObjectID $agent.AgentID -FieldName "Bitlocker Key 1" -Value "C:\ $key"
            }
        }
    } while($blComplete -eq 0)
    'Encryption complete!'
    break
}
