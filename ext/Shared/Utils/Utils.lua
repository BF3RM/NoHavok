local HAVOK_GUID_PREFIX = "ED170123"
local GUIDIndex = 0
function h()
    local vars = {"A","B","C","D","E","F","0","1","2","3","4","5","6","7","8","9"}
    return vars[math.floor(MathUtils:GetRandomInt(1,16))]..vars[math.floor(MathUtils:GetRandomInt(1,16))]
end

-- Generates a random guid.
function GenerateGuid()
    return Guid(HAVOK_GUID_PREFIX.."-"..h()..h().."-"..h()..h().."-"..h()..h().."-"..h()..h()..h()..h()..h()..h(), "D")
end

function GenerateStaticGuid()
    GUIDIndex = GUIDIndex + 1
    return Guid(HAVOK_GUID_PREFIX.."-0000-0000-0000-"..GetFilledNumberAsString(GUIDIndex, 12), "D")
end

function GetFilledNumberAsString(n, stringLength)
    local n_string = tostring(n)
    local prefix = ""

    if string.len(n_string) < stringLength then
        for i=1,stringLength - string.len(n_string) do
            prefix = prefix .."0"
        end
    end

    return (prefix..n_string)
end

function DecreasedGuid( p_Guid )
    local s_Part1 = p_Guid:sub(1,9)
    local s_Part2 = string.byte(p_Guid:sub(10,10))
    local s_Part3 = string.byte(p_Guid:sub(11,11))
    local s_Part4 = p_Guid:sub(12,36)

    if(s_Part3 == 48) then -- 0
        s_Part2 = s_Part2 - 1
        s_Part3 = 70 -- F
    elseif s_Part3 == 65 then -- A
        s_Part3 = 57 -- 9
    else
        s_Part3 = s_Part3 - 1
    end

    local s_Ret = s_Part1 .. string.char(s_Part2) .. string.char(s_Part3) .. s_Part4
    return s_Ret
end

function IncreasedGuid( p_Guid )
    local s_Part1 = p_Guid:sub(1,9)
    local s_Part2 = string.byte(p_Guid:sub(10,10))
    local s_Part3 = string.byte(p_Guid:sub(11,11))
    local s_Part4 = p_Guid:sub(12,36)

    if(s_Part3 == 70) then -- 0
        s_Part2 = s_Part2 + 1
        s_Part3 = 48 -- 0
    elseif s_Part3 == 57 then -- A
        s_Part3 = 65 -- 9
    else
        s_Part3 = s_Part3 + 1
    end

    local s_Ret = s_Part1 .. string.char(s_Part2) .. string.char(s_Part3) .. s_Part4
    return s_Ret
end


function StringToVec3(linearTransformString)
    local s_LinearTransformRaw = tostring(linearTransformString)
    local s_Split = s_LinearTransformRaw:gsub("%(", ""):gsub("%)", ""):gsub("% ", ","):split(",")
    local s_Vec = Vec3(tonumber(s_Split[1]), tonumber(s_Split[2]), tonumber(s_Split[3]))
    return s_Vec
end

function StringToVec4(linearTransformString)
    local s_LinearTransformRaw = tostring(linearTransformString)
    local s_Split = s_LinearTransformRaw:gsub("%(", ""):gsub("%)", ""):gsub("% ", ","):split(",")

    local s_Vec = Vec4(tonumber(s_Split[1]), tonumber(s_Split[2]), tonumber(s_Split[3]), tonumber(s_Split[4]))

    return s_Vec
end

function QuatToLineartransform( quat, pos, scale )
    local res = LinearTransform()
    res.left = VecMultiply(quat, Vec3(scale,0,0))
    res.up = VecMultiply(quat, Vec3(0,scale,0))
    res.forward = VecMultiply(quat, Vec3(0,0,scale))


    -- TODO: Scale?!

    res.trans = pos

    return res

end

function VecMultiply(quat, vec)
    local num = quat.x * 2.0
    local num2 = quat.y * 2.0
    local num3 = quat.z * 2.0
    local num4 = quat.x * num
    local num5 = quat.y * num2
    local num6 = quat.z * num3
    local num7 = quat.x * num2
    local num8 = quat.x * num3
    local num9 = quat.y * num3
    local num10 = quat.w * num
    local num11 = quat.w * num2
    local num12 = quat.w * num3
    local result = Vec3()

    result.x = (1.0 - (num5 + num6)) * vec.x + (num7 - num12) * vec.y + (num8 + num11) * vec.z;
    result.y = (num7 + num12) * vec.x + (1.0 - (num4 + num6)) * vec.y + (num9 - num10) * vec.z;
    result.z = (num8 - num11) * vec.x + (num9 + num10) * vec.y + (1.0 - (num4 + num5)) * vec.z;
    return result;
end


function string:split(sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end