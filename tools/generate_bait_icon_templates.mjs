import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const outputPath = path.resolve(scriptDirectory, "../src/ui/FishingGui/BaitIconTemplates.rbxmx");

const model = `<?xml version="1.0" encoding="utf-8"?>
<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
	<Meta name="ExplicitAutoJoints">true</Meta>
	<External>null</External>
	<External>nil</External>
	<Item class="Folder" referent="RBX00000001">
		<Properties>
			<string name="Name">BaitIconTemplates</string>
		</Properties>
		<Item class="ImageLabel" referent="RBX00000002">
			<Properties>
				<string name="Name">BaitIconTemplate</string>
				<Vector2 name="AnchorPoint">
					<X>0.5</X>
					<Y>0.5</Y>
				</Vector2>
				<Color3 name="BackgroundColor3">
					<R>1</R>
					<G>1</G>
					<B>1</B>
				</Color3>
				<float name="BackgroundTransparency">1</float>
				<int name="BorderSizePixel">0</int>
				<bool name="ClipsDescendants">false</bool>
				<Vector2 name="ImageRectOffset">
					<X>0</X>
					<Y>0</Y>
				</Vector2>
				<Vector2 name="ImageRectSize">
					<X>0</X>
					<Y>0</Y>
				</Vector2>
				<int name="LayoutOrder">0</int>
				<UDim2 name="Position">
					<XS>0</XS>
					<XO>0</XO>
					<YS>0</YS>
					<YO>0</YO>
				</UDim2>
				<token name="ScaleType">3</token>
				<UDim2 name="Size">
					<XS>0</XS>
					<XO>0</XO>
					<YS>0</YS>
					<YO>0</YO>
				</UDim2>
				<bool name="Visible">false</bool>
				<int name="ZIndex">99</int>
			</Properties>
		</Item>
	</Item>
</roblox>
`;

fs.writeFileSync(outputPath, model, "utf8");
console.log(`Generated ${outputPath}`);
