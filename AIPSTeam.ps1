<#PSScriptInfo
.VERSION 2.0.1
.GUID f0f4316d-f106-43b5-936d-0dd93a49be6b
.AUTHOR voytas75
.TAGS ai,psaoai,llm,project,team,gpt
.PROJECTURI https://github.com/voytas75/AzureOpenAI-PowerShell/tree/master/AIPSTeam/README.md
.EXTERNALMODULEDEPENDENCIES PSAOAI, PSScriptAnalyzer
.RELEASENOTES
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

<# 
.SYNOPSIS 
This script emulates a team of specialists working together on a PowerShell project.

.DESCRIPTION 
The script simulates a team of specialists, each with a unique role in executing a project. The user input is processed by one specialist who performs their task and passes the result to the next specialist. This process continues until all tasks are completed.

.PARAMETER userInput 
Defines the project outline as a string. Default is to monitor RAM usage and show a color block based on the load. This parameter can also accept input from the pipeline.

.PARAMETER Stream 
Controls whether the output should be streamed live. Default is `$true`.

.PARAMETER NOPM 
Disables the Project Manager functions when used.

.PARAMETER NODocumentator 
Disables the Documentator functions when used.

.PARAMETER NOLog
Disables the logging functions when used.

.PARAMETER NOTips
Disables tips.

.PARAMETER VerbosePrompt
Show Prompts.

.PARAMETER LogFolder
Specifies the folder where logs should be stored.

.PARAMETER DeploymentChat
Specifies the deployment chat environment variable for PSAOAI. Default is retrieved from the environment variable `PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT`.

.PARAMETER LoadProjectStatus
Loads the project status from a specified path. Part of the 'LoadStatus' parameter set.

.PARAMETER MaxTokens
Specifies the maximum number of tokens to generate in the response. Default is 20480.

.PARAMETER LLMProvider
Specifies the LLM provider to use (e.g., ollama, LMStudio, AzureOpenAI). Default is "AzureOpenAI".

.INPUTS 
System.String. You can pipe a string to the 'userInput' parameter.

.OUTPUTS 
The output varies depending on how each specialist processes their part of the project. Typically, text-based results are expected, which may include status messages or visual representations like graphs or color blocks related to system metrics such as RAM load, depending on the user input specification provided via the 'userInput' parameter.

.EXAMPLE 
PS> "A PowerShell project to monitor CPU usage and display dynamic graph." | .\AIPSTeam.ps1 -Stream $false

This command runs the script without streaming output live (-Stream $false) and specifies custom user input about monitoring CPU usage instead of RAM, displaying it through dynamic graphing methods rather than static color blocks.

.NOTES 
Version: 2.0.1
Author: voytas75
Creation Date: 05.2024
Purpose/Change: Initial release for emulating teamwork within PowerShell scripting context, rest in PSScriptInfo Releasenotes.

