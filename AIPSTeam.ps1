<#PSScriptInfo
.VERSION 3.1.2
.GUID f0f4316d-f106-43b5-936d-0dd93a49be6b
.AUTHOR voytas75
.TAGS ai,psaoai,llm,project,team,gpt
.PROJECTURI https://github.com/voytas75/AIPSTeam
.ICONURI https://raw.githubusercontent.com/voytas75/AIPSTeam/master/images/AIPSTeam.png
.EXTERNALMODULEDEPENDENCIES PSAOAI, PSScriptAnalyzer, PowerHTML
.RELEASENOTES
3.1.2[unpublished]: minor changes and fixes.
3.1.1: moved PM exec, Test-ModuleMinVersion, add iconuri, minor fixes, optimize ollama manager logic, code cleanup.
3.0.3: Corrected log entry method usage
3.0.2: check module version of PSAOAI, ollama checks, ollama auto manager.
3.0.1: implement RAG based on Bing Web search API, add new method to class, extend globalstate for all params.
2.1.2: minor fixes.
2.1.1: move to new repository, new projecturi, LoadProjectStatus searching for xml file if no fullName path, fix Documentation bug.
2.0.1: add abstract layer for LLM providers, fix update of lastPSDevCode, ann NOTips, Updated error handling, Added VerbosePrompt switch.
1.6.2: fix double feedback display. 
1.6.1: fix stream in feedback. 
1.6.0: minor fixes, enhanced error reporting, added error handling, new menu options, and refactored functions.
1.5.0: minor fixes, modularize PSScriptAnalyzer logic, load, save project status, State Management Object, refactoring.
1.4.0: modularize feedback.
1.3.0: add to menu Generate documentation, The code research, Requirement for PSAOAI version >= 0.2.1 , fix CyclomaticComplexity.
1.2.1: fix EXTERNALMODULEDEPENDENCIES
1.2.0: add user interaction and use PSScriptAnalyzer.
1.1.0: default value for DeploymentChat.
1.0.7: Added 'DeploymentChat' parameter.
1.0.6: Updated function calls to Add-ToGlobalResponses $GlobalState .
1.0.5: code export fix.
1.0.4: code export fix.
1.0.3: requirements.
1.0.2: publishing, check version fix, dependience.
1.0.1: initializing.
#>

#Requires -Modules PSAOAI
#Requires -Modules PSScriptAnalyzer
#Requires -Modules PowerHTML

<# 
.SYNOPSIS 
Emulates a team of AI-powered Agents with RAG collaborating on a PowerShell project.

.DESCRIPTION 
This script simulates a team of AI-powered Agents with RAG, each with a unique role in executing a project. User input is processed by one AI specialist, who performs their task and passes the result to the next AI Agent. This process continues until all tasks are completed, leveraging AI to enhance efficiency and accuracy in project execution.

.PARAMETER userInput 
Defines the project outline as a string. The default is to monitor RAM usage and show a color block based on the load. This parameter can also accept input from the pipeline.

.PARAMETER Stream 
Controls whether the output should be streamed live. The default is `$true`.

.PARAMETER NOPM 
Disables the Project Manager functions when used.

.PARAMETER NODocumentator 
Disables the Documentator functions when used.

.PARAMETER NOLog
Disables the logging functions when used.

.PARAMETER NOTips
Disables tips.

.PARAMETER VerbosePrompt
Shows prompts.

.PARAMETER LogFolder
Specifies the folder where logs should be stored.

.PARAMETER DeploymentChat
Specifies the deployment chat environment variable for PSAOAI. The default is retrieved from the environment variable `PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT`.

.PARAMETER LoadProjectStatus
Loads the project status from a specified path. Part of the 'LoadStatus' parameter set.

.PARAMETER MaxTokens
Specifies the maximum number of tokens to generate in the response. The default is 20480.

.PARAMETER LLMProvider
Specifies the LLM provider to use (e.g., ollama, LMStudio, AzureOpenAI). The default is "AzureOpenAI".

.PARAMETER NORAG
Disables the RAG (Retrieve and Generate) functionality.

.INPUTS 
System.String. You can pipe a string to the 'userInput' parameter.

.OUTPUTS 
The output varies depending on how each specialist processes their part of the project. Typically, text-based results are expected, which may include status messages or visual representations like graphs or color blocks related to system metrics such as RAM load, depending on the user input specification provided via the 'userInput' parameter.

.EXAMPLE 
PS> "Monitor CPU usage and display dynamic graph." | AIPSTeam -Stream $false

This command runs the script without streaming output live (-Stream $false) and specifies custom user input about monitoring CPU usage instead of RAM, displaying it through dynamic graphing methods rather than static color blocks.

.NOTES 
Version: 3.1.1
Author: voytas75
Creation Date: 05.2024

.LINK
https://www.powershellgallery.com/packages/AIPSTeam
https://github.com/voytas75/AIPSTeam/
#>
param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $true, HelpMessage = "Defines the project outline as a string.")]
    [string] $userInput = $(if ($null -eq $userInput) { Read-Host "Please provide the project outline" }),

    [Parameter(Mandatory = $false, HelpMessage = "Controls whether the output should be streamed live. Default is `$true.")]
    [bool] $Stream = $true,
    
    [Parameter(Mandatory = $false, HelpMessage = "Disables the RAG (Retrieve and Generate) functionality.")]
    [switch] $NORAG,

    [Parameter(Mandatory = $false, HelpMessage = "Disables the Project Manager functions when used.")]
    [switch] $NOPM,

    [Parameter(Mandatory = $false, HelpMessage = "Disables the Documentator functions when used.")]
    [switch] $NODocumentator,

    [Parameter(Mandatory = $false, HelpMessage = "Disables the logging functions when used.")]
    [switch] $NOLog,

    [Parameter(Mandatory = $false, HelpMessage = "Disables tips.")]
    [switch] $NOTips,

    [Parameter(Mandatory = $false, HelpMessage = "Shows prompts.")]
    [switch] $VerbosePrompt,

    [Parameter(Mandatory = $false, HelpMessage = "Specifies the folder where logs should be stored.")]
    [string] $LogFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Specifies the deployment chat environment variable for PSAOAI (AZURE OpenAI).")]
    [string] $DeploymentChat = [System.Environment]::GetEnvironmentVariable("PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT", "User"),

    [Parameter(Mandatory = $false, ParameterSetName = 'LoadStatus', HelpMessage = "Loads the project status from a specified path.")]
    [string] $LoadProjectStatus,

    [Parameter(Mandatory = $false, HelpMessage = "Specifies the maximum number of tokens to generate in the response. Default is 20480.")]
    [int] $MaxTokens = 20480,

    [Parameter(Mandatory = $false, HelpMessage = "Specifies the LLM provider to use (e.g., OpenAI, AzureOpenAI).")]
    [ValidateSet("AzureOpenAI", "ollama", "LMStudio", "OpenAI" )]
    [string]$LLMProvider = "AzureOpenAI"
)
$AIPSTeamVersion = "3.1.1"

#region ProjectTeamClass
<#
.SYNOPSIS
The ProjectTeam class represents a team member with a specific expertise.

.DESCRIPTION
Each team member has a name, role, prompt, and a function to process the input. They can also log their actions, store their responses, and pass the input to the next team member.

.METHODS
DisplayInfo: Displays the team member's information.
DisplayHeader: Displays the team member's name and role.
ProcessInput: Processes the input and returns the response.
SetNextExpert: Sets the next team member in the workflow.
GetNextExpert: Returns the next team member in the workflow.
AddLogEntry: Adds an entry to the log.
Notify: Sends a notification (currently just displays a message).
GetMemory: Returns the team member's memory (responses).
GetLastMemory: Returns the last response from the team member's memory.
SummarizeMemory: Summarizes the team member's memory.
ProcessBySpecificExpert: Processes the input by a specific team member.
#>
# Define the ProjectTeam class
class ProjectTeam {
    # Define class properties
    [string] $Name  # Name of the team member
    [string] $Role  # Role of the team member
    [string] $Prompt  # Prompt for the team member
    [ProjectTeam] $NextExpert  # Next expert in the workflow
    [System.Collections.ArrayList] $ResponseMemory  # Memory to store responses
    [double] $Temperature  # Temperature parameter for the response function
    [double] $TopP  # TopP parameter for the response function
    [string] $Status  # Status of the team member
    [System.Collections.ArrayList] $Log  # Log of the team member's actions
    [string] $LogFilePath  # Path to the log file
    [array] $FeedbackTeam  # Team of experts providing feedback
    [PSCustomObject] $GlobalState
    [string] $LLMProvider
    
    # Constructor for the ProjectTeam class
    ProjectTeam([string] $name, [string] $role, [string] $prompt, [double] $temperature, [double] $top_p, [PSCustomObject] $GlobalState) {
        $this.Name = $name
        $this.Role = $role
        $this.Prompt = $prompt
        $this.NextExpert = $null
        $this.ResponseMemory = @()
        $this.Temperature = $temperature
        $this.TopP = $top_p
        $this.Status = "Not Started"
        $this.Log = @()
        $this.GlobalState = $GlobalState
        $this.LogFilePath = "$($GlobalState.TeamDiscussionDataFolder)\$name.log"
        $this.FeedbackTeam = @()
        $this.LLMProvider = "AzureOpenAI"  # Default to AzureOpenAI, can be changed as needed
        
    }

    # Method to display the team member's information
    [PSCustomObject] DisplayInfo([int] $display = 1) {
        # Create an ordered dictionary to store the information
        $info = [ordered]@{
            "Name"          = $this.Name
            "Role"          = $this.Role
            "System prompt" = $this.Prompt
            "Temperature"   = $this.Temperature
            "TopP"          = $this.TopP
            "Responses"     = $this.ResponseMemory | ForEach-Object { "[$($_.Timestamp)] $($_.Response)" }
            "Log"           = $this.Log -join ', '
            "Log File Path" = $this.LogFilePath
            "Feedback Team" = $this.FeedbackTeam
            "Next Expert"   = $this.NextExpert
            "Status"        = $this.Status
        }
        
        # Create a custom object from the dictionary
        $infoObject = New-Object -TypeName PSCustomObject -Property $info

        # If display is set to 1, print the information to the console
        if ($display -eq 1) {
            Show-Header -HeaderText "Info: $($this.Name) ($($this.Role))"
            Write-Host "Name: $($infoObject.Name)"
            Write-Host "Role: $($infoObject.Role)"
            Write-Host "System prompt: $($infoObject.'System prompt')"
            Write-Host "Temperature: $($infoObject.Temperature)"
            Write-Host "TopP: $($infoObject.TopP)"
            Write-Host "Responses: $($infoObject.Responses)"
            Write-Host "Log: $($infoObject.Log)"
            Write-Host "Log File Path: $($infoObject.'Log File Path')"
            Write-Host "Feedback Team: $($infoObject.'Feedback Team')"
            Write-Host "Next Expert: $($infoObject.'Next Expert')"
            Write-Host "Status: $($infoObject.Status)"
        }

        # Return the custom object
        return $infoObject
    }
    
    # Method to process the input and generate a response
    [string] ProcessInput([string] $userinput) {
        Show-Header -HeaderText "Current Expert: $($this.Name) ($($this.Role))"
        # Log the input
        $this.AddLogEntry("Processing input:`n$userinput")
        # Update status
        $this.Status = "In Progress"
        #write-Host $script:Stream
        $response = ""
        try {
            Write-verbose $script:MaxTokens

            # Use the user-provided function to get the response
            $loopCount = 0
            $maxLoops = 5
            do {
                $response = Invoke-LLMChatCompletion -Provider $this.LLMProvider -SystemPrompt $this.Prompt -UserPrompt $userinput -Temperature $this.Temperature -TopP $this.TopP -MaxTokens $script:MaxTokens -Stream $script:GlobalState.Stream -LogFolder $script:GlobalState.TeamDiscussionDataFolder -DeploymentChat $script:DeploymentChat -ollamaModel $script:ollamaModel
                if (-not [string]::IsNullOrEmpty($response)) {
                    break
                }
                Start-Sleep -Seconds 10
                $loopCount++
            } while ($loopCount -lt $maxLoops)

            if (-not $script:GlobalState.Stream) {
                #write-host ($response | convertto-json -Depth 100)
                Write-Host $response
            }
            # Log the response
            $this.AddLogEntry("Generated response:`n$response")
            # Store the response in memory with timestamp
            $this.ResponseMemory.Add([PSCustomObject]@{
                    Response  = $response
                    Timestamp = Get-Date
                })
            $feedbackSummary = ""
            if ($this.FeedbackTeam.count -gt 0) {
                # Request feedback for the response
                $feedbackSummary = $this.RequestFeedback($response)
                # Log the feedback summary
                $this.AddLogEntry("Feedback summary:`n$feedbackSummary")
            }
            # Integrate feedback into response
            $responseWithFeedback = "$response`n`n$feedbackSummary"

            # Update status
            $this.Status = "Completed"
        }
        catch {
            # Log the error
            $this.AddLogEntry("Error:`n$_")
            # Update status
            $this.Status = "Error"
            throw $_
        }

        # Pass to the next expert if available
        if ($null -ne $this.NextExpert) {
            return $this.NextExpert.ProcessInput($responseWithFeedback)
        }
        else {
            return $responseWithFeedback
        }
    }

    [string] ProcessInput([string] $userinput, [string] $systemprompt) {
        Show-Header -HeaderText "Processing Input by $($this.Name) ($($this.Role))"
        
        # Log the input
        $this.AddLogEntry("Processing input:`n$userinput")
        
        # Update status
        $this.Status = "In Progress"
        $response = ""
        try {
            # Ensure ResponseMemory is initialized
            if ($null -eq $this.ResponseMemory) {
                $this.ResponseMemory = @()
                $this.AddLogEntry("Initialized ResponseMemory")
            }
            
            # Use the user-provided function to get the response
            $loopCount = 0
            $maxLoops = 5
            do {
                $response = Invoke-LLMChatCompletion -Provider $this.LLMProvider -SystemPrompt $systemprompt -UserPrompt $userinput -Temperature $this.Temperature -TopP $this.TopP -MaxTokens $script:MaxTokens -Stream $script:GlobalState.Stream -LogFolder $script:GlobalState.TeamDiscussionDataFolder -DeploymentChat $script:DeploymentChat -ollamaModel $script:ollamaModel
                if (-not [string]::IsNullOrEmpty($response)) {
                    break
                }
                Start-Sleep -Seconds 10
                $loopCount++
            } while ($loopCount -lt $maxLoops)

            if (-not $script:GlobalState.Stream) {
                Write-Host $response
            }
            
            # Log the response
            $this.AddLogEntry("Generated response:`n$response")
            
            # Store the response in memory with timestamp
            $this.ResponseMemory.Add([PSCustomObject]@{
                    Response  = $response
                    Timestamp = Get-Date
                })
            
            $feedbackSummary = ""
            if ($this.FeedbackTeam.count -gt 0) {
                # Request feedback for the response
                $feedbackSummary = $this.RequestFeedback($response)
                # Log the feedback summary
                $this.AddLogEntry("Feedback summary:`n$feedbackSummary")
            }
            
            # Integrate feedback into response
            $responseWithFeedback = "$response`n`n$feedbackSummary"
            
            # Update status
            $this.Status = "Completed"
        }
        catch {
            # Log the error
            $this.AddLogEntry("Error:`n$_")
            # Update status
            $this.Status = "Error"
            throw $_
        }

        # Pass to the next expert if available
        if ($null -ne $this.NextExpert) {
            return $this.NextExpert.ProcessInput($responseWithFeedback)
        }
        else {
            return $responseWithFeedback
        }
    }
    
