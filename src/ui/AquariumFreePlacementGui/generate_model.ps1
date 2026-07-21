Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Prop([string]$Kind, $Value) {
    [pscustomobject]@{ Kind = $Kind; Value = $Value }
}

function UDim2Value([double]$XS, [int]$XO, [double]$YS, [int]$YO) {
    Prop "UDim2" @($XS, $XO, $YS, $YO)
}

function UDimValue([double]$Scale, [int]$Offset) {
    Prop "UDim" @($Scale, $Offset)
}

function Vector2Value([double]$X, [double]$Y) {
    Prop "Vector2" @($X, $Y)
}

function ColorValue([int]$R, [int]$G, [int]$B) {
    Prop "Color3" @((($R / 255.0)), (($G / 255.0)), (($B / 255.0)))
}

function New-Node([string]$ClassName, [string]$Name, [hashtable]$Properties = @{}) {
    [pscustomobject]@{
        ClassName = $ClassName
        Name = $Name
        Properties = $Properties
        Children = [System.Collections.Generic.List[object]]::new()
    }
}

function Add-Child($Parent, $Child) {
    [void]$Parent.Children.Add($Child)
    $Child
}

function CommonGuiProps($Position, $Size, $Background, [double]$Transparency, [int]$ZIndex = 1) {
    @{
        AnchorPoint = Vector2Value 0 0
        AutoLocalize = Prop "bool" $false
        BackgroundColor3 = $Background
        BackgroundTransparency = Prop "float" $Transparency
        BorderSizePixel = Prop "int" 0
        ClipsDescendants = Prop "bool" $false
        LayoutOrder = Prop "int" 0
        Position = $Position
        Size = $Size
        Visible = Prop "bool" $true
        ZIndex = Prop "int" $ZIndex
    }
}

function New-Frame([string]$Name, $Position, $Size, $Background, [double]$Transparency = 1, [int]$ZIndex = 1) {
    New-Node "Frame" $Name (CommonGuiProps $Position $Size $Background $Transparency $ZIndex)
}

function Add-Corner($Parent, [int]$Radius) {
    Add-Child $Parent (New-Node "UICorner" "UICorner" @{ CornerRadius = UDimValue 0 $Radius }) | Out-Null
}

function Add-Stroke($Parent, $Color, [double]$Thickness, [string]$Name = "UIStroke") {
    Add-Child $Parent (New-Node "UIStroke" $Name @{
        ApplyStrokeMode = Prop "token" 1
        Color = $Color
        Thickness = Prop "float" $Thickness
        Transparency = Prop "float" 0
    }) | Out-Null
}

function Add-TextConstraint($Parent, [int]$Minimum, [int]$Maximum) {
    Add-Child $Parent (New-Node "UITextSizeConstraint" "UITextSizeConstraint" @{
        MinTextSize = Prop "int" $Minimum
        MaxTextSize = Prop "int" $Maximum
    }) | Out-Null
}

function New-Label([string]$Name, [string]$Text, $Position, $Size, [int]$TextSize = 14, $TextColor = $null, [int]$ZIndex = 2) {
    if ($null -eq $TextColor) { $TextColor = ColorValue 235 242 255 }
    $props = CommonGuiProps $Position $Size (ColorValue 255 255 255) 1 $ZIndex
    $props.Text = Prop "string" $Text
    $props.Font = Prop "token" 26
    $props.TextColor3 = $TextColor
    $props.TextScaled = Prop "bool" $false
    $props.TextSize = Prop "float" $TextSize
    $props.TextStrokeTransparency = Prop "float" 1
    $props.TextTransparency = Prop "float" 0
    $props.TextWrapped = Prop "bool" $true
    $props.TextXAlignment = Prop "token" 0
    $props.TextYAlignment = Prop "token" 1
    New-Node "TextLabel" $Name $props
}

function New-Button([string]$Name, [string]$Text, $Position, $Size, $Background, [int]$TextSize = 13, [int]$ZIndex = 3) {
    $props = CommonGuiProps $Position $Size $Background 0 $ZIndex
    $props.AutoButtonColor = Prop "bool" $true
    $props.Font = Prop "token" 26
    $props.Text = Prop "string" $Text
    $props.TextColor3 = ColorValue 255 255 255
    $props.TextScaled = Prop "bool" $false
    $props.TextSize = Prop "float" $TextSize
    $props.TextStrokeTransparency = Prop "float" 1
    $props.TextTransparency = Prop "float" 0
    $props.TextWrapped = Prop "bool" $true
    $button = New-Node "TextButton" $Name $props
    Add-Corner $button 7
    $button
}

