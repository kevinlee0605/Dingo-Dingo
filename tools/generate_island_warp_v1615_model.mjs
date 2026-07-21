// Generate the exact authored v1615 Island Warp base hierarchy.
// Destination rows are cloned from IslandCardTemplate by the bind-only client.

import fs from "node:fs/promises";
import path from "node:path";
import {
  scalar, udim, udim2, vec2, color, content, node, gui,
  textProps, imageProps, corner, escapeXml, propertyXml,
} from "./generate_fishdex_v22_model.mjs";

const ROOT = path.resolve(import.meta.dirname, "..");
const OUTPUT = path.join(ROOT, "src", "ui", "FishingGui", "BiomeWarpOverlay.rbxmx");

const ASSET = {
  backbone: "rbxassetid://139219110427433",
  lilyshore: "rbxassetid://94386681729236",
  riverbend: "rbxassetid://83913634264814",
  coral: "rbxassetid://122703152321295",
  go: "rbxassetid://111469265624538",
  decoration: "rbxassetid://81989089279793",
  coin: "rbxassetid://79109082679955",
  card: "rbxassetid://135395684428311",
  close: "rbxassetid://94429518283822",
  coming: "rbxassetid://97504855517031",
};

const CROP = {
  lilyshore: { source: [1211, 1299], offset: [462, 552], size: [254, 247] },
  decoration: { source: [1211, 1299], offset: [534, 609], size: [139, 115] },
  go: { source: [1211, 1299], offset: [459, 536], size: [279, 172] },
  close: { source: [1187, 1326], offset: [375, 422], size: [427, 439] },
  card: { source: [1200, 420], offset: [35, 56], size: [1130, 308] },
  coming: { source: [1211, 1299], offset: [345, 448], size: [473, 417] },
};

const artwork = (imageId, crop, zindex, tint = color(255, 255, 255)) => {
  const position = crop
    ? udim2(-crop.offset[0] / crop.size[0], 0, -crop.offset[1] / crop.size[1], 0)
    : udim2(0, 0, 0, 0);
  const size = crop
    ? udim2(crop.source[0] / crop.size[0], 0, crop.source[1] / crop.size[1], 0)
    : udim2(1, 0, 1, 0);
  return node("ImageLabel", "Artwork", {
    ...imageProps({ image: imageId, position, size, zindex }),
    ImageColor3: tint,
  });
};

const holder = (name, imageId, crop, position, size, zindex, visible = true, children = []) => node("Frame", name, {
  ...gui({ position, size, visible, clips: crop != null, zindex }),
}, [artwork(imageId, crop, zindex), ...children]);

const imageButton = (name, imageId, crop, position, size, zindex, children = [], enabled = true) => node("ImageButton", name, {
  ...imageProps({ image: "", position, size, zindex }),
  Active: scalar("bool", enabled),
  AutoButtonColor: scalar("bool", false),
  ClipsDescendants: scalar("bool", crop != null),
  Selectable: scalar("bool", enabled),
}, [artwork(imageId, crop, zindex, enabled ? color(255, 255, 255) : color(160, 175, 210)), ...children]);

const label = (name, text, position, size, textSize, textColor, zindex, xalign = 0) => node("TextLabel", name, textProps({
  text, position, size, textSize, scaled: false, textColor, zindex, xalign,
}));

const goLabel = (text) => label(
  "Label", text, udim2(0, 0, 0, 0), udim2(1, 0, 1, 0), 57,
  color(255, 255, 255), 310, 2,
);

const goButton = (text = "GO", enabled = true) => imageButton(
  "GoButton", ASSET.go, CROP.go,
  udim2(0, 790, 0, 74), udim2(0, 260, 0, 158), 308,
  [goLabel(text)], enabled,
);

const cardBase = (name, visible, layoutOrder, children) => holder(
  name, ASSET.card, CROP.card,
  udim2(0, 0, 0, 0), udim2(0, 1090, 0, 300), 303,
  visible,
  children,
);
cardBase;

