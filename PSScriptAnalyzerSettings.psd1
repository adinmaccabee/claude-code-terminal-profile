@{
    Severity     = @('Error', 'Warning')
    # Write-Host is intentional: this is an interactive installer that prints status messages.
    ExcludeRules = @('PSAvoidUsingWriteHost')
}
