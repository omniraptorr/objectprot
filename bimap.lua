--luacheck: no max line length

-- local inspect = require "inspect"
-- local p = function(...) print(inspect(...)) end

-- an implementation of a bidict https://stackoverflow.com/a/21894086
-- fwdtable is just used as a regular table.
-- but each entry of revtable is a read-only set of unique keys that point to the corresponding value in fwdtable.
-- example of how internal structure looks:
-- fwdtable = {key1 = "a", key2 = "a", key3 = "b"}
-- revtable = {a = {key1 = true, key2 = true}, b = {key3 = true}}
-- and after reassigning (with bimap.fwd[key1] = "c") revtable will look like
-- fwdtable = {key1 = "c", key2 = "a", key3 = "b"}
-- revtable = {a = {<removed key1 = true>, key2 = true}, b = {key3}, <added c = {key1 = true}>

local function iter(t, k)
 k = k + 1
 local v = t[k]
 if v then
   return k, v
 end
end

local function revtable__newindex(_, k, v)
  print("tried to write revtable[" .. tostring(k) .. "] = " .. tostring(v) .. " but revtable is read only! please use the corresponding fwdtable to write data")
end
local reventry_mt = {
  __newindex = function(_, k, v)
    print("tried to write reventry[" .. tostring(k) .. "] = " .. tostring(v) .. " but revtable entries are read only! please only modify them through the corresponding fwdtable")
  end,
}

local newbimap = function(init)
  local fwdtable, revtable = {}, {}
  local fwd_size, rev_size = 0, 0

  -- access to the main table
  local fwd_mt = {
    __len = function(_) -- does not act like normal len! lists number of keys rather than just contiguous integer keys. shouldn't be an issue most of the time.
      return fwd_size
      -- return #fwdtable -- this would act like normal len
    end,
    __pairs = function(_) -- with this you can iterate over the forward table normally
      return next, fwdtable, nil
    end,
    __ipairs = function(_)
      return iter, fwdtable, 0
    end,
    __index = function(_, k) -- access a key's value in fwd table
      return fwdtable[k]
    end,
    __newindex = function(_, k, new_value) -- set a new value, or reassign an old one
      local old_value = fwdtable[k]
      if old_value then -- handle reassignment away from old_value if needed
        if old_value == new_value then
          return -- if we're reassigning to the same value no need to do anything lol. followup on if this is a good optimization or not.
        end
        local old_rev_entry = revtable[old_value]
        revtable[old_value][k] = nil -- delete the old backwards reference
        if next(old_rev_entry) == nil then
          revtable[old_value] = nil -- delete old_rev_entry if it's now empty
          rev_size = rev_size - 1
        end
      else
        fwd_size = fwd_size + 1
      end

      fwdtable[k] = new_value   -- update forward table

      if new_value == nil then
        fwd_size = fwd_size - 1
        return -- if new_value is nil, we already removed old_value in revtable so nothing else to do.
      else
        local rev_entry = revtable[new_value]
        if not rev_entry then -- check if revtable entry exists for this value already
          revtable[new_value] = setmetatable({[k] = true}, reventry_mt) -- initialize a new set of unique keys
          rev_size = rev_size + 1
        else
          rawset(rev_entry, k, true) -- or insert a new key into the set if it exists
        end
      end
    end,
  }
  -- access to the reverse table (the one that contains sets of unique keys)
  local rev_mt = {
    __len = function(_) -- does not act like normal len! lists number of keys rather than just contiguous integer keys. shouldn't be an issue most of the time.
      return rev_size
      -- return #revtable -- this would act like normal len
    end,
    __pairs = function(_) -- with this you can iterate over the rev table normally
      return next, revtable, nil
    end,
    __ipairs = function(_)
      return iter, revtable, 0
    end,
    __index = function(_, k)
      return revtable[k]
    end,
    __newindex = revtable__newindex
  }

  if type(init) == "table" then
    local insert = fwd_mt.__newindex
    for k,v in pairs(init) do
      insert(nil, k, v)
    end
  end

  -- alternate access: use unary minus to access reverse table
  -- fwd_mt.__unm = rev_mt
  -- return setmetatable({}, fwd_mt) -- so the reverse access would be keys_of_value = (-bimap)[value]

  -- return could be a table too, but for now multiple returns is more convenient
  return
  -- {
    setmetatable({}, fwd_mt),
    setmetatable({}, rev_mt)
  -- }
end

return newbimap
