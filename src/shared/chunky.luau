--!strict

export type chunkyPrimativeType = {
    upperLimit: number?,
    lowerLimit: number?,
    byteLength: number,
    signed: boolean,
    read_func: <T>(self:chunkyPrimativeType,b: buffer, offset: number) -> (T, number),
    write_func: <T>(self:chunkyPrimativeType, b: buffer, offset: number, value: T) -> number,
    type: "SchemaTable" | "generic"
}

export type chunkyTable = {
    data: {[string]: chunkyPrimativeType | chunkyTable},
    byteLength: number,
    type: "SchemaTable" | "generic"
}

export type chunkySchema = {
    data: {[string]: chunkyPrimativeType | chunkyTable},
    byteLength: number
}

local chunkyModule = {}
chunkyModule.__index = chunkyModule

local reservedNames = {
    byteLength = true
}

@native
local function write_func_generic<T>(self: chunkyPrimativeType, buf: buffer, offset: number, value: T): number
    local func_name = (self.signed and "writei" or "writeu")..(8*self.byteLength)
    ;(buffer :: {[string]: (b:buffer, offset: number, value: T) -> ()})[func_name](buf, offset, value)
    return self.byteLength
end

@native
local function read_func_generic<T>(self: chunkyPrimativeType, buf: buffer, offset: number) : (T, number)
    local func_name = (self.signed and "readi" or "readu")..(8*self.byteLength)
    ;return (buffer :: {[string]: (b:buffer, offset: number) -> T})[func_name](buf, offset), self.byteLength
end

@native
local function getLengthFromTable(table: {[string]:chunkyPrimativeType | chunkyTable}): number
    local length = 0
    for k,v in pairs(table) do
        if not v["byteLength"] then
            error("[Chunky]: Invalid schema given. (Failed getting Primative Table byte size.)")
        elseif reservedNames[k] then
            error("Sorry, '"..k.."' is a reserved name and can not be used in a Schema.")
        end

        if v.type == "SchemaTable" then
            length += getLengthFromTable((v :: chunkyTable).data)
        else
            length += v.byteLength
        end
    end
    return length
end

@native
local function getLengthFromSchema(SchemaTable: {[string]:chunkyPrimativeType | chunkyTable}): number
    local length = 0
    for k,v in pairs(SchemaTable) do
        if not (v["byteLength"] > 0) then
            error("[Chunky]: Invalid schema given. (Failed getting Primative Table byte size.)")
        elseif reservedNames[k] then
            error("Sorry, '"..k.."' is a reserved name and can not be used in a Schema.")
        end
        length += v.byteLength
    end
    return length
end

@native
local function deserializeTable<T>(SchemaOrTable: chunkySchema | chunkyTable, buf: buffer): {[string]: T}
    local data = {}
    local current_offset = 0
    for k,v in pairs(SchemaOrTable.data) do
        if v.type == "generic" then
            local value,off = (v :: chunkyPrimativeType):read_func(buf, current_offset)
            data[k] = value
            current_offset += off
        elseif v.type == "SchemaTable" then
            local table_buf = buffer.create(v.byteLength)
            buffer.copy(table_buf, 0, buf, current_offset, v.byteLength)
            data[k] = deserializeTable((v::chunkyTable), table_buf) 
            current_offset += v.byteLength
        end
    end
    return data
end

@native
local function serialize<T>(SchemaOrTable: chunkySchema | chunkyTable, data: {[string]: T}): buffer
    local b = buffer.create(SchemaOrTable.byteLength)
    local current_offset = 0
    for k,v in pairs(SchemaOrTable.data) do
        if not data[k] then
            error("[Chunky]: Failed to fill data field: '"..k.."'. Please input all fields.")
        end
        if not v.byteLength then
            error("[Chunky]: Failed to serialize data. (Invalid Schema)")
        end
        if v.type == "generic" then
            (v :: chunkyPrimativeType):write_func(b, current_offset, data[k])
            current_offset += v.byteLength
        elseif v.type == "SchemaTable" then
            local source_copy = serialize((v::chunkyTable), data[k])
            buffer.copy(b, current_offset, source_copy)
            current_offset += v.byteLength
        end
    end
    return b
