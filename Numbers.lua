local _, ns = ...

-- Display counts only. IDs and machine-readable values remain unchanged.
function ns.FormatCount(value)
    if type(value) ~= "number" then return tostring(value or "unknown") end
    local text = tostring(value)
    local sign, whole, fraction = text:match("^(-?)(%d+)(.*)$")
    if not whole then return text end
    whole = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return sign .. whole .. fraction
end
