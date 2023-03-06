
local Base64 = {}

local CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local CHAR_TABLE = string.split(CHARS, "")

local function pushOctet(stack: number, byte: number)
    stack = bit32.lshift(stack, 8)
    stack = bit32.bor(stack, byte)
    return stack
end

local function splitStack(stack: number, size: number)

    local mask = 0b111111

    local elements = {}
    for offset = 0, size - 6, 6 do
        local element = bit32.band(mask, bit32.rshift(stack, offset))
        table.insert(elements, 1, element)
    end

    return elements
end
local function bit32Encode(data: string)
    local charCodes = {data:byte(1, #data)}
    local encodedData = {}

    for i = 1, #charCodes, 3 do
        local stack, b, c = charCodes[i], charCodes[i+1], charCodes[i+2]
        stack = pushOctet(stack, b)
        stack = pushOctet(stack, c)

        for _, element in splitStack(stack, 24) do
            table.insert(encodedData, element)
        end

    end

    local encodedString = ""
    for _, code in encodedData do
        encodedString ..= CHAR_TABLE[code+1]
    end

    return encodedString
end

-- this function converts a string to base64
function Base64:Encode(data: string)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x)
        local r, b = '', x:byte()
        for i=8,1,-1 do 
            r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0')
        end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then
            return ''
        end
        local c=0
        for i=1,6 do 
            c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0)
        end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- this function converts base64 to string
function Base64:Decode(data: string)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if x == '=' then
            return ''
        end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do 
            r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0')
        end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c=0
        for i=1,8 do
            c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0)
        end
        return string.char(c)
    end))
end

local test = "Manmanmanmanmanmna"

local t0 = os.clock()
for _ = 1, 1_000_000 do
    bit32Encode(test)
end
print(`{os.clock() - t0}`)
print(bit32Encode(test))

return Base64