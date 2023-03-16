###			Create Home Folders for Parallels clients               ###
###				 Written by Sean Urbina	         			        ###
###				 reachout4sean@gmail.com				            ###

Add-Type -AssemblyName PresentationFramework

#GUI staging
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:AUNC_Homes"
        Title="Make Home Folders" Height="246" Width="542" ResizeMode="NoResize">
    <Grid Margin="10,0,10,95">
        <TextBox x:Name="txtUsername" HorizontalAlignment="Left" Margin="140,10,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="209" Grid.Row="1"/>
        <TextBox x:Name="txtSharepath" HorizontalAlignment="Left" Margin="140,56,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="208" Grid.Row="1"/>
        <Label x:Name="lblUsername" Content="Enter AD username:" HorizontalAlignment="Left" Margin="10,6,0,0" VerticalAlignment="Top" RenderTransformOrigin="-0.077,-0.211" Grid.Row="1"/>
        <Label x:Name="lblSharepath" Content="Local path to share: " HorizontalAlignment="Left" Margin="10,52,0,0" VerticalAlignment="Top" RenderTransformOrigin="-0.077,-0.211" Width="110" Grid.Row="1"/>
        <Button x:Name="btnMakeFolder" Content="Make Home Folder" HorizontalAlignment="Left" Margin="371,4,0,0" VerticalAlignment="Top"  Height="28" Grid.Row="1" Width="113"/>
        <TextBlock x:Name="txtResults" HorizontalAlignment="Left" Margin="10,94,0,-85" Grid.Row="1" TextWrapping="WrapWithOverflow" Background="#E5012456" Width="500" Height="105" Text="" VerticalAlignment="Top"/>
        <Button x:Name="btnSetProfile" Content="Set Home Directory" HorizontalAlignment="Left" Margin="371,50,0,0" VerticalAlignment="Top" Height="28" Grid.Row="1" Width="113"/>

    </Grid>
</Window> 
"@

#Load Form Controls
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader] $xaml)
$window=[Windows.Markup.XamlReader]::Load( $reader )

$txtUsername=$window.FindName("txtUsername")
$txtSharepath=$window.FindName("txtSharepath")
$lblUsername=$window.FindName("lblUsername")
$lblSharepath=$window.FindName("lblSharepath")
$btnMakeFolder=$window.FindName("btnMakeFolder")
$txtResults=$window.FindName("txtResults")
$btnSetProfile=$window.FindName("btnSetProfile")

#Function to make the share
function New-NetworkShare {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Username,
        [Parameter(Mandatory=$true)]
        [string]$LocalPath
    )

      try {
        # Check if the username is a valid AD user
        $user = Get-ADUser $Username -ErrorAction Stop
        
        # Create the share name
        $shareName = $Username + '$'

        # Create the share and set the appropriate permissions
        New-Item $LocalPath -ItemType Directory

        # Set the NTFS permissions on the local folder
        $Acl = Get-Acl $LocalPath
        $Acl.SetAccessRuleProtection($True,$True)

        $Ar1 = New-Object System.Security.AccessControl.FileSystemAccessRule($Username,"FullControl","Allow")
        $Ar2 = New-Object System.Security.AccessControl.FileSystemAccessRule("Domain Admins","FullControl","Allow")
        $Ar3 = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl","Allow")

        $Acl.SetAccessRule($Ar1)
        $Acl.SetAccessRule($Ar2)
        $Acl.SetAccessRule($Ar3)

        Set-Acl $LocalPath $Acl

        #Create the remote path to share and set share permissions
         New-SmbShare -Name $shareName -Path $LocalPath -FullAccess "Domain Admins" -ChangeAccess "$Username"
         $showShare = Get-SmbShare -Name $shareName
        
       
        # Construct a string with the remote path in it
        $serverName = $env:COMPUTERNAME
        $remotePath = "\\$serverName\$shareName"

        # Print succesful
        $txtResults.Text = "Share successfully created at $remotePath"
        $txtResults.Foreground = "Yellow"
       

    } catch {
        # Print errors
        $txtResults.Text = $_.Exception.Message
        $txtResults.Foreground = "Red"
    }
}


 #Add button click event to make share
$btnMakeFolder.Add_Click({
    try {
        #Run new-networkshare function on button press
        New-NetworkShare -Username $txtUsername.Text -LocalPath $txtSharepath.Text
    } catch{
        # Print errores
        $txtResults.Text = $_.Exception.Message
        $txtResults.Foreground = "Red"
    }
})

$btnSetProfile.Add_Click({
    try {
        # Get username
        $username = $txtUsername.Text

        # Construct the UNC path to the user's home directory
        $homeDirectory = "\\$env:COMPUTERNAME\$username`$"

        # Set the "Connect" field in the user's Active Directory profile to the mapped network drive
        Set-ADUser -Identity $username -HomeDirectory $homeDirectory -HomeDrive "H:"

        # Print successful creation
        $txtResults.Text = " $username Home Directory mapped to $homeDirectory in Active Directory.`nCreate another Home folder or exit window" 
        $txtResults.Foreground = "Yellow"
        $txtUsername.Text = ""
        $txtSharepath.Text = ""

    } catch {
        # Print errors
        $txtResults.Text = $_.Exception.Message
        $txtResults.Foreground = "Red"
    }
})

$window.ShowDialog() | Out-Null