const islandCardTemplate = cardBase("IslandCardTemplate", false, 0, [
  holder(
    "IslandIcon", ASSET.lilyshore, CROP.lilyshore,
    udim2(0, 18, 0, 18), udim2(0, 285, 0, 258), 306,
  ),
  label("IslandTitle", "Lilyshore Island", udim2(0, 310, 0, 50), udim2(0, 490, 0, 70), 49, color(255, 255, 255), 307),
  label("RequirementLabel", "Requirement:", udim2(0, 315, 0, 142), udim2(0, 235, 0, 50), 31, color(172, 200, 255), 307),
  label("RequirementValue", "Free", udim2(0, 495, 0, 142), udim2(0, 220, 0, 50), 31, color(52, 231, 76), 307),
  holder("CoinIcon", ASSET.coin, null, udim2(0, 315, 0, 177), udim2(0, 58, 0, 58), 307, false),
  node("TextLabel", "CoinRequirement", {
    ...textProps({
      text: "5,000 Coins", position: udim2(0, 383, 0, 174), size: udim2(0, 380, 0, 62),
      textSize: 34, scaled: false, textColor: color(255, 220, 31), zindex: 307, xalign: 0,
    }),
    Visible: scalar("bool", false),
  }),
  goButton(),
]);
islandCardTemplate.props.LayoutOrder = scalar("int", 0);

const comingCard = cardBase("ComingSoonCard", true, 4, [
  holder(
    "ComingSoonIsland", ASSET.coming, CROP.coming,
    udim2(0, 8, 0, 7), udim2(0, 300, 0, 278), 306,
  ),
  label("IslandTitle", "???", udim2(0, 310, 0, 43), udim2(0, 450, 0, 82), 62, color(255, 255, 255), 307),
  label("Requirement", "Requirement: Unavailable", udim2(0, 315, 0, 139), udim2(0, 480, 0, 58), 33, color(102, 200, 255), 307),
  label("Detail", "More islands on the way", udim2(0, 315, 0, 198), udim2(0, 470, 0, 55), 31, color(255, 221, 35), 307),
  goButton("SOON", false),
]);
comingCard.props.LayoutOrder = scalar("int", 4);

const cards = node("Frame", "Cards", {
  ...gui({ size: udim2(1, 0, 0, 1302), zindex: 302 }),
  AutomaticSize: scalar("token", 0),
}, [
  node("UIListLayout", "UIListLayout", {
    FillDirection: scalar("token", 1),
    HorizontalAlignment: scalar("token", 0),
    Padding: udim(0, 26),
    SortOrder: scalar("token", 2),
  }),
  comingCard,
]);

const islandList = node("ScrollingFrame", "IslandList", {
  ...gui({ position: udim2(0, 43, 0, 176), size: udim2(0, 1125, 0, 1060), clips: true, zindex: 302 }),
  Active: scalar("bool", true),
  AutomaticCanvasSize: scalar("token", 0),
  CanvasPosition: vec2(0, 0),
  CanvasSize: udim2(0, 0, 0, 1302),
  ScrollBarImageColor3: color(33, 137, 255),
  ScrollBarThickness: scalar("int", 8),
  ScrollingDirection: scalar("token", 2),
  ScrollingEnabled: scalar("bool", true),
  Selectable: scalar("bool", true),
}, [cards]);

const root = node("ImageLabel", "ModernIslandWarp", imageProps({
  image: ASSET.backbone,
  position: udim2(.5, 0, .4, 0),
  size: udim2(0, 1211, 0, 1299),
  anchor: vec2(.5, .5),
  visible: false,
  zindex: 300,
}), [
  node("UIScale", "ResponsiveScale", { Scale: scalar("float", 1) }),
  holder(
    "TopLeftDecoration", ASSET.decoration, CROP.decoration,
    udim2(0, 35, 0, 31), udim2(0, 155, 0, 128), 304,
  ),
  label("Title", "ISLAND WARP", udim2(0, 200, 0, 52), udim2(0, 720, 0, 100), 70, color(255, 255, 255), 304),
  imageButton(
    "CloseButton", ASSET.close, CROP.close,
    udim2(0, 1052, 0, 38), udim2(0, 108, 0, 108), 310,
  ),
  islandList,
  islandCardTemplate,
]);

const model = node("Frame", "BiomeWarpOverlay", gui({ visible: false, zindex: 300 }), [root]);

let referent = 0;
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
