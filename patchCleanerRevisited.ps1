<#
.SYNOPSIS
  A GUI tool to manage the C:\Windows\Installer folder by identifying and cleaning orphaned or outdated MSI/MSP files.

.DESCRIPTION
  This script provides a comprehensive interface to safely reclaim disk space from the Windows Installer cache.
  It compares physical files against the registered products and patches in the Windows Installer database.

  Key Features:
  - Orphaned Detection: Finds files no longer linked to any installed product.
  - Registered View: Optionally displays all registered installers for management.
  - Deep Scan: Reads digital certificates for more accurate identification and filtering.
  - Smart Filters:
    - Text Search: Real-time filtering with a manual refresh button.
    - Show Selected Only: Toggle to focus on checked items.
    - Exclusions: Customizable list to protect specific vendors (e.g., Adobe) or products.
  - Specialized Cleaning:
    - .NET Framework Cleanup: Automatically identifies and selects older .NET patches, keeping only the latest version for each branch.
  - Safety & Management:
    - System Restore: Option to create a restore point before any deletion or uninstallation.
    - Batch Uninstall: Uses msiexec with basic UI (/qb) for reliable, non-interactive uninstallation of multiple packages.
    - Batch Delete: Directly removes selected files from disk (use with caution for registered items).
    - Export: Save the list of identified files to a text file.
  - Dynamic UI:
    - Status bar showing "Selected / Total" items.
    - Progress counter showing "Remaining / Total" during batch operations.

.PARAMETER Help
  Displays this help message.

.EXAMPLE
  .\patchCleanerRevisited.ps1
  Launches the graphical interface.

.NOTES
  Administrator privileges are required to access C:\Windows\Installer and perform uninstalls/deletions.
#>

param (
  [Alias('h')]
  [switch]$Help
)

# Display script summary at launch
Write-Host 'This script provides a GUI to list and manage orphaned MSI/MSP files in the Windows Installer folder.'

# Display help message if -Help parameter is used
if ($Help) {
  Get-Help -Name $MyInvocation.MyCommand.Name -Full
  exit
}

# ---------------------------------------------------------
# Main Script Logic
# ---------------------------------------------------------

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Define the data class for the ListView
if (-not ("WindowsInstallerPackage" -as [type])) {
    Add-Type -TypeDefinition @"
    public class WindowsInstallerPackage {
        public bool IsSelected { get; set; }
        public string Status { get; set; }
        public string Name { get; set; }
        public string FileName { get; set; }
        public double FileSizeMB { get; set; }
        public string Date { get; set; }
        public string Author { get; set; }
        public string Title { get; set; }
        public string Subject { get; set; }
        public string DigitalSignature { get; set; }
        public string Comment { get; set; }
        public string FullPath { get; set; }
        public string ProductCode { get; set; }
        public string ParentProductCode { get; set; }
    }
"@
}

