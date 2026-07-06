function Build-AgentSpecArchitecture {
    param([object]$RawIdea)

    if ([string]::IsNullOrWhiteSpace($RawIdea.problem)) {
        throw "Raw idea problem is required."
    }

    $NormalizedTargetAgentId = ($RawIdea.problem.ToLower() -replace '[^a-z0-9]+', '_').Trim('_')

    if ([string]::IsNullOrWhiteSpace($NormalizedTargetAgentId)) {
        $NormalizedTargetAgentId = "generated_agent"
    }

    $ProblemText = ""
    if ($null -ne $RawIdea.problem) {
        $ProblemText = [string]$RawIdea.problem
    }

    $OperatorGoalText = ""
    if ($null -ne $RawIdea.operator_goal) {
        $OperatorGoalText = [string]$RawIdea.operator_goal
    }

    $ExpectedJoined = @($RawIdea.expected_outputs) -join " "

    $ClassificationText = @(
        $ProblemText,
        $OperatorGoalText,
        $ExpectedJoined
    ) -join " "

    $AgentKind = "decision_support_agent"

    if ($ClassificationText -match "\b(audit|audits|finding|findings|report|reports)\b") {
        $AgentKind = "audit_agent"
    }
    elseif ($ClassificationText -match "\b(template|templates|document|documents|spec|specs|specification|specifications)\b") {
        $AgentKind = "specification_agent"
    }
    elseif ($ClassificationText -match "\b(workflow|workflows|runbook|runbooks|orchestration|execution agent|task runner)\b") {
        $AgentKind = "workflow_execution_agent"
    }
    elseif ($ClassificationText -match "\b(monitoring|monitor|monitors|alert|alerts|telemetry|watchdog)\b") {
        $AgentKind = "monitoring_agent"
    }

    return [pscustomobject]@{
        normalized_intent = [ordered]@{
            problem = $RawIdea.problem
            target_user = $RawIdea.target_user
            operator_goal = $RawIdea.operator_goal
        }
        proposed_agent_kind = $AgentKind
        suggested_package_profile = "operational_specialized"
        normalized_target_agent_id = $NormalizedTargetAgentId
        required_inputs = @(
            "structured request payload"
        )
        required_outputs = @(
            "structured architecture result",
            "draft production spec"
        )
        validation_expectations = @(
            "input payload fields exist",
            "architecture result is emitted",
            "production spec draft is present"
        )
        forbidden_scope = @($RawIdea.non_goals)
        build_readiness = "READY_FOR_SPEC_REVIEW"
        production_spec_draft = [ordered]@{
            agent_id = $NormalizedTargetAgentId
            display_name = "Draft $NormalizedTargetAgentId"
            mission = "Convert a raw operator idea into a reviewed production agent specification."
            agent_kind = $AgentKind
            package_profile = "operational_specialized"
            runtime = [ordered]@{
                shell = "PowerShell"
                entrypoint = "orchestrator/run.ps1"
            }
            inputs = @(
                [ordered]@{
                    name = "request"
                    type = "json"
                    required = $true
                    description = "Structured operator idea payload."
                }
            )
            outputs = @(
                [ordered]@{
                    name = "result"
                    type = "json"
                    required = $true
                    description = "Structured architecture result and draft spec."
                }
            )
            capabilities = @(
                "normalize raw agent idea",
                "propose agent architecture",
                "emit draft production spec"
            )
            validation = @(
                "architecture result exists",
                "build readiness exists",
                "draft spec exists"
            )
            forbidden_scope = @($RawIdea.non_goals)
        }
    }
}
