# =============================================================================
# info_host.ps1 — recolhe a configuração do anfitrião Windows 11 e das VMs
# Abrir o PowerShell COMO ADMINISTRADOR, ir para a pasta deste ficheiro e:
#     Set-ExecutionPolicy -Scope Process Bypass
#     .\info_host.ps1 -VmwareVmDir "C:\caminho\para\a\pasta\da\VM\VMware"
# Gera  info_host.txt  -> enviar.
# Correr DUAS vezes: (1) na configuração usada para o Hyper-V e
#                    (2) na configuração usada para o VMware (depois de reiniciar).
# =============================================================================
param([string]$VmwareVmDir = "")

$out = "info_host_$(Get-Date -Format yyyyMMdd_HHmm).txt"
& {
  "== CPU";        Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed,VirtualizationFirmwareEnabled | Format-List
  "== RAM";        Get-CimInstance Win32_PhysicalMemory | Select-Object Manufacturer,PartNumber,Capacity,Speed,ConfiguredClockSpeed | Format-Table -AutoSize
  "== Discos";     Get-PhysicalDisk | Select-Object FriendlyName,MediaType,BusType,Size | Format-Table -AutoSize
  "== Volumes";    Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter,FileSystem,Size,SizeRemaining | Format-Table -AutoSize
  "== Windows";    Get-ComputerInfo | Select-Object WindowsProductName,WindowsVersion,OsBuildNumber,HyperVisorPresent,HyperVRequirementVirtualizationFirmwareEnabled | Format-List
  "== Funcionalidade Hyper-V"; Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All | Select-Object FeatureName,State
  "== Plataforma de Hipervisor do Windows"; Get-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform | Select-Object FeatureName,State
  "== bcdedit (hypervisorlaunchtype)"; bcdedit /enum "{current}" | Select-String -Pattern "hypervisorlaunchtype"
  "== VBS / Integridade de Memoria"; Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard | Select-Object VirtualizationBasedSecurityStatus,SecurityServicesConfigured,SecurityServicesRunning | Format-List
  "== Plano de energia"; powercfg /getactivescheme
  "== Bateria (portatil?)"; Get-CimInstance Win32_Battery | Select-Object Name,BatteryStatus
  "== Exclusoes Defender"; (Get-MpPreference).ExclusionPath
  "== Tipo de escalonador do Hyper-V (0x2 classic, 0x3 core, 0x4 root)"
  Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-Hyper-V-Hypervisor';Id=2} -MaxEvents 1 -ErrorAction SilentlyContinue | Select-Object TimeCreated,Message | Format-List

  "== Hyper-V: VMs"
  Get-VM -ErrorAction SilentlyContinue | Select-Object Name,State,Generation,Version,ProcessorCount,MemoryStartup,DynamicMemoryEnabled | Format-List
  Get-VM -ErrorAction SilentlyContinue | Get-VMProcessor | Select-Object VMName,Count,Reserve,Maximum,RelativeWeight,CompatibilityForMigrationEnabled | Format-List
  Get-VM -ErrorAction SilentlyContinue | Get-VMHardDiskDrive | Select-Object VMName,ControllerType,Path | Format-List
  Get-VM -ErrorAction SilentlyContinue | Get-VMHardDiskDrive | Get-VHD | Select-Object Path,VhdFormat,VhdType,Size,FileSize,LogicalSectorSize,PhysicalSectorSize | Format-List

  if ($VmwareVmDir -ne "") {
    "== VMware: ficheiro .vmx"
    Get-ChildItem $VmwareVmDir -Filter *.vmx | ForEach-Object { Get-Content $_.FullName }
    "== VMware: descritores .vmdk (tipo de disco)"
    Get-ChildItem $VmwareVmDir -Filter *.vmdk | Select-Object Name,Length | Format-Table -AutoSize
    "== VMware: modo do monitor (CPL0 = nativo | ULM = a correr sobre o Hyper-V)"
    Get-ChildItem $VmwareVmDir -Filter vmware*.log | ForEach-Object {
      "--- $($_.Name)"; Select-String -Path $_.FullName -Pattern "Monitor Mode","ULM","CPL0","Hyper-V","VBS","WHP","Product version" | Select-Object -First 25 | ForEach-Object { $_.Line }
    }
  }
} *> $out
Write-Host "Feito -> $out"
