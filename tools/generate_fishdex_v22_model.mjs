// Generate the authored v1615 / FishdexVisualPatch v22 base hierarchy.
// Dynamic fish entries clone the hidden FishCardTemplate; the controller only
// binds events, state, and scrolling behavior to this persisted skin.

import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUTPUT = path.join(ROOT, "src", "ui", "FishingGui", "ModernFishdex.rbxmx");

const scalar = (tag, value) => ({ tag, value });
const udim = (scale, offset) => ({ tag: "UDim", value: [scale, offset] });
const udim2 = (xs, xo, ys, yo) => ({ tag: "UDim2", value: [xs, xo, ys, yo] });
const vec2 = (x, y) => ({ tag: "Vector2", value: [x, y] });
const color = (r, g, b) => ({ tag: "Color3", value: [r / 255, g / 255, b / 255] });
const colorSequence = (...keypoints) => ({
  tag: "ColorSequence",
  value: keypoints.flatMap(([time, r, g, b, envelope = 0]) => [
    time,
    r / 255,
    g / 255,
    b / 255,
    envelope,
  ]),
});
const content = (value) => ({ tag: "Content", value });
const node = (className, name, props = {}, children = []) => ({ className, name, props, children });

const gui = ({
  position = udim2(0, 0, 0, 0),
  size = udim2(1, 0, 1, 0),
  anchor = vec2(0, 0),
  transparency = 1,
  background = color(255, 255, 255),
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
  scaled,
  textColor = color(255, 255, 255),
  zindex,
  xalign = 2,
  yalign = 1,
}) => ({
  ...gui({ position, size, anchor, zindex }),
  Font: scalar("token", 26), // FredokaOne
  Text: scalar("string", text),
  TextColor3: textColor,
  TextScaled: scalar("bool", scaled),
  TextSize: scalar("float", textSize),
  TextStrokeColor3: color(0, 0, 0),
  TextStrokeTransparency: scalar("float", 0),
  TextTransparency: scalar("float", 0),
  TextXAlignment: scalar("token", xalign),
  TextYAlignment: scalar("token", yalign),
});

const sizeConstraint = (minimum, maximum) => node("UITextSizeConstraint", "UITextSizeConstraint", {
  MaxTextSize: scalar("int", maximum),
  MinTextSize: scalar("int", minimum),
});

const corner = (name, scale, offset) => node("UICorner", name, {
  CornerRadius: udim(scale, offset),
});

const stroke = (name, r, g, b, thickness, transparency, contextual = false) => node("UIStroke", name, {
  ...(contextual ? { ApplyStrokeMode: scalar("token", 0) } : {}),
  Color: color(r, g, b),
  Thickness: scalar("float", thickness),
  Transparency: scalar("float", transparency),
});

const imageProps = ({
  image,
  position,
  size,
  anchor = vec2(0, 0),
  scaleType = 0,
  imageTransparency = 0,
  visible = true,
  zindex,
}) => ({
  ...gui({ position, size, anchor, visible, zindex }),
  Image: content(image),
  ImageColor3: color(255, 255, 255),
  ImageTransparency: scalar("float", imageTransparency),
  ScaleType: scalar("token", scaleType),
});

const ASSET = {
  background: "rbxassetid://89231191992466",
  fishdexIcon: "rbxassetid://126888363962311",
  yellowBadge: "rbxassetid://86677248763340",
  close: "rbxassetid://119322438066977",
  allSelected: "rbxassetid://74193356060798",
  allNormal: "rbxassetid://122642765846638",
  islandSelected: "rbxassetid://119120751789446",
  islandNormal: "rbxassetid://74423157457349",
  allIcon: "rbxassetid://104401098200678",
  lilyshoreIcon: "rbxassetid://98205500611196",
  riverbendIcon: "rbxassetid://71447038153276",
  coralIcon: "rbxassetid://118883751708776",
  collection: "rbxassetid://101419501637204",
  checked: "rbxassetid://73430945226148",
  fishCard: "rbxassetid://77909229815890",
};