if (-not ("LeftoverItem" -as [type])) {
    Add-Type -TypeDefinition @"
    public class LeftoverItem {
        public bool IsSelected { get; set; }
        public string Type { get; set; }
        public string Name { get; set; }
        public string Path { get; set; }
        public int Score { get; set; }
        public string MatchedKeywords { get; set; }
        public string Source { get; set; }
        public string SampleFile { get; set; }
    }
"@
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Windows Patch Cleaner" Height="950" Width="1200" WindowStartupLocation="CenterScreen" Background="#2b2b2b" Foreground="White">
    <Window.Resources>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="White" />
        </Style>
        <Style TargetType="Label">
            <Setter Property="Foreground" Value="White" />
        </Style>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#444" />
            <Setter Property="Foreground" Value="White" />
            <Setter Property="Padding" Value="10,5" />
            <Setter Property="Margin" Value="5,0" />
            <Setter Property="BorderBrush" Value="#666" />
        </Style>
        <Style TargetType="RadioButton">
            <Setter Property="Foreground" Value="White" />
            <Setter Property="Margin" Value="0,0,10,0" />
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="VerticalAlignment" Value="Center" />
        </Style>
        <Style TargetType="GridViewColumnHeader">
            <Setter Property="Background" Value="#444" />
            <Setter Property="Foreground" Value="White" />
        </Style>
    </Window.Resources>
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0" Margin="0,0,0,10">
            <TextBlock Text="Installers List" FontSize="18" FontWeight="Bold" Margin="0,0,0,5" />
            <DockPanel>
                <TextBlock Text="Software products installed or orphaned on your system." VerticalAlignment="Center" />
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                    <CheckBox Name="chkShowSelectedOnly" Content="Show selected only" Foreground="White" VerticalAlignment="Center" Margin="0,0,15,0" ToolTip="Only show items that are currently checked." />
                    <TextBlock Text="Search:" VerticalAlignment="Center" Margin="0,0,5,0" />
                    <TextBox Name="txtSearch" Width="200" Background="#333" Foreground="White" BorderBrush="#555" Padding="2" VerticalContentAlignment="Center" />
                    <Button Name="btnRefreshSearch" Content="↻" Width="25" Margin="5,0,0,0" ToolTip="Refresh list and filters" Background="#444" BorderBrush="#555" Foreground="White" Padding="0" />
                </StackPanel>
            </DockPanel>
        </StackPanel>

        <ListView Name="lvInstallers" Grid.Row="1" Background="#333" Foreground="White" SelectionMode="Extended">
            <ListView.View>
                <GridView>
                    <GridViewColumn Width="25">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <CheckBox IsChecked="{Binding IsSelected}" HorizontalAlignment="Center" />
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="Subject" DisplayMemberBinding="{Binding Subject}" Width="350" />
                    <GridViewColumn Header="File Name" DisplayMemberBinding="{Binding FileName}" Width="210" />
                    <GridViewColumn Header="File Size" DisplayMemberBinding="{Binding FileSizeMB}" Width="80" />
                    <GridViewColumn Header="Date" DisplayMemberBinding="{Binding Date}" Width="110" />
                    <GridViewColumn Header="Path" DisplayMemberBinding="{Binding FullPath}" Width="350" />
                </GridView>
            </ListView.View>
            <ListView.ContextMenu>
                <ContextMenu>
                    <MenuItem Header="Uninstall" Name="menuUninstall" />
                    <MenuItem Header="Delete" Name="menuDelete" />
                    <MenuItem Header="Browse to" Name="menuBrowse" />
                </ContextMenu>
            </ListView.ContextMenu>
        </ListView>

        <StackPanel Grid.Row="2" DataContext="{Binding ElementName=lvInstallers, Path=SelectedItem}" Margin="0,15,0,0">
            <TextBlock Text="Product Details" FontWeight="Bold" HorizontalAlignment="Center" Margin="0,0,0,5" />
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="120"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <TextBlock Text="Author" Grid.Row="0" Grid.Column="0" Margin="5" HorizontalAlignment="Right" Foreground="#ccc"/>
                <TextBox Text="{Binding Author, Mode=OneWay}" Grid.Row="0" Grid.Column="1" Margin="5" IsReadOnly="True" Background="#333" Foreground="White" BorderBrush="#555"/>

                <TextBlock Text="Title" Grid.Row="1" Grid.Column="0" Margin="5" HorizontalAlignment="Right" Foreground="#ccc"/>
                <TextBox Text="{Binding Title, Mode=OneWay}" Grid.Row="1" Grid.Column="1" Margin="5" IsReadOnly="True" Background="#333" Foreground="White" BorderBrush="#555"/>

                <TextBlock Text="Subject" Grid.Row="2" Grid.Column="0" Margin="5" HorizontalAlignment="Right" Foreground="#ccc"/>
                <TextBox Text="{Binding Subject, Mode=OneWay}" Grid.Row="2" Grid.Column="1" Margin="5" IsReadOnly="True" Background="#333" Foreground="White" BorderBrush="#555"/>

                <TextBlock Text="Digital Signature" Grid.Row="3" Grid.Column="0" Margin="5" HorizontalAlignment="Right" Foreground="#ccc"/>
                <TextBox Text="{Binding DigitalSignature, Mode=OneWay}" Grid.Row="3" Grid.Column="1" Margin="5" IsReadOnly="True" Background="#333" Foreground="White" BorderBrush="#555"/>

                <TextBlock Text="Date" Grid.Row="4" Grid.Column="0" Margin="5" HorizontalAlignment="Right" Foreground="#ccc"/>
                <TextBox Text="{Binding Date, Mode=OneWay}" Grid.Row="4" Grid.Column="1" Margin="5" IsReadOnly="True" Background="#333" Foreground="White" BorderBrush="#555"/>

                <TextBlock Text="File Size" Grid.Row="5" Grid.Column="0" Margin="5" HorizontalAlignment="Right" Foreground="#ccc"/>
                <TextBox Text="{Binding FileSizeMB, StringFormat={}{0} MB, Mode=OneWay}" Grid.Row="5" Grid.Column="1" Margin="5" IsReadOnly="True" Background="#333" Foreground="White" BorderBrush="#555"/>

                <TextBlock Text="Comment" Grid.Row="6" Grid.Column="0" Margin="5" HorizontalAlignment="Right" Foreground="#ccc"/>
                <TextBox Text="{Binding Comment, Mode=OneWay}" Grid.Row="6" Grid.Column="1" Margin="5" IsReadOnly="True" Background="#333" Foreground="White" BorderBrush="#555" TextWrapping="Wrap" MaxHeight="60"/>
            </Grid>
        </StackPanel>

        <StackPanel Grid.Row="3" Margin="0,15,0,0">
            <StackPanel Orientation="Horizontal" Margin="0,0,0,5">
                <TextBlock Text="Options" FontWeight="Bold" Margin="0,0,15,0" VerticalAlignment="Center" ToolTip="Configuration options for the scan."/>
                <CheckBox Name="chkShowAll" Content="Show registered installers" Foreground="White" VerticalAlignment="Center" Margin="0,0,20,0" ToolTip="Show both registered and orphaned installers." />
                <CheckBox Name="chkScanOnStart" Content="Scan on start" Foreground="White" VerticalAlignment="Center" Margin="0,0,20,0" ToolTip="Automatically start scanning when the application opens." />
                <CheckBox Name="chkRestorePoint" Content="Create restore point" Foreground="White" VerticalAlignment="Center" Margin="0,0,20,0" ToolTip="Automatically create a system restore point before modifying packages." />

                <TextBlock Text="Deep Scan" FontWeight="Bold" Margin="0,0,15,0" VerticalAlignment="Center" ToolTip="Reads digital certificates for deeper filtering. Slower but more accurate."/>
                <RadioButton Name="rbDeepScanOn" Content="On" IsChecked="True" VerticalAlignment="Center" ToolTip="Enable Deep Scan" />
                <RadioButton Name="rbDeepScanOff" Content="Off" VerticalAlignment="Center" ToolTip="Disable Deep Scan" />
            </StackPanel>

            <StackPanel Orientation="Horizontal" Margin="0,10,0,5">
                <TextBlock Text="Exclusion Filter" FontWeight="Bold" Margin="0,0,15,0" VerticalAlignment="Center" ToolTip="Exclude product patches from detection by author, title, subject, or signature (e.g., Adobe)." />
                <TextBox Name="txtExclusion" Width="250" Background="#444" Foreground="White" BorderBrush="#666" Padding="2" VerticalContentAlignment="Center" ToolTip="Enter text to exclude" />
                <Button Name="btnAddExclusion" Content="+" Width="30" ToolTip="Add exclusion" />
                <Button Name="btnRemoveExclusion" Content="x" Width="30" ToolTip="Remove selected exclusion" />
            </StackPanel>
            <ListBox Name="lbExclusions" Height="80" Background="#333" Foreground="White" BorderBrush="#666" ToolTip="List of exclusions. Items matching these strings will not be marked as orphaned.">
                <ListBoxItem Content="Adobe" />
            </ListBox>
        </StackPanel>

        <StackPanel Grid.Row="4" Margin="0,20,0,0">
            <DockPanel LastChildFill="False">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Name="txtStatus" Text="Ready" Margin="0,0,20,0" Foreground="#aaa" />
                    <TextBlock Name="txtItemCount" Text="Items: 0" Foreground="#aaa" />
                </StackPanel>
                <StackPanel Orientation="Horizontal" DockPanel.Dock="Right">
                    <Button Name="btnCleanDotNet" Content="Clean .NET packages" Background="#512bd4" />
                    <CheckBox Name="chkDryRunDotNet" Content="Dry run" IsChecked="True" Foreground="White" VerticalAlignment="Center" Margin="5,0,5,0" />
                    <CheckBox Name="chkUninstallDotNet" Content="Uninstall registered" IsChecked="False" Foreground="White" VerticalAlignment="Center" Margin="0,0,20,0" ToolTip="Silently uninstall registered products before deleting their installer files. Slower but safer." />
                    <CheckBox Name="chkCleanLeftovers" Content="Clean leftovers" IsChecked="False" Foreground="White" VerticalAlignment="Center" Margin="0,0,20,0" ToolTip="After cleaning .NET packages, perform a deep scan to find leftover files/folders and registry entries related to the removed packages (similar to Revo Uninstaller). Registry entries are exported as .reg files before deletion." />
                    <Button Name="btnScan" Content="Scan" FontWeight="Bold" />
                    <Button Name="btnDeleteSel" Content="Delete selection" />
                    <Button Name="btnExportSel" Content="Export selection" />
                    <Button Name="btnOpenLeftovers" Content="Load leftovers list..." ToolTip="Open the Leftovers Scanner window pre-loaded from a previously exported JSON file (no .NET scan required)." />
                    <Button Name="btnClose" Content="Close" />
                </StackPanel>
            </DockPanel>
        </StackPanel>
    </Grid>
</Window>
'@

$leftoversXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Leftovers Scanner" Height="750" Width="1000" WindowStartupLocation="CenterOwner" Background="#2b2b2b" Foreground="White">
    <Window.Resources>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="White" />
        </Style>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#444" />
            <Setter Property="Foreground" Value="White" />
            <Setter Property="Padding" Value="10,5" />
            <Setter Property="Margin" Value="5,0" />
            <Setter Property="BorderBrush" Value="#666" />
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="VerticalAlignment" Value="Center" />
            <Setter Property="Foreground" Value="White" />
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#333" />
            <Setter Property="Foreground" Value="White" />
            <Setter Property="BorderBrush" Value="#555" />
            <Setter Property="Padding" Value="2" />
            <Setter Property="VerticalContentAlignment" Value="Center" />
        </Style>
        <Style TargetType="GridViewColumnHeader">
            <Setter Property="Background" Value="#444" />
            <Setter Property="Foreground" Value="White" />
        </Style>
    </Window.Resources>
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0" Margin="0,0,0,10">
            <TextBlock Name="lblHeader" Text="Leftovers Scanner" FontSize="14" FontWeight="Bold" Margin="0,0,0,5" />
            <TextBlock TextWrapping="Wrap" Foreground="#ccc">
                These items match the keywords of the removed packages. Review carefully before deletion. Registry entries will be exported as .reg files before removal. Items with a strong match (Score >= 2) are pre-selected; weaker matches are unchecked and require manual review.
            </TextBlock>
        </StackPanel>

        <DockPanel Grid.Row="1" Margin="0,0,0,10">
            <TextBlock Text="Search:" VerticalAlignment="Center" Margin="0,0,5,0" />
            <TextBox Name="txtFilter" Width="250" Margin="0,0,15,0" />
            <CheckBox Name="chkOnlyFolders" Content="Folders only" Margin="0,0,10,0" />
            <CheckBox Name="chkOnlyRegistry" Content="Registry only" Margin="0,0,10,0" />
            <TextBlock Name="lblStatus" VerticalAlignment="Center" Margin="20,0,0,0" Foreground="#aaa" />
        </DockPanel>

        <ListView Name="lvLeftovers" Grid.Row="2" Background="#333" Foreground="White" SelectionMode="Extended">
            <ListView.View>
                <GridView>
                    <GridViewColumn Width="40">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <CheckBox IsChecked="{Binding IsSelected}" HorizontalAlignment="Center" />
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="Type" DisplayMemberBinding="{Binding Type}" Width="80" />
                    <GridViewColumn Header="Name" DisplayMemberBinding="{Binding Name}" Width="250" />
                    <GridViewColumn Header="Path" DisplayMemberBinding="{Binding Path}" Width="450" />
                    <GridViewColumn Header="Score" DisplayMemberBinding="{Binding Score}" Width="60" />
                </GridView>
            </ListView.View>
        </ListView>

        <DockPanel Grid.Row="3" Margin="0,10,0,0">
            <StackPanel Orientation="Horizontal" DockPanel.Dock="Left">
                <Button Name="btnExportLeftovers" Content="Export List..." ToolTip="Save the current list of leftovers to a JSON file for later review or sharing." />
                <Button Name="btnLoadLeftovers" Content="Load List..." ToolTip="Reload a previously exported list of leftovers." />
            </StackPanel>
            <StackPanel Orientation="Horizontal" DockPanel.Dock="Right">
                <Button Name="btnSelectAll" Content="Select All" />
                <Button Name="btnSelectNone" Content="Select None" />
                <Button Name="btnDeleteLeftovers" Content="Delete Selected" Background="#a00" />
                <Button Name="btnCloseLeftovers" Content="Close" />
            </StackPanel>
        </DockPanel>
    </Grid>
</Window>
'@

$reader = (New-Object System.Xml.XmlNodeReader ([xml]$xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Map controls
$lvInstallers = $window.FindName("lvInstallers")
$chkShowAll = $window.FindName("chkShowAll")
$chkScanOnStart = $window.FindName("chkScanOnStart")
$chkRestorePoint = $window.FindName("chkRestorePoint")
$rbDeepScanOn = $window.FindName("rbDeepScanOn")
$rbDeepScanOff = $window.FindName("rbDeepScanOff")
$txtExclusion = $window.FindName("txtExclusion")
$btnAddExclusion = $window.FindName("btnAddExclusion")
$btnRemoveExclusion = $window.FindName("btnRemoveExclusion")
$lbExclusions = $window.FindName("lbExclusions")

$btnCleanDotNet = $window.FindName("btnCleanDotNet")
$chkDryRunDotNet = $window.FindName("chkDryRunDotNet")
$chkUninstallDotNet = $window.FindName("chkUninstallDotNet")
$chkCleanLeftovers = $window.FindName("chkCleanLeftovers")
$chkShowSelectedOnly = $window.FindName("chkShowSelectedOnly")

$txtSearch = $window.FindName("txtSearch")
$btnRefreshSearch = $window.FindName("btnRefreshSearch")
$txtItemCount = $window.FindName("txtItemCount")
$txtStatus = $window.FindName("txtStatus")

$btnScan = $window.FindName("btnScan")
$btnDeleteSel = $window.FindName("btnDeleteSel")
$btnExportSel = $window.FindName("btnExportSel")
$btnOpenLeftovers = $window.FindName("btnOpenLeftovers")
$btnClose = $window.FindName("btnClose")

$menuUninstall = $window.FindName("menuUninstall")
$menuDelete = $window.FindName("menuDelete")
$menuBrowse = $window.FindName("menuBrowse")

# Helper function for sorting
$global:lastSortColumn = ""
$global:lastSortDirection = [System.ComponentModel.ListSortDirection]::Ascending

$lvInstallers.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($evt_sender, $e)
    if ($e.OriginalSource -is [System.Windows.Controls.GridViewColumnHeader]) {
        $header = $e.OriginalSource
        if ($header.Column.DisplayMemberBinding) {
            $sortBy = $header.Column.DisplayMemberBinding.Path.Path

            if ($global:lastSortColumn -eq $sortBy) {
                if ($global:lastSortDirection -eq [System.ComponentModel.ListSortDirection]::Ascending) {
                    $global:lastSortDirection = [System.ComponentModel.ListSortDirection]::Descending
                } else {
                    $global:lastSortDirection = [System.ComponentModel.ListSortDirection]::Ascending
                }
            } else {
                $global:lastSortColumn = $sortBy
                $global:lastSortDirection = [System.ComponentModel.ListSortDirection]::Ascending
            }

            $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($lvInstallers.Items)
            $view.SortDescriptions.Clear()
            $view.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription($sortBy, $global:lastSortDirection)))
        } else {
            # Checkbox column header was clicked - toggle all selection
            # Note: We toggle based on the *filtered* view, not the underlying collection
            $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($lvInstallers.Items)
            $allSelected = $true
            foreach ($item in $view) {
                if (-not $item.IsSelected) { $allSelected = $false; break }
            }
            $newState = -not $allSelected
            foreach ($item in $view) {
                $item.IsSelected = $newState
            }
            $lvInstallers.Items.Refresh()
            Update-ItemCount
        }
    } elseif ($e.OriginalSource -is [System.Windows.Controls.CheckBox]) {
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke([Action]{ Update-ItemCount }) | Out-Null
    }
})

# Helper function for creating a system restore point
function Invoke-RestorePoint {
    if ($chkRestorePoint.IsChecked -eq $true) {
        $txtStatus.Text = "Creating System Restore Point..."
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, 'Background')
        try {
            Enable-ComputerRestore -Drive "$env:SystemDrive" -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description "Windows Patch Cleaner (Auto)" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
            return $true
        } catch {
            if ($_.Exception.Message -match "1440") {
                # Ignore the default Windows 24-hour limit error
                return $true
            } else {
                $res = [System.Windows.MessageBox]::Show("Failed to create restore point:`n$_`n`nDo you want to proceed anyway?", "Warning", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
                if ($res -eq 'No') { return $false }
            }
        }
    }
    return $true
}

# Helper function to resolve potential short paths to long paths
function Get-LongPath {
    param($path)
    if ([string]::IsNullOrEmpty($path)) { return $path }
    try {
        return (Get-Item -LiteralPath $path -ErrorAction SilentlyContinue).FullName
    } catch {
        return $path
    }
}

# Helper function to update the item counter
function Update-ItemCount {
    if ($lvInstallers) {
        $total = $lvInstallers.Items.Count
        $selected = 0
        foreach ($item in $lvInstallers.Items) {
            if ($item.IsSelected) { $selected++ }
        }
        $txtItemCount.Text = "Items: $selected / $total"
    }
}

