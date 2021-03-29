@{

    RootModule           = 'JeaDsc.psm1'

    ModuleVersion        = '0.0.1'

    GUID                 = 'c7c41e83-55c3-4e0f-9c4f-88de602e04db'

    Author               = 'DSC Community'

    CompanyName          = 'DSC Community'

    Copyright            = 'Copyright the DSC Community contributors. All rights reserved.'

    Description          = 'This module contains resources to configure Just Enough Administration endpoints.'

    PowerShellVersion    = '5.1'

    NestedModules        = @()

    FunctionsToExport    = @(
        'ConvertTo-Expression'
    )

    CmdletsToExport      = @()

    VariablesToExport    = @()

    AliasesToExport      = @()

    DscResourcesToExport = @('JeaSessionConfiguration','JeaRoleCapabilities')

    PrivateData          = @{

        PSData = @{

            Tags         = @('DesiredStateConfiguration', 'DSC', 'DSCResource', 'JEA', 'JustEnoughAdministration')

            LicenseUri   = 'https://github.com/dsccommunity/JeaDsc/blob/master/LICENSE'

            ProjectUri   = 'https://github.com/dsccommunity/JeaDsc'

            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'

            Prerelease   = ''

            ReleaseNotes = '## [0.0.1] - 2021-03-25

### Added

- Adding herited classes that contains helper methods.
- Adding Reason class.
- Adding Reasons property in JeaSessionConfiguration and JeaRoleCapabilities resources.
  It''s a requirement of [Guest Configuration](https://docs.microsoft.com/en-us/azure/governance/policy/how-to/guest-configuration-create#get-targetresource-requirements)
- Adding pester tests to check Reasons property.

### Changed

- Moving the class based resources from nested modules to root module.
- Moving LocalizedData of class based resources in .strings.psd1 files.
Based on [stylesguidelines](https://dsccommunity.org/styleguidelines/localization/) of DscCommunity.
- Updated the Required Modules and Build.Yaml with Sampler.GitHubTasks.

### Removed

- Removing dummy object

'

        }

    }
}




