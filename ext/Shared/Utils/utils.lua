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