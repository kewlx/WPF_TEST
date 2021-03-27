$syncHash = [hashtable]::Synchronized(@{})
$newRunspace =[runspacefactory]::CreateRunspace()
$newRunspace.ApartmentState = "STA"
$newRunspace.ThreadOptions = "ReuseThread"         
$newRunspace.Open()
$newRunspace.SessionStateProxy.SetVariable("syncHash",$syncHash)

$inputXML = @"
<Window x:Name="Windows_OS_Upgrade_Form" x:Class="WpfApp2.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:WpfApp2"
        mc:Ignorable="d"
        Title="Windows OS Upgrade" Topmost="True" WindowStartupLocation="CenterScreen" Visibility="Visible" ResizeMode="CanMinimize" Height="119.552" Width="300.244">
    <Grid>
        <RadioButton x:Name="RadioButton_CopyFiles" Content="Copy Files" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="10,11,0,0" AutomationProperties.Name="CopyFilesRB"/>
        <RadioButton x:Name="RadioButton_CopyFilesAndInstall" Content="Copy Files and Install" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="10,31,0,0" AutomationProperties.Name="CopyFilesAndInstallRB"/>
        <Button x:Name="Button_Confirm" Content="Confirm" HorizontalAlignment="Left" VerticalAlignment="Top" Width="75" Margin="202,55,0,0" AutomationProperties.Name="ConfirmButton" IsEnabled="False" />
        <CheckBox x:Name="CheckBox_Reboot" Content="Reboot" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="202,11,0,0" IsEnabled="False"/>
    </Grid>
</Window>
"@



$inputXML = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML

#Read XAML 
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
try {
    $syncHash.Window = [Windows.Markup.XamlReader]::Load( $reader )
}
catch {
    Write-Warning "Unable to parse XML, with error: $PSItem `n Ensure that there are NO SelectionChanged or TextChanged properties in your textboxes (PowerShell cannot process them)"
    throw
}

#===========================================================================
# Load XAML Objects In PowerShell
#===========================================================================
  
$xaml.SelectNodes("//*[@Name]") | ForEach-Object {
    try {
        Write-Output "Adding $($PSItem.Name)"
        $syncHash.Add($PSItem.Name,$syncHash.Window.FindName($PSItem.Name))
    } catch {
        throw
    }
}

#===========================================================================
# Use this space to add code to the various form elements in your GUI
#===========================================================================


$syncHash.Window.add_Loaded({
    $global:Session = [PowerShell]::Create().AddScript({

        $syncHash.Window.Dispatcher.invoke(
            [action]{
                function Compare-somefunction {
                    [CmdletBinding()]
                    param (
                        [Parameter(Mandatory,
                            ValueFromPipeline,
                            ValueFromPipelineByPropertyName)]
                        [ValidateNotNullOrEmpty()]
                        [ValidateScript( {
                                if (-Not ($_ | Test-Path) ) {
                                    throw "File does not exist"
                                }
                                if (-Not ($_ | Test-Path -PathType Leaf) ) {
                                    throw "The path argument must be a file. Folder paths are not allowed."
                                }
                                if ($_ -notmatch "(\.json)") {
                                    throw "The file specified in the path argument must be .json"
                                }
                                return $true 
                            })]
                        [string]$Path
                    )
                
                }
                
                function Copy-somefunction {
                    [CmdletBinding(SupportsShouldProcess)]
                    param (
                        [Parameter(Mandatory,
                            ValueFromPipeline,
                            ValueFromPipelineByPropertyName)]
                        [ValidateScript( {
                                if (-Not ($_ | Test-Path) ) {
                                    throw "File or folder does not exist"
                                }
                                return $true 
                            })]
                        [string]$Source,
                
                        [Parameter(
                            ValueFromPipeline,
                            ValueFromPipelineByPropertyName)]
                        [ValidateScript( {
                                if (-Not ($_ | Test-Path) ) {
                                    throw "File or folder does not exist"
                                }
                                if (-Not ($_ | Test-Path -PathType container) ) {
                                    throw "The Path argument must be a folder. Folder paths are not allowed."
                                }
                                return $true 
                            })]
                        [string]$Destination = "$Home\downloads"
                    )
                
                }
                
                $source = "$home\desktop"
                $destination = "$home\downloads"
                
                $EndTailArgs = @{
                    Wait = $True
                }
                
            $syncHash.RadioButton_CopyFiles.Add_Click( {
                $syncHash.Button_Confirm.IsEnabled = $true
                $syncHash.CheckBox_Reboot.IsChecked = $false
                $syncHash.CheckBox_Reboot.IsEnabled = $false
            })
            
            $syncHash.RadioButton_CopyFilesAndInstall.Add_Click( {
                $syncHash.Button_Confirm.IsEnabled = $true
                $syncHash.CheckBox_Reboot.IsEnabled = $true
            })
            
            $syncHash.CheckBox_Reboot.Add_Click( {
            })
            
            $syncHash.Button_Confirm.Add_Click( {
                Compare-somefunction -Path "\\server\path\here"
                Copy-somefunction -Source $source -Destination $destination
                1..60 | ForEach-Object {
                    Start-Sleep -Seconds 1
                    Write-Host $_
                }
                Pause
                $form.Close()
        
            })
        
        },"Normal"
        )
    })


    $Session.Runspace = $newRunspace
    $global:Handle = $Session.BeginInvoke()
})



#===========================================================================
# Shows the form
#===========================================================================
#write-host "To show the form, run the following" -ForegroundColor Cyan

#$Form.ShowDialog() | Out-Null

# check if a command is still running when exiting the GUI
$syncHash.Window.add_Closing({
    if ($null -ne $Session -and $Handle.IsCompleted -eq $false) {
        [Windows.MessageBox]::Show('A command is still running.')
        # the event object is automatically passed through as $_
        $PSItem.Cancel = $true
    }
})

$syncHash.Window.add_Closed({
    if ($null -ne $Session) {
        $Session.EndInvoke($Handle)
    }
    
    $newRunspace.Close()
})

$syncHash.Window.ShowDialog() | Out-Null
