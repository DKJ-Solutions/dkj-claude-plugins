<#
.SYNOPSIS
    The one place dkj-subagents-shopify's scripts invoke the Shopify CLI: Invoke-ShopifyCli, which lowers
    $ErrorActionPreference for the duration of the call so the caller's $LASTEXITCODE check is
    actually reached.

.DESCRIPTION
    WHY THIS EXISTS, AND WHY IT IS NOT A STYLE PREFERENCE (inbound #1183, September 1, 2026). Every
    script here runs under $ErrorActionPreference = 'Stop'. In Windows PowerShell 5.1 a single stderr
    line from a native executable becomes an ErrorRecord, and under 'Stop' that ErrorRecord is
    TERMINATING -- at exit code 0 as much as at any other. A bare

        & shopify theme pull --store $store --theme $liveId --path $mirror
        if ($LASTEXITCODE -ne 0) { <clean up the mirror; report; exit 1> }

    therefore dies on the line AFTER the call, and the block that was written to handle the failure
    never runs. What was measured was not a slower failure but a DIFFERENT one: the temp mirror is left
    behind and the script's own "The Shopify pull failed. Nothing was touched." is never printed.

    WHAT MADE IT ARRIVE NOW: the CLI writes a hint line to stderr WHILE SUCCEEDING when it runs under
    Claude Code --

        node.exe : <claude-code-hint v="1" type="plugin" value="shopify-ai-toolkit@claude-plugins-official" />
        At C:\Users\<user>\AppData\Roaming\npm\shopify.ps1:24 char:5
            + CategoryInfo          : NotSpecified: (...) [], RemoteException
            + FullyQualifiedErrorId : NativeCommandError

    -- so the exit code stayed 0 and the script died anyway. Confirmed in a consumer on a captured
    'shopify theme list --json' (BWJ-ecommerce/smartwatchbanden#433). THE ENVIRONMENT CHANGED, NOT THE
    CODE, and that is the whole argument for a wrapper: a bare native call is only safe while the exe
    never writes to stderr, which is not a property any calling script controls.

    READ THE STACK: THE ErrorRecord IS RAISED ONE FRAME IN, INSIDE THE SHIM. On Windows 'shopify' is not
    an .exe at all -- it is the npm-generated PowerShell shim %APPDATA%\npm\shopify.ps1, and its line 24
    (measured against the shim installed here) is the bare '& "node$exe" ... $args' that actually starts
    the CLI. '& shopify' runs that script IN-PROCESS, so it inherits the caller's preference variables:
    measured on this machine, a shim invoked from a script at 'Stop' reports $ErrorActionPreference =
    'Stop' inside itself. That is the fact this repair rests on, and it has two consequences the report
    that filed this did not draw:

      * LOWERING EAP AROUND THE CALL REACHES THE SHIM. There is nothing else to reach -- the frame that
        wraps node's stderr runs under OUR preference, so the wrapper fixes it at the only place it can
        be fixed. A try/catch at the call site would merely turn the death into a caught exception,
        still with $LASTEXITCODE never judged.
      * WHETHER THE CALL SITE CAPTURES IS NOT THE DISCRIMINATOR. The report treated the confirmed
        instance (a captured 'theme list --json') as the stronger case and scoped the uncaptured
        'theme pull' as "same class, not separately reproduced". They are the same MECHANISM: the frame
        that wraps stderr is inside the shim, not at our line. So all four bare call sites in this
        plugin are equally exposed, and all four are routed through here.

    WHAT WAS NOT REPRODUCED, STATED RATHER THAN GLOSSED. No synthetic reproduction succeeded on the
    machine this was built on: the CLI here is 4.7.0 and emits no hint line, and a stub shim faithful to
    the npm template does not wrap its child's stderr when driven from this harness. The consumer's
    stack trace is the evidence that it happens; the shim reading above is the evidence for WHY, and it
    is checkable by anyone with npm's shopify on PATH.

    NOT Invoke-NativeCapture, AND THE REASON IS THE SHAPE RATHER THAN THE DANCE. That lib (registered
    for dkj-policy and, since inbound #1181, for dkj-subagents-shopify) centralises exactly this
    EAP dance for git and gh, and reusing it was the first thing tried. Two things rule it out here:

      1. IT CAPTURES; THESE CALLS HAVE TO STREAM. 'theme pull' and 'theme push' are the two longest
         calls in this plugin -- minutes on a real theme -- and the CLI can stop mid-way to ask for
         authentication. Captured, that prompt is invisible and the run reads as still in progress,
         which is precisely the silent-hang class inbound #1179 and #1181 exist to end. Swallowing it
         here would trade one silent hang for another.
      2. ITS BOUNDED/UTF-8 ARM USES Start-Process, WHICH CANNOT RUN A .ps1. On Windows 'shopify' is an
         npm shim -- AppData\Roaming\npm\shopify.ps1 -- resolved by PowerShell's own command discovery,
         not an .exe. So -TimeoutSeconds and -Utf8 are unavailable to a Shopify call whatever else is
         decided, and a wrapper that cannot offer them should not look like the one that can.

    Invoke-SyncGitQuiet in sync-rules.ps1 is the precedent for that call: a small purpose-built wrapper
    that repeats the four-line dance deliberately, because what it needs around the call differs.

    THE BARE FORM IS REFUSED BY THE LINT GATE, and that half is what makes this stick. The dangerous
    spelling is now the ABSENCE of a wrapper rather than a redirect a regex can spot, so
    check-plugin-integrity.ps1 parses every .ps1 in the tree and reports any command named 'shopify'
    that is not the one call inside this file. A convention nothing enforces is how the four sites this
    lib replaced came to exist in the first place.

    No Set-StrictMode here: dot-sourcing would modify the calling script's strict mode.
    Pure ASCII (repo convention for .ps1).
#>

function Get-ShopifyLineText {
    <#
        One output object from the CLI, as the text a reader should see. Internal to this lib.

        A '2>&1' redirect turns every stderr line into an ErrorRecord wrapping a RemoteException, and
        for a line with text in it all three of ToString(), Exception.Message and TargetObject agree.
        AN EMPTY STDERR LINE IS WHERE THEY STOP AGREEING, and the CLI writes several -- it draws its
        errors in a box with blank lines inside it. There ToString() has no message to defer to and
        falls back to the TYPE NAME, so the console shows a literal
        'System.Management.Automation.RemoteException' in the middle of the box and any caller doing
        'Output | Out-String' captures it. Measured against the real CLI 4.7.0 during review, on a
        'Flag not specified' refusal: fourteen lines, thirteen correct, one type name.

        SO TargetObject IS READ FIRST -- it is the raw stderr line, string-typed, empty string and all.
        The exception's message is the fallback for a record that is not a native stderr line at all.

        BYTE-FOR-BYTE THE BODY OF Get-NativeLineText in native-capture-lib.ps1, AND THAT DUPLICATION IS
        THE DECISION RATHER THAN AN OVERSIGHT (issue #2158, which weighed unifying them and closed on
        this reason). The two libs do not depend on each other: this file dot-sources nothing, because
        its wrapper is purpose-built for the two measured reasons in the header above -- these calls have
        to STREAM, and the bounded/UTF-8 arm's Start-Process cannot run the npm .ps1 shim that 'shopify'
        actually is. Promoting eight lines to a shared source would have to buy back a dependency this
        file was written not to have, or invent a third lib; and both libs are mirrored separately --
        native-capture-lib into dkj-policy and dkj-subagents-shopify, this one into
        dkj-subagents-shopify -- so a shared copy would have to land in the mirror set of every plugin
        carrying either caller and resolve $PSScriptRoot-relative at each mirror's own depth. Eight lines
        is the cheaper half of that trade. THE COST IS THAT NOTHING ENFORCES IT: if the TargetObject-first
        order ever changes, change it in both.
    #>
    param([Parameter(Mandatory = $true)][AllowNull()]$Line)

    if ($null -eq $Line) { return '' }
    if ($Line -is [System.Management.Automation.ErrorRecord]) {
        if ($Line.TargetObject -is [string]) { return [string]$Line.TargetObject }
        return [string]$Line.Exception.Message
    }
    return [string]$Line
}

function Invoke-ShopifyCli {
    <#
        Run the Shopify CLI with $ErrorActionPreference lowered to 'Continue' for the duration, and hand
        back a pscustomobject with:
          - Output   : the command's output lines. Always populated, so a caller that streams can still
                       parse afterwards; empty only where the command wrote nothing.
          - ExitCode : $LASTEXITCODE, recorded immediately after the command ran. THE ONLY THING A
                       CALLER MAY JUDGE THE RUN ON -- never the absence of an ErrorRecord.
        EAP is restored in a finally, whether the command succeeds, fails, or throws.

        STREAMING IS THE DEFAULT AND -Quiet IS THE OPT-OUT, deliberately in that direction. A caller who
        forgets -Quiet gets output on the console it did not need, which is visible and harmless; a
        caller who forgot to ask for streaming would get minutes of silence on a theme push, which is
        the failure this wrapper was written to stop being invisible. The stream is a genuine tee -- the
        lines reach the host as the CLI produces them, and the same text falls through into Output.

        -DiscardStderr RUNS THE CALL AS '2>$null' RATHER THAN '2>&1', and it is required wherever Output
        is PARSED. The hint line in this file's header is written to stderr while the command succeeds,
        so a merged capture puts it in front of the JSON and ConvertFrom-Json fails on output that was
        never wrong. Pass it for '--json' calls; leave it off wherever the CLI's progress is the point.

        OUTPUT IS STRINGS, NEVER ErrorRecords, and that is a repair rather than a preference. With
        '2>&1' every stderr line arrives as an ErrorRecord wrapping a RemoteException, and an
        ErrorRecord's ToString() is the EXCEPTION's message -- which for that wrapper is empty, so
        'Write-Host $_' prints the literal text 'System.Management.Automation.RemoteException' where the
        CLI's own line should be. Measured against the real CLI 4.7.0 while this was being reviewed: a
        'Flag not specified' refusal streamed one such line. Normalising through Get-ShopifyLineText
        below fixes the console and the capture at once -- a caller doing '$r.Output | Out-String' gets
        the CLI's words rather than a type name.
    #>
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$Quiet,
        [switch]$DiscardStderr
    )

    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'

        # FOUR ARMS RATHER THAN A COMPOSED PIPELINE, because a redirection operator is parsed, not
        # passed: '2>$null' cannot be held in a variable and spliced in. Spelling each combination out
        # is the only form PowerShell accepts, and it keeps the '& shopify' call -- the one spelling
        # the lint gate exempts in this file -- visible rather than hidden behind an Invoke-Expression.
        #
        # THE NORMALISATION SITS INSIDE THE PIPELINE for the two streaming arms rather than after them,
        # because that is what makes the tee a tee: the line is rendered and passed on as the CLI
        # produces it, not once the call has finished.
        if ($Quiet) {
            if ($DiscardStderr) { $out = @(& shopify @Arguments 2>$null | ForEach-Object { Get-ShopifyLineText $_ }) }
            else                { $out = @(& shopify @Arguments 2>&1   | ForEach-Object { Get-ShopifyLineText $_ }) }
        } else {
            if ($DiscardStderr) { $out = @(& shopify @Arguments 2>$null | ForEach-Object { $t = Get-ShopifyLineText $_; Write-Host $t; $t }) }
            else                { $out = @(& shopify @Arguments 2>&1   | ForEach-Object { $t = Get-ShopifyLineText $_; Write-Host $t; $t }) }
        }
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
    }

    return [pscustomobject]@{ Output = $out; ExitCode = $code }
}

function Get-ThemeFileCount {
    <#
        How many files a theme on the store holds, or -1 where that cannot be measured. It exists for one
        question -- has a 'shopify theme duplicate' finished filling? -- and both scripts that ask it
        (backup-live-theme and push-preview) call this one copy. Get-ThemeFillVerdict in
        theme-lifecycle-rules.ps1 judges the counts; this only takes them, which is why it lives beside the
        wrapper rather than in that lib, whose header promises no CLI and no network.

        THE COUNT IS TAKEN OFF A REAL PULL, and that is a measurement rather than a shortcut not taken.
        'theme info --json' carries no file count on current CLI releases (#2033 -- @shopify/cli 4.8.0's
        schema is fixed to id/name/role/shop/preview_url/editor_url), and 'theme list --json' carries none
        either (only id/name/role/processing, and 'processing''s meaning is undocumented -- not something
        this function will guess at). So a full 'theme pull' into a scratch directory is counted off what
        actually landed on disk. A pull that fails, or a scratch directory that cannot be read back, is
        reported as -1, which Get-ThemeFillVerdict treats as unknown.

        NOT -Quiet: 'theme pull' is one of the calls that can run for minutes and stop mid-way to ask for
        authentication -- captured, that prompt is invisible and the run reads as still in progress (this
        file's own header).

        It was a local function inside backup-live-theme.ps1 until #2348, when push-preview needed the same
        count and a consumer had already carried a second copy of it.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Store,
        [Parameter(Mandatory = $true)][string]$ThemeId
    )
    $pullPath = Join-Path ([System.IO.Path]::GetTempPath()) ('shopify-fill-check-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $pullPath -Force | Out-Null
    try {
        $r = Invoke-ShopifyCli -Arguments @('theme', 'pull', '--store', $Store, '--theme', $ThemeId, '--path', $pullPath)
        if ($r.ExitCode -ne 0) { return -1 }
        return @(Get-ChildItem -LiteralPath $pullPath -Recurse -File -ErrorAction SilentlyContinue).Count
    } catch {
        return -1
    } finally {
        Remove-Item -LiteralPath $pullPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