end

@native
local function Table(SchemaTable: {[string]: chunkyPrimativeType | chunkyTable} ) : chunkyTable
    return {
        data = SchemaTable,
        byteLength = getLengthFromTable(SchemaTable),
        type = "SchemaTable"
    } :: chunkyTable
end

@native
function chunkyModule.Schema(SchemaTable: {[string]:chunkyPrimativeType | chunkyTable} ) : chunkySchema
    return {
        data = SchemaTable,
        byteLength = getLengthFromSchema(SchemaTable)
    } :: chunkySchema
end

@native
function chunkyModule.serialize<T>(Schema: chunkySchema, data: {[string]:T}): buffer
    return serialize(Schema, data)
end

@native
function chunkyModule.deserialize<T>(Schema: chunkySchema, buf: buffer): {[string]: T}
    return deserializeTable(Schema, buf)
end

@native
local function create_generic(bitSize: number, signed: boolean): chunkyPrimativeType
    local item = {
        upperLimit = (signed and (2 ^ (bitSize-1) -1) or (2 ^ bitSize - 1)),
        lowerLimit = (signed and (2 ^ (bitSize-1)) or 0),
        byteLength = bitSize/8,
        signed = signed,
        type = "generic"
    } :: chunkyPrimativeType
    item.write_func = write_func_generic
    item.read_func = read_func_generic
    return item
end

