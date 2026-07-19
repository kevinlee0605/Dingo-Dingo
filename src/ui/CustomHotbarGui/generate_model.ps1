Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Generates the exact static visual hierarchy created by the recovered v1615
# CustomHotbarClient. Runtime behavior lives in StarterPlayerScripts and binds
# these authored objects; it does not construct or replace them.

function Prop([string]$Kind, $Value) {
    [pscustomobject]@{ Kind = $Kind; Value = $Value }
}

function UDimValue([double]$Scale, [int]$Offset) {
    Prop "UDim" @($Scale, $Offset)
}

function UDim2Value([double]$XS, [int]$XO, [double]$YS, [int]$YO) {
    Prop "UDim2" @($XS, $XO, $YS, $YO)
}

function Vector2Value([double]$X, [double]$Y) {
    Prop "Vector2" @($X, $Y)
}

function ColorValue([int]$R, [int]$G, [int]$B) {
    Prop "Color3" @(($R / 255.0), ($G / 255.0), ($B / 255.0))
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

function Add-Corner($Parent, [int]$Radius) {
    Add-Child $Parent (New-Node "UICorner" "UICorner" @{
        CornerRadius = UDimValue 0 $Radius
    }) | Out-Null
}

function Add-Stroke($Parent, [double]$Thickness, $Color) {
    Add-Child $Parent (New-Node "UIStroke" "UIStroke" @{
        ApplyStrokeMode = Prop "token" 1
        Color = $Color
        Thickness = Prop "float" $Thickness
    }) | Out-Null
}

$holder = New-Node "Frame" "Holder" @{
    AnchorPoint = Vector2Value 0.5 1
    BackgroundTransparency = Prop "float" 1
    Position = UDim2Value 0.5 0 1 -12
    Size = UDim2Value 0 308 0 124
}

Add-Child $holder (New-Node "UIScale" "DeviceScale" @{
    # Match the normal desktop test preview. The controller replaces this only
    # when the actual viewport requires a different device scale.
    Scale = Prop "float" 0.9324
}) | Out-Null

Add-Child $holder (New-Node "UIListLayout" "UIListLayout" @{
    FillDirection = Prop "token" 0
    HorizontalAlignment = Prop "token" 1
    Padding = UDimValue 0 10
    SortOrder = Prop "token" 2
    VerticalAlignment = Prop "token" 2
}) | Out-Null

$previewIcons = @(
    "rbxassetid://105149981299569",
    "rbxassetid://75795273892452",
    "rbxassetid://135629767511743"
)
$previewLabels = @("Wooden Rod", "Bag", "Fishdex")
$previewLabelColors = @(
    (ColorValue 160 255 80),
    (ColorValue 45 210 255),
    (ColorValue 255 220 130)
)

for ($index = 1; $index -le 3; $index++) {
    $button = Add-Child $holder (New-Node "TextButton" ("Slot" + $index) @{
        AutoButtonColor = Prop "bool" $false
        BackgroundColor3 = ColorValue 22 18 15
        BackgroundTransparency = Prop "float" 0.22
        ClipsDescendants = Prop "bool" $false
        LayoutOrder = Prop "int" $index
        Size = UDim2Value 0 96 0 88
        Text = Prop "string" ""
    })

    Add-Corner $button 10
    Add-Stroke $button 3 (ColorValue 0 0 0)
    Add-Child $button (New-Node "UIScale" "UIScale" @{
        Scale = Prop "float" 1
    }) | Out-Null

    $numberBox = Add-Child $button (New-Node "TextLabel" "NumberBox" @{
        BackgroundColor3 = ColorValue 55 55 55
        BackgroundTransparency = Prop "float" 0.15
        Font = Prop "token" 20
        Position = UDim2Value 0 6 0 6
        Size = UDim2Value 0 22 0 22
        Text = Prop "string" ([string]$index)
        TextColor3 = ColorValue 255 255 255
        TextScaled = Prop "bool" $false
        TextSize = Prop "float" 16
        TextStrokeTransparency = Prop "float" 0
        Visible = Prop "bool" $true
        ZIndex = Prop "int" 20
    })
    Add-Corner $numberBox 7
    Add-Stroke $numberBox 1.5 (ColorValue 180 180 180)

    Add-Child $button (New-Node "ImageLabel" "Icon" @{
        AnchorPoint = Vector2Value 0.5 0.5
        BackgroundTransparency = Prop "float" 1
        Image = Prop "Content" $previewIcons[$index - 1]
        Position = UDim2Value 0.5 0 0.46 0
        ScaleType = Prop "token" 3
        Size = UDim2Value 0.78 0 0.70 0
        ZIndex = Prop "int" 10
    }) | Out-Null

    Add-Child $button (New-Node "TextLabel" "Label" @{
        AnchorPoint = Vector2Value 0.5 1
        BackgroundTransparency = Prop "float" 1
        Font = Prop "token" 20
        Position = UDim2Value 0.5 0 0.98 0
        Size = UDim2Value 0.95 0 0.27 0
        Text = Prop "string" $previewLabels[$index - 1]
        TextColor3 = $previewLabelColors[$index - 1]
        TextScaled = Prop "bool" $true
        TextStrokeTransparency = Prop "float" 0
        ZIndex = Prop "int" 15
    }) | Out-Null
}

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

$outputPath = Join-Path $PSScriptRoot "Holder.rbxmx"
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
    Write-Node $writer $holder
    $writer.WriteEndElement()
    $writer.WriteEndDocument()
}
finally {
    $writer.Dispose()
}

Write-Output "Generated $outputPath"