function New-ScrollingFrame([string]$Name, $Position, $Size, [int]$ZIndex = 2) {
    $props = CommonGuiProps $Position $Size (ColorValue 7 29 65) 0 $ZIndex
    $props.Active = Prop "bool" $true
    $props.AutomaticCanvasSize = Prop "token" 2
    $props.CanvasSize = UDim2Value 0 0 0 0
    $props.ClipsDescendants = Prop "bool" $true
    $props.ElasticBehavior = Prop "token" 1
    $props.ScrollBarThickness = Prop "int" 4
    $props.ScrollingDirection = Prop "token" 2
    New-Node "ScrollingFrame" $Name $props
}

function New-ImageVisual(
    [string]$ClassName,
    [string]$Name,
    [string]$Asset,
    [int[]]$Crop,
    $Position,
    $Size,
    [int]$ZIndex = 1
) {
    $props = CommonGuiProps $Position $Size (ColorValue 255 255 255) 1 $ZIndex
    $props.Image = Prop "Content" $Asset
    $props.ImageColor3 = ColorValue 255 255 255
    $props.ImageTransparency = Prop "float" 0
    $props.ImageRectOffset = Vector2Value $Crop[0] $Crop[1]
    $props.ImageRectSize = Vector2Value $Crop[2] $Crop[3]
    $props.ScaleType = Prop "token" 0
    if ($ClassName -eq "ImageButton") {
        $props.AutoButtonColor = Prop "bool" $false
    }
    New-Node $ClassName $Name $props
}

function Add-InstalledCheck($Parent) {
    $check = Add-Child $Parent (New-Frame "InstalledCheck" (UDim2Value 1 -6 0 5) (UDim2Value 0 29 0 29) (ColorValue 24 111 18) 0.01 33)
    $check.Properties.AnchorPoint = Vector2Value 1 0
    $check.Properties.Visible = Prop "bool" $false
    Add-Corner $check 999
    Add-Stroke $check (ColorValue 192 255 82) 2
    $short = Add-Child $check (New-Frame "CheckShort" (UDim2Value 0 9 0 10) (UDim2Value 0 5 0 13) (ColorValue 255 255 215) 0 35)
    $short.Properties.AnchorPoint = Vector2Value 0.5 0.5
    $short.Properties.Rotation = Prop "float" -43
    Add-Corner $short 4
    $long = Add-Child $check (New-Frame "CheckLong" (UDim2Value 0 18 0 5) (UDim2Value 0 5 0 20) (ColorValue 255 255 215) 0 35)
    $long.Properties.AnchorPoint = Vector2Value 0.5 0.5
    $long.Properties.Rotation = Prop "float" 43
    Add-Corner $long 4
}

$transparent = ColorValue 255 255 255
$root = New-Frame "Interface" (UDim2Value 0 0 0 0) (UDim2Value 1 0 1 0) $transparent 1 1

# Recovered version-1636 image assets and exact crops. The UI is authored here
# so Studio Edit mode and Play mode render the same hierarchy and artwork.
$assets = @{
    ReferenceTopBorder = @("rbxassetid://78119100190793", @(0, 0, 1024, 20))
    ReferenceHeaderDivider = @("rbxassetid://78119100190793", @(0, 73, 1024, 6))
    ReferenceLeftRail = @("rbxassetid://78119100190793", @(0, 0, 25, 576))
    ReferenceRightRail = @("rbxassetid://78119100190793", @(999, 0, 25, 576))
    ReferenceBottomRail = @("rbxassetid://78119100190793", @(0, 548, 1024, 28))
    ReferencePreview = @("rbxassetid://78119100190793", @(22, 76, 523, 462))
    ReferenceThemesPanel = @("rbxassetid://78119100190793", @(551, 73, 448, 96))
    ReferenceDecorPanel = @("rbxassetid://78119100190793", @(551, 173, 448, 227))
    ReferenceAdjustmentsPanel = @("rbxassetid://78119100190793", @(551, 407, 448, 82))
    MainDisplay = @("rbxassetid://73798557079455", @(41, 57, 941, 870))
    MappedMainDisplay = @("rbxassetid://73798557079455", @(106, 180, 815, 665))
    LeftDecoration = @("rbxassetid://91056388997818", @(170, 56, 78, 83))
    CloseButton = @("rbxassetid://119322438066977", @(290, 326, 330, 339))
    ThemesPanel = @("rbxassetid://93391070554478", @(132, 162, 367, 88))
    ThemeNormal = @("rbxassetid://77785584261234", @(396, 329, 219, 91))
    DecorPanel = @("rbxassetid://122540568649709", @(131, 103, 366, 226))
    DecorNormal = @("rbxassetid://81143457443906", @(168, 66, 83, 69))
    Backdrop = @("rbxassetid://119386888334158", @(175, 72, 64, 50))
    AdjustmentsBig = @("rbxassetid://89729513198581", @(130, 173, 370, 84))
    AdjustmentsSmall = @("rbxassetid://100275421759931", @(131, 190, 367, 52))
    CircleNormal = @("rbxassetid://84469227464999", @(189, 82, 30, 31))
    LeftDirection = @("rbxassetid://94712658264920", @(339, 155, 346, 339))
    PreviewButton = @("rbxassetid://110797697720551", @(215, 53, 595, 210))
    RemoveButton = @("rbxassetid://97923557167562", @(182, 42, 661, 248))
    ApplyButton = @("rbxassetid://96038949706970", @(317, 248, 389, 131))
}