# Helper function to get registered installers with their install dates and product codes
function Get-RegisteredInstallers {
    try {
        $installer = New-Object -ComObject WindowsInstaller.Installer
    } catch {
        [System.Windows.MessageBox]::Show("Could not initialize WindowsInstaller.Installer COM object. Ensure you have administrator rights.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return @{}
    }

    $validFiles = @{} # Path -> @{Date, Code, ParentCode}

    # Products
    try {
        $products = $installer.Products
        foreach ($product in $products) {
            $localPackage = $installer.ProductInfo($product, "LocalPackage")
            if ($localPackage) {
                $longPath = Get-LongPath $localPackage
                $installDateStr = $installer.ProductInfo($product, "InstallDate") # YYYYMMDD
                $installDate = if ($installDateStr -match '^(\d{4})(\d{2})(\d{2})$') { "$($Matches[1])-$($Matches[2])-$($Matches[3])" } else { "Unknown" }
                $validFiles[$longPath] = @{ Date = $installDate; Code = $product; ParentCode = $null }
            }
        }
    } catch { Write-Warning "Error reading products: $_" }

    # Patches
    try {
        $products = $installer.Products
        foreach ($product in $products) {
            try {
                $prodPatches = $installer.Patches($product)
                foreach ($patch in $prodPatches) {
                    $localPackage = $installer.PatchInfo($patch, "LocalPackage")
                    if ($localPackage) {
                        $longPath = Get-LongPath $localPackage
                        # If multiple products share a patch, the last one found will be the reference for uninstallation
                        $patchDateStr = $installer.PatchInfo($patch, "InstallDate")
                        $patchDate = if ($patchDateStr -match '^(\d{4})(\d{2})(\d{2})$') { "$($Matches[1])-$($Matches[2])-$($Matches[3])" } else { "Unknown" }
                        $validFiles[$longPath] = @{ Date = $patchDate; Code = $patch; ParentCode = $product }
                    }
                }
            } catch { }
        }
    } catch { Write-Warning "Error reading patches: $_" }

    if ($null -ne $installer) {
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($installer)
    }

    return $validFiles
}

# Common stop words excluded from leftover keyword extraction.
# These are too generic to identify specific packages reliably.
# Note: 'microsoft' is excluded because almost every .NET / VS package shares it as a publisher,
# so a folder named "Microsoft <anything>" would otherwise trigger tons of false positives.
$script:LeftoverStopWords = @(
    'the','a','an','and','or','for','with','of','to','in','on','by','at','from',
    'as','is','it','be','this','that','these','those',
    'inc','llc','ltd','corp','corporation','company','co','limited','microsoft',
    'service','pack','update','hotfix','security','critical','x64','x86'
)

# Extracts meaningful keywords from a package's metadata for leftover searching.
# Returns an object with two distinct lists:
#   - Primary  : distinctive non-version words (the package "name") - REQUIRED for any leftover match
#   - Versions : version-like tokens (e.g. "8.0.5") - used as confidence boosters only
#
# Version tokens alone NEVER produce a match. This prevents the false-positive scenario where
# an isolated version like "9.0" would match unrelated folders just because they happen to
# contain a "9.0" somewhere in their name (e.g. "Microsoft Visual Studio 16.9.0 ...").
function Get-PackageKeywords {
    param([Parameter(Mandatory=$true)]$Package)

    $primary  = @()
    $versions = @()

    $text = "$($Package.Subject) $($Package.Title) $($Package.Name) $($Package.Author)"

    # Version-like tokens first (kept separate, used only as boosters)
    $versionMatches = [regex]::Matches($text, '\b\d+\.\d+(?:\.\d+)?\b')
    foreach ($vm in $versionMatches) {
        if ($vm.Value -notmatch '^\d{1,2}$') { $versions += $vm.Value }
    }

    # Build the cleaned word list for primary keywords
    $cleanText = $text -replace '\b\d+[\.\d]*\b', ' '
    $cleanText = $cleanText -replace '\([^)]*\)', ' '
    $cleanText = $cleanText -replace '[^a-zA-Z0-9\s]', ' '

    foreach ($token in ($cleanText -split '\s+' | Where-Object { $_ -ne '' })) {
        $lower = $token.ToLower()
        if ($token.Length -ge 3 -and $script:LeftoverStopWords -notcontains $lower) {
            $primary += $token
        }
    }

    return [PSCustomObject]@{
        Primary  = @($primary  | Select-Object -Unique)
        Versions = @($versions | Select-Object -Unique)
    }
}

# Searches for leftover files/folders using FILE NAMES rather than folder names.
# Folder-name matching was producing false positives like Paint.NET / GitHub Desktop / WindowsPowerShell
# being flagged whenever the keyword "NET" or "Desktop" was extracted from a .NET package.
#
# Three strategies, in order of confidence:
#   1. GUID Package Cache lookup  (very high confidence, only for MSI files named with GUIDs)
#   2. .NET structured path lookup (high confidence: dotnet\shared\<r>\<v>\ etc.)
#   3. Generic file-name search    (medium confidence: filenames containing primary keywords)
function Search-FileSystemLeftovers {
    param(
        [Parameter(Mandatory=$true)][array]$Packages,
        [string[]]$PrimaryKeywords,
        [string[]]$VersionKeywords,
        [hashtable]$InstalledVersions
    )

    if ($null -eq $PrimaryKeywords -or $PrimaryKeywords.Count -eq 0) { return @() }
    if ($null -eq $VersionKeywords) { $VersionKeywords = @() }

    $results = @()

    # ----------------------------------------------------------------------
    # Strategy 1: GUID-based Package Cache lookup
    # MSI files in C:\Windows\Installer are named with their product GUID.
    # The corresponding installer cache lives in C:\ProgramData\Package Cache\{GUID}\.
    # If that cache still exists after uninstallation, it's a guaranteed leftover.
    # ----------------------------------------------------------------------
    $guidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\.msi?$'
    $packageCacheRoot = Join-Path $env:ProgramData 'Package Cache'
    if (Test-Path $packageCacheRoot) {
        foreach ($pkg in $Packages) {
            if ($pkg.FileName -match $guidPattern) {
                $guid = $pkg.FileName.Substring(0, 36)
                $cacheFolder = Join-Path $packageCacheRoot $guid
                if (Test-Path $LiteralPath $cacheFolder) {
                    $results += [PSCustomObject]@{
                        Type            = 'Folder'
                        Path            = $cacheFolder
                        Name            = $guid
                        Score           = 10
                        MatchedKeywords = "GUID match for removed MSI: $guid"
                        Source          = 'Package Cache (GUID match)'
                        SampleFile      = ''
                    }
                }
            }
        }
    }

    # ----------------------------------------------------------------------
    # Strategy 2: .NET structured path lookup
    # Looks at dotnet\shared\<runtime>\<version>\ and similar layouts. The runtime
    # folder name MUST contain a primary keyword AND the version folder name MUST
    # match a version keyword. Both conditions = high-confidence leftover.
    # ----------------------------------------------------------------------
    $dotnetRoots = @()
    if (Test-Path "$env:ProgramFiles\dotnet")          { $dotnetRoots += "$env:ProgramFiles\dotnet" }
    if (Test-Path "${env:ProgramFiles(x86)}\dotnet")   { $dotnetRoots += "${env:ProgramFiles(x86)}\dotnet" }

    foreach ($root in $dotnetRoots) {
        foreach ($sub in @('shared','sdk','host','packs','templates')) {
            $subPath = Join-Path $root $sub
            if (-not (Test-Path $subPath)) { continue }
            foreach ($component in (Get-ChildItem -Path $subPath -Directory -ErrorAction SilentlyContinue)) {
                $componentName = $component.Name
                $matchedPrimary = $null
                foreach ($kw in $PrimaryKeywords) {
                    if ($componentName -like "*$kw*") { $matchedPrimary = $kw; break }
                }
                if (-not $matchedPrimary) { continue }

                foreach ($versionDir in (Get-ChildItem -Path $component.FullName -Directory -ErrorAction SilentlyContinue)) {
                    $versionName = $versionDir.Name
                    # CRITICAL GUARD: skip any version that is currently installed on the system.
                    # Without this, the live installation (e.g. 8.0.10) gets flagged whenever a
                    # removed package extracts "8.0.1" as a keyword.
                    if (Test-InstalledVersion -Version $versionName -InstalledVersions $InstalledVersions) { continue }

                    foreach ($v in $VersionKeywords) {
                        # Component-wise comparison: "8.0.1" != "8.0.10". Previously used
                        # `$versionName -like "$v*"` which treated them as equal.
                        if ((Compare-VersionString -A $versionName -B $v) -eq 0) {
                            $results += [PSCustomObject]@{
                                Type            = 'Folder'
                                Path            = $versionDir.FullName
                                Name            = $versionName
                                Score           = 8
                                MatchedKeywords = "$sub component: $componentName | Version: $versionName"
                                Source          = "$($root)\$sub"
                                SampleFile      = ''
                            }
                            break
                        }
                    }
                }
            }
        }
    }

    # Same approach for the NuGet packages cache (user profile, per-machine, VS private feeds)
    $nugetRoots = @()
    if (Test-Path "$env:USERPROFILE\.nuget\packages")   { $nugetRoots += @{ Path = "$env:USERPROFILE\.nuget\packages"; Label = 'NuGet packages' } }
    if (Test-Path "$env:ProgramData\Microsoft\VisualStudio\Packages") { $nugetRoots += @{ Path = "$env:ProgramData\Microsoft\VisualStudio\Packages"; Label = 'VS Packages' } }
    foreach ($nuget in $nugetRoots) {
        foreach ($pkgDir in (Get-ChildItem -Path $nuget.Path -Directory -ErrorAction SilentlyContinue)) {
            $pkgName = $pkgDir.Name
            $matchedPrimary = $null
            foreach ($kw in $PrimaryKeywords) {
                if ($pkgName -like "*$kw*") { $matchedPrimary = $kw; break }
            }
            if (-not $matchedPrimary) { continue }

            foreach ($versionDir in (Get-ChildItem -Path $pkgDir.FullName -Directory -ErrorAction SilentlyContinue)) {
                $versionName = $versionDir.Name
                # Skip currently-installed versions (see dotnet structured-path section above).
                if (Test-InstalledVersion -Version $versionName -InstalledVersions $InstalledVersions) { continue }

                foreach ($v in $VersionKeywords) {
                    # Component-wise comparison (not prefix matching) — fixes 8.0.1 vs 8.0.10.
                    if ((Compare-VersionString -A $versionName -B $v) -eq 0) {
                        $results += [PSCustomObject]@{
                            Type            = 'Folder'
                            Path            = $versionDir.FullName
                            Name            = $versionName
                            Score           = 8
                            MatchedKeywords = "Package: $pkgName | Version: $versionName"
                            Source          = $nuget.Label
                            SampleFile      = ''
                        }
                        break
                    }
                }
            }
        }
    }

    # ----------------------------------------------------------------------
    # Strategy 3: Generic file-name search in known package directories
    # Scans FILES (not folders) whose names contain a primary keyword, in
    # the canonical .NET / installer locations only. File names like
    # "Microsoft.NETCore.App.deps.json" are extremely specific; this avoids
    # the false positives caused by folder-name matching.
    # A folder is flagged only if it ALSO matches a version keyword
    # (this filters out current installations we want to keep).
    # ----------------------------------------------------------------------
    $fileSearchRoots = @()
    if (Test-Path "$env:ProgramFiles\dotnet")          { $fileSearchRoots += @{ Path = "$env:ProgramFiles\dotnet";          Label = 'ProgramFiles\dotnet' } }
    if (Test-Path "${env:ProgramFiles(x86)}\dotnet")   { $fileSearchRoots += @{ Path = "${env:ProgramFiles(x86)}\dotnet"; Label = 'ProgramFiles(x86)\dotnet' } }

    $dedup = @{}
    foreach ($root in $fileSearchRoots) {
        try {
            $files = Get-ChildItem -Path $root.Path -Recurse -File -ErrorAction SilentlyContinue -Depth 8 -Force
        } catch {
            $files = @()
        }
        foreach ($file in $files) {
            $fileName = $file.Name
            $primaryMatches = @()
            foreach ($kw in $PrimaryKeywords) {
                if ($fileName -like "*$kw*") { $primaryMatches += $kw }
            }
            if ($primaryMatches.Count -eq 0) { continue }

            $parentFolder = $file.DirectoryName
            $parentName   = Split-Path -Leaf $parentFolder

            # CRITICAL GUARD: never flag a folder whose name matches a currently-installed
            # version. This is the final backstop that protects live installations even
            # when the keyword extraction produced a shorter version token than the real one.
            if (Test-InstalledVersion -Version $parentName -InstalledVersions $InstalledVersions) { continue }

            # Only flag the parent folder if its name matches a version keyword.
            # This filters out currently-used installations we must NOT delete.
            $versionMatched = $false
            $matchedVersion = $null
            foreach ($v in $VersionKeywords) {
                # Component-wise comparison (not prefix) — keeps "8.0.1" distinct from "8.0.10".
                if ((Compare-VersionString -A $parentName -B $v) -eq 0) {
                    $versionMatched = $true
                    $matchedVersion = $v
                    break
                }
            }
            if (-not $versionMatched) { continue }

            $key = $parentFolder.ToLowerInvariant()
            if (-not $dedup.ContainsKey($key)) {
                $dedup[$key] = [PSCustomObject]@{
                    Type            = 'Folder'
                    Path            = $parentFolder
                    Name            = $parentName
                    Score           = 0
                    MatchedKeywords = ''
                    Source          = $root.Label
                    SampleFile      = ''
                    FileCount       = 0
                }
            }
            $entry = $dedup[$key]
            $entry.Score += $primaryMatches.Count
            $entry.FileCount += 1
            if (-not $entry.SampleFile) { $entry.SampleFile = $fileName }
            $keywordsText = "File: $fileName | Primary: $($primaryMatches -join ', ')"
            if ($matchedVersion) { $keywordsText += " | Version: $matchedVersion" }
            if ($entry.MatchedKeywords -notlike "*$fileName*") {
                if ($entry.MatchedKeywords) { $entry.MatchedKeywords += "; $keywordsText" } else { $entry.MatchedKeywords = $keywordsText }
            }
        }
    }
    foreach ($entry in $dedup.Values) {
        $entry.Score = [Math]::Min($entry.Score + 5, 7)  # cap below GUID / structured matches
        $results += $entry
    }

    return $results
}

# Searches common registry hives (Uninstall, App Paths, Classes\Applications) for keys
# whose properties match BOTH a primary keyword AND a version keyword.
# Requiring the version match eliminates ~90% of false positives caused by generic
# primary keywords (Windows/Core/Runtime/Desktop) matching unrelated system components
# (Paint.NET, Python Core Interpreter, runtimebroker.exe, WindowsSandboxServer.exe, ...).
function Search-RegistryLeftovers {
    param(
        [string[]]$PrimaryKeywords,
        [string[]]$VersionKeywords,
        [hashtable]$InstalledVersions
    )

    if ($null -eq $PrimaryKeywords -or $PrimaryKeywords.Count -eq 0) { return @() }
    if ($null -eq $VersionKeywords) { $VersionKeywords = @() }

    # If no version keywords were extracted (package had no version), fall back to
    # primary-only matching so the function still produces useful results.
    $requireVersion = $VersionKeywords.Count -gt 0

    $results = @()
    $regPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths',
        'HKLM:\SOFTWARE\Classes\Applications',
        'HKCU:\SOFTWARE\Classes\Applications'
    )

    foreach ($path in $regPaths) {
        if (-not (Test-Path $path)) { continue }
        try {
            foreach ($key in (Get-ChildItem -Path $path -ErrorAction SilentlyContinue)) {
                $keyName = $key.PSChildName
                $props = $null
                try { $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue } catch {}

                # Build the list of string fields we'll scan. Includes the key name itself
                # plus the properties that frequently contain product/version information.
                $fields = [System.Collections.Generic.List[string]]::new()
                [void]$fields.Add($keyName)
                if ($props) {
                    foreach ($propName in @('DisplayName','Publisher','InstallLocation','UninstallString','DisplayVersion')) {
                        $val = $props.$propName
                        if ($val -and "$val".Trim()) { [void]$fields.Add("$val") }
                    }
                }

                # Scan all fields for primary AND version matches (no early exit - we want to know
                # the full set of matches so we can display them and score properly).
                $matchedPrimary  = [System.Collections.Generic.List[string]]::new()
                $matchedVersion  = [System.Collections.Generic.List[string]]::new()

                foreach ($field in $fields) {
                    foreach ($kw in $PrimaryKeywords) {
                        if ($field -like "*$kw*") {
                            if (-not $matchedPrimary.Contains($kw)) { [void]$matchedPrimary.Add($kw) }
                        }
                    }
                    foreach ($kw in $VersionKeywords) {
                        if ($field -like "*$kw*") {
                            if (-not $matchedVersion.Contains($kw)) { [void]$matchedVersion.Add($kw) }
                        }
                    }
                }

                $primaryScore = $matchedPrimary.Count
                $versionScore = $matchedVersion.Count

                # Hard requirement: at least one primary keyword must match.
                if ($primaryScore -eq 0) { continue }

                # If we have version keywords to filter on, ALSO require a version match.
                # This is the key anti-FP guard: generic words like "Windows", "Core", "Runtime"
                # only produce a hit when paired with a real version like "9.0.17" or "10.0.100".
                if ($requireVersion -and $versionScore -eq 0) { continue }

                # CRITICAL GUARD: skip registry entries whose DisplayVersion matches a currently-
                # installed .NET version. Without this, the LIVE installation's own Uninstall
                # key (e.g. "Microsoft .NET Runtime - 9.0.18 (x64)" with DisplayVersion=9.0.18)
                # would be reported as a leftover whenever a removed package extracted "9.0"
                # as a version keyword. The DisplayVersion comparison is component-wise so
                # "9.0.18" is never confused with "9.0.1".
                if ($props -and $props.DisplayVersion -and (Test-InstalledVersion -Version $props.DisplayVersion -InstalledVersions $InstalledVersions)) {
                    continue
                }

                $totalScore = $primaryScore + $versionScore
                $matchedDisplay = if ($matchedPrimary.Count -gt 0 -and $matchedVersion.Count -gt 0) {
                    "Primary: " + ($matchedPrimary -join ', ') + " | Version: " + ($matchedVersion -join ', ')
                } elseif ($matchedPrimary.Count -gt 0) {
                    "Primary: " + ($matchedPrimary -join ', ')
                } else {
                    "Version: " + ($matchedVersion -join ', ')
                }

                $displayName = $keyName
                if ($props -and $props.DisplayName) { $displayName = $props.DisplayName }

                $results += [PSCustomObject]@{
                    Type            = 'Registry'
                    Path            = $key.PSPath
                    Name            = $displayName
                    Score           = $totalScore
                    MatchedKeywords = $matchedDisplay
                    Source          = $path
                }
            }
        } catch {}
    }

    return $results
}