const tabs = [
  { name: "AllTab", label: "All", image: ASSET.allSelected, icon: ASSET.allIcon, x: 136, w: 194, textX: .70, textW: .28, textMax: 35, iconX: .25, iconSize: 48 },
  { name: "LilyshoreIslandTab", label: "Lilyshore Island", image: ASSET.islandNormal, icon: ASSET.lilyshoreIcon, x: 356, w: 345, textX: .63, textW: .60, textMax: 32, iconX: .16, iconSize: 60 },
  { name: "RiverbendIslandTab", label: "Riverbend Island", image: ASSET.islandNormal, icon: ASSET.riverbendIcon, x: 725, w: 342, textX: .63, textW: .60, textMax: 32, iconX: .16, iconSize: 60 },
  { name: "CoralCoastIslandTab", label: "Coral Coast Island", image: ASSET.islandNormal, icon: ASSET.coralIcon, x: 1090, w: 335, textX: .63, textW: .62, textMax: 31, iconX: .16, iconSize: 60 },
];

const tabNodes = tabs.map((tab) => node("ImageButton", tab.name, {
  ...imageProps({ image: tab.image, position: udim2(0, tab.x, 0, 153), size: udim2(0, tab.w, 0, 82), zindex: 207 }),
  AutoButtonColor: scalar("bool", false),
}, [
  node("TextLabel", "TabTitle", textProps({
    text: tab.label,
    position: udim2(tab.textX, 0, .5, 0),
    size: udim2(tab.textW, 0, .68, 0),
    anchor: vec2(.5, .5),
    textSize: tab.textMax,
    scaled: true,
    zindex: 208,
  }), [sizeConstraint(14, tab.textMax)]),
  node("ImageLabel", "TabIcon", imageProps({
    image: tab.icon,
    position: udim2(tab.iconX, 0, .5, 0),
    size: udim2(0, tab.iconSize, 0, tab.iconSize),
    anchor: vec2(.5, .5),
    scaleType: 3,
    zindex: 208,
  })),
  stroke("SelectedStroke", 160, 235, 255, 3, 1),
  corner("UICorner", 0, 18),
]));

const fishCardTemplate = node("ImageLabel", "FishCardTemplate", {
  ...imageProps({ image: ASSET.fishCard, position: udim2(0, 0, 0, 0), size: udim2(0, 390, 0, 270), visible: false, zindex: 206 }),
  BackgroundColor3: color(2, 31, 82),
  BackgroundTransparency: scalar("float", 0),
  ImageTransparency: scalar("float", 1),
  LayoutOrder: scalar("int", 0),
}, [
  corner("ReferenceCardCorner", 0, 18),
  stroke("ReferenceCardBorder", 10, 112, 255, 3, 0),
  node("Frame", "ReferenceInnerBorder", gui({
    position: udim2(0, 8, 0, 8), size: udim2(1, -16, 1, -16), zindex: 206,
  }), [
    corner("ReferenceInnerCorner", 0, 14),
    stroke("ReferenceInnerStroke", 7, 76, 181, 2, .18),
  ]),
  node("ImageLabel", "FishImage", imageProps({
    image: "",
    position: udim2(.5, 0, .33, 0),
    size: udim2(.92, 0, .58, 0),
    anchor: vec2(.5, .5),
    scaleType: 3,
    zindex: 207,
  })),
  node("TextLabel", "FishName", textProps({
    text: "???",
    position: udim2(.5, 0, .67, 0),
    size: udim2(.92, 0, .16, 0),
    anchor: vec2(.5, .5),
    textSize: 25,
    scaled: true,
    zindex: 207,
  }), [sizeConstraint(12, 25)]),
  node("ImageLabel", "RarityBadge", {
    ...imageProps({
      image: "",
      position: udim2(.5, 0, .84, 0),
      size: udim2(.62, 0, .18, 0),
      anchor: vec2(.5, .5),
      zindex: 207,
    }),
    BackgroundColor3: color(82, 92, 112),
    BackgroundTransparency: scalar("float", 0),
    ImageTransparency: scalar("float", 1),
  }, [
    corner("ReferenceCorner", 0, 12),
    stroke("ReferenceBorder", 190, 202, 224, 3, 0),
    node("UIGradient", "ReferenceGradient", {
      Color: colorSequence(
        [0, 255, 255, 255],
        [1, 190, 200, 220],
      ),
      Rotation: scalar("float", 90),
    }),
    node("TextLabel", "RarityText", textProps({
      text: "COMMON",
      position: udim2(.5, 0, .5, 0),
      size: udim2(.88, 0, .72, 0),
      anchor: vec2(.5, .5),
      textSize: 22,
      scaled: true,
      zindex: 208,
    }), [sizeConstraint(10, 22)]),
  ]),
]);

