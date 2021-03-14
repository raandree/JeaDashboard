$here = $PSScriptRoot

$datumDefinitionFile = Join-Path $here ..\..\DscConfigData\Datum.yml
$nodeDefinitions = Get-ChildItem $here\..\..\DscConfigData\AllNodes -Recurse -Include *.yml
$datum = New-DatumStructure -DefinitionFile $datumDefinitionFile
$configurationData = Get-FilteredConfigurationData -Datum $datum -Filter $filter

$nodeNames = [System.Collections.ArrayList]::new()

Describe 'Datum Tree Definition' -Tag Integration {
    It 'Exists in DscConfigData Folder' {
        Test-Path $datumDefinitionFile | Should -Be $true
    }

    $datumYamlContent = Get-Content $datumDefinitionFile -Raw
    It 'is Valid Yaml' {
        { $datumYamlContent | ConvertFrom-Yaml } | Should -Not -Throw
    }

}

Describe 'Node Definition Files' -Tag Integration {
    
    $nodeDefinitions.ForEach{
        # A Node cannot be empty
        $content = Get-Content -Path $_ -Raw
        $node = $content | ConvertFrom-Yaml
        $nodeName = $node.NodeName
        
        if ($_.BaseName -ne 'AllNodes') {
            It "'$($_.FullName)' should not be duplicated" {
                $nodeNames -contains $_.BaseName | Should -Be $false
            }
        }

        $nodeNames.Add($_.BaseName) | Out-Null

        It "'$nodeName' has valid yaml" {
            { $content | ConvertFrom-Yaml } | Should -Not -Throw
        }
    }
}
