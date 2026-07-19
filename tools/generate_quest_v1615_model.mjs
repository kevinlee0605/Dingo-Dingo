// Generate the exact authored v1615 Quest UI hierarchy.
// Static visuals live in StarterGui; the controller clones only the declared
// QuestCardTemplate or EmptyQuestTemplate for state-driven list content.

import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..");
const OUTPUT = path.join(ROOT, "src", "ui", "FishingGui", "ModernQuestUI.rbxmx");

const scalar = (tag, value) => ({ tag, value });
const udim = (scale, offset) => ({ tag: "UDim", value: [scale, offset] });
const udim2 = (xs, xo, ys, yo) => ({ tag: "UDim2", value: [xs, xo, ys, yo] });
const vec2 = (x, y) => ({ tag: "Vector2", value: [x, y] });
const color = (r, g, b) => ({ tag: "Color3", value: [r / 255, g / 255, b / 255] });
const content = (value) => ({ tag: "Content", value });
const colorSequence = (...keypoints) => ({ tag: "ColorSequence", value: keypoints });
const node = (className, name, props = {}, children = []) => ({ className, name, props, children });

const gui = ({
  position = udim2(0, 0, 0, 0),
  size = udim2(1, 0, 1, 0),
  anchor = vec2(0, 0),
  background = color(255, 255, 255),
  transparency = 1,
  visible = true,
  zindex = 1,
  clips = false,
} = {}) => ({
  AnchorPoint: anchor,
  BackgroundColor3: background,
  BackgroundTransparency: scalar("float", transparency),
  BorderSizePixel: scalar("int", 0),
  ClipsDescendants: scalar("bool", clips),
  Position: position,
  Size: size,
  Visible: scalar("bool", visible),
  ZIndex: scalar("int", zindex),
});

const textProps = ({
  text,
  position,
  size,
  anchor = vec2(0, 0),
  textSize,
  textColor = color(255, 255, 255),
  font = 26, // FredokaOne
  xalign = 0,
  wrapped = false,
  strokeTransparency = .25,
  visible = true,
  zindex = 205,
}) => ({
  ...gui({ position, size, anchor, visible, zindex }),
  Font: scalar("token", font),
  Text: scalar("string", text),
  TextColor3: textColor,
  TextScaled: scalar("bool", false),
  TextSize: scalar("float", textSize),
  TextStrokeColor3: color(0, 0, 0),
  TextStrokeTransparency: scalar("float", strokeTransparency),
  TextTransparency: scalar("float", 0),
  TextWrapped: scalar("bool", wrapped),
  TextXAlignment: scalar("token", xalign),
  TextYAlignment: scalar("token", 1),
});

const imageProps = ({
  image,
  position,
  size,
  anchor = vec2(0, 0),
  visible = true,
  zindex,
  scaleType = 0,
}) => ({
  ...gui({ position, size, anchor, visible, zindex }),
  Image: content(image),
  ImageColor3: color(255, 255, 255),
  ImageTransparency: scalar("float", 0),
  ScaleType: scalar("token", scaleType),
});

const corner = (radius, name = "UICorner") => node("UICorner", name, {
  CornerRadius: udim(0, radius),
});

const stroke = (r, g, b, thickness, transparency, name = "UIStroke") => node("UIStroke", name, {
  Color: color(r, g, b),
  Thickness: scalar("float", thickness),
  Transparency: scalar("float", transparency),
});

const label = (name, text, position, size, textSize, textColor, zindex, options = {}) => node(
  "TextLabel",
  name,
  textProps({ text, position, size, textSize, textColor, zindex, ...options }),
);

const ASSET = {
  mainWindow: "rbxassetid://75381184130055",
  headerPanel: "rbxassetid://139422887890221",
  questCard: "rbxassetid://93889386487602",
  tabNormal: "rbxassetid://101135473927300",
  tabSelected: "rbxassetid://106120450577925",
  dailyWeeklyIcon: "rbxassetid://86912435019607",
  monthlyIcon: "rbxassetid://78189475055056",
  close: "rbxassetid://119322438066977",
  questIcon1: "rbxassetid://76825236524029",
  questIcon2: "rbxassetid://105499819099238",
  questIcon3: "rbxassetid://88355071605279",
  questIcon4: "rbxassetid://101869041913042",
  headerDecoration: "rbxassetid://75908657886403",
  rewardBox: "rbxassetid://117715064456350",
  cornerDecoration: "rbxassetid://86731176898277",
  progressTrack: "rbxassetid://133345960968161",
  progressGreenFill: "rbxassetid://125033823798319",
  scrollbar: "rbxassetid://73367138577137",
  statusBlue: "rbxassetid://96566593336613",
  statusGreen: "rbxassetid://109147124391851",
  moneyIcon: "rbxassetid://133418085425740",
  xpIcon: "rbxassetid://102202681165196",
};

