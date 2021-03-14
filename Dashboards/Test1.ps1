New-UDDashboard -Title "Hello, World!" -Content {
    New-UDHeading -Text "Hello, World!" -Size 1

    New-UDHeading -Text "Hello, $v1!" -Size 1

    $r = Get-Content C:\param.xml -Raw
    New-UDTypography -Text $r -Variant h5

    New-UDUpload -Text 'Upload Image' -OnUpload {
        $Data = $Body | ConvertFrom-Json
        
        $bytes = [System.Convert]::FromBase64String($Data.Data)
        [System.IO.File]::WriteAllBytes("$env:temp\$($Data.Name)", $bytes)
    }

    New-UDButton -Text "Click me!" -OnClick {
        $item = $body | ConvertFrom-Json
        Wait-Debugger
        Show-UDToast -Message "Clicked!"
    }
}