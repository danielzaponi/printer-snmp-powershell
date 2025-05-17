param(
    [string]$Host,
    [string]$Community = "public"
)

# Solicita o host caso não seja passado por parâmetro
if (-not $Host) {
    $Host = Read-Host "Digite o IP ou hostname da impressora"
}

# OIDs principais usados no PHP
$OIDs = @{
    FactoryId             = ".1.3.6.1.2.1.25.3.2.1.3.1"
    VendorName            = ".1.3.6.1.2.1.43.9.2.1.8.1.1"
    SerialNumber          = ".1.3.6.1.2.1.43.5.1.1.17.1"
    PrintedPapers         = ".1.3.6.1.2.1.43.10.2.1.4.1.1"
    CartridgeColorSlot1   = ".1.3.6.1.2.1.43.12.1.1.4.1.1"
    MaxTonerSlots         = @(
        ".1.3.6.1.2.1.43.11.1.1.8.1.1",
        ".1.3.6.1.2.1.43.11.1.1.8.1.2",
        ".1.3.6.1.2.1.43.11.1.1.8.1.3",
        ".1.3.6.1.2.1.43.11.1.1.8.1.4",
        ".1.3.6.1.2.1.43.11.1.1.8.1.5"
    )
    ActualTonerSlots      = @(
        ".1.3.6.1.2.1.43.11.1.1.9.1.1",
        ".1.3.6.1.2.1.43.11.1.1.9.1.2",
        ".1.3.6.1.2.1.43.11.1.1.9.1.3",
        ".1.3.6.1.2.1.43.11.1.1.9.1.4",
        ".1.3.6.1.2.1.43.11.1.1.9.1.5"
    )
}

function Get-SNMPValue {
    param(
        [string]$OID
    )
    $result = snmpget -v 2c -c $Community $Host $OID 2>&1
    if ($result -match ' = (.*): (.*)$') {
        return $Matches[2].Trim('"')
    } else {
        return $null
    }
}

function Get-TonerLevel {
    param(
        [string]$MaxOID,
        [string]$ActualOID
    )
    $max = Get-SNMPValue $MaxOID
    $actual = Get-SNMPValue $ActualOID
    if ($null -eq $max -or $null -eq $actual) { return $null }
    if ([int]$actual -le 0) { return [int]$actual }
    return [math]::Round(($actual / ($max / 100)),2)
}

# Descobre se é colorida (slot 1 = cyan)
$color1 = Get-SNMPValue $OIDs.CartridgeColorSlot1
if ($color1 -and $color1.ToLower() -eq "cyan") {
    $PrinterType = "color printer"
} else {
    $PrinterType = "mono printer"
}

# Toner levels
if ($PrinterType -eq "color printer") {
    $BlackToner   = Get-TonerLevel $OIDs.MaxTonerSlots[3] $OIDs.ActualTonerSlots[3]
    $CyanToner    = Get-TonerLevel $OIDs.MaxTonerSlots[0] $OIDs.ActualTonerSlots[0]
    $MagentaToner = Get-TonerLevel $OIDs.MaxTonerSlots[1] $OIDs.ActualTonerSlots[1]
    $YellowToner  = Get-TonerLevel $OIDs.MaxTonerSlots[2] $OIDs.ActualTonerSlots[2]
    $DrumLevel    = Get-TonerLevel $OIDs.MaxTonerSlots[4] $OIDs.ActualTonerSlots[4]
} else {
    $BlackToner = Get-TonerLevel $OIDs.MaxTonerSlots[0] $OIDs.ActualTonerSlots[0]
    $DrumLevel  = Get-TonerLevel $OIDs.MaxTonerSlots[1] $OIDs.ActualTonerSlots[1]
    $CyanToner = $MagentaToner = $YellowToner = $null
}

# Monta objeto final
$printerInfo = [PSCustomObject]@{
    current_time         = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
    printer_type         = $PrinterType
    factory_name         = Get-SNMPValue $OIDs.FactoryId
    vendor               = Get-SNMPValue $OIDs.VendorName
    serial_number        = Get-SNMPValue $OIDs.SerialNumber
    black_toner          = $BlackToner
    cyan_toner           = $CyanToner
    magenta_toner        = $MagentaToner
    yellow_toner         = $YellowToner
    drum_level           = $DrumLevel
    printed_papers       = Get-SNMPValue $OIDs.PrintedPapers
}

$printerInfo | Format-List