const CROP = {
  headerPanel: { source: [1672, 941], offset: [22, 279], size: [1628, 376] },
  questCard: { source: [1672, 941], offset: [14, 218], size: [1650, 466] },
  close: { source: [1187, 1326], offset: [375, 422], size: [427, 439] },
  questIcon1: { source: [1187, 1326], offset: [343, 391], size: [492, 513] },
  questIcon2: { source: [1187, 1326], offset: [317, 382], size: [547, 554] },
  questIcon3: { source: [1187, 1326], offset: [302, 366], size: [582, 592] },
  questIcon4: { source: [1187, 1326], offset: [375, 420], size: [435, 455] },
  scrollbarTrack: { source: [1448, 1086], offset: [683, 29], size: [65, 1021] },
  scrollbarThumb: { source: [1448, 1086], offset: [701, 77], size: [30, 825] },
  scrollbarChannel: { source: [1448, 1086], offset: [701, 914], size: [30, 90] },
  headerDecoration: { source: [1187, 1326], offset: [424, 504], size: [342, 174] },
  rewardBox: { source: [1187, 1326], offset: [373, 543], size: [440, 232] },
  moneyIcon: { source: [1187, 1326], offset: [539, 618], size: [58, 64] },
  xpIcon: { source: [1187, 1326], offset: [565, 624], size: [51, 56] },
  cornerDecoration: { source: [1187, 1326], offset: [1000, 1080], size: [187, 246] },
};

const artwork = (imageId, crop, zindex, visible = true) => node("ImageLabel", "Artwork", {
  ...imageProps({
    image: imageId,
    position: crop
      ? udim2(-crop.offset[0] / crop.size[0], 0, -crop.offset[1] / crop.size[1], 0)
      : udim2(0, 0, 0, 0),
    size: crop
      ? udim2(crop.source[0] / crop.size[0], 0, crop.source[1] / crop.size[1], 0)
      : udim2(1, 0, 1, 0),
    visible,
    zindex,
  }),
});

const holder = (name, imageId, crop, position, size, zindex, visible = true, children = []) => node(
  "Frame",
  name,
  gui({ position, size, visible, zindex, clips: crop != null }),
  [artwork(imageId, crop, zindex), ...children],
);

const imageButton = (name, imageId, crop, position, size, zindex, children = []) => node(
  "ImageButton",
  name,
  {
    ...imageProps({ image: "", position, size, zindex }),
    AutoButtonColor: scalar("bool", false),
    ClipsDescendants: scalar("bool", crop != null),
  },
  [artwork(imageId, crop, zindex), ...children],
);

const tab = (period, x, iconId) => {
  const visual = node("Frame", "TabVisual", {
    ...gui({ position: udim2(.5, 0, .5, 0), size: udim2(1, 0, 1, 0), anchor: vec2(.5, .5), zindex: 190 }),
  }, [artwork(period === "Daily" ? ASSET.tabSelected : ASSET.tabNormal, null, 190)]);
  return node(
    "ImageButton",
    `${period}Tab`,
    {
      ...imageProps({ image: "", position: udim2(0, x, 0, 18), size: udim2(0, 352, 0, 176), zindex: 190 }),
      AutoButtonColor: scalar("bool", false),
      ClipsDescendants: scalar("bool", false),
    },
    [
      visual,
      node("ImageLabel", `${period}Icon`, imageProps({
        image: iconId,
        position: udim2(.26, 0, .5, 0),
        size: udim2(0, 60, 0, 60),
        anchor: vec2(.5, .5),
        scaleType: 3,
        zindex: 196,
      })),
      label(
        "Label",
        period,
        udim2(.64, 0, .52, 0),
        udim2(.58, 0, .56, 0),
        33,
        period === "Daily" ? color(255, 255, 255) : color(225, 225, 228),
        196,
        {
          anchor: vec2(.5, .5),
          xalign: 2,
          strokeTransparency: period === "Daily" ? .08 : .28,
        },
      ),
    ],
  );
};

