@{
    PSDependOptions              = @{
        AddToPath      = $true
        Target         = 'DscResources'
        DependencyType = 'PSGalleryModule'
        Parameters     = @{
            Repository = 'PSGallery'
        }
    }

    #JeaDsc                       = '0.7.2'
    #xPSDesiredStateConfiguration = '9.1.0'
}