$dimmer = Add-Child $root (New-Frame "BackdropDimmer" (UDim2Value 0 0 0 0) (UDim2Value 1 0 1 0) (ColorValue 0 5 18) 0.30 1)
$dimmer.Properties.Visible = Prop "bool" $false

$openButton = Add-Child $root (New-Button "OpenButton" "Decor Editor" (UDim2Value 1 -18 1 -24) (UDim2Value 0 148 0 48) (ColorValue 14 94 190) 18 100)
$openButton.Properties.AnchorPoint = Vector2Value 1 1
$openButton.Properties.Visible = Prop "bool" $false
Add-Stroke $openButton (ColorValue 42 218 255) 2

$backButton = Add-Child $root (New-Button "BackButton" "Back to Editor" (UDim2Value 1 -18 1 -24) (UDim2Value 0 168 0 48) (ColorValue 14 94 190) 18 100)
$backButton.Properties.AnchorPoint = Vector2Value 1 1
$backButton.Properties.Visible = Prop "bool" $false
Add-Stroke $backButton (ColorValue 42 218 255) 2

$panel = Add-Child $root (New-Frame "Panel" (UDim2Value 0.5 0 0.5 0) (UDim2Value 0 1672 0 941) $transparent 1 10)
$panel.Properties.AnchorPoint = Vector2Value 0.5 0.5
$panel.Properties.Active = Prop "bool" $true
$panel.Properties.Visible = Prop "bool" $false
Add-Child $panel (New-Node "UIScale" "ResponsiveScale" @{ Scale = Prop "float" 1 }) | Out-Null
Add-Child $panel (New-Node "UISizeConstraint" "PanelSizeConstraint" @{
    MinSize = Vector2Value 1672 941
    MaxSize = Vector2Value 1672 941
}) | Out-Null

$shellFill = Add-Child $panel (New-Frame "ShellFill" (UDim2Value 0 27 0 18) (UDim2Value 0 1618 0 904) (ColorValue 0 14 38) 0 9)
Add-Corner $shellFill 22
foreach ($slice in @(
    @("ReferenceTopBorder", 0, 0, 1672, 31, 11),
    @("ReferenceHeaderDivider", 0, 118, 1672, 10, 11),
    @("ReferenceLeftRail", 0, 0, 40, 941, 12),
    @("ReferenceRightRail", 1632, 0, 40, 941, 12),
    @("ReferenceBottomRail", 0, 895, 1672, 46, 12)
)) {
    $sliceInfo = $assets[$slice[0]]
    Add-Child $panel (New-ImageVisual "ImageLabel" $slice[0] $sliceInfo[0] $sliceInfo[1] (UDim2Value 0 $slice[1] 0 $slice[2]) (UDim2Value 0 $slice[3] 0 $slice[4]) $slice[5]) | Out-Null
}
$leftInfo = $assets.LeftDecoration
Add-Child $panel (New-ImageVisual "ImageLabel" "LeftDecoration" $leftInfo[0] $leftInfo[1] (UDim2Value 0 51 0 29) (UDim2Value 0 82 0 88) 20) | Out-Null

