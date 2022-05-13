# PowerShell Scripts
A collection of scripts written for my job. They are outlined below:

### Enable_BitLocker
Checks that a given computer has a TPM, enables it if it isn't already, encrypts the `C:` drive, and sends the recovery key to Atera (our system manager).

### Get_BitLocker_Keys
Grabs any BitLocker recovery keys from all drives on a computer and sends them to Atera custom fields.

### Get_ManuShip_Dates
Grabs manufacture and ship dates for Dell computers.

### Get_TeamViewer_ID
Grabs the computer's TeamViewer ID and sends it to an Atera custom field.

## Modules and Cmdlets
- `PSAtera`
- `Get-Tpm`
- `DellBIOSProvider`
- `Get-BitLockerVolume`
- `Enable-BitLocker`