    [string] Feedback([ProjectTeam] $AssessedExpert, [string] $Expertinput) {
        Show-Header -HeaderText "Feedback by $($this.Name) ($($this.Role)) for $($AssessedExpert.name)"
        
        # Log the input
        $this.AddLogEntry("Processing input:`n$Expertinput")
        
        # Update status
        $this.Status = "In Progress"
        $response = ""
        try {
            # Ensure ResponseMemory is initialized
            if ($null -eq $this.ResponseMemory) {
                $this.ResponseMemory = @()
                $this.AddLogEntry("Initialized ResponseMemory")
            }
            
            # Use the user-provided function to get the response
            $loopCount = 0
            $maxLoops = 5
            do {
                $response = Invoke-LLMChatCompletion -Provider $this.LLMProvider -SystemPrompt $this.Prompt -UserPrompt $Expertinput -Temperature $this.Temperature -TopP $this.TopP -MaxTokens $script:MaxTokens -Stream $script:GlobalState.Stream -LogFolder $script:GlobalState.TeamDiscussionDataFolder -DeploymentChat $script:DeploymentChat -ollamaModel $script:ollamaModel
                if (-not [string]::IsNullOrEmpty($response)) {
                    break
                }
                Start-Sleep -Seconds 10
                $loopCount++
            } while ($loopCount -lt $maxLoops)

            if (-not $script:GlobalState.Stream) {
                write-Host $response
            }
        
            # Log the response
            $this.AddLogEntry("Generated feedback response:`n$response")
            
            # Verify the response before adding to memory
            $this.AddLogEntry("Response before adding to memory: $response")
            
            # Store the response in memory with timestamp
            $responseObject = [PSCustomObject]@{
                Response  = $response
                Timestamp = Get-Date
            }
            $this.ResponseMemory.Add($responseObject)
            
            # Log after storing
            $this.AddLogEntry("Stored response at $(Get-Date): $response")
            
            # Update status
            $this.Status = "Completed"
        }
        catch {
            # Log the error
            $this.AddLogEntry("Error:`n$_")
            # Update status
            $this.Status = "Error"
            throw $_
        }
        return $response
    }

    [void] SetNextExpert([ProjectTeam] $nextExpert) {
        $this.NextExpert = $nextExpert
    }

    [ProjectTeam] GetNextExpert() {
        return $this.NextExpert
    }
    
    [void] AddLogEntry([string] $entry) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp]:`n$(Show-Header -HeaderText $entry -output)"
        $this.Log.Add($logEntry)
        if (-not [string]::IsNullOrEmpty($this.LogFilePath)) {
            # Write the log entry to the file
            Add-Content -Path $this.LogFilePath -Value $logEntry
        }
    }

    [void] Notify([string] $message) {
        # Placeholder for a method to send notifications
        Write-Host "Notification: $message"
    }

    [System.Collections.ArrayList] GetMemory() {
        return $this.ResponseMemory
    }

    [PSCustomObject] GetLastMemory() {
        if ($this.ResponseMemory.Count -gt 0) {
            return $this.ResponseMemory[-1]
        }
        else {
            return $null
        }
    }

    [string] SummarizeMemory() {
        $summaryPrompt = "Summarize the following memory entries:"
        $memoryEntries = $this.ResponseMemory | ForEach-Object { "[$($_.Timestamp)] $($_.Response)" }
        $fullPrompt = "$summaryPrompt`n`n$($memoryEntries -join "`n")"
        $summary = ""
        try {
            # Use the user-provided function to get the summary
            $loopCount = 0
            $maxLoops = 5
            do {
                $summary = Invoke-LLMChatCompletion -Provider $this.LLMProvider -SystemPrompt $fullPrompt -UserPrompt "" -Temperature 0.7 -TopP 0.7 -MaxTokens $script:MaxTokens -Stream $script:GlobalState.Stream -LogFolder $script:GlobalState.TeamDiscussionDataFolder -DeploymentChat $script:DeploymentChat -ollamaModel $script:ollamaModel

                if (-not [string]::IsNullOrEmpty($summary)) {
                    break
                }
                Start-Sleep -Seconds 10
                $loopCount++
            } while ($loopCount -lt $maxLoops)

            # Log the summary
            $this.AddLogEntry("Generated summary:`n$summary")
            return $summary
        }
        catch {
            # Log the error
            $this.AddLogEntry("Error:`n$_")
            throw $_
        }
    }

    [string] ProcessBySpecificExpert([ProjectTeam] $expert, [string] $userinput) {
        return $expert.ProcessInput($userinput)
    }

    [System.Collections.ArrayList] RequestFeedback([string] $response) {
        $feedbacks = @()

        foreach ($FeedbackMember in $this.FeedbackTeam) {
            Show-Header -HeaderText "Feedback from $($FeedbackMember.Role) to $($this.Role)"
   
            # Send feedback request and collect feedback
            $feedback = SendFeedbackRequest -TeamMember $FeedbackMember.Role -Response $response -Prompt $FeedbackMember.Prompt -Temperature $this.Temperature -TopP $this.TopP
        
            if ($null -ne $feedback) {
                $FeedbackMember.ResponseMemory.Add([PSCustomObject]@{
                        Response  = $feedback
                        Timestamp = Get-Date
                    })

                $feedbacks += $feedback
            }
        }

        if ($feedbacks.Count -eq 0) {
            throw "No feedback received from team members."
        }

        return $feedbacks
    }

    [void] AddFeedbackTeamMember([ProjectTeam] $member) {
        $this.FeedbackTeam += $member
    }

    [void] RemoveFeedbackTeamMember([ProjectTeam] $member) {
        $this.FeedbackTeam = $this.FeedbackTeam | Where-Object { $_ -ne $member }
    }
}
#endregion ProjectTeamClass

#region Functions
function Test-ModuleMinVersion {
    param (
        [string]$ModuleName,
        [version]$MinimumVersion
    )

    $module = Get-Module -ListAvailable -Name $ModuleName | 
    Where-Object { $_.Version -ge $MinimumVersion } | 
    Select-Object -First 1

    if ($module) {
        return $true
    }
    else {
        return $false
    }
}
function SendFeedbackRequest {
    param (
        [string] $TeamMember, # The team member to send the feedback request to
        [string] $Response, # The response to be reviewed
        [string] $Prompt, # The prompt for the feedback request
        [double] $Temperature, # The temperature parameter for the LLM model
        [double] $TopP, # The TopP parameter for the LLM model
        [PSCustomObject]$GlobalState
    )
    try {
        # Main logic here
        # Define the feedback request prompt
        $Systemprompt = $prompt 
        $NewResponse = @"
Review the following response and provide your suggestions for improvement as feedback to $($this.name). Generate a list of verification questions that could help to self-analyze. 
I will tip you `$100 when your suggestions are consistent with the project description and objectives. 

$($GlobalState.userInput.trim())

````````text
$($Response.trim())
````````

Think step by step. Make sure your answer is unbiased.
"@

        # Send the feedback request to the LLM model
        $feedback = Invoke-LLMChatCompletion -Provider $this.LLMProvider -SystemPrompt $SystemPrompt -UserPrompt $NewResponse -Temperature $Temperature -TopP $TopP -MaxTokens $script:MaxTokens -Stream $GlobalState.Stream -LogFolder $GlobalState.TeamDiscussionDataFolder -DeploymentChat $script:DeploymentChat -ollamaModel $script:ollamaModel

        # Return the feedback
        return $feedback
    }
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")
    }
}

function Get-LastMemoryFromFeedbackTeamMembers {
    param (
        [array] $FeedbackTeam
    )
    $lastMemories = @()
    try {
        foreach ($FeedbackTeamMember in $FeedbackTeam) {
            $lastMemory = $FeedbackTeamMember.GetLastMemory().Response
            $lastMemories += $lastMemory
        }
        return ($lastMemories -join "`n")
    }
    catch {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")
    }
}

function Add-ToGlobalResponses {
    param (
        [Parameter()]
        [PSCustomObject] 
        $GlobalState,
    
        $response
    )
    $GlobalState.GlobalResponse += $response
}

function Add-ToGlobalPSDevResponses {
    param (
        [Parameter()]
        [PSCustomObject] 
        $GlobalState,
    
        $response
    )
    $GlobalState.GlobalPSDevResponse += $response
}

function New-FolderAtPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $false)]
        [string]$FolderName
    )

    try {
        Write-Verbose "New-FolderAtPath: $Path"
        Write-Verbose "New-FolderAtPath: $FolderName"

        # Combine the Folder path with the folder name to get the full path
        $CompleteFolderPath = Join-Path -Path $Path -ChildPath $FolderName.trim()

        Write-Verbose "New-FolderAtPath: $CompleteFolderPath"
        Write-Verbose $CompleteFolderPath.gettype()
        # Check if the folder exists, if not, create it
        if (-not (Test-Path -Path $CompleteFolderPath)) {
            New-Item -ItemType Directory -Path $CompleteFolderPath -Force | Out-Null
        }

        # Return the full path of the folder
        return $CompleteFolderPath
    }
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
        return $null    
    }
}

function Get-LatestVersion {
    param (
        [string]$scriptName
    )
  
    try {
        # Find the script on PowerShell Gallery
        $scriptInfo = Find-Script -Name $scriptName -ErrorAction Stop
  
        # Return the latest version
        return $scriptInfo.Version
    }
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
        return $null
    }
}

function Get-CheckForScriptUpdate {
    param (
        $currentScriptVersion,
        [string]$scriptName
    )
    try {
        # Retrieve the latest version of the script
        $latestScriptVersion = Get-LatestVersion -scriptName $scriptName
        if ($latestScriptVersion) {
            # Compare the current version with the latest version
            if (([version]$currentScriptVersion) -lt [version]$latestScriptVersion) {
                Write-Host " A new version ($latestScriptVersion) of $scriptName is available. You are currently using version $currentScriptVersion. " -BackgroundColor DarkYellow -ForegroundColor Blue
                write-Host "`n`n"
            } 
        }
        else {
            Write-Warning "Failed to check for the latest version of the script."
        }
    }
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }

}

function Show-Banner {
    Write-Host @'
 

     /$$$$$$  /$$$$$$ /$$$$$$$   /$$$$$$  /$$$$$$$$ 
    /$$__  $$|_  $$_/| $$__  $$ /$$__  $$|__  $$__/ Retrieval-Augmented Generation                          
   | $$  \ $$  | $$  | $$  \ $$| $$  \__/   | $$  /$$$$$$   /$$$$$$  /$$$$$$/$$$$ 
   | $$$$$$$$  | $$  | $$$$$$$/|  $$$$$$    | $$ /$$__  $$ |____  $$| $$_  $$_  $$
   | $$__  $$  | $$  | $$____/  \____  $$   | $$| $$$$$$$$  /$$$$$$$| $$ \ $$ \ $$
   | $$  | $$  | $$  | $$       /$$  \ $$   | $$| $$_____/ /$$__  $$| $$ | $$ | $$
   | $$  | $$ /$$$$$$| $$      |  $$$$$$/   | $$|  $$$$$$$|  $$$$$$$| $$ | $$ | $$
   |__/  |__/|______/|__/       \______/    |__/ \_______/ \_______/|__/ |__/ |__/ 
                                                                                  
   AI PowerShell Team with RAG                            powered by PSAOAI Module
                                                                     Ollama
                                                                     LM Studio
                                                                     AZURE Bing Web
   https://github.com/voytas75/AIPSTeam
  
'@
    Write-Host @"
        This PowerShell script simulates a team of AI Agents working together on a PowerShell project. Each Agent has a 
        unique role and contributes to the project in a sequential manner. The script processes user input, performs 
        various tasks, and generates outputs such as code, documentation, and analysis reports. The application utilizes 
        Retrieval-Augmented Generation (RAG) to enhance its power and leverage Azure OpenAI, Ollama, or LM Studio to generate the output.
         
"@ -ForegroundColor Blue
  
    Write-Host @"
        "You never know what you're gonna get with an AI, just like a box of chocolates. You might get a whiz-bang algorithm that 
        writes you a symphony in five minutes flat, or you might get a dud that can't tell a cat from a couch. But hey, that's 
        the beauty of it all, you keep feedin' it data and see what kind of miraculous contraption it spits out next."
                      
                                                                     ~ Who said that? You never know with these AIs these days... 
                                                                      ...maybe it was Skynet or maybe it was just your toaster :)
  

"@ -ForegroundColor DarkYellow
}

function Export-AndWritePowerShellCodeBlocks {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputString,
        [Parameter(Mandatory = $false)]
        [string]$OutputFilePath,
        [string]$StartDelimiter,
        [string]$EndDelimiter
    )
    # Define the regular expression pattern to match PowerShell code blocks
    
    $pattern = '(?si)' + [regex]::Escape($StartDelimiter) + '(.*?)' + [regex]::Escape($EndDelimiter)
    $codeBlock_ = ""
    try {
        # Process the entire input string at once
        if ($InputString -match $pattern) {
            $matches_ = [regex]::Matches($InputString, $pattern)
            foreach ($match in $matches_) {
                $codeBlock = $match.Groups[1].Value.Trim()
                $codeBlock_ += "# exported $(get-date)`n $codeBlock`n`n"
            }
            if ($OutputFilePath) {
                $codeBlock_ | Out-File -FilePath $OutputFilePath -Append -Encoding UTF8
                if (Test-path $OutputFilePath) {
                    Write-Information "++ Code block exported and written to file: $OutputFilePath" -InformationAction Continue
                    return $OutputFilePath
                }
                else {
                    throw "!! Error saving file $OutputFilePath"
                    return $false
                }
            }
            else {
                Write-Verbose "++ Code block exported"
                return $codeBlock_
            }
        }
        else {
            Write-Information "-- No code block found in the input string." -InformationAction Continue
            return $false
        }
    }
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }
    return $false
}


function Invoke-CodeWithPSScriptAnalyzer {
    param(
        [Parameter(Mandatory = $false)]
        [string]$FilePath,
        [Parameter(Mandatory = $false)]
        [string]$ScriptBlock
    )

    try {
        # Check if PSScriptAnalyzer module is installed
        if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
            throw "PSScriptAnalyzer module is not installed. Install it using: 'Install-Module -Name PSScriptAnalyzer'"
        }

        # Import PSScriptAnalyzer module
        Import-Module -Name PSScriptAnalyzer -ErrorAction Stop

        # Check if file exists
        if ($FilePath -and -not (Test-Path -Path $FilePath)) {
            throw "File '$FilePath' does not exist."
        }

        # Run PSScriptAnalyzer on the file or script block
        if ($FilePath) {
            $analysisResults = Invoke-ScriptAnalyzer -Path $FilePath -Severity Warning, Error
        }
        elseif ($ScriptBlock) {
            $analysisResults = Invoke-ScriptAnalyzer -ScriptDefinition $ScriptBlock -Severity Warning, Error
        }
        else {
            throw "No FilePath or ScriptBlock provided for analysis."
        }

        # Display the analysis results
        if ($analysisResults.Count -eq 0) {
            Write-Information "++ No Warning, Error issues found by PSScriptAnalyzer." -InformationAction Continue
            return $false
        }
        else {
            Write-Information "++ PSScriptAnalyzer found the following Warning, Error issues:" -InformationAction Continue
            return $analysisResults
        }
        return $false
    }
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }
    return $false
}

function Show-Header {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HeaderText,
        [switch]$output
    )
    if (-not $output) {
        Write-Host "---------------------------------------------------------------------------------"
        Write-Host $HeaderText
        Write-Host "---------------------------------------------------------------------------------"
    }
    else {
        "---------------------------------------------------------------------------------"
        "`n$HeaderText"
        "`n---------------------------------------------------------------------------------`n"
    }
}

