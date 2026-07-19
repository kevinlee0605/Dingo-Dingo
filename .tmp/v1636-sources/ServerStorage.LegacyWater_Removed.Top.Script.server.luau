local stage = 0
function up()
script.Parent.CFrame = script.Parent.CFrame + Vector3.new(.1, 0, .1)
script.Parent.Mesh.Scale = script.Parent.Mesh.Scale + Vector3.new(.2, 0, .2)
end

function down()
script.Parent.CFrame = script.Parent.CFrame + Vector3.new(-.1, 0, -.1)
script.Parent.Mesh.Scale = script.Parent.Mesh.Scale + Vector3.new(-.2, 0, -.2)
end
while true do
for i=0,360,1 do 
up()
wait(.1)
end 
for i=0,360,1 do 
down()
wait(.1)
end 
end 