# Builds a hashtable of currently-installed .NET versions keyed by their full component name
# (e.g. "Microsoft.NETCore.App", "Microsoft.AspNetCore.App", "Microsoft.WindowsDesktop.App",
#  "Microsoft.NETCore.App.Ref", SDK packs, ...). The value is a list of version strings as
# they appear in the corresponding version folder (e.g. "8.0.29", "9.0.18").
#
# We do NOT rely solely on `dotnet --list-runtimes` because that command only reports runtimes
# that are part of a "shared framework" — it misses targeting packs, SDK packs, templates, and
# any manually-installed component. Instead we inspect the filesystem directly:
#   - C:\ProgramFiles\dotnet\shared\<runtime>\<version>
#   - C:\ProgramFiles\dotnet\sdk\<version>
#   - C:\ProgramFiles\dotnet\packs\<pack>\<version>
#   - C:\ProgramFiles\dotnet\templates\<version>
# This way any version that has a live folder on disk is considered "installed and in use"
# and must NEVER be reported as a leftover.
#
# Cross-checked against `dotnet --list-runtimes` for sanity: if a folder exists but the runtime
# isn't reported there, we still keep it in the set (it might be a targeting pack, host, ...).
function Get-InstalledDotNetVersions {
    $installed = @{}  # key = full component name (e.g. "Microsoft.NETCore.App"), value = @("8.0.29","9.0.18")

    # Sanity check via `dotnet --list-runtimes` - we don't use it as the source of truth,
    # but its presence confirms a working .NET install (and we keep the version list as a hint).
    try {
        $dotnetList = & dotnet --list-runtimes 2>$null
        foreach ($line in $dotnetList) {
            # Format: "Microsoft.AspNetCore.App 8.0.29 [C:\Program Files\dotnet\shared\Microsoft.AspNetCore.App]"
            if ($line -match '^\s*([^\s]+)\s+(\d+\.\d+(?:\.\d+)?)\s+\[') {
                $comp = $Matches[1]
                $ver  = $Matches[2]
                if (-not $installed.ContainsKey($comp)) { $installed[$comp] = @() }
                if ($installed[$comp] -notcontains $ver) { $installed[$comp] += $ver }
            }
        }
    } catch {}

    # Source of truth: the actual folders on disk. We walk the canonical .NET install layout.
    $roots = @()
    if (Test-Path "$env:ProgramFiles\dotnet")          { $roots += "$env:ProgramFiles\dotnet" }
    if (Test-Path "${env:ProgramFiles(x86)}\dotnet")   { $roots += "${env:ProgramFiles(x86)}\dotnet" }

    foreach ($root in $roots) {
        # 1) shared\<runtime>\<version>
        $sharedPath = Join-Path $root 'shared'
        if (Test-Path $sharedPath) {
            foreach ($runtimeDir in (Get-ChildItem -Path $sharedPath -Directory -ErrorAction SilentlyContinue)) {
                $compName = $runtimeDir.Name
                foreach ($verDir in (Get-ChildItem -Path $runtimeDir.FullName -Directory -ErrorAction SilentlyContinue)) {
                    if ($verDir.Name -match '^\d+\.\d+(?:\.\d+)?') {
                        if (-not $installed.ContainsKey($compName)) { $installed[$compName] = @() }
                        if ($installed[$compName] -notcontains $verDir.Name) { $installed[$compName] += $verDir.Name }
                    }
                }
            }
        }

        # 2) sdk\<version>
        $sdkPath = Join-Path $root 'sdk'
        if (Test-Path $sdkPath) {
            foreach ($verDir in (Get-ChildItem -Path $sdkPath -Directory -ErrorAction SilentlyContinue)) {
                if ($verDir.Name -match '^\d+\.\d+(?:\.\d+)?') {
                    $key = '__SDK__'
                    if (-not $installed.ContainsKey($key)) { $installed[$key] = @() }
                    if ($installed[$key] -notcontains $verDir.Name) { $installed[$key] += $verDir.Name }
                }
            }
        }

        # 3) packs\<pack>\<version>  (targeting packs, runtime packs, ASP.NET packs, ...)
        $packsPath = Join-Path $root 'packs'
        if (Test-Path $packsPath) {
            foreach ($packDir in (Get-ChildItem -Path $packsPath -Directory -ErrorAction SilentlyContinue)) {
                $packName = $packDir.Name
                foreach ($verDir in (Get-ChildItem -Path $packDir.FullName -Directory -ErrorAction SilentlyContinue)) {
                    if ($verDir.Name -match '^\d+\.\d+(?:\.\d+)?') {
                        if (-not $installed.ContainsKey($packName)) { $installed[$packName] = @() }
                        if ($installed[$packName] -notcontains $verDir.Name) { $installed[$packName] += $verDir.Name }
                    }
                }
            }
        }

        # 4) templates\<version>
        $tplPath = Join-Path $root 'templates'
        if (Test-Path $tplPath) {
            foreach ($verDir in (Get-ChildItem -Path $tplPath -Directory -ErrorAction SilentlyContinue)) {
                if ($verDir.Name -match '^\d+\.\d+(?:\.\d+)?') {
                    $key = '__TEMPLATES__'
                    if (-not $installed.ContainsKey($key)) { $installed[$key] = @() }
                    if ($installed[$key] -notcontains $verDir.Name) { $installed[$key] += $verDir.Name }
                }
            }
        }
    }

    return $installed
}