$titleRow = Add-Child $panel (New-Frame "TitleRow" (UDim2Value 0 0 0 0) (UDim2Value 1 0 1 0) $transparent 1 21)
$title = Add-Child $titleRow (New-Label "Title" "Aquarium Decor Editor" (UDim2Value 0 150 0 31) (UDim2Value 0 700 0 54) 43 (ColorValue 255 255 255) 25)
$status = Add-Child $titleRow (New-Label "StatusLabel" "Scroll to Scale" (UDim2Value 0 151 0 82) (UDim2Value 0 620 0 32) 22 (ColorValue 47 236 255) 25)
$closeButton = Add-Child $titleRow (New-Button "CloseButton" "" (UDim2Value 0 1548 0 31) (UDim2Value 0 68 0 68) $transparent 0 30)
$closeButton.Properties.BackgroundTransparency = Prop "float" 1
$closeInfo = $assets.CloseButton
Add-Child $closeButton (New-ImageVisual "ImageLabel" "Visual" $closeInfo[0] $closeInfo[1] (UDim2Value 0 0 0 0) (UDim2Value 1 0 1 0) 29) | Out-Null

$mainDisplayInfo = $assets.ReferencePreview
Add-Child $panel (New-ImageVisual "ImageLabel" "ReferencePreview" $mainDisplayInfo[0] $mainDisplayInfo[1] (UDim2Value 0 36 0 124) (UDim2Value 0 854 0 755) 18) | Out-Null
$preview = Add-Child $panel (New-Frame "PreviewFrame" (UDim2Value 0 47 0 134) (UDim2Value 0 832 0 735) (ColorValue 8 45 92) 1 22)
$preview.Properties.Active = Prop "bool" $true
$preview.Properties.ClipsDescendants = Prop "bool" $true
Add-Corner $preview 18
$water = Add-Child $preview (New-Frame "PreviewWater" (UDim2Value 0 0 0 0) (UDim2Value 1 0 1 0) (ColorValue 44 151 212) 1 22)
$mappedInfo = $assets.MappedMainDisplay
Add-Child $water (New-ImageVisual "ImageLabel" "MappedMainDisplay" $mappedInfo[0] $mappedInfo[1] (UDim2Value 0 0 0 0) (UDim2Value 1 0 1 0) 20) | Out-Null
$markerLayer = Add-Child $preview (New-Frame "MarkerLayer" (UDim2Value 0 0 0 0) (UDim2Value 1 0 1 0) $transparent 1 24)
$ghost = Add-Child $preview (New-Frame "GhostMarker" (UDim2Value 0.5 0 0.5 0) (UDim2Value 0 22 0 22) (ColorValue 255 255 255) 1 25)
$ghost.Properties.AnchorPoint = Vector2Value 0.5 0.5
$ghost.Properties.Visible = Prop "bool" $false

$themesInfo = $assets.ReferenceThemesPanel
Add-Child $panel (New-ImageVisual "ImageLabel" "ThemesPanel" $themesInfo[0] $themesInfo[1] (UDim2Value 0 899 0 119) (UDim2Value 0 732 0 156) 17) | Out-Null
$themesContentMask = Add-Child $panel (New-Frame "ThemesContentMask" (UDim2Value 0 908 0 151) (UDim2Value 0 714 0 116) (ColorValue 1 15 42) 0 18)
Add-Corner $themesContentMask 10
$themeGrid = Add-Child $panel (New-Frame "ThemeGrid" (UDim2Value 0 919 0 155) (UDim2Value 0 690 0 110) $transparent 1 25)
$themeGrid.Properties.ClipsDescendants = Prop "bool" $true
Add-Child $themeGrid (New-Node "UIGridLayout" "Layout" @{
    CellPadding = UDim2Value 0 10 0 8
    CellSize = UDim2Value 0 160 0 50
    FillDirection = Prop "token" 0
    FillDirectionMaxCells = Prop "int" 4
    SortOrder = Prop "token" 2
}) | Out-Null