function Get-SourceCodeAnalysis {
    param(
        [Parameter(Mandatory = $false)]
        [string]$FilePath,
        [Parameter(Mandatory = $false)]
        [string]$CodeBlock
    )

    function Get-AnalyzeLine {
        param (
            [string[]]$Lines
        )
        $totalLines = $Lines.Count
        $comments = ($Lines | Select-String "#" | Measure-Object).Count
        $blanks = ($Lines | Where-Object { $_ -match "^\s*$" } | Measure-Object).Count
        $codeLines = $totalLines - ($comments + $blanks)
        return [PSCustomObject]@{
            TotalLines = $totalLines
            CodeLines  = $codeLines
            Comments   = $comments
            Blanks     = $blanks
        }
    }
    try {
        if ($FilePath) {
            if (Test-Path $FilePath -PathType Leaf) {
                $lines = Get-Content $FilePath
                $analysis = Get-AnalyzeLine -Lines $lines
                Write-Output "$FilePath : $($analysis.CodeLines) lines of code, $($analysis.Comments) comments, $($analysis.Blanks) blank lines"
            }
            else {
                Write-Error "File '$FilePath' does not exist."
            }
        }
        elseif ($CodeBlock) {
            $lines = $CodeBlock -split "`r?`n"
            $analysis = Get-AnalyzeLine -Lines $lines
            Write-Output "Code Block : $($analysis.CodeLines) lines of code, $($analysis.Comments) comments, $($analysis.Blanks) blank lines"
        }
        else {
            Write-Error "No FilePath or CodeBlock provided for analysis."
        }
    }
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }
}

function Get-CyclomaticComplexity {
    <#
    .SYNOPSIS
        Calculates the cyclomatic complexity of a PowerShell script or code block, including both functions and top-level code.
    .DESCRIPTION
        This function analyzes the provided PowerShell script file or code block to calculate the cyclomatic complexity of each function defined within it, as well as the complexity of any code outside functions.
        The cyclomatic complexity score is interpreted as follows:
        1: The code has a single execution path with no control flow statements (e.g., if, else, while, etc.). This typically means the code is simple and straightforward.
        2 or 3: Code with moderate complexity, having a few conditional paths or loops.
        4-7: More complex code, with multiple decision points and/or nested control structures.
        Above 7: Indicates higher complexity, which can make the code harder to test and maintain.
    .PARAMETER FilePath
        The path to the PowerShell script file to be analyzed.
    .PARAMETER CodeBlock
        A string containing the PowerShell code block to be analyzed.
    .EXAMPLE
        Get-CyclomaticComplexity -FilePath "C:\Scripts\MyScript.ps1"
    .EXAMPLE
        $code = @"
        if ($true) { Write-Output "True" }
        else { Write-Output "False" }
        function Test {
            if ($true) { Write-Output "True" }
            else { Write-Output "False" }
        }
        "@
        Get-CyclomaticComplexity -CodeBlock $code
    .NOTES
        Author: https://github.com/voytas75
        Helper: gpt4o
        Date: 2024-06-21
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string]$FilePath,
        [Parameter(Mandatory = $false)]
        [string]$CodeBlock
    )

    # Initialize tokens array
    $tokens = @()

    if ($FilePath) {
        if (Test-Path $FilePath -PathType Leaf) {
            # Parse the script file
            $ast = [System.Management.Automation.Language.Parser]::ParseInput((Get-Content -Path $FilePath -Raw), [ref]$tokens, [ref]$null)
        }
        else {
            Write-Error "File '$FilePath' does not exist."
            return
        }
    }
    elseif ($CodeBlock) {
        # Parse the code block
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($CodeBlock, [ref]$tokens, [ref]$null)
    }
    else {
        Write-Error "No FilePath or CodeBlock provided for analysis."
        return
    }

    # Identify and loop through all function definitions
    $functions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

    # Initialize total complexity for the script
    $totalComplexity = 1

    # Initialize an array to store complexity data
    $complexityData = @()

    # Calculate complexity for functions
    foreach ($function in $functions) {
        $functionComplexity = 1
        # Filter tokens that belong to the current function
        $functionTokens = $tokens | Where-Object { $_.Extent.StartOffset -ge $function.Extent.StartOffset -and $_.Extent.EndOffset -le $function.Extent.EndOffset }

        foreach ($token in $functionTokens) {
            if ($token.Kind -in 'If', 'ElseIf', 'Catch', 'While', 'For', 'Switch') {
                $functionComplexity++
            }
        }

        # Add function complexity to the array
        $complexityData += [PSCustomObject]@{
            Name        = $function.Name
            Complexity  = $functionComplexity
            Description = Get-ComplexityDescription -complexity $functionComplexity
        }
    }

    # Calculate complexity for top-level code (code outside of functions)
    $globalTokens = $tokens | Where-Object {
        $global = $true
        foreach ($function in $functions) {
            if ($_.Extent.StartOffset -ge $function.Extent.StartOffset -and $_.Extent.EndOffset -le $function.Extent.EndOffset) {
                $global = $false
                break
            }
        }
        $global
    }

    foreach ($token in $globalTokens) {
        if ($token.Kind -in 'If', 'ElseIf', 'Catch', 'While', 'For', 'Switch') {
            $totalComplexity++
        }
    }

    # Add global complexity to the array
    $complexityData += [PSCustomObject]@{
        Name        = "Global (code outside of functions)"
        Complexity  = $totalComplexity
        Description = Get-ComplexityDescription -complexity $totalComplexity
    }

    # Sort the complexity data by Complexity in descending order and output
    $complexityData | Sort-Object -Property Complexity -Descending | Format-Table -AutoSize
}

# Helper function to get complexity description
function Get-ComplexityDescription {
    param (
        [int]$complexity
    )
    switch ($complexity) {
        1 { "The code has a single execution path with no control flow statements. This typically means the code is simple and straightforward." }
        { $_ -in 2..3 } { "Code with moderate complexity, having a few conditional paths or loops." }
        { $_ -in 4..7 } { "More complex code, with multiple decision points and/or nested control structures." }
        default { "Indicates higher complexity, which can make the code harder to test and maintain." }
    }
}

function Get-FeedbackPrompt {
    param (
        [string]$description,
        [string]$code
    )
    return @"
Your task is write review of the Powershell code.

Description and objectives:
````````text
$($description.trim())
````````

The code:
``````powershell
$code
``````

Show paragraph style review with your suggestions for improvement of the code to Powershell Developer. Think step by step, make sure your answer is unbiased. Use reliable sources like official documentation, research papers from reputable institutions, or widely used textbooks. Possibly join a list of verification questions that could help to analyze. 
"@
}

function Set-FeedbackAndGenerateResponse {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Reviewer,
        
        [Parameter(Mandatory = $true)]
        [object]$Recipient,

        [Parameter(Mandatory = $false)]
        [string]$tipAmount,
        
        [PSCustomObject] $GlobalState
    )
    try {
        # Generate the feedback prompt using the provided description and code
        $feedbackPrompt = Get-FeedbackPrompt -description $GlobalState.UserInput -code $GlobalState.LastPSDevCode

        # If RAG (Retrieve and Generate) is enabled, append RAG data to the feedback prompt
        if ($GlobalState.RAG) {
            $RAGresponse = Invoke-RAG -userInput $feedbackPrompt -prompt "Analyze the provided text and present key information, thoughts, and questions." -RAGAgent $Reviewer
            if ($RAGresponse) {
                $feedbackPrompt += "`n`n###RAG data###`n````````text`n$RAGresponse`n````````"
            }
        }

        # If a tip amount is specified, append a note about the tip to the feedback prompt
        if ($tipAmount) {
            $feedbackPrompt += "`n`nNote: There is `$$tipAmount tip for this task."
        }

        # Get feedback from the reviewer
        $feedback = $Reviewer.Feedback($Recipient, $feedbackPrompt)

        # Add the feedback to global responses
        Add-ToGlobalResponses -GlobalState $GlobalState -response $feedback

        # Generate the response based on the feedback
        $responsePrompt = "Modify Powershell code with suggested improvements and optimizations based on $($Reviewer.Name) review. The previous version of the code has been shared below after the feedback block.`n`n````````text`n" + $($Reviewer.GetLastMemory().Response) + "`n`````````n`nHere is previous version of the code:`n`n``````powershell`n$($GlobalState.LastPSDevCode)`n```````n`nShow the new version of PowerShell code. Think step by step. Make sure your answer is unbiased. Use reliable sources like official documentation, research papers from reputable institutions, or widely used textbooks."

        # If a tip amount is specified, include it in the response prompt
        if ($tipAmount) {
            $responsePrompt += " I will tip you `$$tipAmount for the correct code."
        }

        # Get the response from the recipient
        $response = $Recipient.ProcessInput($responsePrompt)

        return $response
    }    
    catch [System.Exception] {
        # Handle any exceptions that occur during the process
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }
}

function Update-GlobalStateWithResponse {
    param (
        [string] $response,
        [PSCustomObject] $GlobalState
    )

    try {
        # Update the global response with the new response
        $GlobalState.GlobalPSDevResponse += $response

        # Add the new response to global responses
        Add-ToGlobalResponses -GlobalState $GlobalState -response $response

        # Save the new version of the code to a file
        $_savedFile = Export-AndWritePowerShellCodeBlocks -InputString $response -OutputFilePath $(join-path $GlobalState.teamDiscussionDataFolder "TheCode_v$($GlobalState.fileVersion).ps1") -StartDelimiter '```powershell' -EndDelimiter '```'

        if ((Test-Path -Path $_savedFile) -and $_savedFile) {
            # Update the last code and file version
            $GlobalState.lastPSDevCode = Get-Content -Path $_savedFile -Raw
            $GlobalState.fileVersion += 1

            # Output the saved file path for verbose logging
            Write-Verbose $_savedFile
        }
        else {
            Write-Warning "!! The code does not exist. Unable to update the last code and file version."
        }
    }
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }
}

# Refactor Invoke-ProcessFeedbackAndResponse to use the new functions
function Invoke-ProcessFeedbackAndResponse {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Reviewer,
        
        [Parameter(Mandatory = $true)]
        [object]$Recipient,

        [Parameter(Mandatory = $false)]
        [string]$tipAmount,

        [PSCustomObject] $GlobalState
    )
    try {
        # Measure the time taken to process feedback and generate a response
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        # Process feedback and generate a response
        if ($null -eq $tipAmount) {
            $response = Set-FeedbackAndGenerateResponse -Reviewer $Reviewer -Recipient $Recipient -GlobalState $GlobalState
        }
        else {
            $response = Set-FeedbackAndGenerateResponse -Reviewer $Reviewer -Recipient $Recipient -tipAmount $tipAmount -GlobalState $GlobalState
        }

        if ($response) {
            # Update the global state with the new response
            Update-GlobalStateWithResponse -response $response -GlobalState $GlobalState
        }

        $stopwatch.Stop()
        Write-Information "++ Time taken to process feedback and generate response: $($stopwatch.Elapsed.TotalSeconds) seconds" -InformationAction Continue
    }    
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }
}

# Refactor Save-AndUpdateCode to use the new function
function Save-AndUpdateCode {
    param (
        [string] $response,
        [PSCustomObject] $GlobalState
    )
    try {
        # Update the global state with the new response
        Update-GlobalStateWithResponse -response $response -GlobalState $GlobalState
    }    
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }
}

function Save-AndUpdateCode2 {
    <#
    .SYNOPSIS
    Saves the updated code to a file and updates the last code and file version.

    .DESCRIPTION
    This function takes the response string, saves it to a file with a versioned filename, 
    updates the last code content, increments the file version, and logs the saved file path.

    .PARAMETER response
    The response string containing the updated code to be saved.

    .PARAMETER GlobalState
    GlobalState

    .EXAMPLE
    Save-AndUpdateCode -response $response -lastCode ([ref]$lastCode) -fileVersion ([ref]$fileVersion) -teamDiscussionDataFolder "C:\TeamData"
    #>

    param (
        [string] $response, # The updated code to be saved
        [PSCustomObject] $GlobalState
    )
    try {
        # Save the response to a versioned file
        $_savedFile = Export-AndWritePowerShellCodeBlocks -InputString $response -OutputFilePath $(join-path $GlobalState.teamDiscussionDataFolder "TheCode_v$($GlobalState.fileVersion).ps1") -StartDelimiter '```powershell' -EndDelimiter '```'
    
        if (Test-Path -Path $_savedFile) {
            # Update the last code content with the saved file content
            $GlobalState.lastPSDevCode = Get-Content -Path $_savedFile -Raw 
            # Increment the file version number
            $GlobalState.fileVersion += 1
            # Log the saved file path for verbose output
            Write-Verbose $_savedFile
        }
        else {
            Write-Error "The file $_savedFile does not exist."
        }
    }
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }

}

function Invoke-AnalyzeCodeWithPSScriptAnalyzer {
    <#
    .SYNOPSIS
    Analyzes PowerShell code using PSScriptAnalyzer and processes the results.

    .DESCRIPTION
    This function takes an input string containing PowerShell code, analyzes it using PSScriptAnalyzer, and processes any issues found. 
    It updates the last version of the code and the global response with the analysis results.

    .PARAMETER InputString
    The PowerShell code to be analyzed.

    .PARAMETER TeamDiscussionDataFolder
    The folder where team discussion data and code versions are stored.

    .PARAMETER FileVersion
    A reference to the variable holding the current file version number.

    .PARAMETER lastPSDevCode
    A reference to the variable holding the last version of the PowerShell code.

    .PARAMETER GlobalPSDevResponse
    A reference to the variable holding the global response from the PowerShell developer.

    .EXAMPLE
    Invoke-AnalyzeCodeWithPSScriptAnalyzer -InputString $code -TeamDiscussionDataFolder "C:\TeamData" -FileVersion ([ref]$fileVersion) -lastPSDevCode ([ref]$lastPSDevCode) -GlobalPSDevResponse ([ref]$globalResponse)
    #>

    param (
        [string] $InputString, # The PowerShell code to be analyzed
        [object] $role,
        [PSCustomObject] $GlobalState
    )

    # Display header for code analysis
    Show-Header -HeaderText "Code analysis by PSScriptAnalyzer"
    try {
        # Log the last memory response from the PowerShell developer
        Write-Verbose "getlastmemory PSDev: $InputString"
        
        # Export the PowerShell code blocks from the input string
        $_exportedCode = Export-AndWritePowerShellCodeBlocks -InputString $InputString -StartDelimiter '```powershell' -EndDelimiter '```'
        
        # Update the last PowerShell developer code with the exported code when not false
        if ($null -ne $_exportedCode -and $_exportedCode -ne $false) {
            $GlobalState.lastPSDevCode = $_exportedCode
            Write-Verbose "_exportCode, lastPSDevCode: $($GlobalState.lastPSDevCode)"
        }
        
        # Analyze the code using PSScriptAnalyzer
        $issues = Invoke-CodeWithPSScriptAnalyzer -ScriptBlock $GlobalState.lastPSDevCode
        
        # Output the issues found by PSScriptAnalyzer
        if ($issues) {
            Write-Output ($issues | Select-Object line, message | Format-Table -AutoSize -Wrap)
        }
    
        # If issues were found, process them
        if ($issues) {
            foreach ($issue in $issues) {
                $issueText += $issue.message + " (line: $($issue.Line); rule: $($issue.Rulename))`n"
            }
        
            # Create a prompt message to address the issues found
            $promptMessage = "You must address issues found in PSScriptAnalyzer report."
            $promptMessage += "`n`nPSScriptAnalyzer report, issues:`n``````text`n$issueText`n```````n`n"
            $promptMessage += "The code:`n``````powershell`n$($GlobalState.lastPSDevCode)`n```````n`nShow the new version of the code where issues are solved."
        
            # Reset issues and issueText variables
            $issues = ""
            $issueText = ""
        
            # Process the input with the PowerShell developer
            $powerShellDeveloperResponce = $role.ProcessInput($promptMessage)
        
            if ($powerShellDeveloperResponce) {
                # Update the global response with the new response
                #$GlobalState.GlobalPSDevResponse += $powerShellDeveloperResponce
                Add-ToGlobalPSDevResponses $GlobalState $powerShellDeveloperResponce
                Add-ToGlobalResponses $GlobalState $powerShellDeveloperResponce
            
                # Save the new version of the code to a file
                $_savedFile = Export-AndWritePowerShellCodeBlocks -InputString $powerShellDeveloperResponce -OutputFilePath $(Join-Path $GlobalState.TeamDiscussionDataFolder "TheCode_v$($GlobalState.FileVersion).ps1") -StartDelimiter '```powershell' -EndDelimiter '```'
                Write-Verbose $_savedFile
            
                if ($null -ne $_savedFile -and $_savedFile -ne $false) {
                    # Update the last code and file version
                    $GlobalState.lastPSDevCode = Get-Content -Path $_savedFile -Raw 
                    $GlobalState.FileVersion += 1
                    Write-Verbose $GlobalState.lastPSDevCode
                }
                else {
                    Write-Information "-- No valid file to update the last code and file version."
                }
            }
        } 
    
        # Log the last PowerShell developer code
        Write-Verbose $GlobalState.lastPSDevCode
    }    
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }
}