const title = node("TextLabel", "FishdexTitle", textProps({
  text: "FISHDEX",
  position: udim2(0, 790, 0, 35),
  size: udim2(0, 650, 0, 112),
  anchor: vec2(.5, 0),
  textSize: 100,
  scaled: false,
  zindex: 210,
}), [
  stroke("FishdexTitleOutline", 0, 0, 0, 4, 0, true),
  sizeConstraint(38, 88),
]);

const closeButton = node("ImageButton", "CloseButton", {
  ...imageProps({ image: ASSET.close, position: udim2(0, 1290, 0, -20), size: udim2(0, 250, 0, 250), scaleType: 3, imageTransparency: 1, zindex: 211 }),
  AutoButtonColor: scalar("bool", false),
});

const closeVisual = node("ImageLabel", "CloseButtonStaticVisual", {
  ...imageProps({ image: ASSET.close, position: udim2(0, 1290, 0, -20), size: udim2(0, 250, 0, 250), scaleType: 3, zindex: 212 }),
  Active: scalar("bool", false),
  Selectable: scalar("bool", false),
}, [node("UIScale", "ClosePressScale", { Scale: scalar("float", 1) })]);

const cardsHolder = node("Frame", "CardsHolder", {
  ...gui({ position: udim2(0, 3, 0, 3), size: udim2(1, -6, 0, 0), zindex: 202 }),
  AutomaticSize: scalar("token", 2),
}, [node("UIGridLayout", "UIGridLayout", {
  CellPadding: udim2(0, 24, 0, 22),
  CellSize: udim2(0, 390, 0, 270),
  FillDirection: scalar("token", 0),
  FillDirectionMaxCells: scalar("int", 3),
  HorizontalAlignment: scalar("token", 0),
  SortOrder: scalar("token", 2),
})]);

const cardsScroll = node("ScrollingFrame", "FishCardsScroll", {
  ...gui({ position: udim2(0, 125, 0, 300), size: udim2(0, 1275, 0, 610), clips: true, zindex: 205 }),
  AutomaticCanvasSize: scalar("token", 2),
  BottomImage: content(""),
  CanvasPosition: vec2(0, 0),
  CanvasSize: udim2(0, 0, 0, 0),
  MidImage: content(""),
  ScrollBarImageTransparency: scalar("float", 1),
  ScrollBarThickness: scalar("int", 0),
  ScrollingDirection: scalar("token", 2),
  ScrollingEnabled: scalar("bool", true),
  TopImage: content(""),
  VerticalScrollBarInset: scalar("token", 0),
}, [cardsHolder]);

const collection = node("ImageLabel", "CollectionPanel", imageProps({
  image: ASSET.collection,
  position: udim2(0, 1172, 0, 860),
  size: udim2(0, 327, 0, 103),
  zindex: 207,
}), [
  node("ImageLabel", "CheckedIcon", imageProps({
    image: ASSET.checked,
    position: udim2(.20, 0, .50, 0),
    size: udim2(0, 78, 0, 78),
    anchor: vec2(.5, .5),
    scaleType: 3,
    zindex: 208,
  })),
  node("TextLabel", "CollectionTitle", textProps({
    text: "Collection",
    position: udim2(.64, 0, .28, 0),
    size: udim2(.58, 0, .30, 0),
    anchor: vec2(.5, .5),
    textSize: 30,
    scaled: false,
    textColor: color(50, 241, 255),
    zindex: 208,
  }), [sizeConstraint(16, 30)]),
  node("TextLabel", "CollectionCount", textProps({
    text: "0 / 0",
    position: udim2(.64, 0, .68, 0),
    size: udim2(.54, 0, .38, 0),
    anchor: vec2(.5, .5),
    textSize: 38,
    scaled: false,
    zindex: 208,
  }), [sizeConstraint(20, 38)]),
]);