# Compares two version strings component-by-component ("8.0.29" vs "8.0.10").
# Returns -1, 0 or 1. This fixes the previous `-like "$v*"` prefix match which
# wrongly treated "8.0.1" and "8.0.10" as equal and would have flagged the live
# installation as a leftover (or vice versa).
function Compare-VersionString {
    param([string]$A, [string]$B)
    $pa = [int[]]($A -split '\.')
    $pb = [int[]]($B -split '\.')
    $len = [Math]::Max($pa.Count, $pb.Count)
    for ($i = 0; $i -lt $len; $i++) {
        $va = if ($i -lt $pa.Count) { $pa[$i] } else { 0 }
        $vb = if ($i -lt $pb.Count) { $pb[$i] } else { 0 }
        if ($va -lt $vb) { return -1 }
        if ($va -gt $vb) { return 1 }
    }
    return 0
}

# Returns $true if the given version is currently installed on the system under ANY of the
# component names (runtime names, SDK, pack names, ...). Used as a final safety net: any folder
# whose name matches an installed version is by definition NOT a leftover and must be skipped.
function Test-InstalledVersion {
    param(
        [string]$Version,
        [hashtable]$InstalledVersions
    )
    if ($null -eq $InstalledVersions -or $InstalledVersions.Count -eq 0) { return $false }
    if ([string]::IsNullOrEmpty($Version)) { return $false }

    foreach ($componentName in $InstalledVersions.Keys) {
        foreach ($installedVer in $InstalledVersions[$componentName]) {
            # Use exact component-wise comparison (NOT prefix) so "8.0.1" and "8.0.10" are
            # correctly distinguished. This is the critical fix for the leftover false positive
            # where the LIVE installation (e.g. 8.0.10) was being flagged because a removed
            # package extracted a shorter version keyword like "8.0.1".
            if ((Compare-VersionString -A $Version -B $installedVer) -eq 0) { return $true }
        }
    }
    return $false
}

# Combines keyword extraction and search across both the filesystem and the registry.
function Search-AllLeftovers {
    param([Parameter(Mandatory=$true)][array]$Packages)

    if ($Packages.Count -eq 0) { return @() }

    $allPrimary  = @()
    $allVersions = @()
    foreach ($pkg in $Packages) {
        $kws = Get-PackageKeywords -Package $pkg
        foreach ($p in $kws.Primary)  { if ($allPrimary  -notcontains $p) { $allPrimary  += $p } }
        foreach ($v in $kws.Versions) { if ($allVersions -notcontains $v) { $allVersions += $v } }
    }

    if ($allPrimary.Count -eq 0) { return @() }

    # Build the list of currently-installed .NET versions (runtimes, SDKs, packs, ...).
    # Used by the search functions to FILTER OUT any folder whose name matches an
    # active install - those are by definition NOT leftovers and must never be deleted.
    $installedVersions = Get-InstalledDotNetVersions

    $fs = Search-FileSystemLeftovers -Packages $Packages -PrimaryKeywords $allPrimary -VersionKeywords $allVersions -InstalledVersions $installedVersions
    $rg = Search-RegistryLeftovers  -PrimaryKeywords $allPrimary -VersionKeywords $allVersions -InstalledVersions $installedVersions

    return @($fs + $rg)
}