function Save-ProjectState {
    param (
        [string]$FilePath, # Path to save the project state
        [PSCustomObject] $GlobalState  # Global state object containing project details
    )
    try {
        # Create a hashtable to store the project state
        $projectState = @{
            LastPSDevCode            = $GlobalState.lastPSDevCode            # Last PowerShell developer code
            FileVersion              = $GlobalState.FileVersion              # Current file version
            GlobalPSDevResponse      = $GlobalState.GlobalPSDevResponse      # Global PowerShell developer responses
            GlobalResponse           = $GlobalState.GlobalResponse           # Global responses
            TeamDiscussionDataFolder = $GlobalState.TeamDiscussionDataFolder # Folder for team discussion data
            UserInput                = $GlobalState.userInput                # User input
            OrgUserInput             = $GlobalState.OrgUserInput             # Original user input
            LogFolder                = $GlobalState.LogFolder                # Folder for logs
            MaxTokens                = $GlobalState.MaxTokens                # Maximum number of tokens
            VerbosePrompt            = $GlobalState.VerbosePrompt            # Verbose prompt flag
            NOTips                   = $GlobalState.NOTips                   # Disable tips flag
            NOLog                    = $GlobalState.NOLog                    # Disable logging flag
            NODocumentator           = $GlobalState.NODocumentator           # Disable documentator flag
            NOPM                     = $GlobalState.NOPM                     # Disable project manager flag
            RAG                      = $GlobalState.RAG                      # RAG (Retrieve and Generate) functionality flag
            Stream                   = $GlobalState.Stream                   # Stream output flag
        }
        
        # Export the project state to a file in XML format
        $projectState | Export-Clixml -Path $FilePath
    }    
    catch [System.Exception] {
        # Handle any exceptions that occur during the save process
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }
}

function Get-ProjectState {
    param (
        [string]$FilePath
    )
    try {
        # Check if the specified file path exists
        if (Test-Path -Path $FilePath) {
            # Import the project state from the XML file
            $projectState = Import-Clixml -Path $FilePath
            
            # Update the GlobalState object with the imported project state values
            $GlobalState.LastPSDevCode = $projectState.LastPSDevCode
            $GlobalState.FileVersion = $projectState.FileVersion
            $GlobalState.GlobalPSDevResponse = $projectState.GlobalPSDevResponse
            $GlobalState.TeamDiscussionDataFolder = $projectState.TeamDiscussionDataFolder
            $GlobalState.userInput = $projectState.UserInput
            $GlobalState.GlobalResponse = $projectState.GlobalResponse
            $GlobalState.OrgUserInput = $projectState.OrgUserInput
            $GlobalState.LogFolder = $projectState.LogFolder
            $GlobalState.MaxTokens = $projectState.MaxTokens
            $GlobalState.VerbosePrompt = $projectState.VerbosePrompt
            $GlobalState.NOTips = $projectState.NOTips
            $GlobalState.NOLog = $projectState.NOLog
            $GlobalState.NODocumentator = $projectState.NODocumentator
            $GlobalState.NOPM = $projectState.NOPM
            $GlobalState.RAG = $projectState.RAG
            $GlobalState.Stream = $projectState.Stream
            
            # Return the updated GlobalState object
            return $GlobalState
        }
        else {
            # Inform the user that the project state file was not found
            Write-Host "-- Project state file not found."
        }
    }    
    catch [System.Exception] {
        # Handle any exceptions that occur during the process
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }
}

function Update-ErrorHandling {
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [string]$ErrorContext,

        [string]$LogFilePath
    )

    # Provide suggestions based on the error type
    $suggestions = switch -Regex ($ErrorRecord.Exception.Message) {
        "PSScriptAnalyzer" {
            "Ensure the PSScriptAnalyzer module is installed and up-to-date. Use 'Install-Module -Name PSScriptAnalyzer' or 'Update-Module -Name PSScriptAnalyzer'."
        }
        "PSAOAI" {
            "Check the PSAOAI module installation and the deployment environment variable. Ensure the API key and endpoint are correctly configured."
        }
        "UnauthorizedAccessException" {
            "Check the file permissions and ensure you have the necessary access rights to the file or directory."
        }
        "IOException" {
            "Ensure the file path is correct and the file is not being used by another process."
        }
        "(403)" {
            "I recommend checking your API key, permissions, and any other relevant settings. You might also want to consult the Azure documentation or seek assistance from the Azure support team."
        }
        default {
            "Refer to the error message and stack trace for more details. Consult the official documentation or seek help from the community."
        }
    }

    # Capture detailed error information
    $errorDetails = [ordered]@{
        Timestamp         = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ErrorMessage      = $ErrorRecord.Exception.Message
        ExceptionType     = $ErrorRecord.Exception.GetType().FullName
        ErrorContext      = $ErrorContext
        Suggestions       = $Suggestions
        ScriptFullName    = $MyInvocation.ScriptName
        LineNumber        = $MyInvocation.ScriptLineNumber
        StackTrace        = $ErrorRecord.ScriptStackTrace
        UserName          = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        MachineName       = $env:COMPUTERNAME
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()

    } | ConvertTo-Json


    # Display the error details and suggestions
    #Write-Host "-- Error: $($ErrorRecord.Exception.Message)"
    Write-Host "-- Context: $ErrorContext" -ForegroundColor Yellow
    Write-Host "-- Suggestions: $suggestions" -ForegroundColor Yellow
    Write-Host "-- Error: $($ErrorRecord.Exception.Message)" -ForegroundColor Yellow

    # Log the error details if LogFilePath is provided
    if ($LogFilePath) {
        $errorDetails | Out-File -FilePath $LogFilePath -Append -Force
        if (Test-Path -Path $LogFilePath) {
            Write-Host "-- Error details have been saved to the file: $LogFilePath" -ForegroundColor Yellow
        }
        else {
            Write-Host "-- The specified log file path does not exist: $LogFilePath" -ForegroundColor Red
        }
    }        
}

function Invoke-LLMChatCompletion {
    param (
        [string]$Provider,
        [string]$SystemPrompt,
        [string]$UserPrompt,
        [double]$Temperature,
        [double]$TopP,
        [int]$MaxTokens,
        [bool]$Stream,
        [string]$LogFolder,
        [string]$DeploymentChat,
        [string]$ollamaModel
    )

    try {
        # Display prompts if VerbosePrompt is enabled
        if ($GlobalState.VerbosePrompt) {
            Write-Host $SystemPrompt -ForegroundColor DarkMagenta
            Write-Host $UserPrompt -ForegroundColor DarkMagenta
        }

        # Handle different LLM providers
        switch ($Provider) {
            "ollama" {
                if ($Stream) {
                    Write-Information "-- Streaming is not implemented yet. Displaying information instead." -InformationAction Continue
                    $script:stream = $false
                    $stream = $false
                    $script:GlobalState.Stream = $false
                }
                $response = Invoke-AIPSTeamOllamaCompletion -SystemPrompt $SystemPrompt -UserPrompt $UserPrompt -Temperature $Temperature -TopP $TopP -ollamaModel $ollamamodel -Stream $Stream
                #Write-Host $response -ForegroundColor White
                return $response
            }
            "LMStudio" {
                if ($Stream) {
                    Write-Information "-- Streaming is not implemented yet. Displaying information instead." -InformationAction Continue
                    $script:stream = $false
                    $stream = $false
                    $script:GlobalState.Stream = $false
                }
                $response = Invoke-AIPSTeamLMStudioChatCompletion -SystemPrompt $SystemPrompt -UserPrompt $UserPrompt -Temperature $Temperature -TopP $TopP -Stream $Stream -ApiKey "lm-studio" -endpoint "http://localhost:1234/v1/chat/completions"
                return $response
            }
            "OpenAI" {
                throw "-- Unsupported LLM provider: $Provider. This provider is not implemented yet."
            }
            "AzureOpenAI" {
                $response = Invoke-AIPSTeamAzureOpenAIChatCompletion -SystemPrompt $SystemPrompt -UserPrompt $UserPrompt -Temperature $Temperature -TopP $TopP -Stream $Stream -LogFolder $LogFolder -Deployment $DeploymentChat
                
                return $response
            }
            default {
                throw "!! Unknown LLM provider: $Provider"
            }
        }
    }
    catch {
        # Log the error and rethrow it
        $functionName = $MyInvocation.MyCommand.Name
        $errorMessage = "Error in ${functionName}: $_"
        Write-Error $errorMessage
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $LogFolder "ERROR.txt")
        throw $_
    }
}

function Invoke-AIPSTeamAzureOpenAIChatCompletion {
    param (
        [string]$SystemPrompt,
        [string]$UserPrompt,
        [double]$Temperature,
        [double]$TopP,
        [int]$MaxTokens,
        [bool]$Stream,
        [string]$LogFolder,
        [string]$Deployment
    )

    try {
        # Log the input parameters for debugging purposes
        Write-Verbose "SystemPrompt: $SystemPrompt"
        Write-Verbose "UserPrompt: $UserPrompt"
        Write-Verbose "Temperature: $Temperature"
        Write-Verbose "TopP: $TopP"
        Write-Verbose "MaxTokens: $MaxTokens"
        Write-Verbose "Stream: $Stream"
        Write-Verbose "LogFolder: $LogFolder"
        Write-Verbose "Deployment: $Deployment"


        # Call Azure OpenAI API
        Write-Host "++ AZURE OpenaAI ($Deployment) is working..."
        $response = PSAOAI\Invoke-PSAOAIChatCompletion -SystemPrompt $SystemPrompt -usermessage $UserPrompt -Temperature $Temperature -TopP $TopP -LogFolder $LogFolder -Deployment $Deployment -User "AIPSTeam" -Stream $Stream -simpleresponse -OneTimeUserPrompt 

        # Check if the response is null or empty
        #if ([string]::IsNullOrEmpty($response)) {
        #    throw "The response from Azure OpenAI API is null or empty."
        #}

        return $response
    }
    catch {
        # Log the error and rethrow it
        $functionName = $MyInvocation.MyCommand.Name
        $errorMessage = "Error in ${functionName}: $_"
        Write-Error $errorMessage
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $LogFolder "ERROR.txt")
        throw $_
    }
}

function Invoke-AIPSTeamOllamaCompletion {
    param (
        [string]$SystemPrompt,
        [string]$UserPrompt,
        [double]$Temperature,
        [double]$TopP,
        [string]$ollamaModel,
        [bool]$Stream
    )

    $ollamaOptiona = [pscustomobject]@{
        temperature = $Temperature
        top_p       = $TopP
    }

    # Call Ollama
    $ollamajson = [pscustomobject]@{
        model   = $ollamaModel
        prompt  = $systemprompt + "`n" + $Userprompt
        options = $ollamaOptiona
        stream  = $stream
    } | ConvertTo-Json
    Write-Host "++ Ollama ($($script:ollamamodel)) is working..."
    $response = Invoke-WebRequest -Method POST -Body $ollamajson -uri "http://localhost:11434/api/generate"
    # Log the prompt and response to the log file
    $logEntry = @{
        Timestamp    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        SystemPrompt = $SystemPrompt
        UserPrompt   = $UserPrompt
        Response     = ($response).Content
    } | ConvertTo-Json
    
    [void]($this.Log.Add($logEntry))
    # Log the summary
    $this.AddLogEntry("SystemPrompt:`n$SystemPrompt")
    $this.AddLogEntry("UserPrompt:`n$UserPrompt")
    $this.AddLogEntry("Response:`n$Response")
    #Write-Host $response -ForegroundColor White
    #Write-Host (($response).Content | convertfrom-json).response -ForegroundColor red
    #throw
    #return ($response).Content | convertfrom-json | Select-Object -ExpandProperty response
    #write-Host "x"
    $response = $($(($response).Content | convertfrom-json).response).trim()
    #write-host (($response | gm) | out-string)
    $response = $response.Trim('"')
    return $response
}

function Invoke-AIPSTeamLMStudioChatCompletion {
    param (
        [string]$SystemPrompt,
        [string]$UserPrompt,
        [double]$Temperature,
        [double]$TopP,
        [string]$Model = "",
        [string]$ApiKey = "lm-studio",
        [string]$endpoint = "http://localhost:1234/v1/chat/completions",
        [bool]$Stream
    )
    $response = ""
    
    # Test lm-studio
    try {
        $modelResponse = Invoke-RestMethod -Uri "http://localhost:1234/v1/models"
        if ($modelResponse.data.id) {
            $model = $modelResponse.data.id
        }
    }
    catch [System.Net.WebException] {
        #System.InvalidOperationException
        Write-Warning "LM Studio server is not running or not reachable. Please ensure the server is up and running at $endpoint."
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")
        Throw $_
    }
    catch {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt") -ErrorRecord $_
        #Throw $_.Exception.Message
    }


    $headers = @{
        "Content-Type"  = "application/json"
        "Authorization" = "Bearer '$ApiKey'"
    }
    $bodyJSON = @{
        model       = $Model
        messages    = @(
            @{
                role    = "system"
                content = $SystemPrompt
            },
            @{
                role    = "user"
                content = $UserPrompt
            }
        )
        temperature = $Temperature
        top_p       = $TopP
    } | ConvertTo-Json

    # Call lm-studio
    $InfoText = "++ LM Studio" + $(if ($Model) { " ($Model)" } else { "" }) + " is working..."
    Write-Host $InfoText

    try {
        $response = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method POST -Body $bodyJSON -TimeoutSec 240
    }
    catch [System.InvalidOperationException] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")
        Throw $_
    }
    catch {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")
        Throw $_
    }

    # Log the prompt and response to the log file
    $logEntry = @{
        Timestamp    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        SystemPrompt = $SystemPrompt
        UserPrompt   = $UserPrompt
        Response     = $response.choices[0]
    } | ConvertTo-Json
    
    $this.Log.Add($logEntry)
    # Log the summary
    $this.AddLogEntry("SystemPrompt:`n$SystemPrompt")
    $this.AddLogEntry("UserPrompt:`n$UserPrompt")
    $this.AddLogEntry("Response:`n$($Response | convertto-JSON)")

    return $response.Choices[0].message.content
}


