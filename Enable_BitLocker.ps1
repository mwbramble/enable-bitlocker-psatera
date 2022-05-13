Set-ExecutionPolicy Bypass -Scope Process -Force
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

if(-not (Get-Module -ListAvailable -Name PSAtera)){
    'Installing PSAtera...'
    Install-Module PSAtera -Force
}

Import-Module PSAtera -Force
Set-AteraAPIKey -APIKey {your_api_key_here}

$tpm = Get-Tpm
$agent = Get-AteraAgent
$blComplete = 0

if(!$tpm.TpmPreset){
    'TPM not found!'

    if (-not ((Get-WmiObject win32_bios).Manufacturer -like "Dell*")) {
            'Agent is not a Dell computer, so the TPM cannot be enabled.'
            break
    }
    
    if (-not (Get-Module -ListAvailable -Name DellBIOSProvider)) {
        'Installing DellBIOSProvider Module...'
        Install-Module -Name DellBIOSProvider -Force
    }

    Import-Module DellBIOSProvider

    'Setting attributes...'
    Set-Item -Path DellSmbios:\TpmSecurity\TpmSecurity "Enabled" -Password {your_bios_password_here} -ErrorAction SilentlyContinue
    Set-Item -Path DellSmbios:\TpmSecurity\TPMActivation "Enabled" -Password {your_bios_password_here} -ErrorAction SilentlyContinue
    Set-Item -Path DellSmbios:\TpmSecurity\TpmActivation "Enabled" -Password {your_bios_password_here} -ErrorAction SilentlyContinue
}

$blVolume = Get-BitLockerVolume -MountPoint C

if($blVolume.VolumeStatus -eq "FullyEncrypted"){
    $key = $blVolume.KeyProtector.RecoveryPassword
    'Drive already encrypted!'
    Write-Output($key)
    if($key.Length -gt 1){
        'Sending recovery key to Atera...'
        Set-AteraCustomValue -ObjectType Agent -ObjectID $agent.AgentID -FieldName "Bitlocker Key 1" -Value "C:\ $key"
    }
    break
}

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