const clock = node("Frame", "Clock", {
  ...gui({ position: udim2(0, 570, 0, 105), size: udim2(0, 42, 0, 42), zindex: 188 }),
}, [
  node("Frame", "ClockCircle", gui({ zindex: 188 }), [corner(21), stroke(30, 221, 255, 3, 0)]),
  node("Frame", "ClockHand", {
    ...gui({ position: udim2(.5, 0, .5, 0), size: udim2(0, 3, 0, 13), anchor: vec2(.5, 1), background: color(30, 221, 255), transparency: 0, zindex: 190 }),
  }, [corner(2)]),
  node("Frame", "ClockCenter", {
    ...gui({ position: udim2(.5, 0, .5, 0), size: udim2(0, 7, 0, 7), anchor: vec2(.5, .5), background: color(30, 221, 255), transparency: 0, zindex: 191 }),
  }, [corner(4)]),
]);

const header = holder(
  "HeaderPanel", ASSET.headerPanel, CROP.headerPanel,
  udim2(0, 42, 0, 178), udim2(0, 1101, 0, 192), 185, true,
  [
    label("HeaderTitle", "Daily Quests", udim2(0, 38, 0, 18), udim2(0, 560, 0, 72), 54, color(255, 255, 255), 188, { strokeTransparency: .05 }),
    label("CompletedText", "0/0 complete", udim2(0, 38, 0, 103), udim2(0, 220, 0, 44), 26, color(30, 221, 255), 188, { font: 19, strokeTransparency: 1 }),
    label("Separator", "|", udim2(0, 245, 0, 103), udim2(0, 25, 0, 44), 29, color(30, 221, 255), 188, { font: 19, xalign: 2, strokeTransparency: 1 }),
    label("ResetText", "Resets automatically in:", udim2(0, 270, 0, 103), udim2(0, 315, 0, 44), 24, color(30, 221, 255), 188, { font: 19, strokeTransparency: 1 }),
    clock,
    label("TimerText", "00h 00m 00s", udim2(0, 620, 0, 103), udim2(0, 310, 0, 44), 26, color(30, 221, 255), 188, { font: 19, strokeTransparency: 1 }),
    holder("HeaderDecoration", ASSET.headerDecoration, CROP.headerDecoration, udim2(0, 760, 0, 17), udim2(0, 320, 0, 160), 187),
  ],
);

const rewardBox = (iconKey, x, suffix) => holder(
  `${iconKey}RewardBox`, ASSET.rewardBox, CROP.rewardBox,
  udim2(0, x, 0, 134), udim2(0, 132, 0, 70), 204, true,
  [
    holder("Icon", ASSET[iconKey === "MoneyIcon" ? "moneyIcon" : "xpIcon"], CROP[iconKey === "MoneyIcon" ? "moneyIcon" : "xpIcon"], udim2(0, 8, 0, 10), udim2(0, 46, 0, 48), 206),
    label("Value", "0", udim2(0, 54, 0, 4), udim2(0, 72, 0, suffix ? 34 : 60), 29, color(255, 255, 255), 207, { xalign: 2 }),
    label("Suffix", suffix ?? "", udim2(0, 54, 0, 35), udim2(0, 72, 0, 24), 20, color(120, 216, 255), 207, { font: 19, xalign: 2, strokeTransparency: .15, visible: suffix != null }),
  ],
);

const fillHolder = node("Frame", "FillHolder", {
  ...gui({ position: udim2(0, 4, 0, 4), size: udim2(1, -8, 1, -8), zindex: 204, clips: true }),
}, [
  corner(20),
  holder("GreenFill", ASSET.progressGreenFill, null, udim2(0, 0, 0, 0), udim2(1, 0, 1, 0), 204, false),
  node("Frame", "BlueFill", {
    ...gui({ size: udim2(0, 0, 1, 0), background: color(0, 139, 255), transparency: 0, visible: false, zindex: 204 }),
  }, [
    corner(20),
    node("UIGradient", "ProgressGradient", {
      Color: colorSequence(
        [0, color(0, 221, 255), 0],
        [1, color(0, 106, 255), 0],
      ),
      Rotation: scalar("float", 90),
    }),
  ]),
]);

const progressTrack = holder(
  "ProgressTrack", ASSET.progressTrack, null,
  udim2(0, 220, 0, 145), udim2(0, 516, 0, 52), 203, true,
  [
    fillHolder,
    label("ProgressText", "0/1", udim2(0, 0, 0, 0), udim2(1, 0, 1, 0), 31, color(255, 255, 255), 206, { xalign: 2, strokeTransparency: 0 }),
  ],
);
progressTrack.props.ClipsDescendants = scalar("bool", true);