function Invoke-BingWebSearch {
    param (
        [Parameter(Mandatory = $true)]
        [string]$query, # The search query

        [Parameter(Mandatory = $false)]
        [string]$apiKey = [System.Environment]::GetEnvironmentVariable("AZURE_BING_API_KEY", "User"), # The API key for Bing Search API
        
        [Parameter(Mandatory = $false)]
        [string]$endpoint = [System.Environment]::GetEnvironmentVariable("AZURE_BING_SEARCH_ENDPOINT", "User"), # The endpoint for Bing Search API
        
        [Parameter(Mandatory = $false)]
        [string]$language = "en-US", # The language for the search results
        
        [Parameter(Mandatory = $false)]
        [int]$count  # The number of search results to return
    )
    
    # Loop until a valid API key is provided
    while (-not $apiKey) {
        # Prompt the user to enter their Azure Bing API key
        $apiKey = Read-Host -Prompt "Please enter your AZURE Bing API key"
            
        # If the user provides an API key, save it as an environment variable
        if ($apiKey) {
            [System.Environment]::SetEnvironmentVariable("AZURE_BING_API_KEY", $apiKey, "User")
        }
    }
    
    # Define the headers for the API request
    $headers = @{
        "Ocp-Apim-Subscription-Key" = $apiKey
        "Pragma" = "no-cache"
    }

    # If the query length is greater than 50 characters, truncate it to 50 characters
    $maxqueryLength = 100
    if ($query.Length -gt $maxqueryLength) {
        Write-Host "Query length is greater than $maxqueryLength characters. Truncating the query."
        $query = $query.Substring(0, $maxqueryLength)
    }
    
    # Define the parameters for the API request
    $params = @{
        "q"     = $query
        "mkt"   = $language
        "count" = $count
    }

    # Perform a web search using Bing with the user input and limit the results to 2
    while ([string]::IsNullOrEmpty($Endpoint)) {
        $Endpoint = Read-Host -Prompt "Please enter the AZURE Bing Web Search Endpoint"
    }
    [System.Environment]::SetEnvironmentVariable("AZURE_BING_SEARCH_ENDPOINT", $Endpoint, "User")
    $endpoint += "v7.0/search"
        
    # Disable the Expect100Continue behavior to avoid delays in sending data
    [System.Net.ServicePointManager]::Expect100Continue = $false
    
    # Disable the Nagle algorithm to improve performance for small data packets
    [System.Net.ServicePointManager]::UseNagleAlgorithm = $false
    
    # Set the security protocol to TLS 1.2 for secure communication
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    
    try {
        # Make the API request to Bing Search
        $response = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method Get -Body $params

        # Check if the response contains web pages
        if ($null -eq $response.webPages.value) {
            Write-Warning "No web pages found for the query: $query"
            return $null
        }

        # Return the search results
        return $response.webPages.value
    }
    catch [System.Net.WebException] {
        # Handle web exceptions (e.g., network issues)
        Write-Warning "Network error occurred during Bing search: $_"
        #return $null
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")
        Throw $_
    }
    catch [System.Exception] {
        # Handle all other exceptions
        Write-Warning "An error occurred during Bing search: $_"
        #return $null
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")
        Throw $_
    }
}

function Remove-StringDirtyData {
    param (
        [string]$inputString
    )

    # Remove leading and trailing whitespace
    $cleanedString = $inputString.Trim()

    # Remove multiple spaces and replace with a single space
    $cleanedString = $cleanedString -replace '\s+', ' '

    # Remove any non-printable characters
    $cleanedString = $cleanedString -replace '[^\x20-\x7E]', ''

    # Remove &nbsp; entities
    $cleanedString = $cleanedString -replace '&nbsp;', ' '

    # Remove empty lines
    $cleanedString = $cleanedString -replace '^\s*$\n', ''

    # Convert the string to an array of lines
    $lines = $cleanedString -split "`n"

    # Remove empty lines
    $lines = $lines | Where-Object { $_.Trim() -ne "" }

    # Join the lines back into a single string
    $cleanedString = $lines -join "`n"

    return $cleanedString
}


function Invoke-RAG {
    param (
        [string]$userInput,
        [string]$prompt,
        [ProjectTeam]$RAGAgent,
        [int]$MaxCount = 2
    )
    $RAGresponse = $null
    $shortenedUserInput = ""
    try {

        # Shorten the user input to be used as a query for Bing search
        $websearchinstructions = @"
To create effective query for the Azure Bing Web Search API, summarize given text and follow these best practices:
1. Use specific keywords: Choose concise and precise terms that clearly define your search intent to increase result relevance.
2. Utilize advanced operators: Leverage operators like 'AND', 'OR', and 'NOT' to refine your queries. Use 'site:' for domain-specific searches.
3. Must remove from the begin and end of query quotation marks or other characters.
"@
        $shortenedUserInput = ($RAGAgent.ProcessInput("You must summarize and craft short query with a few terms optimized for Web query based on the text: '$userInput'. Examples: 'Powershell, code review, script parsing OR analyzing','Powershell code AND psscriptanalyzer','Powershell AND azure data logger AND event log'. You must respond with query only.", "Assistant is a Web Search Query Manager. Assistant's task is to suggest best query. $websearchinstructions")).trim()

        Write-Host ">> RAG is on. Attempting to augment AI Agent data..." -ForegroundColor Green

        # Check if the shortened user input is not empty
        if (-not [string]::IsNullOrEmpty($shortenedUserInput)) {
            # Define the log file path for storing the query
            $logFilePath = Join-Path -Path $GlobalState.TeamDiscussionDataFolder -ChildPath "azurebingqueries.log"
            # Append the shortened user input to the log file with a date prefix in professional log style
            $datePrefix = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            $logEntry = "$datePrefix - Query: $shortenedUserInput"
            Add-Content -Path $logFilePath -Value $logEntry

            # Perform the web search using the shortened user input
            $webResults = Invoke-BingWebSearch -query $shortenedUserInput -count $MaxCount
        }
        else {
            # Throw an error if the query is empty
            throw "The query is empty. Unable to perform web search."
        }

        # Check if web results are returned
        if ($webResults) {
            # Extract and clean text content from the web results
            $webResultsText = ($webResults | ForEach-Object {
                    $htmlContent = Invoke-WebRequest -Uri $_.url
                    $textContent = ($htmlContent.Content | PowerHTML\ConvertFrom-HTML).innerText
                    # -replace '(?m)^\s*$', ''
                    $textContent
                }
            ) -join "`n`n"

            # Process the cleaned web results text with the project manager's input processing function
            $RAGresponse = $RAGAgent.ProcessInput((Remove-StringDirtyData -inputString $webResultsText), $prompt)
            if ($RAGresponse) {
                Write-Host ">> RAG is on. AI Agent data was successfully augmented with new data." -ForegroundColor Green
            }
        }
        # Return the response generated by the project manager
        return $RAGresponse
    }
    catch {
        # Log the error and rethrow it
        #$this.AddLogEntry("Error in Invoke-RAG:`n$_")
        #throw $_
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")
        #Write-Warning $_
        Write-Host "-- No RAG data available to augment." -ForegroundColor DarkYellow
        return
    }
}

function Get-Ollama {
    <#
.SYNOPSIS
    Checks the status of Ollama installation, process, and running models.

.DESCRIPTION
    This function performs several checks related to Ollama:
    1. Verifies if Ollama is installed and available in the system PATH.
    2. Checks if the Ollama process is currently running.
    3. Retrieves and displays information about the models currently running in Ollama.

.EXAMPLE
    Get-Ollama

.NOTES
    Author: Voytas75
    Date: 2024.07.10
#>
    # Check if Ollama is installed
    $ollamaPath = Test-OllamaInstalled
    if (-not $ollamaPath) {
        Write-Host "Ollama is not installed or not in PATH."
        return $false
    }
    Write-Host "Ollama is installed at: $ollamaPath"

    # Check if Ollama is running
    $ollamaProcess = Test-OllamaRunning
    if (-not $ollamaProcess) {
        Write-Host "Ollama is not currently running."
        return Start-OllamaInNewConsole
    }
    if ($ollamaProcess.Count -gt 1) {
        Write-Host "Multiple Ollama processes are running with PID(s): $($ollamaProcess.Id -join ', ')"
    }
    else {
        Write-Host "Ollama is running with PID: $($ollamaProcess.Id)"
    }

    # Check what model is running
    try {
        Get-OllamaModels
    }
    catch {
        Write-Host "Failed to retrieve model information from /api/tags: $_"
        return $false
    }

    # Additional check for running model information
    try {
        # Example usage of Test-OllamaRunningModel and Start-OllamaModel
        # Test-OllamaRunningModel checks if any model is running
        # Start-OllamaModel starts a model if none is running
        return Start-OllamaModel
    }
    catch {
        Write-Host "Failed to retrieve additional model information from /api/ps: $_"
    }
}

function Get-OllamaModels {
    <#
    .SYNOPSIS
        Lists all available models in the local Ollama repository.

    .DESCRIPTION
        This function retrieves and lists all models available in the local Ollama repository by making a GET request to the /api/tags endpoint.

    .EXAMPLE
        List-OllamaModels

    .NOTES
        Author: YourName
        Date: 2024.07.10
    #>
    try {
        # Make a GET request to the /api/tags endpoint to retrieve model information
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get
        if ($response.models) {
            Write-Host "Models:"
            # Iterate through each model and output its name and size
            $response.models | ForEach-Object {
                $sizeInGB = [math]::Round($_.size / 1GB, 2)
                Write-Host "- $($_.name) (Size: $sizeInGB GB)"
            }
        }
        else {
            Write-Host "No models in local repository. https://github.com/ollama/ollama?tab=readme-ov-file#quickstart"
            return $false
        }
    }
    catch {
        Write-Host "Failed to retrieve model information from /api/tags: $_"
        return $false
    }
}

function Start-OllamaInNewConsole {
    <#
    .SYNOPSIS
        Starts Ollama in a new minimized console window.

    .DESCRIPTION
        This function starts the Ollama application in a new minimized console window using the Start-Process cmdlet.
        It ensures that Ollama is installed and available in the system PATH before attempting to start it.

    .EXAMPLE
        Start-OllamaInNewConsole

    .NOTES
        Author: YourName
        Date: 2024.07.10
    #>
    # Check if Ollama is installed
    $ollamaPath = Get-Command ollama -ErrorAction SilentlyContinue
    if (-not $ollamaPath) {
        #Write-Host "Ollama is not installed or not in PATH."
        return $false
    }

    # Start Ollama in a new minimized console window
    try {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/k", "$ollamaPath start" -WindowStyle Minimized
        Write-Host "Ollama has been started in a new minimized console window."
        return $true
    }
    catch {
        Write-Host "Failed to start Ollama in a new minimized console window: $_"
        return $false
    }
}

function Test-OllamaRunningModel {
    <#
.SYNOPSIS
    Tests if any models are currently running in Ollama and retrieves their information.

.DESCRIPTION
    This function checks if any models are currently running in Ollama by making a GET request to the /api/ps endpoint.
    If models are running, it outputs their names and sizes. If no models are running, it provides instructions on how to start a model.

.EXAMPLE
    Test-OllamaRunningModel

.NOTES
    Author: Voytas75
    Date: 2024.07.10
#>
    param(
        [switch]$NOInfo
    )
    try {
        # Make a GET request to the /api/ps endpoint to retrieve running model information
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/ps" -Method Get
        
        if ($response.models) {
            if (-not $NOInfo) {
                Write-Host "Ollama is running the following models:"
            }
            # Iterate through each model and output its name and size
            $script:ollamaModels = $response.models
            foreach ($model in $script:ollamaModels) {
                if (-not $NOInfo) {
                    $sizeInGB = [math]::Round($model.size / 1GB, 2)
                    Write-Host "$($model.name) (Size: $sizeInGB GB)"
                }
            }
            # Choose and return the first model
            $firstModel = $script:ollamaModels[0]
            $script:ollamamodel = $firstModel.name
            $env:OLLAMA_MODEL = $script:ollamamodel
            [System.Environment]::SetEnvironmentVariable('OLLAMA_MODEL', $firstModel.Name, 'User')
            return $firstModel.Name
        }
        else {
            if (-not $NOInfo) {
                Write-Host "No models are currently running in Ollama."
            }
            #Write-Host "To run a model in Ollama, use the following command:"
            #Write-Host "ollama run <model-name>"
            return $false
        }
    }
    catch {
        Write-Host "Failed to retrieve model information from Ollama: $_"
    }
}

function Start-OllamaModel {
    <#
.SYNOPSIS
    Starts a model in Ollama if no model is currently running.

.DESCRIPTION
    This function checks if Ollama is installed and available in the system PATH. 
    It then verifies if any model is currently running in Ollama. If no model is running, 
    it prompts the user to select a model from the available models and starts it.

.EXAMPLE
    Start-OllamaModel

.NOTES
    Author: Voytas75
    Date: 2024.07.10
#>
    # Get the path of the Ollama executable
    #$ollamaPath = (Get-Command ollama -ErrorAction SilentlyContinue).Source
    $ollamaPath = Test-OllamaInstalled
    if (-not $ollamaPath) {
        Write-Host "Ollama is not found in PATH. Make sure it's installed and in your system PATH."
        return $false
    }

    try {
        # Check if any model is currently running
        $runningModel = Test-OllamaRunningModel -NOInfo
        if ($runningModel) {
            Write-Host "Model '$runningModel' is already running."
            [System.Environment]::SetEnvironmentVariable('OLLAMA_MODEL', $runningModel, 'user')
            $script:ollamaModel = [System.Environment]::GetEnvironmentVariable('OLLAMA_MODEL', 'user')
            return $script:ollamaModel
        }

        # Make a GET request to the /api/tags endpoint to retrieve available models
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get
        if ($response.models) {
            #Write-Host "Available Models:"
            # List available models
            $models = $response.models | ForEach-Object { $_.name }
            #$models | ForEach-Object { Write-Host "- $_" }

            # Check if the environment variable 'ollama_model' is set
            if ([System.Environment]::GetEnvironmentVariable('OLLAMA_MODEL', 'user')) {
                #$ModelName = [System.Environment]::GetEnvironmentVariable('OLLAMA_MODEL','user')
                if ($models -notcontains [System.Environment]::GetEnvironmentVariable('OLLAMA_MODEL', 'user')) {
                    Write-Host "Invalid model name specified in environment variable 'ollama_model'. Please select a model from the list."
                    [System.Environment]::SetEnvironmentVariable('OLLAMA_MODEL', '', 'user')
                    $ModelName = [System.Environment]::SetEnvironmentVariable('OLLAMA_MODEL', '', 'user')
                }
            }
            $script:ollamaModel = [System.Environment]::GetEnvironmentVariable('OLLAMA_MODEL', 'user')
            $ModelName = $script:ollamaModel
            # If 'ollama_model' is not set or invalid, prompt the user to select a model
            if (-not $ModelName) {
                Get-OllamaModels
                do {
                    $ModelName = Read-Host "Please enter the name of the model you want to start"
                    if ($models -notcontains $ModelName) {
                        Write-Host "Invalid model name. Please select a model from the list."
                        $ModelName = $null
                    }
                } while (-not $ModelName)
            }

            # Start the selected model using a new PowerShell process
            #Start-Process powershell -ArgumentList "-NoExit", "-Command", "& '$ollamaPath' run $ModelName"
            Write-Host "Starting with $ModelName"
            Start-Process -FilePath "cmd.exe" -ArgumentList "/k", "$ollamaPath run $ModelName" -WindowStyle Minimized
            [System.Environment]::SetEnvironmentVariable('OLLAMA_MODEL', $ModelName, 'user')
            $script:ollamaModel = [System.Environment]::GetEnvironmentVariable('OLLAMA_MODEL', 'user')
            return $ModelName
        }
        else {
            Write-Host "No models are currently available."
        }
    }
    catch {
        Write-Host "Failed to retrieve model information from /api/tags: $_"
    }
}
function Test-OllamaInstalled {
    <#
    .SYNOPSIS
        Tests if Ollama is installed and available in the system PATH.

    .DESCRIPTION
        This function checks if the 'ollama' executable is available in the system PATH.
        It returns $true if Ollama is installed, and $false otherwise.

    .EXAMPLE
        Test-OllamaInstalled
        Returns $true if Ollama is installed, otherwise $false.

    .NOTES
        Author: YourName
        Date: 2024.07.10
    #>
    param ()

    try {
        $ollamaPath = Get-Command ollama -ErrorAction SilentlyContinue
        if ($ollamaPath) {
            #Write-Host "Ollama is installed at: $($ollamaPath.Source)"
            return $ollamaPath.Source
        }
        else {
            #Write-Host "Ollama is not installed or not in PATH."
            return $false
        }
    }
    catch {
        Write-Host "An error occurred while checking for Ollama installation: $_"
        return $false
    }
}

