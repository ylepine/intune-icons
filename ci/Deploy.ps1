<#
    .SYNOPSIS
        AppVeyor pre-deploy script.
#>

# Line break for readability in AppVeyor console
Write-Host -Object ''

# Make sure we're using the main branch and that it's not a pull request
# Environmental Variables Guide: https://www.appveyor.com/docs/environment-variables/
If ($env:APPVEYOR_REPO_BRANCH -ne 'main') {
    Write-Warning -Message "Skipping version increment and push for branch $env:APPVEYOR_REPO_BRANCH"
}
ElseIf ($env:APPVEYOR_PULL_REQUEST_NUMBER -gt 0) {
    Write-Warning -Message "Skipping version increment and push for pull request #$env:APPVEYOR_PULL_REQUEST_NUMBER"
}
Else {

    # Tests success, push to GitHub
    If ($res.FailedCount -eq 0) {
        # Publish the new version back to main on GitHub
        Try {
            # Set up a path to the git.exe cmd, import posh-git to give us control over git
            $env:Path += ";$env:ProgramFiles\Git\cmd"
            Import-Module posh-git -ErrorAction "Stop"

            # Dot source Invoke-Process.ps1. Prevent 'RemoteException' error when running specific git commands
            . $projectRoot\ci\Invoke-Process.ps1

            # Configure the git environment
            git config --global credential.helper store
            Add-Content -Path (Join-Path $env:USERPROFILE ".git-credentials") -Value "https://$($env:GitHubKey):x-oauth-basic@github.com`n"
            git config --global user.email "$($env:APPVEYOR_REPO_COMMIT_AUTHOR_EMAIL)"
            git config --global user.name "$($env:APPVEYOR_REPO_COMMIT_AUTHOR)"
            git config --global core.autocrlf true
            git config --global core.safecrlf false

            # Push changes to GitHub
            $Version = "$(Get-Date -Format yyyy).$(Get-Date -Format MM).$($env:APPVEYOR_BUILD_NUMBER)"
            Invoke-Process -FilePath "git" -ArgumentList "checkout main"
            git add --all
            git status
            git commit -s -m "AppVeyor validate: $Version"
            Invoke-Process -FilePath "git" -ArgumentList "push origin main"
            Write-Host "$Version pushed to GitHub." -ForegroundColor "Cyan"
        }
        Catch {
            # Sad panda; it broke
            Write-Warning "Push to GitHub failed."
            Throw $_
        }
    }
}

# Line break for readability in AppVeyor console
Write-Host -Object ''