$decorInfo = $assets.ReferenceDecorPanel
Add-Child $panel (New-ImageVisual "ImageLabel" "DecorPanel" $decorInfo[0] $decorInfo[1] (UDim2Value 0 899 0 283) (UDim2Value 0 732 0 371) 17) | Out-Null
$decorContentMask = Add-Child $panel (New-Frame "DecorContentMask" (UDim2Value 0 908 0 322) (UDim2Value 0 714 0 324) (ColorValue 1 16 44) 0 18)
Add-Corner $decorContentMask 10
$decorGrid = Add-Child $panel (New-Frame "DecorGrid" (UDim2Value 0 914 0 327) (UDim2Value 0 696 0 318) $transparent 1 25)
$decorGrid.Properties.ClipsDescendants = Prop "bool" $true
Add-Child $decorGrid (New-Node "UIGridLayout" "Layout" @{
    CellPadding = UDim2Value 0 8 0 9
    CellSize = UDim2Value 0 168 0 100
    FillDirection = Prop "token" 0
    FillDirectionMaxCells = Prop "int" 4
    SortOrder = Prop "token" 2
}) | Out-Null
$backdrop = Add-Child $decorGrid (New-Button "BackdropButton" "" (UDim2Value 0 0 0 0) (UDim2Value 0 158 0 79) $transparent 15 27)
$backdrop.Properties.BackgroundTransparency = Prop "float" 1
$backdrop.Properties.LayoutOrder = Prop "int" 0
$decorNormal = $assets.DecorNormal
Add-Child $backdrop (New-ImageVisual "ImageLabel" "Visual" $decorNormal[0] $decorNormal[1] (UDim2Value 0 0 0 0) (UDim2Value 1 0 1 0) 26) | Out-Null
$backdropInfo = $assets.Backdrop
$backdropIcon = Add-Child $backdrop (New-ImageVisual "ImageLabel" "DecorIcon" $backdropInfo[0] $backdropInfo[1] (UDim2Value 0.23 0 0.08 0) (UDim2Value 0.54 0 0.56 0) 30)
$backdropIcon.Properties.ScaleType = Prop "token" 3
$backdropLabel = Add-Child $backdrop (New-Label "Label" "Backdrop On" (UDim2Value 0.04 0 0.60 0) (UDim2Value 0.92 0 0.34 0) 18 (ColorValue 255 255 255) 31)
$backdropLabel.Properties.TextScaled = Prop "bool" $false
$backdropLabel.Properties.TextXAlignment = Prop "token" 1
Add-Stroke $backdrop (ColorValue 95 255 132) 1 "SelectionStroke"

$adjustInfo = $assets.ReferenceAdjustmentsPanel
Add-Child $panel (New-ImageVisual "ImageLabel" "AdjustmentsPanel" $adjustInfo[0] $adjustInfo[1] (UDim2Value 0 899 0 664) (UDim2Value 0 732 0 134) 17) | Out-Null
$adjustment = Add-Child $panel (New-Frame "AdjustmentGrid" (UDim2Value 0 918 0 704) (UDim2Value 0 694 0 76) $transparent 1 26)
$depthLeft = Add-Child $adjustment (New-Button "DepthLeftButton" "" (UDim2Value 0 0 0 12) (UDim2Value 0 56 0 56) $transparent 0 29)
$depthLeft.Properties.BackgroundTransparency = Prop "float" 1
$leftArrow = $assets.LeftDirection
Add-Child $depthLeft (New-ImageVisual "ImageLabel" "Visual" $leftArrow[0] $leftArrow[1] (UDim2Value 0 0 0 0) (UDim2Value 1 0 1 0) 28) | Out-Null
$depthRight = Add-Child $adjustment (New-Button "DepthRightButton" "" (UDim2Value 0 630 0 12) (UDim2Value 0 56 0 56) $transparent 0 29)
$depthRight.Properties.BackgroundTransparency = Prop "float" 1
$rightVisual = Add-Child $depthRight (New-ImageVisual "ImageLabel" "Visual" $leftArrow[0] $leftArrow[1] (UDim2Value 0 0 0 0) (UDim2Value 1 0 1 0) 28)
$rightVisual.Properties.Rotation = Prop "float" 180
$depthTrack = Add-Child $adjustment (New-Frame "DepthTrack" (UDim2Value 0 83 0 40) (UDim2Value 0 515 0 2) (ColorValue 108 172 255) 0.38 28)
for ($level = 1; $level -le 7; $level++) {
    $alpha = ($level - 1) / 6.0
    $dot = Add-Child $depthTrack (New-Button ("DepthLevel" + $level) "" (UDim2Value $alpha -11 0.5 -11) (UDim2Value 0 22 0 22) $transparent 0 30)
    $dot.Properties.BackgroundTransparency = Prop "float" 1
    $circleInfo = $assets.CircleNormal
    Add-Child $dot (New-ImageVisual "ImageLabel" "Visual" $circleInfo[0] $circleInfo[1] (UDim2Value 0 0 0 0) (UDim2Value 1 0 1 0) 29) | Out-Null
    Add-Stroke $dot (ColorValue 105 165 235) 0 "SelectionStroke"
}