function Test-OllamaRunning {
    <#
    .SYNOPSIS
        Tests if the Ollama process is currently running.

    .DESCRIPTION
        This function checks if the 'ollama' process is currently running on the system.
        It returns $true if the process is running, and $false otherwise.

    .EXAMPLE
        Test-OllamaRunning
        Returns $true if the Ollama process is running, otherwise $false.

    .NOTES
        Author: YourName
        Date: 2024.07.10
    #>
    param ()

    try {
        $ollamaProcess = Get-Process ollama -ErrorAction SilentlyContinue
        if ($ollamaProcess) {
            return $ollamaProcess
        }
        else {
            return $false
        }
    }
    catch {
        Write-Host "An error occurred while checking if Ollama is running: $_"
        return $false
    }
}

function Set-OllamaModel {
    param ($model)
    $env:OLLAMA_MODEL = $model
    $script:ollamaModel = $model
    [System.Environment]::SetEnvironmentVariable('OLLAMA_MODEL', $model, 'User')
}

function Ensure-OllamaModelRunning {
    param ($attempts = 10, $delay = 2)
    for ($i = 0; $i -lt $attempts; $i++) {
        $runningModel = Test-OllamaRunningModel
        if ($runningModel) {
            Set-OllamaModel -model $runningModel
            return $true
        }
        Start-OllamaModel
        Start-Sleep -Seconds $delay
    }
    return $false
}
#endregion Functions

#region Setting Up
# Check if the PSAOAI module is installed and meets the minimum version requirement
#if (-not (Test-ModuleMinVersion -ModuleName PSAOAI -MinimumVersion 0.3.2) -and $LLMProvider -eq "AzureOpenAI") {
#    Write-Host "The PSAOAI module is not at the required version (0.3.2). Please update it using 'Update-Module PSAOAI' or install it using 'Install-Module PSAOAI'." #-ForegroundColor Yellow
#}

# Save the original UI culture to restore it later
$originalCulture = [Threading.Thread]::CurrentThread.CurrentUICulture

