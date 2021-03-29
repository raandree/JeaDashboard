ConvertFrom-StringData @'
    ConflictRunAsVirtualAccountGroupsAndGroupManagedServiceAccount  = The 'RunAsVirtualAccountGroups' setting can not be used when a configuration is set to run as a Group Managed Service Account. (JSC0001)
    ConflictRunAsVirtualAccountAndGroupManagedServiceAccount        = The properties 'GroupManagedServiceAccount' and 'RunAsVirtualAccount' cannot be used together. (JSC0002)
    WinRMNotRunningGetPsSession                                     = WinRM service is not running. Cannot get PS Session Configuration(s). (JSC0003)
    WinRMNotRunningUnRegisterPsSession                              = WinRM service is not running. Cannot unregister PS Session Configuration '{0}'. (JSC0004)
    WinRMNotRunningRegisterPsSession                                = WinRM service is not running. Cannot register PS Session Configuration '{0}'. (JSC0005)
    NotDefinedGMSaAndVirtualAccount                                 = 'GroupManagedServiceAccount' and 'RunAsVirtualAccount' are not defined, setting 'RunAsVirtualAccount' to 'true'. (JSC0006)
    RegisterPSSessionConfiguration                                  = Will register PSSessionConfiguration with argument: Name = '{0}', Path = '{1}' and Timeout = '{2}' (JSC0007)
    ForcingProcessToStop                                            = WinRM seems hanging in Stopping state. Forcing process {0} to stop. (JSC0008)
    RestartingServices                                              = "Restarting services: {0} (JSC0009)
    FailureListStartService                                         = Start service {0} (JSC0010)
    FailureListKillWinRMProcess                                     = Kill WinRM process. (JSC0011)
    FailedExecuteOperation                                          = Failed to execute following operation(s): {0} (JSC0012)
    RestartWinRM                                                    = (Re)starting WinRM service (JSC0013)
    StoringPSSessionConfigurationFile                               = Storing PSSessionConfigurationFile in file {0} (JSC0013)
    DesiredStateSessionConfiguration                                = Desired state of session configuration named '{0}' is '{1}', current state is '{2}'. (JSC0014)
    PSSessionConfigurationNamePresent                               = Name present: {0} (JSC0015)
    ReasonEpSessionNotFound                                         = The EndPoint Session {0} not found. (JSC0016)
    ReasonEnsure                                                    = The EndPoint Session {0} is present, but it ought to be absent. (JSC0017)
    ReasonRoleDefinitions                                           = RoleDefinitions hasn't got the good values. (JSC0018)
    ReasonRunAsVirtualAccount                                       = RunAsVirtualAccount hasn't got the good values. (JSC0019)
    ReasonRunAsVirtualAccountGroups                                 = RunAsVirtualAccountGroups hasn't got the good values. (JSC0020)
    ReasonGroupManagedServiceAccount                                = GroupManagedServiceAccount hasn't got the good values. (JSC0021)
    ReasonTranscriptDirectory                                       = TranscriptDirectory hasn't got the good values. (JSC0022)
    ReasonScriptsToProcess                                          = ScriptsToProcess hasn't got the good values. (JSC0023)
    ReasonSessionType                                               = SessionType hasn't got the good values. (JSC0024)
    ReasonMountUserDrive                                            = MountUserDrive hasn't got the good values. (JSC0025)
    ReasonUserDriveMaximumSize                                      = UserDriveMaximumSize hasn't got the good values. (JSC0026)
    ReasonRequiredGroups                                            = RequiredGroups hasn't got the good values. (JSC0027)
    ReasonModulesToImport                                           = ModulesToImport hasn't got the good values. (JSC0028
    ReasonVisibleAliases                                            = VisibleAliases hasn't got the good values. (JSC0029)
    ReasonVisibleCmdlets                                            = VisibleCmdlets hasn't got the good values. (JSC0030)
    ReasonVisibleFunctions                                          = VisibleFunctions hasn't got the good values. (JSC0031)
    ReasonVisibleProviders                                          = VisibleProviders hasn't got the good values. (JSC0032)
    ReasonAliasDefinitions                                          = AliasDefinitions hasn't got the good values. (JSC0033)
    ReasonFunctionDefinitions                                       = FunctionDefinitions hasn't got the good values. (JSC0034)
    ReasonVariableDefinitions                                       = VariableDefinitions hasn't got the good values. (JSC0035)
    ReasonEnvironmentVariables                                      = EnvironmentVariables hasn't got the good values. (JSC0036)
    ReasonTypesToProcess                                            = TypesToProcess hasn't got the good values. (JSC0037)
    ReasonFormatsToProcess                                          = FormatsToProcess hasn't got the good values. (JSC0038)
    ReasonAssembliesToLoad                                          = AssembliesToLoad hasn't got the good values. (JSC0039)
    ReasonHungRegistrationTimeout                                   = HungRegistrationTimeout hasn't got the good values. (JSC0040)
'@