.LINK
https://www.powershellgallery.com/packages/AIPSTeam
https://github.com/voytas75/AzureOpenAI-PowerShell/tree/master/AIPSTeam/README.md
#>
param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $true, HelpMessage = "Defines the project outline as a string. Default is to monitor RAM usage and show a color block based on the load.")]
    [string] $userInput = "Monitor RAM usage and show a single color block based on the load.",

    [Parameter(Mandatory = $false, HelpMessage = "Controls whether the output should be streamed live. Default is `$true.")]
    [bool] $Stream = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Disables the Project Manager functions when used.")]
    [switch] $NOPM,

    [Parameter(Mandatory = $false, HelpMessage = "Disables the Documentator functions when used.")]
    [switch] $NODocumentator,

    [Parameter(Mandatory = $false, HelpMessage = "Disables the logging functions when used.")]
    [switch] $NOLog,

    [Parameter(Mandatory = $false, HelpMessage = "Disables tips.")]
    [switch] $NOTips,

    [Parameter(Mandatory = $false, HelpMessage = "Show Prompts.")]
    [switch] $VerbosePrompt,

    [Parameter(Mandatory = $false, HelpMessage = "Specifies the folder where logs should be stored.")]
    [string] $LogFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Specifies the deployment chat environment variable for PSAOAI.")]
    [string] $DeploymentChat = [System.Environment]::GetEnvironmentVariable("PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT", "User"),

    [Parameter(Mandatory = $false, ParameterSetName = 'LoadStatus', HelpMessage = "Loads the project status from a specified path.")]
    [string] $LoadProjectStatus,

    [Parameter(Mandatory = $false, HelpMessage = "Specifies the maximum number of tokens to generate in the response. Default is 20480.")]
    [int] $MaxTokens = 20480,

    [Parameter(Mandatory = $false, HelpMessage = "Specifies the LLM provider to use (e.g., OpenAI, AzureOpenAI).")]
    [ValidateSet("AzureOpenAI", "ollama", "LMStudio", "OpenAI" )]
    [string]$LLMProvider = "AzureOpenAI"
)
$AIPSTeamVersion = "2.0.1"

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
    [scriptblock] $ResponseFunction  # Function to process the input and generate a response
    [string] $LogFilePath  # Path to the log file
    [array] $FeedbackTeam  # Team of experts providing feedback
    [PSCustomObject] $GlobalState
    [string] $LLMProvider
    
    # Constructor for the ProjectTeam class
    ProjectTeam([string] $name, [string] $role, [string] $prompt, [double] $temperature, [double] $top_p, [scriptblock] $responseFunction, [PSCustomObject] $GlobalState) {
        $this.Name = $name
        $this.Role = $role
        $this.Prompt = $prompt
        $this.NextExpert = $null
        $this.ResponseMemory = @()
        $this.Temperature = $temperature
        $this.TopP = $top_p
        $this.Status = "Not Started"
        $this.Log = @()
        $this.ResponseFunction = $responseFunction
        $this.GlobalState = $GlobalState
        $this.LogFilePath = "$($GlobalState.TeamDiscussionDataFolder)\$name.log"
        $this.FeedbackTeam = @()
        $this.LLMProvider = "AzureOpenAI"  # Default to AzureOpenAI, can be changed as needed
        
    }

    # Method to display the team member's information
    [PSCustomObject] DisplayInfo([int] $display = 1) {
        # Create an ordered dictionary to store the information
        $info = [ordered]@{
            "Name"              = $this.Name
            "Role"              = $this.Role
            "System prompt"     = $this.Prompt
            "Temperature"       = $this.Temperature
            "TopP"              = $this.TopP
            "Responses"         = $this.ResponseMemory | ForEach-Object { "[$($_.Timestamp)] $($_.Response)" }
            "Log"               = $this.Log -join ', '
            "Log File Path"     = $this.LogFilePath
            "Feedback Team"     = $this.FeedbackTeam
            "Next Expert"       = $this.NextExpert
            "Status"            = $this.Status
            "Response Function" = $this.ResponseFunction
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
            Write-Host "Response Function: $($infoObject.'Response Function')"
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
        try {
            Write-verbose $script:MaxTokens

            #Write-Host $userinput -ForegroundColor Cyan
            # Use the user-provided function to get the response
            #$response = & $this.ResponseFunction -SystemPrompt $this.Prompt -UserPrompt $userinput -Temperature $this.Temperature -TopP $this.TopP -MaxTokens $script:MaxTokens
            $response = Invoke-LLMChatCompletion -Provider $this.LLMProvider -SystemPrompt $this.Prompt -UserPrompt $userinput -Temperature $this.Temperature -TopP $this.TopP -MaxTokens $script:MaxTokens -Stream $script:Stream -LogFolder $script:GlobalState.TeamDiscussionDataFolder -DeploymentChat $script:DeploymentChat -ollamaModel $script:ollamaModel
 
            if (-not $script:Stream) {
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

    [string] Feedback([ProjectTeam] $AssessedExpert, [string] $Expertinput) {
        Show-Header -HeaderText "Feedback by $($this.Name) ($($this.Role)) for $($AssessedExpert.name)"
        
        # Log the input
        $this.AddLogEntry("Processing input:`n$Expertinput")
        
        # Update status
        $this.Status = "In Progress"
        
        try {
            # Ensure ResponseMemory is initialized
            if ($null -eq $this.ResponseMemory) {
                $this.ResponseMemory = @()
                $this.AddLogEntry("Initialized ResponseMemory")
            }
            
            # Use the user-provided function to get the response
            #$response = & $this.ResponseFunction -SystemPrompt $this.Prompt -UserPrompt $Expertinput -Temperature $this.Temperature -TopP $this.TopP -MaxTokens $script:MaxTokens
            $response = Invoke-LLMChatCompletion -Provider $this.LLMProvider -SystemPrompt $this.Prompt -UserPrompt $Expertinput -Temperature $this.Temperature -TopP $this.TopP -MaxTokens $script:MaxTokens -Stream $script:Stream -LogFolder $script:GlobalState.TeamDiscussionDataFolder -DeploymentChat $script:DeploymentChat -ollamaModel $script:ollamaModel

            if (-not $script:stream) {
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

        try {
            # Use the user-provided function to get the summary
            #$summary = & $this.ResponseFunction -SystemPrompt $fullPrompt -UserPrompt "" -Temperature 0.7 -TopP 0.9 -MaxTokens $script:MaxTokens
            $summary = Invoke-LLMChatCompletion -Provider $this.LLMProvider -SystemPrompt $fullPrompt -UserPrompt "" -Temperature 0.7 -TopP 0.7 -MaxTokens $script:MaxTokens -Stream $script:Stream -LogFolder $script:GlobalState.TeamDiscussionDataFolder -DeploymentChat $script:DeploymentChat -ollamaModel $script:ollamaModel
       
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
            $feedback = SendFeedbackRequest -TeamMember $FeedbackMember.Role -Response $response -Prompt $FeedbackMember.Prompt -Temperature $this.Temperature -TopP $this.TopP -ResponseFunction $this.ResponseFunction
        
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
function SendFeedbackRequest {
    param (
        [string] $TeamMember, # The team member to send the feedback request to
        [string] $Response, # The response to be reviewed
        [string] $Prompt, # The prompt for the feedback request
        [double] $Temperature, # The temperature parameter for the LLM model
        [double] $TopP, # The TopP parameter for the LLM model
        [scriptblock] $ResponseFunction, # The function to generate the response
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
        $feedback = & $ResponseFunction -SystemPrompt $SystemPrompt -UserPrompt $NewResponse -Temperature $Temperature -TopP $TopP -MaxTokens $script:MaxTokens

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
    /$$__  $$|_  $$_/| $$__  $$ /$$__  $$|__  $$__/                               
   | $$  \ $$  | $$  | $$  \ $$| $$  \__/   | $$  /$$$$$$   /$$$$$$  /$$$$$$/$$$$ 
   | $$$$$$$$  | $$  | $$$$$$$/|  $$$$$$    | $$ /$$__  $$ |____  $$| $$_  $$_  $$
   | $$__  $$  | $$  | $$____/  \____  $$   | $$| $$$$$$$$  /$$$$$$$| $$ \ $$ \ $$
   | $$  | $$  | $$  | $$       /$$  \ $$   | $$| $$_____/ /$$__  $$| $$ | $$ | $$
   | $$  | $$ /$$$$$$| $$      |  $$$$$$/   | $$|  $$$$$$$|  $$$$$$$| $$ | $$ | $$
   |__/  |__/|______/|__/       \______/    |__/ \_______/ \_______/|__/ |__/ |__/ 
                                                                                  
   AI PowerShell Team                                     powered by PSAOAI Module
                                                                     Ollama
                                                                     LM Studio
         
       https://github.com/voytas75/AzureOpenAI-PowerShell/tree/master/AIPSTeam
  
'@
    Write-Host @"
         The script is designed to simulate a project team working on a PowerShell project. The script creates different   
         roles such as Requirements Analyst, System Architect, PowerShell Developer, QA Engineer, Documentation Specialist, 
         and Project Manager. Each role has specific tasks and responsibilities, and they interact with each other 
         to complete a PS project. The script leverages LLMs providers like Azure OpenAI (PSAOAI), Ollama, and LM Studio.
         
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

        if ($tipAmount) {
            $feedbackPrompt += "`n`nNote: There is `$$tipAmount tip for this task."
        }
        # Get feedback from the role object
        $feedback = $Reviewer.Feedback($Recipient, $feedbackPrompt)

        # Add the feedback to global responses
        Add-ToGlobalResponses -GlobalState $GlobalState -response $feedback

        # Process the feedback and generate a response
        if ($tipAmount) {
            $response = $Recipient.ProcessInput("Modify Powershell code with suggested improvements and optimizations based on $($Reviewer.Name) review. The previous version of the code has been shared below after the feedback block.`n`n````````text`n" + $($Reviewer.GetLastMemory().Response) + "`n`````````n`nHere is previous version of the code:`n`n``````powershell`n$($GlobalState.LastPSDevCode)`n```````n`nShow the new version of PowerShell code. Think step by step. Make sure your answer is unbiased. I will tip you `$$tipAmount for the correct code. Use reliable sources like official documentation, research papers from reputable institutions, or widely used textbooks.")
        }
        else {
            $response = $Recipient.ProcessInput("Modify Powershell code with suggested improvements and optimizations based on $($Reviewer.Name) review. The previous version of the code has been shared below after the feedback block.`n`n````````text`n" + $($Reviewer.GetLastMemory().Response) + "`n`````````n`nHere is previous version of the code:`n`n``````powershell`n$($GlobalState.LastPSDevCode)`n```````n`nShow the new version of PowerShell code. Think step by step. Make sure your answer is unbiased. Use reliable sources like official documentation, research papers from reputable institutions, or widely used textbooks.")
        }

        return $response
    }    
    catch [System.Exception] {
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
        [string]$FilePath,
        [PSCustomObject] $GlobalState
    )
    try {
        $projectState = @{
            LastPSDevCode            = $GlobalState.lastPSDevCode
            FileVersion              = $GlobalState.FileVersion
            GlobalPSDevResponse      = $GlobalState.GlobalPSDevResponse
            GlobalResponse           = $GlobalState.GlobalResponse
            TeamDiscussionDataFolder = $GlobalState.TeamDiscussionDataFolder
            UserInput                = $GlobalState.userInput
            OrgUserInput             = $GlobalState.OrgUserInput
            LogFolder                = $GlobalState.LogFolder
        }
        $projectState | Export-Clixml -Path $FilePath
    }    
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")  
    }
}

function Get-ProjectState {
    param (
        [string]$FilePath
        #[PSCustomObject]$GlobalState
    )
    try {
        if (Test-Path -Path $FilePath) {
            $projectState = Import-Clixml -Path $FilePath
            $GlobalState.LastPSDevCode = $projectState.LastPSDevCode
            $GlobalState.FileVersion = $projectState.FileVersion
            $GlobalState.GlobalPSDevResponse = $projectState.GlobalPSDevResponse
            $GlobalState.TeamDiscussionDataFolder = $projectState.TeamDiscussionDataFolder
            $GlobalState.userInput = $projectState.UserInput
            $GlobalState.GlobalResponse = $projectState.GlobalResponse
            $GlobalState.OrgUserInput = $projectState.OrgUserInput
            $GlobalState.LogFolder = $projectState.LogFolder
            return $GlobalState
        }
        else {
            Write-Host "-- Project state file not found."
        }
    }    
    catch [System.Exception] {
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

    # Capture detailed error information
    $errorDetails = [ordered]@{
        Timestamp         = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ErrorMessage      = $ErrorRecord.Exception.Message
        ExceptionType     = $ErrorRecord.Exception.GetType().FullName
        ErrorContext      = $ErrorContext
        ScriptFullName    = $MyInvocation.ScriptName
        LineNumber        = $MyInvocation.ScriptLineNumber
        StackTrace        = $ErrorRecord.ScriptStackTrace
        UserName          = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        MachineName       = $env:COMPUTERNAME
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()

    } | ConvertTo-Json

    # Provide suggestions based on the error type
    $suggestions = switch -Regex ($ErrorMessage) {
        "PSScriptAnalyzer" {
            "Ensure the PSScriptAnalyzer module is installed and up-to-date. Use 'Install-Module -Name PSScriptAnalyzer' or 'Update-Module -Name PSScriptAnalyzer'."
        }
        "Invoke-PSAOAIChatCompletion" {
            "Check the PSAOAI module installation and the deployment chat environment variable. Ensure the API key and endpoint are correctly configured."
        }
        "UnauthorizedAccessException" {
            "Check the file permissions and ensure you have the necessary access rights to the file or directory."
        }
        "IOException" {
            "Ensure the file path is correct and the file is not being used by another process."
        }
        default {
            "Refer to the error message and stack trace for more details. Consult the official documentation or seek help from the community."
        }
    }

    # Display the error details and suggestions
    #Write-Host "-- Error: $($ErrorRecord.Exception.Message)"
    Write-Host "-- Context: $ErrorContext"
    Write-Host "-- Suggestions: $suggestions"
    Write-Host "-- Error: $($ErrorRecord.Exception.Message)"

    # Log the error details if LogFilePath is provided
    if ($LogFilePath) {
        $errorDetails | Out-File -FilePath $LogFilePath -Append -Force
        if (Test-Path -Path $LogFilePath) {
            Write-Host "Error details have been saved to the file: $LogFilePath" -ForegroundColor Yellow
        }
        else {
            Write-Host "The specified log file path does not exist: $LogFilePath" -ForegroundColor Red
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

    if ($VerbosePrompt) {
        Write-Host $SystemPrompt -ForegroundColor DarkMagenta
        Write-Host $UserPrompt -ForegroundColor DarkYellow
    }

    switch ($Provider) {
        "ollama" {
            if ($Stream) {
                Write-Information "-- Streaming is not implemented yet. Displaying information instead." -InformationAction Continue
                $script:stream = $false
                $stream = $false
            } 
            return Invoke-AIPSTeamOllamaCompletion -SystemPrompt $SystemPrompt -UserPrompt $UserPrompt -Temperature $Temperature -TopP $TopP -ollamaModel $ollamamodel -Stream $Stream
        }
        "LMStudio" {
            if ($Stream) {
                Write-Information "-- Streaming is not implemented yet. Displaying information instead." -InformationAction Continue
                $script:stream = $false
                $stream = $false
            } 
            $response = Invoke-AIPSTeamLMStudioChatCompletion -SystemPrompt $SystemPrompt -UserPrompt $UserPrompt -Temperature $Temperature -TopP $TopP -Stream $Stream -ApiKey "lm-studio" -endpoint "http://localhost:1234/v1/chat/completions"
            return $response
        }
        "OpenAI" {
            throw "-- Unsupported LLM provider: $Provider. This provider is not implemented yet."
        }
        "AzureOpenAI" {
            return Invoke-PSAOAIChatCompletion -SystemPrompt $SystemPrompt -usermessage $UserPrompt -Temperature $Temperature -TopP $TopP -Deployment $DeploymentChat -simpleresponse -OneTimeUserPrompt -Stream $script:Stream -LogFolder $GlobalState.TeamDiscussionDataFolder
            return Invoke-AIPSTeamAzureOpenAIChatCompletion -SystemPrompt $SystemPrompt -UserPrompt $UserPrompt -Temperature $Temperature -TopP $TopP -MaxTokens $MaxTokens -Stream $Stream -LogFolder $LogFolder -DeploymentChat $DeploymentChat
        }
        default {
            throw "!! Unknown LLM provider: $Provider"
        }
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
        [string]$DeploymentChat
    )

    # Call Azure OpenAI API
    $response = Invoke-PSAOAIChatCompletion -SystemPrompt $SystemPrompt -usermessage $UserPrompt -Temperature $Temperature -TopP $TopP -MaxTokens $MaxTokens -Stream $Stream -LogFolder $LogFolder -Deployment $DeploymentChat
    return $response
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
    Write-Information "++ Ollama ($($script:ollamamodel)) is working..." -InformationAction Continue
    $response = Invoke-WebRequest -Method POST -Body $ollamajson -uri "http://localhost:11434/api/generate"
    # Log the prompt and response to the log file
    $logEntry = @{
        Timestamp    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        SystemPrompt = $SystemPrompt
        UserPrompt   = $UserPrompt
        Response     = ($response).Content
    } | ConvertTo-Json
    
    $this.Log.Add($logEntry)
    # Log the summary
    $this.AddLogEntry("SystemPrompt:`n$SystemPrompt")
    $this.AddLogEntry("UserPrompt:`n$UserPrompt")
    $this.AddLogEntry("Response:`n$Response")

    return ($response).Content | convertfrom-json | Select-Object -ExpandProperty response
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
#endregion Functions

#region Setting Up
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
}
$GlobalState.LogFolder = $LogFolder

# Disabe PSAOAI importing banner
[System.Environment]::SetEnvironmentVariable("PSAOAI_BANNER", "0", "User")

if ((Get-Module -ListAvailable -Name PSAOAI | Where-Object { [version]$_.version -ge [version]"0.3.0" })) {
    [void](Import-module -name PSAOAI -Force)
}
else {
    Write-Warning "-- You need to install/update PSAOAI module version >= 0.2.1. Use: 'Install-Module PSAOAI' or 'Update-Module PSAOAI'"
    return
}
Show-Banner
$scriptname = "AIPSTeam"
if ($LoadProjectStatus) {
    # Load the project status from the specified file
    try {
        $GlobalState = Get-ProjectState -FilePath $LoadProjectStatus
        Write-Information "++ Project state loaded successfully from $LoadProjectStatus" -InformationAction Continue
        Write-Verbose "`$GlobalState.TeamDiscussionDataFolder: $($GlobalState.TeamDiscussionDataFolder)"
        Write-Verbose "`$GlobalState.FileVersion: $($GlobalState.FileVersion)"
        Write-Verbose "`$GlobalState.LastPSDevCode: $($GlobalState.LastPSDevCode)"
        Write-Verbose "`$GlobalState.GlobalPSDevResponse: $($GlobalState.GlobalPSDevResponse)"
        Write-Verbose "`$GlobalState.GlobalResponse: $($GlobalState.GlobalResponse)"
        Write-Verbose "`$GlobalState.OrgUserInput: $($GlobalState.OrgUserInput)"
        Write-Verbose "`$GlobalState.UserInput: $($GlobalState.UserInput)"
        Write-Verbose "`$GlobalState.LogFolder: $($GlobalState.LogFolder)"
    }    
    catch [System.Exception] {
        Update-ErrorHandling -ErrorRecord $_ -LogFilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ERROR.txt")
    }
}
else {
    Try {
        # Get the current date and time
        $currentDateTime = Get-Date -Format "yyyyMMdd_HHmmss"
        if (-not [string]::IsNullOrEmpty($GlobalState.LogFolder)) {
            # Create a folder with the current date and time as the name in the example path
            $GlobalState.TeamDiscussionDataFolder = New-FolderAtPath -Path $GlobalState.LogFolder -FolderName $currentDateTime
        }
        else {
            $GlobalState.LogFolder = Join-Path -Path ([Environment]::GetFolderPath("MyDocuments")) -ChildPath $scriptname
            if (-not (Test-Path -Path $GlobalState.LogFolder)) {
                New-Item -ItemType Directory -Path $GlobalState.LogFolder | Out-Null
            }
            Write-Information "++ The logs will be saved in the following folder: $($GlobalState.LogFolder)" -InformationAction Continue
            # Create a folder with the current date and time as the name in the example path
            $GlobalState.TeamDiscussionDataFolder = New-FolderAtPath -Path $GlobalState.LogFolder -FolderName $currentDateTime
        }
        if ($GlobalState.TeamDiscussionDataFolder) {
            Write-Information "++ Team discussion folder was created '$($GlobalState.TeamDiscussionDataFolder)'" -InformationAction Continue
        }
    }
    Catch {
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
    [scriptblock]::Create({
            param ($SystemPrompt, $UserPrompt, $Temperature, $TopP)
            $response = Invoke-PSAOAIChatCompletion -SystemPrompt $SystemPrompt -usermessage $UserPrompt -Temperature $Temperature -TopP $TopP -Deployment $DeploymentChat -simpleresponse -OneTimeUserPrompt -Stream $script:Stream -LogFolder $GlobalState.TeamDiscussionDataFolder
            return $response
        }),
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
    [scriptblock]::Create({
            param ($SystemPrompt, $UserPrompt, $Temperature, $TopP)
            $response = Invoke-PSAOAIChatCompletion -SystemPrompt $SystemPrompt -usermessage $UserPrompt -Temperature $Temperature -TopP $TopP -Deployment $DeploymentChat -simpleresponse -OneTimeUserPrompt -Stream $script:Stream
            return $response
        }),
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
    [scriptblock]::Create({
            param ($SystemPrompt, $UserPrompt, $Temperature, $TopP)
            $response = Invoke-PSAOAIChatCompletion -SystemPrompt $SystemPrompt -usermessage $UserPrompt -Temperature $Temperature -TopP $TopP -Deployment $DeploymentChat -simpleresponse -OneTimeUserPrompt -Stream $script:Stream -LogFolder $GlobalState.TeamDiscussionDataFolder
            return $response
        }),
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
    [scriptblock]::Create({
            param ($SystemPrompt, $UserPrompt, $Temperature, $TopP)
            $response = Invoke-PSAOAIChatCompletion -SystemPrompt $SystemPrompt -usermessage $UserPrompt -Temperature $Temperature -TopP $TopP -Deployment $DeploymentChat -simpleresponse -OneTimeUserPrompt -Stream $script:Stream -LogFolder $GlobalState.TeamDiscussionDataFolder
            return $response
        }),
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
    [scriptblock]::Create({
            param ($SystemPrompt, $UserPrompt, $Temperature, $TopP)
            $response = Invoke-PSAOAIChatCompletion -SystemPrompt $SystemPrompt -usermessage $UserPrompt -Temperature $Temperature -TopP $TopP -Deployment $DeploymentChat -simpleresponse -OneTimeUserPrompt -Stream $script:Stream -LogFolder $GlobalState.TeamDiscussionDataFolder
            return $response
        }),
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
    [scriptblock]::Create({
            param ($SystemPrompt, $UserPrompt, $Temperature, $TopP)
            $response = Invoke-PSAOAIChatCompletion -SystemPrompt $SystemPrompt -usermessage $UserPrompt -Temperature $Temperature -TopP $TopP -Deployment $DeploymentChat -simpleresponse -OneTimeUserPrompt -Stream $script:Stream -LogFolder $GlobalState.TeamDiscussionDataFolder
            return $response
        }),
    $GlobalState
)

$projectManagerRole = "Project Manager"
$projectManager = [ProjectTeam]::new(
    "Manager",
    $projectManagerRole,
    @"
You act as {0}. Your task is to provide a comprehensive summary of the PowerShell project based on the completed tasks of each expert. This includes:
- Reviewing the documented requirements from the Requirements Analyst.
- Summarizing the architectural design created by the System Architect.
- Detailing the script development work done by the PowerShell Developer.
- Reporting the testing results and issues found by the QA Engineer.
- Highlighting the documentation prepared by the Documentation Specialist.
- Compiling these summaries into a final project report.
- Identifying key achievements, challenges faced, and lessons learned throughout the project.
- Ensuring that all aspects of the project are covered and documented comprehensively.
- Providing a clear and concise summary that reflects the overall progress and status of the project.
- Including a section on risk management and mitigation strategies.
- Ensuring regular updates and progress reports are included.
- Conducting a post-project review and feedback session.
"@ -f $projectManagerRole,
    0.7,
    0.85,
    [scriptblock]::Create({
            param ($SystemPrompt, $UserPrompt, $Temperature, $TopP)
            $response = Invoke-PSAOAIChatCompletion -SystemPrompt $SystemPrompt -usermessage $UserPrompt -Temperature $Temperature -TopP $TopP -Deployment $DeploymentChat -simpleresponse -OneTimeUserPrompt -Stream $script:Stream -LogFolder $GlobalState.TeamDiscussionDataFolder
            return $response
        }),
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

if ($LLMProvider -eq "ollama" -and -not [string]::IsNullOrEmpty($env:OLLAMA_MODEL)) {
    $script:ollamaModel = $env:OLLAMA_MODEL
}
elseif ($LLMProvider -eq "ollama") {
    $script:ollamaModel = Read-Host "Please provide the LLM model for ollama"
}

if ($NOLog) {
    foreach ($TeamMember_ in $Team) {
        $TeamMember_.LogFilePath = ""
    }
}

if (-not $NOLog) {
    foreach ($TeamMember in $Team) {
        $TeamMember.DisplayInfo(0) | Out-File -FilePath $TeamMember.LogFilePath -Append
    }
    Write-Host "++ " -NoNewline
    Start-Transcript -Path (join-path $GlobalState.TeamDiscussionDataFolder "TRANSCRIPT.log") -Append
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
Write detailed and concise PowerShell project name, description, objectives, deliverables, additional considerations, and success criteria based on user input.

###User input###

````````text
$userInputOryginal
````````
"@
    if (-not $NOTips) {
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
    if (-not $NOTips) {
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
    if ($NOTips) {
        Invoke-ProcessFeedbackAndResponse -reviewer $requirementsAnalyst -recipient $powerShellDeveloper -GlobalState $GlobalState
    }
    else {
        Invoke-ProcessFeedbackAndResponse -reviewer $requirementsAnalyst -recipient $powerShellDeveloper -GlobalState $GlobalState -tipAmount 100
    }
    #endregion RA-PSDev

    #region SA-PSDev
    if ($NOTips) {
        Invoke-ProcessFeedbackAndResponse -reviewer $systemArchitect -recipient $powerShellDeveloper -GlobalState $GlobalState
    }
    else {
        Invoke-ProcessFeedbackAndResponse -reviewer $systemArchitect -recipient $powerShellDeveloper -GlobalState $GlobalState -tipAmount 150
    }

    #endregion SA-PSDev

    #region DE-PSDev
    if ($NOTips) {
        Invoke-ProcessFeedbackAndResponse -reviewer $domainExpert -recipient $powerShellDeveloper -GlobalState $GlobalState
    }
    else {
        Invoke-ProcessFeedbackAndResponse -reviewer $domainExpert -recipient $powerShellDeveloper -GlobalState $GlobalState -tipAmount 200
    }
    #endregion DE-PSDev

    #region QAE-PSDev
    if ($NOTips) {
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
    if (-not $NODocumentator) {
        if (-not $NOLog) {
            $documentationSpecialistResponce = $documentationSpecialist.ProcessInput($GlobalState.lastPSDevCode) | Out-File -FilePath $DocumentationFullName
        }
        else {
            $documentationSpecialistResponce = $documentationSpecialist.ProcessInput($GlobalState.lastPSDevCode)
        }
        Add-ToGlobalResponses $GlobalState $documentationSpecialistResponce
    }
    #endregion Doc
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
    Write-Host "11. (Q)uit"

    # Get the user's choice
    $userOption = Read-Host -Prompt "Enter your choice"
    Write-Output ""

    # Process the user's choice if it's not 'Q' or '9' (both of which mean 'quit')
    if ($userOption -ne 'Q' -and $userOption -ne "11") {
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
                        $documentationSpecialistResponce = $documentationSpecialist.ProcessInput($lastPSDevCode)
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
            default {
                # Handle invalid options
                Write-Information "-- Invalid option. Please try again." -InformationAction Continue
                continue
            }
        }
    }
} while ($userOption -ne 'Q' -and $userOption -ne "11" ) # End the loop when the user chooses to quit
#endregion Menu

#region PM Project report
if (-not $NOPM) {
    # Example of summarizing all steps,  Log final response to file
    if (-not $NOLog) {
        $projectManagerResponse = $projectManager.ProcessInput($GlobalState.GlobalResponse -join ", ") | Out-File -FilePath (Join-Path $GlobalState.TeamDiscussionDataFolder "ProjectSummary.log")
    }
    else {
        $projectManagerResponse = $projectManager.ProcessInput($GlobalState.GlobalResponse -join ", ")
    }
    Add-ToGlobalResponses $GlobalState $projectManagerResponse
}
#endregion PM Project report

#region Final code
if (-not $NOLog) {
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
#endregion Main