$actions = Add-Child $panel (New-Frame "ActionRow" (UDim2Value 0 0 0 0) (UDim2Value 1 0 1 0) $transparent 1 29)
$actionSpecs = @(
    @("PreviewButton", "Preview", 903, 228, "PreviewButton"),
    @("RemoveButton", "Remove", 1150, 228, "RemoveButton"),
    @("ApplyButton", "Apply", 1397, 228, "ApplyButton")
)
foreach ($spec in $actionSpecs) {
    $action = Add-Child $actions (New-Button $spec[0] "" (UDim2Value 0 $spec[2] 0 815) (UDim2Value 0 $spec[3] 0 72) $transparent 0 30)
    $action.Properties.BackgroundTransparency = Prop "float" 1
    $assetInfo = $assets[$spec[4]]
    Add-Child $action (New-ImageVisual "ImageLabel" "Visual" $assetInfo[0] $assetInfo[1] (UDim2Value 0 0 0 0) (UDim2Value 1 0 1 0) 29) | Out-Null
}

$templates = Add-Child $root (New-Node "Folder" "Templates")
$themeTemplate = Add-Child $templates (New-Button "ThemeButtonTemplate" "" (UDim2Value 0 0 0 0) (UDim2Value 0 158 0 52) $transparent 16 27)
$themeTemplate.Properties.BackgroundTransparency = Prop "float" 1
$themeTemplate.Properties.Visible = Prop "bool" $false
$themeNormal = $assets.ThemeNormal
Add-Child $themeTemplate (New-ImageVisual "ImageLabel" "Visual" $themeNormal[0] $themeNormal[1] (UDim2Value 0 0 0 0) (UDim2Value 1 0 1 0) 26) | Out-Null
$themeTemplateLabel = Add-Child $themeTemplate (New-Label "Label" "Theme" (UDim2Value 0.05 0 0.08 0) (UDim2Value 0.90 0 0.84 0) 18 (ColorValue 255 255 255) 30)
$themeTemplateLabel.Properties.TextScaled = Prop "bool" $false
$themeTemplateLabel.Properties.TextXAlignment = Prop "token" 1
Add-Stroke $themeTemplate (ColorValue 35 160 255) 0 "SelectionStroke"
$themeLockProps = CommonGuiProps (UDim2Value 0 0 0 0) (UDim2Value 1 0 1 0) (ColorValue 32 37 52) 0.05 31
$themeLockProps.AutoButtonColor = Prop "bool" $true
$themeLockProps.Font = Prop "token" 19
$themeLockProps.Text = Prop "string" "Theme`nLOCK  0"
$themeLockProps.TextColor3 = ColorValue 255 219 92
$themeLockProps.TextScaled = Prop "bool" $true
$themeLockProps.TextSize = Prop "float" 11
$themeLockProps.TextStrokeTransparency = Prop "float" 1
$themeLockProps.TextTransparency = Prop "float" 0
$themeLockProps.TextWrapped = Prop "bool" $true
$themeLock = Add-Child $themeTemplate (New-Node "TextButton" "SeaStarThemeLock" $themeLockProps)
$themeLock.Properties.Visible = Prop "bool" $false
Add-Corner $themeLock 6
Add-TextConstraint $themeLock 5 10

$decorTemplate = Add-Child $templates (New-Button "DecorButtonTemplate" "" (UDim2Value 0 0 0 0) (UDim2Value 0 158 0 79) $transparent 13 27)
$decorTemplate.Properties.BackgroundTransparency = Prop "float" 1
$decorTemplate.Properties.Visible = Prop "bool" $false
Add-Child $decorTemplate (New-ImageVisual "ImageLabel" "Visual" $decorNormal[0] $decorNormal[1] (UDim2Value 0 0 0 0) (UDim2Value 1 0 1 0) 26) | Out-Null
$decorTemplateIcon = Add-Child $decorTemplate (New-ImageVisual "ImageLabel" "DecorIcon" "" @(0, 0, 0, 0) (UDim2Value 0.23 0 0.08 0) (UDim2Value 0.54 0 0.56 0) 30)
$decorTemplateIcon.Properties.ScaleType = Prop "token" 3
$decorTemplateLabel = Add-Child $decorTemplate (New-Label "Label" "Decor" (UDim2Value 0.04 0 0.60 0) (UDim2Value 0.92 0 0.34 0) 18 (ColorValue 255 255 255) 31)
$decorTemplateLabel.Properties.TextScaled = Prop "bool" $false
$decorTemplateLabel.Properties.TextXAlignment = Prop "token" 1
Add-InstalledCheck $decorTemplate
Add-Stroke $decorTemplate (ColorValue 35 160 255) 0 "SelectionStroke"