const thumb = node("ImageButton", "FishdexCustomScrollThumb", {
  ...imageProps({ image: "", position: udim2(.5, 0, 0, 2), size: udim2(0, 20, 0, 516), anchor: vec2(.5, 0), zindex: 216 }),
  Active: scalar("bool", true),
  AutoButtonColor: scalar("bool", false),
  BackgroundColor3: color(0, 118, 255),
  BackgroundTransparency: scalar("float", 0),
  Selectable: scalar("bool", false),
}, [
  corner("ThumbCorner", 1, 0),
  node("UIGradient", "ThumbGradient", {
    Color: colorSequence(
      [0, 0, 239, 255],
      [.34, 0, 167, 255],
      [1, 15, 72, 235],
    ),
    Rotation: scalar("float", 90),
  }),
  stroke("ThumbGlowStroke", 0, 235, 255, 2, 0),
  node("Frame", "ThumbHighlight", {
    ...gui({ position: udim2(.18, 0, .04, 0), size: udim2(.18, 0, .92, 0), background: color(188, 252, 255), transparency: .43, zindex: 217 }),
    Active: scalar("bool", false),
  }, [corner("HighlightCorner", 1, 0)]),
]);

const scrollTrack = node("Frame", "FishdexCustomScrollTrack", {
  ...gui({ position: udim2(0, 1390, 0, 310), size: udim2(0, 24, 0, 520), background: color(3, 22, 62), transparency: 0, clips: true, zindex: 214 }),
  Active: scalar("bool", true),
}, [
  corner("TrackCorner", 1, 0),
  stroke("TrackStroke", 18, 93, 245, 2, .08),
  node("UIGradient", "TrackGradient", {
    Color: colorSequence(
      [0, 8, 39, 101],
      [.5, 2, 18, 53],
      [1, 8, 39, 101],
    ),
    Rotation: scalar("float", 0),
  }),
  thumb,
]);

const canvas = node("ImageLabel", "ModernFishdex", imageProps({
  image: ASSET.background,
  position: udim2(.5, 0, .43, 0),
  size: udim2(0, 1536, 0, 1024),
  anchor: vec2(.5, .5),
  visible: false,
  zindex: 200,
}), [
  node("UIScale", "ResponsiveScale", { Scale: scalar("float", .37) }),
  title,
  node("ImageLabel", "FishdexHeaderIcon", imageProps({ image: ASSET.fishdexIcon, position: udim2(0, 540, 0, 30), size: udim2(0, 114, 0, 114), anchor: vec2(.5, 0), scaleType: 3, zindex: 210 })),
  node("ImageLabel", "HeaderYellowBadge", imageProps({ image: ASSET.yellowBadge, position: udim2(0, 48, 0, 43), size: udim2(0, 60, 0, 60), scaleType: 3, zindex: 210 })),
  closeButton,
  closeVisual,
  node("Frame", "TabsDivider", gui({ position: udim2(0, 770, 0, 262), size: udim2(0, 1368, 0, 2), anchor: vec2(.5, 0), background: color(68, 164, 255), transparency: .35, zindex: 206 })),
  ...tabNodes,
  cardsScroll,
  collection,
  scrollTrack,
  fishCardTemplate,
]);

const model = node("Frame", "ModernFishdex", gui({ visible: false, zindex: 200 }), [canvas]);

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
  if (tag === "ColorSequence") return `${pad}<ColorSequence name="${name}">${value.join(" ")}</ColorSequence>`;
  throw new Error(`Unsupported property type: ${tag}`);
};

const nodeXml = (item, indent) => {
  referent += 1;
  const pad = "\t".repeat(indent);
  const lines = [`${pad}<Item class="${item.className}" referent="RBX${referent.toString(16).toUpperCase().padStart(8, "0")}">`, `${pad}\t<Properties>`, `${pad}\t\t<string name="Name">${escapeXml(item.name)}</string>`];
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

export {
  scalar,
  udim,
  udim2,
  vec2,
  color,
  colorSequence,
  content,
  node,
  gui,
  textProps,
  imageProps,
  sizeConstraint,
  corner,
  stroke,
  escapeXml,
  propertyXml,
};