local types = {
    S8 = create_generic(8, true) :: chunkyPrimativeType,
    U8 = create_generic(8, false) :: chunkyPrimativeType,
    S16 = create_generic(16, true) :: chunkyPrimativeType,
    U16 = create_generic(16, false) :: chunkyPrimativeType,
    S32 = create_generic(32, true) :: chunkyPrimativeType,
    U32 = create_generic(32, false) :: chunkyPrimativeType,
    S64 = create_generic(64, true) :: chunkyPrimativeType,
    U64 = create_generic(64, false) :: chunkyPrimativeType,
    BOOL = {
        byteLength = 1,
        read_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number): (boolean, number)
            local func_name = (self.signed and "readi" or "readu")..(8*self.byteLength)
            ;return ((buffer :: {[string]: (b:buffer, offset: number) -> number})[func_name](b, offset))==1, self.byteLength
        end,
        write_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number, value: boolean): number
            local func_name = (self.signed and "writei" or "writeu")..(8*self.byteLength)
            local val = value and 1 or 2 :: number
            ;(buffer :: {[string]: (b:buffer, offset: number, value: number) -> ()})[func_name](b, offset, val)
            return self.byteLength
        end,
        type = "generic"
    },
    Vector3 = {
        byteLength = 12,
        read_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number): (Vector3, number)
            return Vector3.new(
                buffer.readf32(b, offset),
                buffer.readf32(b, offset+4),
                buffer.readf32(b, offset+8)
            ), self.byteLength

        end,
        write_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number, value: Vector3): number

            buffer.writef32(b, offset, value.X)
            buffer.writef32(b, offset+4, value.Y)
            buffer.writef32(b, offset+8, value.Z)

            return self.byteLength
        end,
        type = "generic"
    },
    CFrame = {
        byteLength = 48,
        read_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number): (CFrame, number)
            local values = {} :: {number}
            
            for i = 0, 44, 4 do
                table.insert(values, buffer.readf32(b, offset+i))
            end
            local v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12 = table.unpack(values)
            return CFrame.new(
                v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12
            ), self.byteLength


        end,
        write_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number, value: CFrame): number

            for i, v in ipairs(table.pack(value:GetComponents())) do
                buffer.writef32(b, (offset-4)+i*4, v)
            end

            return self.byteLength
        end,
        type = "generic"
    },
    Color3 = {
        byteLength = 3,
        read_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number): (Color3, number)
            return Color3.fromRGB(
                buffer.readu8(b, offset),
                buffer.readu8(b, offset+1),
                buffer.readu8(b, offset+2)
            ), 1
        end,
        write_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number, value: Color3): number
            buffer.writeu8(b, offset, math.round(value.R*255))
            buffer.writeu8(b, offset+1, math.round(value.G*255))
            buffer.writeu8(b, offset+2, math.round(value.B*255))
            return self.byteLength
        end,
        type = "generic"
    },
    String8 = {
        byteLength = 256,
        read_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number): (string, number)
            local length = buffer.readu8(b, offset)
            local res = buffer.readstring(b, offset+1, length)
            return res, res:len()+1

        end,
        write_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number, value: string): number
            if value:len() > self.byteLength-1 then
                error("Provided string is larger than the allowed number of characters (16 bit string)")
            end
            buffer.writeu8(b, offset, value:len())
            buffer.writestring(b, offset+1, value)
            return value:len()+1
        end,
        type = "generic"
    },
    String16 = {
        byteLength = 2^16,
        read_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number): (string, number)
            local length = buffer.readu16(b, offset)
            local res = buffer.readstring(b, offset+1, length)
            return res, res:len()+2

        end,
        write_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number, value: string): number
            if value:len() > self.byteLength-2 then
                error("Provided string is larger than the allowed number of characters (16 bit string)")
            end
            buffer.writeu16(b, offset, value:len())
            buffer.writestring(b, offset+2, value)
            return value:len()+2
        end,
        type = "generic"
    },
    String32 = {
        byteLength = 2^32,
        read_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number): (string, number)
            local length = buffer.readu32(b, offset)
            local res = buffer.readstring(b, offset+1, length)
            return res, res:len()+4

        end,
        write_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number, value: string): number
            if value:len() > self.byteLength-4 then
                error("Provided string is larger than the allowed number of characters (16 bit string)")
            end
            buffer.writeu32(b, offset, value:len())
            buffer.writestring(b, offset+4, value)
            return value:len()+1
        end,
        type = "generic"
    },
    buffer8 = {
        byteLength = 256,
        read_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number): (buffer, number)
            local length = buffer.readu8(b, offset)
            local buf = buffer.create(length)
            buffer.copy(buf, 0, b, offset+1,length)
            return buf, buffer.len(buf)+1
        end,
        write_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number, value: buffer): number
            if buffer.len(value) > self.byteLength-1 then
                error("Provided buffer exceeds assigned type limit (8 bit buffer too small, use a bigger one)")
            end
            buffer.writeu8(b, offset, buffer.len(value))
            buffer.copy(b, offset+1, value)
            return buffer.len(value)+1
        end,
        type = "generic"
    },
    buffer16 = {
        byteLength = 2^16,
        read_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number): (buffer, number)
            local length = buffer.readu8(b, offset)
            local buf = buffer.create(length)
            buffer.copy(buf, 0, b, offset+2,length)
            return buf, buffer.len(buf)+2
        end,
        write_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number, value: buffer): number
            if buffer.len(value) > self.byteLength-2 then
                error("Provided buffer exceeds assigned type limit (8 bit buffer too small, use a bigger one)")
            end
            buffer.writeu8(b, offset, buffer.len(value))
            buffer.copy(b, offset+2, value)
            return buffer.len(value)+2
        end,
        type = "generic"
    },
    buffer32 = {
        byteLength = 2^32,
        read_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number): (buffer, number)
            local length = buffer.readu32(b, offset)
            local buf = buffer.create(length)
            buffer.copy(buf, 0, b, offset+4,length)
            return buf, buffer.len(buf)+4
        end,
        write_func = @native function(self:chunkyPrimativeType, b: buffer, offset: number, value: buffer): number
            if buffer.len(value) > self.byteLength-4 then
                error("Provided buffer exceeds assigned type limit (8 bit buffer too small, use a bigger one)")
            end
            buffer.writeu32(b, offset, buffer.len(value))
            buffer.copy(b, offset+4, value)
            return buffer.len(value)+4
        end,
        type = "generic"
    },



    Table = Table
}

types.__index = types

chunkyModule.types = types

return chunkyModule