# Opens a modal review window listing the discovered leftovers and lets the user
# decide which ones to delete. Registry keys are exported to .reg files first.
function Show-LeftoversWindow {
    param(
        [array]$Packages = @(),
        [array]$PreloadedItems = @()
    )

    if ($PreloadedItems.Count -gt 0) {
        # Items loaded from a JSON export - skip the search entirely.
        $items = $PreloadedItems
        $items = $items | Sort-Object Score -Descending
    } else {
        # Normal flow: scan for leftovers based on the supplied packages.
        $txtStatus.Text = "Scanning for leftover files and registry entries..."
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, 'Background')

        $results = Search-AllLeftovers -Packages $Packages
        $txtStatus.Text = "Ready"

        if ($null -eq $results -or $results.Count -eq 0) {
            [System.Windows.MessageBox]::Show("No leftover files or registry entries were found for the cleaned packages.`n`nThis can happen when the packages were already clean, or when their identifying keywords are too generic to identify leftovers.", "Leftovers Scanner", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            return
        }

        $results = $results | Sort-Object Score -Descending

        $items = @()
        foreach ($r in $results) {
            $item = New-Object LeftoverItem
            # Pre-select strong matches (score >= 2). Weaker matches require manual confirmation.
            $item.IsSelected = ($r.Score -ge 2)
            $item.Type = $r.Type
            $item.Name = $r.Name
            $item.Path = $r.Path
            $item.Score = $r.Score
            $item.MatchedKeywords = $r.MatchedKeywords
            $item.Source = $r.Source
            $item.SampleFile = $r.SampleFile
            $items += ,$item
        }
    }

    if ($items.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No items to display.", "Leftovers Scanner", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }

    $reader = (New-Object System.Xml.XmlNodeReader ([xml]$leftoversXaml))
    $w = [Windows.Markup.XamlReader]::Load($reader)
    $w.Owner = $window

    $lv  = $w.FindName("lvLeftovers")
    $bsa = $w.FindName("btnSelectAll")
    $bsn = $w.FindName("btnSelectNone")
    $bdl = $w.FindName("btnDeleteLeftovers")
    $bcl = $w.FindName("btnCloseLeftovers")
    $bel = $w.FindName("btnExportLeftovers")
    $bll = $w.FindName("btnLoadLeftovers")
    $lh  = $w.FindName("lblHeader")
    $tf  = $w.FindName("txtFilter")
    $cof = $w.FindName("chkOnlyFolders")
    $cor = $w.FindName("chkOnlyRegistry")
    $ls  = $w.FindName("lblStatus")

    foreach ($item in $items) { [void]$lv.Items.Add($item) }

    if ($PreloadedItems.Count -gt 0) {
        $lh.Text = "Loaded $($items.Count) leftover item(s) from file (review before deletion)"
    } else {
        $lh.Text = "Found $($items.Count) potential leftovers for $($Packages.Count) cleaned package(s)"
    }
    $ls.Text = "Items: $($items.Count)"

    $filterScript = {
        $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($lv.Items)
        $fText = $tf.Text.Trim()
        $onlyF = $cof.IsChecked -eq $true
        $onlyR = $cor.IsChecked -eq $true
        if ([string]::IsNullOrEmpty($fText) -and -not $onlyF -and -not $onlyR) {
            $view.Filter = $null
        } else {
            $view.Filter = [Predicate[Object]]{
                param($obj)
                $it = $obj -as [LeftoverItem]
                $matchS = $true
                if (-not [string]::IsNullOrEmpty($fText)) {
                    $matchS = ($it.Name -like "*$fText*") -or ($it.Path -like "*$fText*") -or ($it.MatchedKeywords -like "*$fText*")
                }
                $matchT = $true
                if ($onlyF -and $onlyR) { $matchT = $true }
                elseif ($onlyF) { $matchT = ($it.Type -eq 'Folder') }
                elseif ($onlyR) { $matchT = ($it.Type -eq 'Registry') }
                return $matchS -and $matchT
            }
        }
        $vis = 0; foreach ($x in $view) { $vis++ }
        $ls.Text = "Visible: $vis / $($lv.Items.Count)"
    }

    $tf.add_TextChanged($filterScript)
    $cof.add_Click($filterScript)
    $cor.add_Click($filterScript)

    $bsa.add_Click({
        $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($lv.Items)
        foreach ($it in $view) { $it.IsSelected = $true }
        $lv.Items.Refresh()
    })
    $bsn.add_Click({
        $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($lv.Items)
        foreach ($it in $view) { $it.IsSelected = $false }
        $lv.Items.Refresh()
    })

    # Export the current leftovers list to a JSON file so it can be reviewed later or reloaded.
    $bel.add_Click({
        if ($lv.Items.Count -eq 0) {
            [System.Windows.MessageBox]::Show("There are no items to export.", "Export", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            return
        }
        $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveDialog.Filter = "Leftovers List (*.json)|*.json|All files (*.*)|*.*"
        $saveDialog.FileName = "Leftovers_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        if ($saveDialog.ShowDialog() -ne $true) { return }

        $exportItems = @()
        foreach ($it in $lv.Items) {
            $exportItems += [PSCustomObject]@{
                Type            = [string]$it.Type
                Name            = [string]$it.Name
                Path            = [string]$it.Path
                Score           = [int]$it.Score
                MatchedKeywords = [string]$it.MatchedKeywords
                Source          = [string]$it.Source
            }
        }
        $payload = [PSCustomObject]@{
            SchemaVersion = 1
            ExportDate    = (Get-Date).ToString('o')
            SourceScript  = 'patchCleanerRevisited.ps1'
            ItemCount     = $exportItems.Count
            Items         = $exportItems
        }
        try {
            $payload | ConvertTo-Json -Depth 6 | Out-File -FilePath $saveDialog.FileName -Encoding UTF8 -Force
            [System.Windows.MessageBox]::Show("Exported $($exportItems.Count) items to:`n$($saveDialog.FileName)", "Export Complete", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        } catch {
            [System.Windows.MessageBox]::Show("Failed to export leftovers list:`n$_", "Export Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        }
    })

    # Reload a previously exported leftovers list from a JSON file (replaces current list).
    $bll.add_Click({
        $openDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openDialog.Filter = "Leftovers List (*.json)|*.json|All files (*.*)|*.*"
        if ($openDialog.ShowDialog() -ne $true) { return }

        try {
            $loaded = Get-Content -LiteralPath $openDialog.FileName -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            [System.Windows.MessageBox]::Show("Failed to parse the file. It may not be valid JSON.`n`n$_", "Load Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }

        # Validate basic structure
        if ($null -eq $loaded -or $null -eq $loaded.Items -or -not ($loaded.Items -is [System.Collections.IEnumerable])) {
            [System.Windows.MessageBox]::Show("The file does not look like a leftovers list (missing 'Items' array).", "Load Failed", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            return
        }

        $newCount = @($loaded.Items).Count
        if ($lv.Items.Count -gt 0) {
            $res = [System.Windows.MessageBox]::Show("Replace the current list ($($lv.Items.Count) items) with $newCount items loaded from the file?`n`nUnsaved selections in the current list will be lost.", "Confirm Load", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
            if ($res -ne 'Yes') { return }
        }

        $lv.Items.Clear()
        $added = 0; $skipped = 0
        foreach ($entry in $loaded.Items) {
            # Skip entries that don't have the minimum required fields
            if (-not $entry.Path -or -not $entry.Type) { $skipped++; continue }
            $item = New-Object LeftoverItem
            $item.IsSelected     = $true   # Loaded items are checked by default for batch cleanup
            $item.Type           = [string]$entry.Type
            $item.Name           = [string]$entry.Name
            $item.Path           = [string]$entry.Path
            $item.Score          = if ($entry.Score) { [int]$entry.Score } else { 0 }
            $item.MatchedKeywords = if ($entry.MatchedKeywords) { [string]$entry.MatchedKeywords } else { '' }
            $item.Source         = if ($entry.Source) { [string]$entry.Source } else { '' }
            [void]$lv.Items.Add($item)
            $added++
        }

        # Refresh filter + status label
        & $filterScript

        $msg = "Loaded $added items from:`n$($openDialog.FileName)"
        if ($skipped -gt 0) { $msg += "`n`n$skipped entries were skipped (missing required fields)." }
        [System.Windows.MessageBox]::Show($msg, "Load Complete", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    })

    $bdl.add_Click({
        $selected = @()
        foreach ($it in $lv.Items) { if ($it.IsSelected) { $selected += $it } }

        if ($selected.Count -eq 0) {
            [System.Windows.MessageBox]::Show("No items selected.", "Information", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            return
        }

        $folderCount = ($selected | Where-Object { $_.Type -eq 'Folder' }).Count
        $regCount    = ($selected | Where-Object { $_.Type -eq 'Registry' }).Count

        $msg = "Delete $($selected.Count) leftover items?`n`n"
        $msg += "Folders: $folderCount`n"
        $msg += "Registry entries: $regCount`n`n"
        $msg += "Registry entries will be exported as .reg files before removal.`n"
        $msg += "Folders cannot be individually backed up; proceed with caution.`n`n"
        $msg += "This action is irreversible."

        $res = [System.Windows.MessageBox]::Show($msg, "Confirm Leftovers Deletion", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($res -ne 'Yes') { return }

        $txtStatus.Text = "Deleting leftovers..."
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, 'Background')

        $backupDir = Join-Path $env:TEMP "WindowsPatchCleaner_Leftovers_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        if ($regCount -gt 0) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }

        $okCount = 0; $skipCount = 0; $failCount = 0; $failures = @()

        foreach ($it in $selected) {
            try {
                if ($it.Type -eq 'Folder') {
                    # Use -LiteralPath to avoid bracket/curly-brace parsing issues (Package Cache GUIDs etc.)
                    if (Test-Path -LiteralPath $it.Path) {
                        Remove-Item -LiteralPath $it.Path -Recurse -Force -ErrorAction Stop
                        $okCount++
                    } else {
                        # Already gone (deleted manually or by another process) - skip without error
                        $skipCount++
                    }
                } elseif ($it.Type -eq 'Registry') {
                    if (Test-Path $it.Path) {
                        $safe = ($it.Path -replace '[:\\]', '_') -replace '^_+', ''
                        $regFile = Join-Path $backupDir "$safe.reg"
                        reg.exe export $it.Path $regFile /y 2>&1 | Out-Null
                        Remove-Item -Path $it.Path -Recurse -Force -ErrorAction Stop
                        $okCount++
                    } else {
                        $skipCount++
                    }
                } else {
                    # Unknown type - treat as a real failure so the user can investigate
                    $failCount++
                    $failures += "Unknown type '$($it.Type)': $($it.Path)"
                }
                # Remove the item from the visible list regardless of outcome (success / skipped / failed)
                # so the user has a clear view of what still needs attention.
                $lv.Items.Remove($it)
            } catch {
                # Isolate the failure: log it and keep going through the rest of the selection.
                $failCount++
                $failures += "$($it.Type): $($it.Path) - $($_.Exception.Message)"
                try { $lv.Items.Remove($it) } catch {}
            }
        }

        $report = "Leftovers cleanup complete.`n`n"
        $report += "Successfully deleted: $okCount`n"
        $report += "Already missing (skipped): $skipCount`n"
        $report += "Failed: $failCount`n"
        if ($skipCount -gt 0) {
            $report += "`nSkipped items were no longer present on disk or in the registry (deleted elsewhere).`n"
        }
        if ($failCount -gt 0) {
            $report += "`nFailures:`n" + ($failures -join "`n")
        }
        if ($regCount -gt 0 -and $okCount -gt 0) {
            $report += "`n`nRegistry backups saved to:`n$backupDir"
        }

        [System.Windows.MessageBox]::Show($report, "Leftovers Cleanup Complete", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    })

    $bcl.add_Click({ $w.Close() })

    # Column-header sorting + checkbox header toggle
    $lv.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
        param($sender, $e)
        if ($e.OriginalSource -is [System.Windows.Controls.GridViewColumnHeader]) {
            $header = $e.OriginalSource
            if ($header.Column.DisplayMemberBinding) {
                $sortBy = $header.Column.DisplayMemberBinding.Path.Path
                $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($lv.Items)
                $view.SortDescriptions.Clear()
                $view.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription($sortBy, [System.ComponentModel.ListSortDirection]::Descending)))
            } else {
                # Checkbox header - toggle all
                $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($lv.Items)
                $allSel = $true
                foreach ($it in $view) { if (-not $it.IsSelected) { $allSel = $false; break } }
                $newState = -not $allSel
                foreach ($it in $view) { $it.IsSelected = $newState }
                $lv.Items.Refresh()
            }
        }
    })

    $w.ShowDialog() | Out-Null
}

# .NET Cleaning Logic
$btnCleanDotNet.add_Click({
    $dryRun = $chkDryRunDotNet.IsChecked -eq $true
    $doUninstall = $chkUninstallDotNet.IsChecked -eq $true

    # 1. Collect .NET items from the list
    $dotNetItems = @()
    foreach ($item in $lvInstallers.Items) {
        # Match pattern for .NET Core, SDK, Runtimes, Desktop Runtime, and Targeting Pack
        $pattern = '(\.NET|Windows Desktop Runtime|Windows Desktop Targeting Pack).*?\s(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)'
        if ($item.Subject -match $pattern) {
            $major = $Matches['major']
            $minor = $Matches['minor']
            $patch = [int]$Matches['patch']

            # Create a key for grouping (Product Name + Major.Minor)
            # We remove the full version number and any trailing info to group variants together
            $baseName = $item.Subject -replace '\s\d+\.\d+\.\d+', ''

            $dotNetItems += [PSCustomObject]@{
                Item = $item
                BaseName = $baseName
                MajorMinor = "$major.$minor"
                Patch = $patch
            }
        }
    }

    if ($dotNetItems.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No .NET packages with versioning found in the list. Run a scan first.", "Information", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }

    # 2. Identify latest patch for each group
    $toDelete = @()
    $groups = $dotNetItems | Group-Object BaseName, MajorMinor
    foreach ($group in $groups) {
        $sorted = $group.Group | Sort-Object Patch -Descending
        # All except the latest (index 0) are candidates for cleaning
        for ($i = 1; $i -lt $sorted.Count; $i++) {
            $toDelete += $sorted[$i].Item
        }
    }

    if ($toDelete.Count -eq 0) {
        [System.Windows.MessageBox]::Show("All .NET packages in the list are already at the latest patch version for their respective branches.", "Information", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }

    # 3. Handle action
    if ($dryRun) {
        # Select them in the list to show what would happen
        foreach ($item in $lvInstallers.Items) { $item.IsSelected = $false }
        foreach ($item in $toDelete) { $item.IsSelected = $true }
        $lvInstallers.Items.Refresh()
        Update-ItemCount
        [System.Windows.MessageBox]::Show("Dry run: Found $($toDelete.Count) older .NET patches.`n`nThey have been selected in the list for review.", "Dry Run Result", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        if ($chkCleanLeftovers.IsChecked -eq $true) {
            Show-LeftoversWindow -Packages $toDelete
        }
    } else {
        $msg = "Are you sure you want to delete $($toDelete.Count) older .NET patches?`n`nOnly the latest patch for each version branch will be kept."
        if ($doUninstall) { $msg += "`n`nNOTE: Registered products will be SILENTLY UNINSTALLED first." }
        if ($chkRestorePoint.IsChecked -eq $true) { $msg += "`n`nNOTE: A system restore point will be created before proceeding." }
        $msg += "`n`nThis action is irreversible."

        $confirm = [System.Windows.MessageBox]::Show($msg, "Confirm Clean", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($confirm -eq 'Yes') {
            if (-not (Invoke-RestorePoint)) {
                $txtStatus.Text = "Ready"
                return
            }

            $txtStatus.Text = "Cleaning .NET packages..."
            $successCount = 0
            $failCount = 0
            # Create a copy of the list to avoid collection modification issues
            $itemsToRemove = @($toDelete)
            $initialCount = $itemsToRemove.Count
            $remainingCount = $initialCount

            foreach ($item in $itemsToRemove) {
                $txtItemCount.Text = "Remaining: $remainingCount / $initialCount"
                try {
                    $canDelete = $true
                    # Batch Uninstallation if requested and registered
                    if ($doUninstall) {
                        $txtStatus.Text = "Uninstalling $($item.FileName)..."
                        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, 'Background')

                        $argStr = ""
                        if ($item.FullPath -match '\.msp$') {
                            if ($item.ProductCode -and $item.ParentProductCode) {
                                # Correct msiexec order for patches: /uninstall <patch> /package <product>
                                $argStr = "/uninstall `"$($item.ProductCode)`" /package `"$($item.ParentProductCode)`""
                            } elseif ($item.ProductCode) {
                                $argStr = "/uninstall `"$($item.ProductCode)`""
                            } else {
                                $argStr = "/uninstall `"$($item.FullPath)`""
                            }
                        } else {
                            if ($item.ProductCode) {
                                $argStr = "/x `"$($item.ProductCode)`""
                            } else {
                                $argStr = "/x `"$($item.FullPath)`""
                            }
                        }

                        $argStr += " /qb /norestart"
                        $process = Start-Process msiexec.exe -ArgumentList $argStr -Wait -PassThru -NoNewWindow

                        # 0 = success, 3010 = success (reboot required)
                        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                            $canDelete = $false # msiexec already removed the file (or should have)
                            $successCount++
                            $lvInstallers.Items.Remove($item)
                        } elseif ($process.ExitCode -eq 1605) {
                            # 1605 = This action is only valid for products that are currently installed.
                            $canDelete = $true # It's truly orphaned, safe to delete physically
                        } else {
                            $canDelete = $false
                            $failCount++
                            Write-Warning "Uninstallation of $($item.Name) failed with exit code $($process.ExitCode)"
                        }
                    }

                    if ($canDelete) {
                        if (Test-Path $item.FullPath) {
                            $txtStatus.Text = "Deleting $($item.FileName)..."
                            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, 'Background')
                            Remove-Item -Path $item.FullPath -Force -ErrorAction Stop
                        }
                        $lvInstallers.Items.Remove($item)
                        $successCount++
                    }
                } catch {
                    [System.Windows.MessageBox]::Show("Failed to process $($item.FullPath)`n$_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                }
                $remainingCount--
            }
            Update-ItemCount
            $txtStatus.Text = "Ready"
            $completionMsg = "Successfully cleaned $successCount .NET packages."
            if ($failCount -gt 0) { $completionMsg += "`n$failCount uninstalls failed and their files were KEPT to prevent broken registrations." }
            [System.Windows.MessageBox]::Show($completionMsg, "Complete", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            if ($chkCleanLeftovers.IsChecked -eq $true) {
                Show-LeftoversWindow -Packages $itemsToRemove
            }
        }
    }
})

$configFile = Join-Path $PSScriptRoot "..\etc\patchCleanerRevisited_config.json"

if (Test-Path $configFile) {
    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        if ($null -ne $config.ShowAll) { $chkShowAll.IsChecked = [boolean]$config.ShowAll }
        if ($null -ne $config.DeepScan) {
            $rbDeepScanOn.IsChecked = [boolean]$config.DeepScan
            $rbDeepScanOff.IsChecked = -not [boolean]$config.DeepScan
        }
        if ($null -ne $config.ScanOnStart) { $chkScanOnStart.IsChecked = [boolean]$config.ScanOnStart }
        if ($null -ne $config.CreateRestorePoint) { $chkRestorePoint.IsChecked = [boolean]$config.CreateRestorePoint }
        if ($null -ne $config.Exclusions) {
            $lbExclusions.Items.Clear()
            foreach ($ex in $config.Exclusions) {
                [void]$lbExclusions.Items.Add($ex)
            }
        }
    } catch { Write-Warning "Failed to load config: $_" }
}

# Event Handlers
function Update-Filter {
    $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($lvInstallers.Items)
    $filterText = $txtSearch.Text.Trim()
    $showSelectedOnly = $chkShowSelectedOnly.IsChecked -eq $true

    if ([string]::IsNullOrEmpty($filterText) -and -not $showSelectedOnly) {
        $view.Filter = $null
    } else {
        $view.Filter = [Predicate[Object]]{
            param($obj)
            $item = $obj -as [WindowsInstallerPackage]

            $matchSearch = $true
            if (-not [string]::IsNullOrEmpty($filterText)) {
                $matchSearch = ($item.Subject -like "*$filterText*") -or
                               ($item.FileName -like "*$filterText*") -or
                               ($item.FullPath -like "*$filterText*")
            }

            $matchSelected = $true
            if ($showSelectedOnly) {
                $matchSelected = $item.IsSelected
            }

            return $matchSearch -and $matchSelected
        }
    }
    Update-ItemCount
}

$txtSearch.add_TextChanged({ Update-Filter })
$btnRefreshSearch.add_Click({ Update-Filter; $lvInstallers.Items.Refresh() })
$chkShowSelectedOnly.add_Click({ Update-Filter })

$btnAddExclusion.add_Click({
    if (![string]::IsNullOrWhiteSpace($txtExclusion.Text)) {
        [void]$lbExclusions.Items.Add($txtExclusion.Text.Trim())
        $txtExclusion.Text = ""
    }
})

$btnRemoveExclusion.add_Click({
    if ($lbExclusions.SelectedItem) {
        $lbExclusions.Items.Remove($lbExclusions.SelectedItem)
    }
})

function Invoke-Scan {
    $btnScan.IsEnabled = $false
    $btnScan.Content = "Scanning..."
    $txtStatus.Text = "Scanning installer folder..."

    # Force UI update to show "Scanning..."
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, 'Background')

    [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait

    $lvInstallers.Items.Clear()

    $isDeepScan = $rbDeepScanOn.IsChecked -eq $true
    $showAll = $chkShowAll.IsChecked -eq $true
    $exclusions = @()
    foreach ($item in $lbExclusions.Items) {
        if ($item -is [System.Windows.Controls.ListBoxItem]) {
            $exclusions += $item.Content
        } else {
            $exclusions += $item
        }
    }

    $registered = Get-RegisteredInstallers
    $registeredPaths = $registered.Keys

    $installerDir = "$env:windir\Installer"
    # Use -Filter or join multiple results for reliability without -Recurse
    $msiFiles = Get-ChildItem -Path $installerDir -Filter *.msi -File -ErrorAction SilentlyContinue
    $mspFiles = Get-ChildItem -Path $installerDir -Filter *.msp -File -ErrorAction SilentlyContinue
    $allFiles = $msiFiles + $mspFiles

    if ($null -eq $allFiles) { $allFiles = @() }

    $installerObj = $null
    try { $installerObj = New-Object -ComObject WindowsInstaller.Installer } catch {}

    foreach ($file in $allFiles) {
        $isOrphaned = $true
        $date = $file.CreationTime.ToString("yyyy-MM-dd") # Default to creation date
        $productCode = ""

        # Check if the file path is registered (case-insensitive check)
        foreach ($regPath in $registeredPaths) {
            if ($file.FullName -ieq $regPath) {
                $isOrphaned = $false
                $date = $registered[$regPath].Date # Use install date for registered products
                $productCode = $registered[$regPath].Code
                break
            }
        }

        if ($showAll -or $isOrphaned) {
            $subject = ""
            $title = ""
            $author = ""
            $comment = ""
            $name = ""
            $parentProductCode = ""

            if ($isOrphaned -eq $false) {
                $parentProductCode = $registered[$file.FullName].ParentCode
            }

            if ($null -ne $installerObj) {
                try {
                    $summaryInfo = $installerObj.SummaryInformation($file.FullName, 0)
                    if ($summaryInfo) {
                        $title = $summaryInfo.Property(2)
                        $subject = $summaryInfo.Property(3)
                        $author = $summaryInfo.Property(4)
                        $comment = $summaryInfo.Property(6)
                        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($summaryInfo)
                    }
                } catch { }
            }

            $name = if ($title) { $title } elseif ($subject) { $subject } else { "Unknown" }

            $digitalSignature = ""
            if ($isDeepScan) {
                $sig = Get-AuthenticodeSignature -FilePath $file.FullName
                if ($sig.SignerCertificate) {
                    $digitalSignature = $sig.SignerCertificate.Subject
                }
            }

            $excluded = $false
            foreach ($ex in $exclusions) {
                if (($subject -match [regex]::Escape($ex)) -or ($file.Name -match [regex]::Escape($ex)) -or ($digitalSignature -match [regex]::Escape($ex)) -or ($author -match [regex]::Escape($ex)) -or ($title -match [regex]::Escape($ex))) {
                    $excluded = $true
                    break
                }
            }

            if (-not $excluded) {
                $item = New-Object WindowsInstallerPackage
                $item.IsSelected = $false
                $item.Status = if ($isOrphaned) { "Orphaned" } else { "Registered" }
                $item.Name = $name
                $item.FileName = $file.Name
                $item.FileSizeMB = [math]::Round($file.Length / 1MB, 2)
                $item.Date = $date
                $item.Author = $author
                $item.Title = $title
                $item.Subject = $subject
                $item.DigitalSignature = $digitalSignature
                $item.Comment = $comment
                $item.FullPath = $file.FullName
                $item.ProductCode = $productCode
                $item.ParentProductCode = $parentProductCode

                [void]$lvInstallers.Items.Add($item)
            }
        }
    }

    if ($null -ne $installerObj) {
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($installerObj)
    }

    [System.GC]::Collect()

    $btnScan.IsEnabled = $true
    $btnScan.Content = "Scan"
    [System.Windows.Input.Mouse]::OverrideCursor = $null
    Update-ItemCount
    $txtStatus.Text = "Ready"
    if ($lvInstallers.Items.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No installers found with current filters.", "Scan Complete")
    }
}

$btnScan.add_Click({ Invoke-Scan })

$btnDeleteSel.add_Click({
    $itemsToDelete = @()
    foreach ($item in $lvInstallers.Items) {
        if ($item.IsSelected) {
            $itemsToDelete += $item
        }
    }

    if ($itemsToDelete.Count -gt 0) {
        # SAFETY CHECK: Prevent accidental deletion of registered MSIs
        $registeredCount = ($itemsToDelete | Where-Object { $_.Status -eq "Registered" }).Count
        if ($registeredCount -gt 0) {
            $warn = [System.Windows.MessageBox]::Show("You have selected $registeredCount REGISTERED package(s) for file deletion.`n`nDeleting registered files directly will CORRUPT the Windows Installer database for these products, preventing future updates or uninstalls.`n`nAre you absolutely sure you want to proceed with raw deletion instead of Uninstalling?", "CRITICAL WARNING", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Error)
            if ($warn -ne 'Yes') { return }
        }

        $res = [System.Windows.MessageBox]::Show("Delete $($itemsToDelete.Count) selected items?", "Confirm", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($res -eq 'Yes') {
            if (-not (Invoke-RestorePoint)) { return }
            $txtStatus.Text = "Deleting files..."
            $initialCount = $itemsToDelete.Count
            $remainingCount = $initialCount

            foreach ($item in $itemsToDelete) {
                $txtItemCount.Text = "Remaining: $remainingCount / $initialCount"
                try {
                    Remove-Item -Path $item.FullPath -Force -ErrorAction Stop
                    $lvInstallers.Items.Remove($item)
                } catch {
                    [System.Windows.MessageBox]::Show("Failed to delete $($item.FullPath)`n$_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                }
                $remainingCount--
            }
            Update-ItemCount
            $txtStatus.Text = "Ready"
        }
    } else {
        [System.Windows.MessageBox]::Show("No items selected. Please check the boxes next to the items you want to delete.", "Information", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

$btnExportSel.add_Click({
    $itemsToExport = @()
    foreach ($item in $lvInstallers.Items) {
        if ($item.IsSelected) {
            $itemsToExport += $item
        }
    }

    # If no selection, export all
    if ($itemsToExport.Count -eq 0) {
        foreach ($item in $lvInstallers.Items) {
            $itemsToExport += $item
        }
    }

    if ($itemsToExport.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No items to export. Run a scan first.", "Information", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }

    $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
    # Default filter: plain text (backwards compatible). The JSON filter uses the same schema
    # as the Leftovers Scanner so a file can be re-loaded in that window if needed.
    $saveDialog.Filter = "Text files (*.txt)|*.txt|Leftovers JSON (*.json)|*.json|All files (*.*)|*.*"
    $saveDialog.FileName = "OrphanedInstallers.txt"
    if ($saveDialog.ShowDialog() -ne $true) { return }

    $ext = [System.IO.Path]::GetExtension($saveDialog.FileName).ToLower()

    try {
        if ($ext -eq '.json') {
            # JSON format compatible with the Leftovers Scanner's export schema.
            # Each item now includes a clearly-named "PackageName" field (the Subject)
            # plus extra metadata (Publisher, ProductCode, InstallDate, FileSize, ...) so
            # the export is self-contained and re-usable for analysis outside the GUI.
            $jsonItems = foreach ($it in $itemsToExport) {
                [PSCustomObject]@{
                    # Leftovers-scanner compatible core fields
                    Type            = 'InstallerFile'
                    PackageName     = [string]$it.Subject          # explicitly the package name
                    FileName        = [string]$it.FileName         # the MSI/MSP file name
                    Path            = [string]$it.FullPath
                    Score           = 0
                    MatchedKeywords = ''
                    Source          = [string]$it.Subject          # kept for backwards compatibility
                    # Extra metadata (loader ignores unknown fields)
                    Status          = [string]$it.Status           # Orphaned / Registered
                    Title           = [string]$it.Title
                    Publisher       = [string]$it.Author
                    FileSizeMB      = [double]$it.FileSizeMB
                    InstallDate     = [string]$it.Date
                    ProductCode     = [string]$it.ProductCode
                    ParentProductCode = [string]$it.ParentProductCode
                }
            }
            $payload = [PSCustomObject]@{
                SchemaVersion = 1
                ExportDate    = (Get-Date).ToString('o')
                SourceScript  = 'patchCleanerRevisited.ps1'
                SourceList    = 'Main installers list (orphaned or registered MSI/MSP)'
                ItemCount     = @($jsonItems).Count
                Items         = $jsonItems
            }
            $payload | ConvertTo-Json -Depth 6 | Out-File -FilePath $saveDialog.FileName -Encoding UTF8 -Force
        } else {
            # Plain text export: one full path per line (original behaviour).
            $paths = foreach ($it in $itemsToExport) { $it.FullPath }
            $paths | Out-File -FilePath $saveDialog.FileName -Encoding UTF8
        }
        [System.Windows.MessageBox]::Show("Exported $($itemsToExport.Count) items to $($saveDialog.FileName)", "Export Complete", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    } catch {
        [System.Windows.MessageBox]::Show("Failed to export:`n$_", "Export Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

$btnClose.add_Click({
    $window.Close()
})

# Open the Leftovers Scanner window pre-loaded with items from a previously exported JSON file.
# This works even when there is no .NET scan active (the user can review/delete leftovers from
# an earlier cleanup session, or share/review a list generated on another machine).
$btnOpenLeftovers.add_Click({
    $openDialog = New-Object Microsoft.Win32.OpenFileDialog
    $openDialog.Filter = "Leftovers List (*.json)|*.json|All files (*.*)|*.*"
    $openDialog.Title = "Load leftovers list from JSON"
    if ($openDialog.ShowDialog() -ne $true) { return }

    try {
        $loaded = Get-Content -LiteralPath $openDialog.FileName -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        [System.Windows.MessageBox]::Show("Failed to parse the file. It may not be valid JSON.`n`n$_", "Load Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return
    }

    # Validate basic structure
    if ($null -eq $loaded -or $null -eq $loaded.Items -or -not ($loaded.Items -is [System.Collections.IEnumerable])) {
        [System.Windows.MessageBox]::Show("The file does not look like a leftovers list (missing 'Items' array).", "Load Failed", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $loadedItems = @($loaded.Items)
    if ($loadedItems.Count -eq 0) {
        [System.Windows.MessageBox]::Show("The file contains no items.", "Load Failed", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }

    # Convert loaded entries into LeftoverItem objects
    $preloaded = @()
    $skipped = 0
    foreach ($entry in $loadedItems) {
        if (-not $entry.Path -or -not $entry.Type) { $skipped++; continue }
        $item = New-Object LeftoverItem
        $item.IsSelected     = $true   # loaded items are checked by default for batch review/deletion
        $item.Type           = [string]$entry.Type
        $item.Name           = [string]$entry.Name
        $item.Path           = [string]$entry.Path
        $item.Score          = if ($entry.Score) { [int]$entry.Score } else { 0 }
        $item.MatchedKeywords = if ($entry.MatchedKeywords) { [string]$entry.MatchedKeywords } else { '' }
        $item.Source         = if ($entry.Source) { [string]$entry.Source } else { '' }
        $item.SampleFile     = if ($entry.SampleFile) { [string]$entry.SampleFile } else { '' }
        $preloaded += ,$item
    }

    Show-LeftoversWindow -PreloadedItems $preloaded
})

$menuUninstall.add_Click({
    $targets = @()
    foreach ($i in $lvInstallers.Items) { if ($i.IsSelected) { $targets += $i } }
    if ($targets.Count -eq 0 -and $lvInstallers.SelectedItem) { $targets += $lvInstallers.SelectedItem }

    if ($targets.Count -gt 0) {
        $res = [System.Windows.MessageBox]::Show("Are you sure you want to uninstall $($targets.Count) selected package(s)?`n`nNote: This will attempt to uninstall both products and patches.", "Confirm Uninstall", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
        if ($res -eq 'Yes') {
            if (-not (Invoke-RestorePoint)) { return }
            $txtStatus.Text = "Batch Uninstalling..."

            # Work on a copy to avoid modification issues
            $toProcess = @($targets)
            $initialCount = $toProcess.Count
            $remainingCount = $initialCount

            foreach ($item in $toProcess) {
                $txtItemCount.Text = "Remaining: $remainingCount / $initialCount"
                $txtStatus.Text = "Uninstalling $($item.FileName)..."
                [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, 'Background')

                $argStr = ""
                if ($item.FullPath -match '\.msp$') {
                    if ($item.ProductCode -and $item.ParentProductCode) {
                        # Correct msiexec order for patches: /uninstall <patch> /package <product>
                        $argStr = "/uninstall `"$($item.ProductCode)`" /package `"$($item.ParentProductCode)`""
                    } elseif ($item.ProductCode) {
                        $argStr = "/uninstall `"$($item.ProductCode)`""
                    } else {
                        $argStr = "/uninstall `"$($item.FullPath)`""
                    }
                } else {
                    if ($item.ProductCode) {
                        $argStr = "/x `"$($item.ProductCode)`""
                    } else {
                        $argStr = "/x `"$($item.FullPath)`""
                    }
                }

                $argStr += " /qb /norestart"
                $process = Start-Process msiexec.exe -ArgumentList $argStr -Wait -PassThru -NoNewWindow

                if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                    $lvInstallers.Items.Remove($item)
                } elseif ($process.ExitCode -eq 1605) {
                    # 1605 = This action is only valid for products that are currently installed.
                    # It's an orphan. We can safely delete it.
                    if (Test-Path $item.FullPath) { Remove-Item -Path $item.FullPath -Force }
                    $lvInstallers.Items.Remove($item)
                } else {
                    Write-Warning "Uninstall failed for $($item.Name) with exit code $($process.ExitCode)"
                    [System.Windows.MessageBox]::Show("Uninstallation failed with exit code $($process.ExitCode). The file was kept.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                }
            }
            $txtItemCount.Text = "Items: $($lvInstallers.Items.Count)"
            $txtStatus.Text = "Ready"
        }
    }
})

$menuDelete.add_Click({
    $targets = @()
    foreach ($i in $lvInstallers.Items) { if ($i.IsSelected) { $targets += $i } }
    if ($targets.Count -eq 0 -and $lvInstallers.SelectedItem) { $targets += $lvInstallers.SelectedItem }

    if ($targets.Count -gt 0) {
        # SAFETY CHECK: Prevent accidental deletion of registered MSIs
        $registeredCount = ($targets | Where-Object { $_.Status -eq "Registered" }).Count
        if ($registeredCount -gt 0) {
            $warn = [System.Windows.MessageBox]::Show("You have selected $registeredCount REGISTERED package(s) for file deletion.`n`nDeleting registered files directly will CORRUPT the Windows Installer database for these products, preventing future updates or uninstalls.`n`nAre you absolutely sure you want to proceed with raw deletion instead of Uninstalling?", "CRITICAL WARNING", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Error)
            if ($warn -ne 'Yes') { return }
        }

        $res = [System.Windows.MessageBox]::Show("Delete $($targets.Count) selected item(s)?", "Confirm Delete", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($res -eq 'Yes') {
            if (-not (Invoke-RestorePoint)) { return }
            $txtStatus.Text = "Deleting files..."
            # Work on a copy to avoid modification issues
            $toProcess = @($targets)
            $initialCount = $toProcess.Count
            $remainingCount = $initialCount

            foreach ($item in $toProcess) {
                $txtItemCount.Text = "Remaining: $remainingCount / $initialCount"
                try {
                    $txtStatus.Text = "Deleting $($item.FileName)..."
                    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, 'Background')
                    Remove-Item -Path $item.FullPath -Force -ErrorAction Stop
                    $lvInstallers.Items.Remove($item)
                } catch {
                    [System.Windows.MessageBox]::Show("Failed to delete $($item.FullPath)`n$_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                }
                $remainingCount--
            }
            Update-ItemCount
            $txtStatus.Text = "Ready"
        }
    }
})

$menuBrowse.add_Click({
    if ($lvInstallers.SelectedItem) {
        $path = $lvInstallers.SelectedItem.FullPath
        Start-Process "explorer.exe" -ArgumentList "/select,`"$path`""
    }
})

# Save settings and Auto-Start
$window.add_Closing({
    $exclusions = @()
    foreach ($item in $lbExclusions.Items) {
        if ($item -is [System.Windows.Controls.ListBoxItem]) { $exclusions += $item.Content }
        else { $exclusions += $item }
    }

    $config = @{
        ShowAll = $chkShowAll.IsChecked -eq $true
        DeepScan = $rbDeepScanOn.IsChecked -eq $true
        ScanOnStart = $chkScanOnStart.IsChecked -eq $true
        CreateRestorePoint = $chkRestorePoint.IsChecked -eq $true
        Exclusions = $exclusions
    }

    $configDir = Split-Path $configFile
    if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
    $config | ConvertTo-Json | Out-File -FilePath $configFile -Encoding UTF8
})

$window.add_Loaded({
    if ($chkScanOnStart.IsChecked -eq $true) {
        Invoke-Scan
    }
})

# Show the GUI
$window.ShowDialog() | Out-Null

# Display completion message
Write-Host "FINISHED: GUI Closed."