const questCardTemplate = holder(
  "QuestCardTemplate", ASSET.questCard, CROP.questCard,
  udim2(0, 0, 0, 0), udim2(0, 1095, 0, 238), 200, false,
  [
    holder("QuestIcon", ASSET.questIcon1, CROP.questIcon1, udim2(0, 24, 0, 26), udim2(0, 166, 0, 166), 203),
    label("QuestTitle", "Quest", udim2(0, 220, 0, 24), udim2(0, 535, 0, 52), 38, color(255, 255, 255), 204),
    label("QuestDescription", "", udim2(0, 220, 0, 74), udim2(0, 535, 0, 52), 25, color(78, 205, 255), 204, { font: 19, wrapped: true, strokeTransparency: .4 }),
    progressTrack,
    holder("StatusBadge", ASSET.statusBlue, null, udim2(0, 785, 0, 24), udim2(0, 261, 0, 62), 203, true, [
      label("StatusText", "In Progress", udim2(0, 0, 0, 0), udim2(1, 0, 1, 0), 28, color(0, 224, 255), 205, { font: 19, xalign: 2, strokeTransparency: .15 }),
    ]),
    label("RewardsLabel", "Rewards", udim2(0, 785, 0, 96), udim2(0, 250, 0, 34), 25, color(72, 210, 255), 204, { font: 19, strokeTransparency: .35 }),
    rewardBox("MoneyIcon", 785, null),
    rewardBox("XPIcon", 925, "XP"),
  ],
);
questCardTemplate.props.LayoutOrder = scalar("int", 0);

const emptyTemplate = label(
  "EmptyQuestTemplate", "Loading quests...",
  udim2(0, 0, 0, 0), udim2(0, 1095, 0, 100), 34,
  color(220, 235, 255), 205, { xalign: 2, visible: false },
);
emptyTemplate.props.LayoutOrder = scalar("int", 1);

const questList = node("ScrollingFrame", "QuestList", {
  ...gui({ position: udim2(0, 42, 0, 382), size: udim2(0, 1095, 0, 876), zindex: 184, clips: true }),
  Active: scalar("bool", true),
  AutomaticCanvasSize: scalar("token", 0),
  CanvasPosition: vec2(0, 0),
  CanvasSize: udim2(0, 0, 0, 0),
  ElasticBehavior: scalar("token", 0),
  ScrollBarImageTransparency: scalar("float", 1),
  ScrollBarThickness: scalar("int", 0),
  ScrollingDirection: scalar("token", 2),
  ScrollingEnabled: scalar("bool", true),
  Selectable: scalar("bool", true),
  VerticalScrollBarInset: scalar("token", 0),
}, [
  node("UIListLayout", "QuestListLayout", {
    FillDirection: scalar("token", 1),
    HorizontalAlignment: scalar("token", 1),
    Padding: udim(0, 12),
    SortOrder: scalar("token", 2),
  }),
]);

const scrollbarTrack = holder(
  "ScrollbarTrack", ASSET.scrollbar, CROP.scrollbarTrack,
  udim2(0, 1152, 0, 382), udim2(0, 28, 0, 876), 186, true,
  [holder("ScrollbarChannel", ASSET.scrollbar, CROP.scrollbarChannel, udim2(.28, 0, .05, 0), udim2(.44, 0, .82, 0), 187)],
);
scrollbarTrack.props.Active = scalar("bool", true);

const scrollbarThumb = holder(
  "ScrollbarThumb", ASSET.scrollbar, CROP.scrollbarThumb,
  udim2(0, 1146, 0, 382), udim2(0, 14, 0, 180), 188,
);
scrollbarThumb.props.Active = scalar("bool", true);

