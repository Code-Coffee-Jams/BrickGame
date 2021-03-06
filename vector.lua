local module = { ZERO = 1e-3 }

local VectorMT = {}
VectorMT.__index = VectorMT

local function euclideanNorm(x, y)
    assert(type(x) == "number", "x must be a number")
    assert(type(y) == "number", "y must be a number")

    return math.sqrt(x * x + y * y)
end

function module.isVector(obj)
    return type(obj) == "table" and getmetatable(obj) == VectorMT
end

-- constructors
function module.new(x, y)
    if x ~= nil then assert(type(x) == "number", "x must be a number") else x = 0.0 end
    if y ~= nil then assert(type(y) == "number", "y must be a number") else y = 0.0 end

    return setmetatable({ x = x, y = y }, VectorMT)
end

function module.fromAngle(angle, length)
    assert(type(angle) == "number", "angle must be a number")
    if length ~= nil then assert(type(length) == "number", "length must be a number") else length = 1.0 end

    return module.new(math.cos(angle) * length, math.sin(angle) * length)
end

function VectorMT.copy(self)
    return module.new(self.x, self.y)
end

-- metamethods
function VectorMT.__tostring(self)
    return string.format("Vector(%f, %f)", self.x, self.y)
end

function VectorMT.__unm(self)
    return module.new(-self.x, -self.y)
end

function VectorMT.__add(self, other)
    assert(module.isVector(other), "other must be a vector")

    return module.new(self.x + other.x, self.y + other.y)
end

function VectorMT.__sub(self, other)
    assert(module.isVector(other), "other must be a vector")

    return module.new(self.x - other.x, self.y - other.y)
end

function VectorMT.__mul(self, value)
    assert(type(value) == "number", "value must be a number")

    return module.new(self.x * value, self.y * value)
end

function VectorMT.__div(self, value)
    assert(type(value) == "number" and value ~= 0, "value must be a non-zero number")

    return module.new(self.x / value, self.y / value)
end

function VectorMT.__eq(self, other)
    assert(module.isVector(other), "other must be a vector")

    return (other - self):getLength() < module.ZERO
end

-- other methods
function VectorMT.setXY(self, x, y)
    assert(type(x) == "number", "x must be a number")
    assert(type(y) == "number", "y must be a number")

    self.x = x
    self.y = y

    return true
end

function VectorMT.transform(self, other)
    assert(module.isVector(other), "other must be a vector")

    self.x = self.x + other.x
    self.y = self.y + other.y

    return true
end

function VectorMT.getLength(self)
    return euclideanNorm(self.x, self.y)
end

function VectorMT.setLength(self, newLength)
    local length = self:getLength()
    assert(length ~= 0, "cannot directly set length of a zero-length vector")

    self.x = self.x / length * newLength
    self.y = self.y / length * newLength
end

function VectorMT.getAngle(self)
    assert(self:getLength() ~= 0, "cannot calculate direction angle of a zero-length vector")

    return math.atan2(self.y, self.x)
end

function VectorMT.setAngle(self, newAngle)
    assert(type(newAngle) == "number", "angle must be a number")

    local length = self:getLength()
    assert(length ~= 0, "cannot directly set direction angle of a zero-length vector")

    self.x = math.cos(newAngle) * length
    self.y = math.sin(newAngle) * length

    return true
end

function VectorMT.rotate(self, angle)
    assert(type(angle) == "number", "angle must be a number")

    return self:setAngle(self:getAngle() + angle)
end

function VectorMT.getRotated(self, angle)
    local copy = self:copy()
    copy:rotate(angle)

    return copy
end

function VectorMT.normalize(self)
    local length = self:getLength()
    assert(length ~= 0, "zero-length vectors cannot be normalized")

    self.x = self.x / length
    self.y = self.y / length

    return true
end

function VectorMT.getNormalized(self)
    local copy = self:copy()
    copy:normalize()

    return copy
end

function VectorMT.reflect(self, normal)
    assert(module.isVector(normal), "normal must be a vector")
    assert(self:getLength() ~= 0, "zero-length vectors cannot be reflected")

    -- equation taken from:
    -- https://math.stackexchange.com/questions/13261/how-to-get-a-reflection-vector
    return self:transform(normal * (-2) * self:dotProduct(normal))
end

function VectorMT.getReflected(self, normal)
    local copy = self:copy()
    copy:reflect(normal)

    return copy
end

function VectorMT.dotProduct(self, other)
    assert(module.isVector(other), "other must be a vector")

    return self.x * other.x + self.y * other.y
end

function VectorMT.crossProduct(self, other)
    assert(module.isVector(other), "other must be a vector")

    return self.x * other.y - self.y * other.x
end

function VectorMT.isPerpendicularTo(self, other)
    assert(module.isVector(other), "other must be a vector")

    if self:getLength() == 0 or other:getLength() == 0 then
        return false
    end

    return self:dotProduct(other) < module.ZERO
end

function VectorMT.isParallelTo(self, other)
    assert(module.isVector(other), "other must be a vector")

    if self:getLength() == 0 or other:getLength() == 0 then
        return false
    end

    return self:crossProduct(other) < module.ZERO
end

function VectorMT.getDistanceTo(self, other)
    assert(module.isVector(other), "other must be a vector")

    return euclideanNorm(self.x - other.x, self.y - other.y)
end

return module