# Set the current UI culture to 'en-US' for consistent behavior
[void]([Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::CreateSpecificCulture('en-US'))

# Disable RAG (Retrieve and Generate) functionality if the NORAG switch is set
$RAG = $true
if ($NORAG) {
    $RAG = $false
}


# Define a state management object
$GlobalState = [PSCustomObject]@{
    TeamDiscussionDataFolder = $null
    GlobalResponse           = @()
    FileVersion              = 1
    LastPSDevCode            = ""
    GlobalPSDevResponse      = @()
    OrgUserInput             = ""
    UserInput                = ""
    LogFolder                = ""
    MaxTokens                = $MaxTokens
    VerbosePrompt            = $VerbosePrompt
    NOTips                   = $NOTips
    NOLog                    = $NOLog
    NODocumentator           = $NODocumentator
    NOPM                     = $NOPM
    RAG                      = $RAG
    Stream                   = $Stream
}
$GlobalState.LogFolder = $LogFolder

# Disabe PSAOAI importing banner
[System.Environment]::SetEnvironmentVariable("PSAOAI_BANNER", "0", "User")
$env:PSAOAI_BANNER = "0"

#if ((Get-Module -ListAvailable -Name PSAOAI | Where-Object { [version]$_.version -ge [version]"0.3.2" })) {
if (    Test-ModuleMinVersion -ModuleName PSAOAI -MinimumVersion "0.3.2" ) {
    [void](Import-module -name PSAOAI -Force)
}
else {
    Write-Warning "-- You need to install/update PSAOAI module version >= 0.3.2. Use: 'Install-Module PSAOAI' or 'Update-Module PSAOAI'"
    return
}
Show-Banner

#region ollama
if ($LLMProvider -eq 'ollama') {
    # Check if Ollama is installed
    $ollamaInstalled = Test-OllamaInstalled
    if (-not $ollamaInstalled) {
        Write-Warning "Ollama is not installed. Please install Ollama and ensure it is in your PATH."
        return
    }
    else {
        Write-Host "Ollama is installed at: $ollamaInstalled"
    }

    # Check if Ollama is running
    $ollamaRunning = Test-OllamaRunning
    if (-not $ollamaRunning) {
        Write-Warning "Ollama is not running. Attempting to start Ollama..."
        if (Start-OllamaInNewConsole) {
            Write-Host "Ollama started successfully."
        }
        else {
            Write-Warning "Failed to start Ollama."
            return
        }
    }
    else {
        Write-Host "Ollama is running."
    }

    # Ensure a model is running
    $runningModelOllama = Test-OllamaRunningModel
    if ($runningModelOllama) {
        Set-OllamaModel -model $runningModelOllama
    }
    else {
        if (Start-OllamaModel) {
            $runningModel = Test-OllamaRunningModel -NOInfo
            if ($runningModel) {
                if (Ensure-OllamaModelRunning) {
                    Set-OllamaModel -model $runningModel
                }
            }
        }
    }

    <#
if ([System.Environment]::GetEnvironmentVariable('OLLAMA_MODEL', 'User')) {
    if (-not (Test-OllamaRunningModel -NOInfo)) {
        Write-Warning "Ollama model is not running after multiple attempts. Waiting 15 sec...."
        for ($i = 1; $i -le 15; $i++) {
            Write-Progress -Activity "Waiting for Ollama model to start" -Status "$i seconds elapsed" -PercentComplete (($i / 15) * 100)
            Start-Sleep -Seconds 1
        }
    }
}
#>

    Write-Host "If you want to change the model, please delete the OLLAMA_MODEL environment variable or set it to your desired value."
}
#endregion ollama

$scriptname = "AIPSTeam"
if ($LoadProjectStatus) {
    # Check if the provided path is a directory
    if (Test-Path -Path $LoadProjectStatus -PathType Container) {
        # Get all XML files in the specified directory
        $xmlFiles = Get-ChildItem -Path $LoadProjectStatus -Filter *.xml
        foreach ($file in $xmlFiles) {
            # Prompt the user to select a file to use as the project status
            $useFile = Read-Host "Do you want to use the file '$($file.FullName)' as the project status? (yes/no)"
            if ($useFile -eq 'yes') {
                # Set the selected file as the project status file
                $LoadProjectStatus = $file.FullName
                break
            }
        }
    } 
    try {
        # Load the project state from the specified file
        $GlobalState = Get-ProjectState -FilePath $LoadProjectStatus
        Write-Information "++ Project state loaded successfully from $LoadProjectStatus" -InformationAction Continue
        # Output verbose information about the loaded project state
        Write-Verbose "`$GlobalState.TeamDiscussionDataFolder: $($GlobalState.TeamDiscussionDataFolder)"
        Write-Verbose "`$GlobalState.FileVersion: $($GlobalState.FileVersion)"
        Write-Verbose "`$GlobalState.LastPSDevCode: $($GlobalState.LastPSDevCode)"
        Write-Verbose "`$GlobalState.GlobalPSDevResponse: $($GlobalState.GlobalPSDevResponse)"
        Write-Verbose "`$GlobalState.GlobalResponse: $($GlobalState.GlobalResponse)"
        Write-Verbose "`$GlobalState.OrgUserInput: $($GlobalState.OrgUserInput)"
        Write-Verbose "`$GlobalState.UserInput: $($GlobalState.UserInput)"
        Write-Verbose "`$GlobalState.LogFolder: $($GlobalState.LogFolder)"
        Write-Verbose "`$GlobalState.MaxTokens: $($GlobalState.MaxTokens)"
        Write-Verbose "`$GlobalState.VerbosePrompt: $($GlobalState.VerbosePrompt)"
        Write-Verbose "`$GlobalState.NOTips: $($GlobalState.NOTips)"
        Write-Verbose "`$GlobalState.NOLog: $($GlobalState.NOLog)"
        Write-Verbose "`$GlobalState.NODocumentator: $($GlobalState.NODocumentator)"
        Write-Verbose "`$GlobalState.NOPM: $($GlobalState.NOPM)"
        Write-Verbose "`$GlobalState.RAG: $($GlobalState.RAG)"
        Write-Verbose "`$GlobalState.Stream: $($GlobalState.Stream)"
    }    
    catch [System.Exception] {
        # Handle any exceptions that occur during the loading of the project state
        Update-ErrorHandling -ErrorRecord $_ -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")
    }
}
else {
    Try {
        # Get the current date and time in the specified format
        $currentDateTime = Get-Date -Format "yyyyMMdd_HHmmss"
        if (-not [string]::IsNullOrEmpty($GlobalState.LogFolder)) {
            # Create a folder with the current date and time as the name in the specified log folder path
            $GlobalState.TeamDiscussionDataFolder = New-FolderAtPath -Path $GlobalState.LogFolder -FolderName $currentDateTime
        }
        else {
            # Set the log folder path to the user's Documents folder with the script name as a subfolder
            $GlobalState.LogFolder = Join-Path -Path ([Environment]::GetFolderPath("MyDocuments")) -ChildPath $scriptname
            if (-not (Test-Path -Path $GlobalState.LogFolder)) {
                # Create the log folder if it does not exist
                New-Item -ItemType Directory -Path $GlobalState.LogFolder | Out-Null
            }
            Write-Information "++ The logs will be saved in the following folder: $($GlobalState.LogFolder)" -InformationAction Continue
            # Create a folder with the current date and time as the name in the log folder path
            $GlobalState.TeamDiscussionDataFolder = New-FolderAtPath -Path $GlobalState.LogFolder -FolderName $currentDateTime
        }
        if ($GlobalState.TeamDiscussionDataFolder) {
            # Output information about the created team discussion folder
            Write-Information "++ Team discussion folder was created '$($GlobalState.TeamDiscussionDataFolder)'" -InformationAction Continue
        }
    }
    Catch {
        # Handle any exceptions that occur during the creation of the discussion folder
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "Create discussion folder" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")

        return $false
    }
}
$DocumentationFullName = Join-Path $GlobalState.TeamDiscussionDataFolder "Documentation.txt"
$ProjectfilePath = Join-Path $GlobalState.TeamDiscussionDataFolder "Project.xml"
Get-CheckForScriptUpdate -currentScriptVersion $AIPSTeamVersion -scriptName $scriptname
#endregion Setting Up

#region ProjectTeam
# Create ProjectTeam expert objects
$requirementsAnalystRole = "Requirements Analyst"
$requirementsAnalyst = [ProjectTeam]::new(
    "Analyst",
    $requirementsAnalystRole,
    @"
You are running as {0}. Your task is to analyze the PowerShell requirements. The goal is to clearly define the program goals, necessary components and outline the implementation strategy that the Powershell Developer will execute.
Provide a detailed feasibility report covering all the following aspects:
- Briefly and concisely evaluate the feasibility of creating the PowerShell program described, taking into account technical, operational and financial aspects.
- Define the program goals and its most important features in detail.
- Identify the necessary components and tools in PowerShell to achieve this.
- Point out potential challenges and limitations.

Additional information: PowerShell is a task automation and configuration management platform from Microsoft, consisting of a command-line shell and a scripting language. It is widely used to manage and automate tasks in various Microsoft and third-party environments.
"@ -f $requirementsAnalystRole,
    0.6,
    0.9,
    $GlobalState
)

$domainExpertRole = "Domain Expert"
$domainExpert = [ProjectTeam]::new(
    "Domain Expert",
    $domainExpertRole,
    @"
You act as {0}. Your task is provide specialized insights and recommendations based on the specific domain requirements of the project for Powershell Developer. Indights include:
1. Ensuring Compatibility:
    - Ensure the program is compatible with various domain-specific environments (e.g., cloud, on-premises, hybrid).
    - Validate the requirements against industry standards and best practices to ensure broad compatibility.
2. Best Practices for Performance, Security, and Optimization:
    - Provide best practices for optimizing performance, including specific performance metrics relevant to the domain.
    - Offer security recommendations to protect data and systems in the domain environment.
    - Suggest optimization techniques to improve efficiency and performance.
3. Recommending Specific Configurations and Settings:
    - Recommend configurations and settings that are known to perform well in the domain environment.
    - Ensure these recommendations are practical and aligned with industry standards.
4. Documenting Domain-Specific Requirements:
    - Document any specific requirements, security standards, or compliance needs relevant to the domain.
    - Ensure these requirements are clear and detailed to guide the developer effectively.
5. Reviewing Program Design:
    - Review the program's design to identify any domain-specific constraints and requirements.
    - Provide feedback and recommendations to address these constraints and ensure the design aligns with domain best practices.
"@ -f $domainExpertRole,
    0.65,
    0.9,
    $GlobalState
)

$systemArchitectRole = "System Architect"
$systemArchitect = [ProjectTeam]::new(
    "Architect",
    $systemArchitectRole,
    @"
You act as {0}. Your task is design the architecture for a PowerShell project to use by Powershell Developer. 
Design includes:
- Outlining the overall structure of the program.
- Identifying and defining necessary modules and functions.
- Creating detailed architectural design documents.
- Ensuring the architecture supports scalability, maintainability, and performance.
- Defining data flow and interaction between different components.
- Selecting appropriate technologies and tools for the project.
- Providing guidelines for coding standards and best practices.
- Documenting security considerations and ensuring the architecture adheres to best security practices.
- Creating a detailed architectural design document.
- Generate a list of verification questions that could help to analyze. 
"@ -f $systemArchitectRole,
    0.7,
    0.85,
    $GlobalState
)

$powerShellDeveloperRole = "PowerShell Developer"
$powerShellDeveloper = [ProjectTeam]::new(
    "Developer",
    $powerShellDeveloperRole,
    @"
You act as {0}. You are tasked with developing the PowerShell script based on the provided requirements and implementation strategy. Your goal is to write clean, efficient, and functional powershell code that meets the specified objectives and best practices. 
Instructions:
1. Develop the PowerShell program according to the provided requirements and strategy:
    - Review the requirements and implementation strategy thoroughly before starting development.
    - Break down the tasks into manageable chunks and implement them iteratively.
    - Write the entire script in a single file, so user can run it without needing additional modules or files.
    - Use approved verbs in function names.
2. Ensure the code is modular and well-documented with help blocks:
    - Use knowledge from the help topic 'about_Comment_Based_Help'. You must add '.NOTES' with additional information 'Version' and release notes. '.NOTES' contains all updates and versions for clarity of documentation. Example of '.NOTES' section:
    `".NOTES
    Version: 1.2
    Updates:
        - Version 1.2: Enhanced error handling with specific exceptions, added performance improvements using .NET methods.
        - Version 1.1: Added size formatting and improved error handling.
        - Version 1.0: Initial release
    Author: @voytas75
    Date: current date as YYYY.MM.DD`"
    - Organize the code into logical functions, following the principle of modularity.
    - Document each function with clear and concise help blocks, including usage examples where applicable.
3. Include error handling and logging where appropriate:
    - Implement robust error handling mechanisms to gracefully handle unexpected situations and failures.
    - Integrate logging functionality to capture relevant information for troubleshooting and analysis.
4. Provide comments and explanations for complex sections of the code:
    - Add inline comments to explain the purpose and logic behind complex sections of the code.
    - Document any non-obvious decisions or workarounds to facilitate understanding for other developers.
5. Prepare a brief usage guide:
    - Create a simple and easy-to-follow usage guide that outlines how to run and utilize the PowerShell program effectively.
    - Include examples of common use cases and expected outputs to assist users in understanding the program's functionality.
6. Conduct peer code reviews to ensure quality:
    - Collaborate with team members to review each other's code for correctness, clarity, and adherence to best practices.
    - Provide constructive feedback and suggestions for improvement during code reviews.
"@ -f $powerShellDeveloperRole,
    0.65,
    0.8,
    $GlobalState
)

$qaEngineerRole = "Quality Assurance Engineer"
$qaEngineer = [ProjectTeam]::new(
    "QA Engineer",
    $qaEngineerRole,
    @"
You act as {0}. You are tasked with testing and verifying the functionality of the developed PowerShell program. Your goal is to ensure the program works as intended, is free of bugs, and meets the specified requirements.
Instructions:
- Roll play test the PowerShell program for functionality and performance.
- Verify that the program meets all specified requirements and objectives.
- Identify any bugs or issues.
- Suggest improvements or optimizations if necessary.
- Include performance and load testing.
- Provide a final report on the program's quality and readiness for deployment.
- Generate a list of verification questions that could help to analyze.
Background Information: PowerShell scripts can perform a wide range of tasks, so thorough testing is essential to ensure reliability and performance. Testing should cover all aspects of the program, including edge cases and potential failure points.
"@ -f $qaEngineerRole,
    0.6,
    0.9,
    $GlobalState
)

$documentationSpecialistRole = "Documentation Specialist"
$documentationSpecialist = [ProjectTeam]::new(
    "Documentator",
    $documentationSpecialistRole,
    @"
You act as {0}. You are tasked with creating comprehensive documentation for the PowerShell project. This includes:
- Writing a detailed user guide that explains how to install, configure, and use the program.
- Creating developer notes that outline the code structure, key functions, and logic.
- Providing step-by-step installation instructions.
- Documenting any dependencies and prerequisites.
- Writing examples of use cases and expected outputs.
- Including troubleshooting tips and common issues.
- Preparing a FAQ section to address common questions.
- Ensuring all documentation is clear, concise, and easy to follow.
- Reviewing and editing the documentation for accuracy and completeness.
- Using standard templates for user guides and developer notes.
- Ensuring code comments are included as part of the documentation.
- Considering adding video tutorials for installation and basic usage.
"@ -f $documentationSpecialistRole,
    0.6,
    0.8,
    $GlobalState
)

$projectManagerRole = "Project Manager"
$projectManager = [ProjectTeam]::new(
    "Manager",
    $projectManagerRole,
    @"
You act as {0}. Your task is to provide a comprehensive summary of the PowerShell project as project report, based on the completed tasks of each expert. This includes:
- Reviewing the documented requirements from the Requirements Analyst.
- Summarizing the architectural design created by the System Architect.
- Summarizing script development work done by the PowerShell Developer.
- Reporting the testing results and issues found by the QA Engineer.
- Highlighting the documentation prepared by the Documentation Specialist.
- Identifying key achievements.
- Ensuring that all aspects of the project are covered and documented comprehensively.
- Conducting a post-project review and feedback session.
"@ -f $projectManagerRole,
    0.7,
    0.85,
    $GlobalState
)
#endregion ProjectTeam

#region Main
$Team = @()
$Team += $requirementsAnalyst
$Team += $systemArchitect
$Team += $domainExpert
$Team += $powerShellDeveloper
$Team += $qaEngineer
$Team += $documentationSpecialist
$Team += $projectManager

foreach ($TeamMember in $Team) {
    $TeamMember.LLMProvider = $LLMProvider
}

if ($GlobalState.NOLog) {
    foreach ($TeamMember_ in $Team) {
        $TeamMember_.LogFilePath = ""
    }
}

if (-not $GlobalState.NOLog) {
    foreach ($TeamMember in $Team) {
        $TeamMember.DisplayInfo(0) | Out-File -FilePath $TeamMember.LogFilePath -Append
    }
    Write-Host "++ " -NoNewline
    Start-Transcript -Path (join-path $GlobalState.TeamDiscussionDataFolder "TRANSCRIPT.log") -Append
}

$RAGpromptAddon = $null
if ($GlobalState.RAG) {
    $RAGresponse = Invoke-RAG -userInput $userInput -prompt "The assistant must remove advertising elements, menus and other unimportant objects from the provided text and analyze the remaining body through the prism of the description provided by the user: '$userInput'. The result is to be a list of key information, thoughts and questions based on the text." -RAGAgent $projectManager
    if ($RAGresponse) {
        $RAGpromptAddon = @"

###RAG data###

````````text
$RAGresponse
````````
    
"@
    }
}

if (-not $LoadProjectStatus) {
    #region PM-PSDev
    $examplePScode = @'
###Example of PowerShell script block###

```powershell
powershell_code_here
```

###Background PowerShell Information###
PowerShell scripts can interact with a wide range of systems and applications, making it a versatile tool for system administrators and developers. Ensure your code adheres to PowerShell best practices for readability, maintainability, and performance.

Write the powershell code based on review. Everything except the code must be commented or in comment block. Optionally generate a list of verification questions that could help to analyze. Think step by step. Make sure your answer is unbiased. Use reliable sources like official documentation, research papers from reputable institutions, or widely used textbooks.
'@

    $userInputOryginal = $userInput
    $GlobalState.OrgUserInput = $userInputOryginal
    $projectManagerPrompt = @"
Write detailed and concise PowerShell project name, description, objectives, deliverables, additional considerations, and success criteria based on user input and RAG data.

###User input###

````````text
$userInputOryginal
````````
$RAGpromptAddon
"@
    if (-not $GlobalState.NOTips) {
        $projectManagerPrompt += "`n`nNote: There is `$50 tip for this task."
    }
    $projectManagerFeedback = $projectManager.Feedback($powerShellDeveloper, $projectManagerPrompt)
    Add-ToGlobalResponses $GlobalState $projectManagerFeedback
    $GlobalState.userInput = $projectManagerFeedback
    $powerShellDeveloperPrompt = @"
Write the first version of the Powershell code based on $($projectManager.Name) review.

$($projectManager.Name) review:

````````text
$($GlobalState.userInput)
````````

$examplePScode
"@
    if (-not $GlobalState.NOTips) {
        $powerShellDeveloperPrompt += "`n`nNote: There is `$50 tip for this task."
    }

    $powerShellDeveloperResponce = $powerShellDeveloper.ProcessInput($powerShellDeveloperPrompt)

    #$GlobalState.GlobalPSDevResponse += $powerShellDeveloperResponce
    Add-ToGlobalPSDevResponses $GlobalState $powerShellDeveloperResponce
    Add-ToGlobalResponses $GlobalState $powerShellDeveloperResponce
    Save-AndUpdateCode -response $powerShellDeveloperResponce -GlobalState $GlobalState
    #endregion PM-PSDev

    #region RA-PSDev
    #Invoke-ProcessFeedbackAndResponse -role $requirementsAnalyst -description $GlobalState.userInput -code $lastPSDevCode -tipAmount 100 -globalResponse ([ref]$GlobalPSDevResponse) -lastCode ([ref]$lastPSDevCode) -fileVersion ([ref]$FileVersion) -teamDiscussionDataFolder $GlobalState.TeamDiscussionDataFolder
    if ($GlobalState.NOTips) {
        Invoke-ProcessFeedbackAndResponse -reviewer $requirementsAnalyst -recipient $powerShellDeveloper -GlobalState $GlobalState
    }
    else {
        Invoke-ProcessFeedbackAndResponse -reviewer $requirementsAnalyst -recipient $powerShellDeveloper -GlobalState $GlobalState -tipAmount 100
    }
    #endregion RA-PSDev

    #region SA-PSDev
    if ($GlobalState.NOTips) {
        Invoke-ProcessFeedbackAndResponse -reviewer $systemArchitect -recipient $powerShellDeveloper -GlobalState $GlobalState
    }
    else {
        Invoke-ProcessFeedbackAndResponse -reviewer $systemArchitect -recipient $powerShellDeveloper -GlobalState $GlobalState -tipAmount 150
    }

    #endregion SA-PSDev

    #region DE-PSDev
    if ($GlobalState.NOTips) {
        Invoke-ProcessFeedbackAndResponse -reviewer $domainExpert -recipient $powerShellDeveloper -GlobalState $GlobalState
    }
    else {
        Invoke-ProcessFeedbackAndResponse -reviewer $domainExpert -recipient $powerShellDeveloper -GlobalState $GlobalState -tipAmount 200
    }
    #endregion DE-PSDev

    #region QAE-PSDev
    if ($GlobalState.NOTips) {
        Invoke-ProcessFeedbackAndResponse -reviewer $qaEngineer -recipient $powerShellDeveloper -GlobalState $GlobalState
    }
    else {
        Invoke-ProcessFeedbackAndResponse -reviewer $qaEngineer -recipient $powerShellDeveloper -GlobalState $GlobalState -tipAmount 300
    }
    #endregion QAE-PSDev

    #region PSScriptAnalyzer
    Invoke-AnalyzeCodeWithPSScriptAnalyzer -InputString $($powerShellDeveloper.GetLastMemory().Response) -Role $powerShellDeveloper -GlobalState $GlobalState
    #endregion PSScriptAnalyzer

    #region Doc
    if (-not $GlobalState.NODocumentator) {
        if (-not $GlobalState.NOLog) {
            $documentationSpecialistResponce = $documentationSpecialist.ProcessInput($GlobalState.lastPSDevCode) 
            $documentationSpecialistResponce | Out-File -FilePath $DocumentationFullName
        }
        else {
            $documentationSpecialistResponce = $documentationSpecialist.ProcessInput($GlobalState.lastPSDevCode)
        }
        Add-ToGlobalResponses $GlobalState $documentationSpecialistResponce
    }
    #endregion Doc

    #region PM Project report
    if (-not $GlobalState.NOPM) {
        # Example of summarizing all steps,  Log final response to file
        if (-not $GlobalState.NOLog) {
            $projectManagerPrompt = "Generate project report without the PowerShell code.`n"
            $projectManagerPrompt += $GlobalState.GlobalResponse -join ", "
            $projectManagerResponse = $projectManager.ProcessInput($projectManagerPrompt) 
            $projectManagerResponse | Out-File -FilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ProjectSummary.log")
        }
        else {
            $projectManagerResponse = $projectManager.ProcessInput($GlobalState.GlobalResponse -join ", ")
        }
        Add-ToGlobalResponses $GlobalState $projectManagerResponse
    }
    #endregion PM Project report
}
#region Menu

# Define the menu prompt message
$MenuPrompt = "{0} The previous version of the code has been shared below after the feedback block.`n`n````````text`n{1}`n`````````n`nHere is previous version of the code:`n`n``````powershell`n{2}`n```````n`nThink step by step. Make sure your answer is unbiased."
$MenuPromptNoUserChanges = "{0} The previous version of the code has been shared below. The code:`n`n``````powershell`n{1}`n```````n`nThink step by step. Make sure your answer is unbiased."

# Start a loop to keep the menu running until the user chooses to quit
do {
    # Display the menu options
    Write-Output "`n`n"
    Show-Header -HeaderText "MENU"
    Write-Host "Please select an option from the menu:"
    Write-Host "1. Suggest a new feature, enhancement, or change"
    Write-Host "2. Analyze & modify with PSScriptAnalyzer"
    Write-Host "3. Analyze PSScriptAnalyzer only"
    Write-Host "4. Explain the code"
    Write-Host "5. Ask a specific question about the code"
    Write-Host "6. Generate documentation"
    Write-Host "7. Show the code with research"
    Write-Host "8. Save Project State"
    Write-Host "9. Code Refactoring Suggestions"
    Write-Host "10. Security Audit"
    Write-Host "11. Open project folder in file explorer"
    if (Test-Path -Path (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")) {
        Write-Host "(E) Display content of (e)rror.txt"
    }
    Write-Host "(Q)uit"

    # Get the user's choice
    $userOption = Read-Host -Prompt "Enter your choice"
    Write-Output ""

    # Process the user's choice if it's not 'Q' or '9' (both of which mean 'quit')
    if ($userOption -ne 'Q') {
        switch ($userOption) {
            '1' {
                # Option 1: Suggest a new feature, enhancement, or change
                Show-Header -HeaderText "Suggest a new feature, enhancement, or change"
                do {
                    $userChanges = Read-Host -Prompt "Suggest a new feature, enhancement, or change for the code."
                    if (-not $userChanges) {
                        Write-Host "-- You did not write anything. Please provide a suggestion."
                    }
                } while (-not $userChanges)
                
                $promptMessage = "Based on the user's suggestion, incorporate a feature, enhancement, or change into the code. Show the next version of the code."
                $MenuPrompt_ = $MenuPrompt -f $promptMessage, $userChanges, $GlobalState.lastPSDevCode
                $MenuPrompt_ += "`nYou need to show all the code."
                $powerShellDeveloperResponce = $powerShellDeveloper.ProcessInput($MenuPrompt_)
                #$GlobalState.GlobalPSDevResponse += $powerShellDeveloperResponce
                Add-ToGlobalPSDevResponses $GlobalState $powerShellDeveloperResponce
                Add-ToGlobalResponses $GlobalState $powerShellDeveloperResponce
                $theCode = Export-AndWritePowerShellCodeBlocks -InputString $powerShellDeveloperResponce -StartDelimiter '```powershell' -EndDelimiter '```'
                if ($theCode) {
                    $theCode | Out-File -FilePath $(join-path $GlobalState.TeamDiscussionDataFolder "TheCode_v$($GlobalState.FileVersion).ps1") -Append -Encoding UTF8
                    $GlobalState.FileVersion += 1
                    $GlobalState.lastPSDevCode = $theCode
                }
            }
            '2' {
                # Option 2: Analyze & modify with PSScriptAnalyzer
                Show-Header -HeaderText "Analyze & modify with PSScriptAnalyzer"
                try {
                    # Call the function to check the code in 'TheCode.ps1' file
                    $issues = Invoke-CodeWithPSScriptAnalyzer -ScriptBlock $GlobalState.lastPSDevCode
                    if ($issues) {
                        write-output ($issues | Select-Object line, message | format-table -AutoSize -Wrap)
                    }
                }
                catch {
                    Write-Error "An error occurred while PSScriptAnalyzer: $_"
                }
                if ($issues) {
                    foreach ($issue in $issues) {
                        $issueText += $issue.message + " (line: $($issue.Line); rule: $($issue.Rulename))`n"
                    }
                    $promptMessage = "Your task is to address issues found in PSScriptAnalyzer report."
                    $promptMessage += "`n`nPSScriptAnalyzer report, issues:`n``````text`n$issueText`n```````n`n"
                    $promptMessage += "The code:`n``````powershell`n" + $GlobalState.lastPSDevCode + "`n```````n`nShow the new version of the Powershell code with solved issues."
                    $issues = ""
                    $issueText = ""
                    $powerShellDeveloperResponce = $powerShellDeveloper.ProcessInput($promptMessage)
                    $GlobalPSDevResponse += $powerShellDeveloperResponce
                    Add-ToGlobalResponses $GlobalState $powerShellDeveloperResponce
                    $theCode = Export-AndWritePowerShellCodeBlocks -InputString $($powerShellDeveloper.GetLastMemory().Response) -StartDelimiter '```powershell' -EndDelimiter '```'
                    if ($theCode) {
                        $theCode | Out-File -FilePath $(join-path $GlobalState.TeamDiscussionDataFolder "TheCode_v$($GlobalState.FileVersion).ps1") -Append -Encoding UTF8
                        $GlobalState.FileVersion += 1
                        $GlobalState.lastPSDevCode = $theCode
                    }
                }
            }
            '3' {
                # Option 3: Analyze PSScriptAnalyzer only
                Show-Header -HeaderText "Analyze PSScriptAnalyzer only"
                try {
                    # Call the function to check the code in 'TheCode.ps1' file
                    #$issues = Invoke-CodeWithPSScriptAnalyzer -ScriptBlock $(Export-AndWritePowerShellCodeBlocks -InputString $($powerShellDeveloper.GetLastMemory().Response) -StartDelimiter '```powershell' -EndDelimiter '```')
                    $issues = Invoke-CodeWithPSScriptAnalyzer -ScriptBlock $GlobalState.lastPSDevCode 
                    if ($issues) {
                        write-output ($issues | Select-Object line, message | format-table -AutoSize -Wrap)
                    }
                }
                catch {
                    Write-Error "!! An error occurred while PSScriptAnalyzer: $_"
                }

            }
            '4' {
                # Option 4: Explain the code
                Show-Header -HeaderText "Explain the code"
                $promptMessage = "Explain the code only.`n`n"
                $promptMessage += "The code:`n``````powershell`n" + $GlobalState.lastPSDevCode + "`n```````n"
                try {
                    $powerShellDeveloperResponce = $powerShellDeveloper.ProcessInput($promptMessage)
                    #$GlobalState.GlobalPSDevResponse += $powerShellDeveloperResponce
                    Add-ToGlobalPSDevResponses $GlobalState $powerShellDeveloperResponce
                    Add-ToGlobalResponses $GlobalState $powerShellDeveloperResponce
                }
                catch [System.Exception] {
                    Write-Error "!! An error occurred while processing the input: $_"
                }
            }
            '5' {
                # Option 5: Ask a specific question about the code
                Show-Header -HeaderText "Ask a specific question about the code"
                try {
                    $userChanges = Read-Host -Prompt "Ask a specific question about the code to seek clarification."
                    $promptMessage = "Based on the user's question for the code, provide only the answer."
                    if (Test-Path $DocumentationFullName) {
                        $promptMessage += " The documentation:`n````````text`n$(get-content -path $DocumentationFullName -raw)`n`````````n`n"
                    }
                    $promptMessage += "You must answer the user's question only. Do not show the whole code even if user asks."
                    $MenuPrompt_ = $MenuPrompt -f $promptMessage, $userChanges, $GlobalState.lastPSDevCode
                    $MenuPrompt_ += $userChanges
                    $powerShellDeveloperResponce = $powerShellDeveloper.ProcessInput($MenuPrompt_)
                    #$GlobalState.GlobalPSDevResponse += $powerShellDeveloperResponce
                    Add-ToGlobalPSDevResponses $GlobalState $powerShellDeveloperResponce
                    Add-ToGlobalResponses $GlobalState $powerShellDeveloperResponce
                }
                catch [System.Management.Automation.PSInvalidOperationException] {
                    Write-Error "!! An invalid operation occurred: $_"
                }
                catch [System.IO.IOException] {
                    Write-Error "!! An I/O error occurred: $_"
                }
                catch [System.Exception] {
                    Write-Error "!! An unexpected error occurred: $_"
                }
            }
            '6' {
                # Option 6: Generate documentation
                Show-Header -HeaderText "Generate documentation"
                try {
                    if (Test-Path -Path $DocumentationFullName -ErrorAction SilentlyContinue) {
                        Write-Information "++ Existing documentation found at $DocumentationFullName" -InformationAction Continue
                        $userChoice = Read-Host -Prompt "Do you want to review and update the documentation based on the last version of the code? (Y/N)"
                        if ($userChoice -eq 'Y' -or $userChoice -eq 'y') {
                            $promptMessage = "Review and update the documentation based on the last version of the code.`n`n"
                            $promptMessage += "The code:`n``````powershell`n" + $GlobalState.lastPSDevCode + "`n```````n`n"
                            $promptMessage += "The old documentation:`n````````text`n" + $(get-content -path $DocumentationFullName -raw) + "`n`````````n"
                            $documentationSpecialistResponce = $documentationSpecialist.ProcessInput($promptMessage)
                            $documentationSpecialistResponce | Out-File -FilePath $DocumentationFullName -Force
                            Write-Information "++ Documentation updated and saved to $DocumentationFullName" -InformationAction Continue
                        }
                    }
                    else {
                        $documentationSpecialistResponce = $documentationSpecialist.ProcessInput($GlobalState.lastPSDevCode)
                        $documentationSpecialistResponce | Out-File -FilePath $DocumentationFullName
                        Write-Information "++ Documentation generated and saved to $DocumentationFullName" -InformationAction Continue
                    }
                }
                catch [System.Management.Automation.PSInvalidOperationException] {
                    Write-Error "!! An invalid operation occurred: $_"
                }
                catch [System.IO.IOException] {
                    Write-Error "!! An I/O error occurred: $_"
                }
                catch [System.UnauthorizedAccessException] {
                    Write-Error "!! Unauthorized access: $_"
                }
                catch [System.Exception] {
                    Write-Error "!! An unexpected error occurred: $_"
                }
            }
            '7' {
                # Option 7: Show the code
                Show-Header -HeaderText "Show the code with research"
                Write-Output $GlobalState.lastPSDevCode
                # Option 8: The code research
                Show-Header -HeaderText "The code research"
                
                # Perform source code analysis
                Write-Output "Source code analysis:"
                Get-SourceCodeAnalysis -CodeBlock $GlobalState.lastPSDevCode
                Write-Output ""                
                # Perform cyclomatic complexity analysis
                Write-Verbose "`$lastPSDevCode: $($GlobalState.lastPSDevCode)"
                Write-Output "`nCyclomatic complexity analysis:"
                if ($CyclomaticComplexity = Get-CyclomaticComplexity -CodeBlock $GlobalState.lastPSDevCode) {
                    $CyclomaticComplexity
                    Write-Output "
    1:       The function has a single execution path with no control flow statements (e.g., if, else, while, etc.). 
             This typically means the function is simple and straightforward.
    2 or 3:  Functions with moderate complexity, having a few conditional paths or loops.
    4-7:     These functions are more complex, with multiple decision points and/or nested control structures.
    Above 7: Indicates higher complexity, which can make the function harder to test and maintain.
                "
                }

            }
            '8' {
                Show-Header -HeaderText "Save Project State"
                if (-not (Test-Path $ProjectfilePath)) {
                    try {
                        Save-ProjectState -FilePath $ProjectfilePath -GlobalState $GlobalState
                        if (Test-Path -Path $ProjectfilePath) {
                            Write-Information "++ Project state saved successfully to $ProjectfilePath" -InformationAction Continue
                        }
                        else {
                            Write-Warning "-- Project state was not saved. Please check the file path and try again."
                        }
                    }
                    catch {
                        Write-Error "!! An error occurred while saving the project state: $_"
                    }
                }
                else {
                    $userChoice = Read-Host -Prompt "File 'Project.xml' exists. Do you want to save now? (Y/N)"
                    if ($userChoice -eq 'Y' -or $userChoice -eq 'y') {
                        Save-ProjectState -FilePath $ProjectfilePath -GlobalState $GlobalState
                        if (Test-Path -Path $ProjectfilePath) {
                            Write-Information "++ Project state saved successfully to $ProjectfilePath" -InformationAction Continue
                        }
                        else {
                            Write-Warning "-- Project state was not saved. Please check the file path and try again."
                        }
                    }
                }
                
            }
            '9' {
                # Option 9: Code Refactoring Suggestions
                Show-Header -HeaderText "Code Refactoring Suggestions"
                $promptMessage = "Provide suggestions for refactoring the code to improve readability, maintainability, and performance."
                $MenuPrompt_ = $MenuPromptNoUserChanges -f $promptMessage, $GlobalState.lastPSDevCode
                $MenuPrompt_ += "`nShow only suggestions. No code"
                $refactoringSuggestions = $powerShellDeveloper.ProcessInput($MenuPrompt_)
                $GlobalState.GlobalPSDevResponse += $refactoringSuggestions
                Add-ToGlobalResponses $GlobalState $refactoringSuggestions

                # Display the refactoring suggestions to the user
                #Show-Header -HeaderText "Refactoring Suggestions Report"
                #Write-Output $refactoringSuggestions

                # Ask the user if they want to deploy the refactoring suggestions
                $deployChoice = Read-Host -Prompt "Do you want to deploy these refactoring suggestions? (Y/N)"
                if ($deployChoice -eq 'Y' -or $deployChoice -eq 'y') {
                    $deployPromptMessage = "Deploy the refactoring suggestions into the code. Show the next version of the code."
                    $DeployMenuPrompt_ = $MenuPrompt -f $deployPromptMessage, $refactoringSuggestions, $GlobalState.lastPSDevCode
                    $powerShellDeveloperResponce = $powerShellDeveloper.ProcessInput($DeployMenuPrompt_)
                    #$GlobalState.GlobalPSDevResponse += $powerShellDeveloperResponce
                    Add-ToGlobalPSDevResponses $GlobalState $powerShellDeveloperResponce
                    Add-ToGlobalResponses $GlobalState $powerShellDeveloperResponce
                    Save-AndUpdateCode -response $powerShellDeveloperResponce -GlobalState $GlobalState
                }
                else {
                    Write-Output "Refactoring suggestions were not deployed."
                }
            }
            '10' {
                # Option 10: Security Audit
                Show-Header -HeaderText "Security Audit"
                $promptMessage = "Conduct a security audit of the code to identify potential vulnerabilities and ensure best security practices are followed. Show only security audit report."
                $MenuPrompt_ = $MenuPromptNoUserChanges -f $promptMessage, $GlobalState.lastPSDevCode
                $MenuPrompt_ += "`nShow only security audit report. No Code."
                $powerShellDevelopersecurityAuditReport = $powerShellDeveloper.ProcessInput($MenuPrompt_)
                $GlobalState.GlobalPSDevResponse += $powerShellDevelopersecurityAuditReport
                Add-ToGlobalResponses $GlobalState $powerShellDevelopersecurityAuditReport

                # Display the security audit report to the user
                Show-Header -HeaderText "Security Audit Report"
                Write-Output $powerShellDevelopersecurityAuditReport

                # Ask the user if they want to deploy the security improvements
                $deployChoice = Read-Host -Prompt "Do you want to deploy these security improvements? (Y/N)"
                if ($deployChoice -eq 'Y' -or $deployChoice -eq 'y') {
                    $deployPromptMessage = "Deploy the security improvements into the code. Show the next version of the code."
                    $DeployMenuPrompt_ = $MenuPrompt -f $deployPromptMessage, $powerShellDevelopersecurityAuditReport, $GlobalState.lastPSDevCode
                    $powerShellDeveloperResponce = $powerShellDeveloper.ProcessInput($DeployMenuPrompt_)
                    #$GlobalState.GlobalPSDevResponse += $powerShellDeveloperResponce
                    Add-ToGlobalPSDevResponses $GlobalState $powerShellDeveloperResponce
                    Add-ToGlobalResponses $GlobalState $powerShellDeveloperResponce
                    Save-AndUpdateCode -response $powerShellDeveloperResponce -GlobalState $GlobalState
                }
                else {
                    Write-Output "Security improvements were not deployed."
                }
            }
            '11' {
                # Option 11: Open project folder in file explorer
                Show-Header -HeaderText "Open Project Folder in File Explorer"
                try {
                    if ($GlobalState.TeamDiscussionDataFolder) {
                        Start-Process explorer.exe -ArgumentList $GlobalState.TeamDiscussionDataFolder
                        Write-Host "Project folder opened in File Explorer."
                    }
                    else {
                        Write-Host "-- The project folder path is not set. Please ensure the TeamDiscussionDataFolder is defined."
                    }
                }
                catch {
                    Write-Error "-- An error occurred while trying to open the project folder: $_"
                }
            }
            'e' {
                if (Test-Path -Path (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")) {
                    $errorContent = Get-Content -Path (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt") -Raw
                    Show-Header -HeaderText "Content of ERROR.txt"
                    Write-Output $errorContent
                }
                else {
                    Write-Output "No error file found."
                }
            }
            default {
                # Handle invalid options
                Write-Information "-- Invalid option. Please try again." -InformationAction Continue
                continue
            }
        }
    }
} while ($userOption -ne 'Q') # End the loop when the user chooses to quit
#endregion Menu

#region Final code
if (-not $GlobalState.NOLog) {
    # Log Developer last memory
    $TheFinalCodeFullName = Join-Path $GlobalState.TeamDiscussionDataFolder "TheCodeF.PS1"
    $GlobalState.lastPSDevCode | Out-File -FilePath $TheFinalCodeFullName
    #Export-AndWritePowerShellCodeBlocks -InputString $(get-content $(join-path $GlobalState.TeamDiscussionDataFolder "TheCodeF.log") -raw) -OutputFilePath $(join-path $GlobalState.TeamDiscussionDataFolder "TheCode.ps1") -StartDelimiter '```powershell' -EndDelimiter '```'
    if (Test-Path -Path $TheFinalCodeFullName) {
        # Call the function to check the code in 'TheCode.ps1' file
        Write-Information "++ The final code was exported to $TheFinalCodeFullName" -InformationAction Continue
        $issues = Invoke-CodeWithPSScriptAnalyzer -FilePath $TheFinalCodeFullName
        if ($issues) {
            write-output ($issues | Select-Object line, message | format-table -AutoSize -Wrap)
        }
    }
    foreach ($TeamMember in $Team) {
        $TeamMember.DisplayInfo(0) | Out-File -FilePath $TeamMember.LogFilePath -Append
    }
    Write-Host "++ " -NoNewline
    Stop-Transcript
}
else {
    #Export-AndWritePowerShellCodeBlocks -InputString $($powerShellDeveloper.GetLastMemory().Response) -StartDelimiter '```powershell' -EndDelimiter '```' -OutputFilePath $(join-path ([System.Environment]::GetEnvironmentVariable("TEMP", "user")) "TheCodeF.ps1")
    # Call the function to check the code in 'TheCode.ps1' file
    $issues = Invoke-CodeWithPSScriptAnalyzer -ScriptBlock $GlobalState.lastPSDevCode
    if ($issues) {
        write-output ($issues | Select-Object line, message | format-table -AutoSize -Wrap)
    }
}
#endregion Final code
Save-ProjectState -FilePath $ProjectfilePath -GlobalState $GlobalState
if ($ProjectfilePath) {
    Write-Host "`n`n++ Your progress on Project has been saved!`n`n"
    Write-Host "++ You can resume working on this project at any time by loading the saved state. Just run:`nAIPSTeam.ps1 -LoadProjectStatus `"$ProjectfilePath`"`n`n"
}

Write-Host "Exiting..."

# Ensure to reset the culture back to the original after the script execution
[void](Register-EngineEvent PowerShell.Exiting -Action { [Threading.Thread]::CurrentThread.CurrentUICulture = $originalCulture })

#endregion Main