const canvas = node("Frame", "QuestCanvas", {
  ...gui({ position: udim2(.5, 0, .4, 0), size: udim2(0, 1187, 0, 1326), anchor: vec2(.5, .5), visible: false, zindex: 180 }),
}, [
  node("UIScale", "ResponsiveScale", { Scale: scalar("float", .30) }),
  holder("MainWindow", ASSET.mainWindow, null, udim2(0, 0, 0, 0), udim2(0, 1187, 0, 1326), 181),
  tab("Daily", 42, ASSET.dailyWeeklyIcon),
  tab("Weekly", 369, ASSET.dailyWeeklyIcon),
  tab("Monthly", 696, ASSET.monthlyIcon),
  imageButton("CloseButton", ASSET.close, CROP.close, udim2(0, 1053, 0, 37), udim2(0, 85, 0, 99), 210),
  header,
  questList,
  node("TextButton", "ScrollInputCatcher", {
    ...gui({ position: udim2(0, 42, 0, 382), size: udim2(0, 1095, 0, 876), zindex: 250 }),
    Active: scalar("bool", true),
    AutoButtonColor: scalar("bool", false),
    Selectable: scalar("bool", false),
    Text: scalar("string", ""),
    TextTransparency: scalar("float", 1),
  }),
  scrollbarTrack,
  scrollbarThumb,
  node("Frame", "QuestCardRightEdgeMask", gui({ position: udim2(0, 1133, 0, 382), size: udim2(0, 5, 0, 876), background: color(1, 28, 58), transparency: 0, visible: true, zindex: 252 })),
  holder("CornerDecoration", ASSET.cornerDecoration, CROP.cornerDecoration, udim2(0, 1000, 0, 1090), udim2(0, 185, 0, 225), 208, false),
]);

const templates = node("Folder", "Templates", {}, [questCardTemplate, emptyTemplate]);
const model = node("Frame", "ModernQuestUI", gui({ visible: false, zindex: 180 }), [
  canvas,
  templates,
  node("BlurEffect", "FishyFishQuestUiBlur", {
    Enabled: scalar("bool", false),
    Size: scalar("float", 0),
  }),
]);

const escapeXml = (value) => String(value)
  .replaceAll("&", "&amp;")
  .replaceAll("<", "&lt;")
  .replaceAll(">", "&gt;")
  .replaceAll('"', "&quot;")
  .replaceAll("'", "&apos;");

let referent = 0;
const propertyXml = (name, declaration, indent) => {
  const pad = "\t".repeat(indent);
  const { tag, value } = declaration;
  if (["string", "float", "int", "token", "bool"].includes(tag)) {
    const normalized = tag === "bool" ? String(value).toLowerCase() : value;
    return `${pad}<${tag} name="${name}">${escapeXml(normalized)}</${tag}>`;
  }
  if (tag === "Content") return `${pad}<Content name="${name}"><url>${escapeXml(value)}</url></Content>`;
  if (tag === "UDim") return `${pad}<UDim name="${name}"><S>${value[0]}</S><O>${value[1]}</O></UDim>`;
  if (tag === "UDim2") return `${pad}<UDim2 name="${name}"><XS>${value[0]}</XS><XO>${value[1]}</XO><YS>${value[2]}</YS><YO>${value[3]}</YO></UDim2>`;
  if (tag === "Vector2") return `${pad}<Vector2 name="${name}"><X>${value[0]}</X><Y>${value[1]}</Y></Vector2>`;
  if (tag === "Color3") return `${pad}<Color3 name="${name}"><R>${value[0]}</R><G>${value[1]}</G><B>${value[2]}</B></Color3>`;
  if (tag === "ColorSequence") {
    const encoded = value.flatMap(([time, declarationColor, envelope]) => [time, ...declarationColor.value, envelope]).join(" ");
    return `${pad}<ColorSequence name="${name}">${encoded}</ColorSequence>`;
  }
  throw new Error(`Unsupported property type: ${tag}`);
};

const nodeXml = (item, indent) => {
  referent += 1;
  const pad = "\t".repeat(indent);
  const lines = [
    `${pad}<Item class="${item.className}" referent="RBX${referent.toString(16).toUpperCase().padStart(8, "0")}">`,
    `${pad}\t<Properties>`,
    `${pad}\t\t<string name="Name">${escapeXml(item.name)}</string>`,
  ];
  for (const key of Object.keys(item.props).sort()) lines.push(propertyXml(key, item.props[key], indent + 2));
  lines.push(`${pad}\t</Properties>`);
  for (const child of item.children) lines.push(nodeXml(child, indent + 1));
  lines.push(`${pad}</Item>`);
  return lines.join("\n");
};

const xml = [
  '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
  '\t<Meta name="ExplicitAutoJoints">true</Meta>',
  '\t<External>null</External>',
  '\t<External>nil</External>',
  nodeXml(model, 1),
  '</roblox>',
  '',
].join("\n");

await fs.writeFile(OUTPUT, xml, "utf8");
console.log(`Generated ${OUTPUT}`);