$markerTemplate = Add-Child $templates (New-Button "MarkerTemplate" "" (UDim2Value 0.5 0 0.5 0) (UDim2Value 0 120 0 120) $transparent 0 27)
$markerTemplate.Properties.AnchorPoint = Vector2Value 0.5 0.5
$markerTemplate.Properties.BackgroundTransparency = Prop "float" 1
$markerTemplate.Properties.Visible = Prop "bool" $false
$markerTemplateIcon = Add-Child $markerTemplate (New-ImageVisual "ImageLabel" "DecorIcon" "" @(0, 0, 0, 0) (UDim2Value 0 0 0 0) (UDim2Value 1 0 1 0) 28)
$markerTemplateIcon.Properties.ScaleType = Prop "token" 3
Add-Stroke $markerTemplate (ColorValue 255 255 255) 0 "SelectionStroke"

function Write-Property([System.Xml.XmlWriter]$Writer, [string]$Name, $Declaration) {
    $kind = [string]$Declaration.Kind
    $value = $Declaration.Value
    $Writer.WriteStartElement($kind)
    $Writer.WriteAttributeString("name", $Name)
    switch ($kind) {
        "UDim" {
            $Writer.WriteElementString("S", [string]$value[0])
            $Writer.WriteElementString("O", [string]$value[1])
        }
        "UDim2" {
            $Writer.WriteElementString("XS", [string]$value[0])
            $Writer.WriteElementString("XO", [string]$value[1])
            $Writer.WriteElementString("YS", [string]$value[2])
            $Writer.WriteElementString("YO", [string]$value[3])
        }
        "Vector2" {
            $Writer.WriteElementString("X", [string]$value[0])
            $Writer.WriteElementString("Y", [string]$value[1])
        }
        "Color3" {
            $Writer.WriteElementString("R", [string]$value[0])
            $Writer.WriteElementString("G", [string]$value[1])
            $Writer.WriteElementString("B", [string]$value[2])
        }
        "Content" { $Writer.WriteElementString("url", [string]$value) }
        "bool" { $Writer.WriteString(([bool]$value).ToString().ToLowerInvariant()) }
        default { $Writer.WriteString([string]$value) }
    }
    $Writer.WriteEndElement()
}

$script:Referent = 0
function Write-Node([System.Xml.XmlWriter]$Writer, $Node) {
    $script:Referent++
    $Writer.WriteStartElement("Item")
    $Writer.WriteAttributeString("class", [string]$Node.ClassName)
    $Writer.WriteAttributeString("referent", ("RBX{0:X8}" -f $script:Referent))
    $Writer.WriteStartElement("Properties")
    Write-Property $Writer "Name" (Prop "string" $Node.Name)
    foreach ($entry in ($Node.Properties.GetEnumerator() | Sort-Object Key)) {
        Write-Property $Writer ([string]$entry.Key) $entry.Value
    }
    $Writer.WriteEndElement()
    foreach ($child in $Node.Children) {
        Write-Node $Writer $child
    }
    $Writer.WriteEndElement()
}

$outputPath = Join-Path $PSScriptRoot "Interface.rbxmx"
$settings = [System.Xml.XmlWriterSettings]::new()
$settings.Indent = $true
$settings.IndentChars = "`t"
$settings.Encoding = [System.Text.UTF8Encoding]::new($false)
$writer = [System.Xml.XmlWriter]::Create($outputPath, $settings)
try {
    $writer.WriteStartDocument()
    $writer.WriteStartElement("roblox")
    $writer.WriteAttributeString("version", "4")
    $writer.WriteElementString("External", "null")
    $writer.WriteElementString("External", "nil")
    Write-Node $writer $root
    $writer.WriteEndElement()
    $writer.WriteEndDocument()
}
finally {
    $writer.Dispose()
}

Write-Output "Generated $outputPath"
