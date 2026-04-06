-- Copyright (c) 2026 Alberto Otero de la Roza <aoterodelaroza@gmail.com>.
--
-- stumpy is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or (at
-- your option) any later version.
--
-- stumpy is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

-- TODO: add icon
-- TODO: o and c-o swap clients between stacks, instead of just moving one
-- TODO: consider how clients travel between different tags - use last_tag to handle all
-- TODO: mod4+1 = single stack, mod4+2 = two stacks, etc.

local awful   = require("awful")
local naughty = require("naughty")

local stumpy = {}
stumpy.name = "stumpy"
stumpy.debug = false

-- store the tag of each client
local last_tag = {}

-- number of stacks
local nstack = 4

------------------------
-- xx Private functions
------------------------

local function stack_id(slot)
   -- return the stack ID for the given slot
   return (slot-1) % nstack + 1
end

local function show_message(s, text, timeout, id)
   -- Show a message (text) at screen s for timeout seconds at position given
   -- by integer id (1 to nstack).
   if not id or not timeout then return end
   if text == "" then return end

   local placement = {
      [1] = "top_left",
      [2] = "top_right",
      [3] = "bottom_left",
      [4] = "bottom_right",
   }

   naughty.notify({
	 text  = text,
	 timeout = timeout,
	 position = placement[id],
	 ignore_suspend = true,
	 border_color = "#82C3EC",
	 fg = "#82C3EC",
	 replaces_id = id,
   })
end

local function stack_id_from_position(x,y)
   -- Given a client position, return the stack ID that best approximates it.
   local s = awful.screen.focused()
   if not s then return end
   local area = s.workarea
   if not area then return nil end

   local xmid = area.x + area.width / 2
   local ymid = area.y + area.height / 2

   if x <= xmid and y <= ymid then
      return 1
   elseif x > xmid and y <= ymid then
      return 2
   elseif x <= xmid and y > ymid then
      return 3
   elseif x > xmid and y > ymid then
      return 4
   end
end

local function next_empty_slot()
   -- Return the next empty slot corresponding to the stack with the
   -- fewest clients. In case of tie, the stack with the lowest
   -- ordinal.

   local t = awful.screen.focused().selected_tag
   if t.layout ~= stumpy then return nil end
   local clients = t and t:clients() or {}

   local used = {}
   local smax = 0
   for _, c in ipairs(clients) do
      if c.slot then
	 used[c.slot] = c
	 smax = math.max(smax,c.slot)
      end
   end

   for i = 1, smax+1 do
      if not used[i] then
	 return i
      end
   end
   return nil

end

local function list_clients_in_stack(cin,id)
   -- Returns a sorted list of all clients in a stack. If cin or
   -- cin.slot are nil, the id (1 to nstack) is used to identify the stack.

   if cin and cin.slot then
      id = cin.slot
   end
   if not id then return nil end

   local t = awful.screen.focused().selected_tag
   if t.layout ~= stumpy then return nil end
   local clients = t and t:clients() or {}

   local stack = {}
   for _, c in ipairs(clients) do
      if c.slot and (id % nstack) == (c.slot % nstack) then
	 table.insert(stack,c)
      end
   end
   table.sort(stack, function(a,b) return a.slot < b.slot end)
   return stack

end

local function cycle_clients_in_stack(cin,id,direction)
   -- Cycle the clients in the stack determined by cin. If cin or
   -- cin.slot are nil, the id (1 to nstack) is used to identify the stack.
   -- direction (1 or -1) gives the direction of cycling.

   local stack = list_clients_in_stack(cin)
   if not stack or #stack == 0 then return end

   if direction == 1 then
      local first_slot = stack[1].slot
      for i = 1, #stack-1 do
	 stack[i].slot = stack[i+1].slot
      end
      stack[#stack].slot = first_slot
   else
      local last_slot = stack[#stack].slot
      for i = #stack, 2, -1 do
	 stack[i].slot = stack[i-1].slot
      end
      stack[1].slot = last_slot
   end

end

local function focus_front_stack(cin,id)
   -- Focus the front of the stack in which client cin is, or id if not provided.

   local stack = list_clients_in_stack(cin,id)
   if not stack or #stack == 0 then return end
   client.focus = stack[1]

end

local function swap_clients(c1,c2)
   -- Swap the positions of clients c1 and c2.

   if not c1 or not c2 or not c1.slot or not c2.slot then return end

   c1.slot, c2.slot = c2.slot, c1.slot

end

local function push_stack_front(c,id)
   -- Push client c in the front of stack id.
   if not c or not id then return end

   local stack = list_clients_in_stack(nil,id)

   local n = id
   c.slot = n
   for i = 1, #stack do
      n = n + nstack
      stack[i].slot = n
   end

end

local function try_assign_slot(c,slot)
   -- Try to assign the given slot to client c. If the slot is already occupied,
   -- push the client to the front of the corresponding stack.

   local t = awful.screen.focused().selected_tag
   if t.layout ~= stumpy then return nil end
   local clients = t and t:clients() or {}

   local found = false
   for _, c in ipairs(clients) do
      if c.slot and c.slot == slot then
	 found = true
	 break
      end
   end
   if found then
      push_stack_front(c,stack_id(slot))
   else
      c.slot = slot
   end

end

local function tidy_stack(id)
   -- Reset the labels for all clients within a stack, so they are in order.
   -- Assign slot_previous to the current slot.

   local stack = list_clients_in_stack(nil,id)
   local n = id
   for i = 1, #stack do
      stack[i].slot = n
      stack[i].slot_previous = n
      n = n + nstack
   end

end

local function next_client(cin,instack,direction)
   -- Given a client, find the next client (direction = 1) or the previous client (direction = -1). If instack =
   --   "yes": return a client's slot in the same stack as c, or nil.
   --   "prefer": return a client's slot in the same stack as c if possible; otherwise any hidden client in any stack.
   --   "no": return the grid slot of any hidden client.

   local t = awful.screen.focused().selected_tag
   if t.layout ~= stumpy then return nil end
   local clients = t and t:clients() or {}

   if not cin or not cin.slot then return nil end

   local inext = nil
   if direction == 1 then
      inext = 99999
   elseif direction == -1 then
      inext = 0
   else
      return nil
   end

   local cnext = nil
   for _, c in ipairs(clients) do
      local ok = nil
      if instack == "yes" or instack == "prefer" then
	 ok = c.slot and c.slot ~= cin.slot and c.slot > nstack and (c.slot % nstack) == (cin.slot % nstack)
      elseif instack == "no" then
	 ok = c.slot and c.slot ~= cin.slot and c.slot > nstack
      else
	 return nil
      end

      if direction == 1 then
	 ok = ok and c.slot < inext
      else
	 ok = ok and c.slot > inext
      end

      if ok then
	 inext = c.slot
	 cnext = c
      end
   end

   if not cnext and instack == "prefer" then
      return next_client(cin,"no",direction)
   end
   return cnext
end

------------------------
-- xx Public functions
------------------------

function stumpy.cycle_clients_in_stack(direction)
   -- If the focused client is c,
   -- - If the stack in which c is placed is empty, and there are no hidden clients,
   --   do nothing.
   -- - If the stack in which c is placed is empty, but there are hidden clients in
   --   other stacks, move the client from the other stack to the current stack and
   --   place it on top of c.
   -- - If the stack in which c is placed is not empty, focus the next client in the
   --   stack and cycle the stack.
   -- The direction (+1 or -1) controls in which direction the operations are applied.

   local t = awful.screen.focused().selected_tag
   if t.layout ~= stumpy then return nil end
   local clients = t and t:clients() or {}

   local focused = client.focus
   if not focused or not focused.slot then return end

   local cother = next_client(focused,"yes",direction)
   if cother then
      -- there are clients in the same stack
      cycle_clients_in_stack(cother,nil,direction)
   else
      -- there may be clients in other stacks
      cother = next_client(focused,"no",direction)
      if cother then
	 swap_clients(focused,cother)
      else
	 return
      end
   end

   -- focus the top of the stack
   focus_front_stack(cother)
   awful.layout.arrange(awful.screen.focused())
end

function stumpy.swap_clients_in_stack()
   -- Swap the currently focused client with the next client in the stack.
   -- If there are no clients in the stack, swap with any of the clients
   -- in the other stacks. If there are no hidden clients, do nothing.
   local t = awful.screen.focused().selected_tag
   if t.layout ~= stumpy then return nil end
   local clients = t and t:clients() or {}

   local focused = client.focus
   if not focused or not focused.slot then return end

   local lnext = next_client(focused,"prefer",1)
   if not lnext then return end
   swap_clients(focused,lnext)
   client.focus = lnext
   awful.layout.arrange(awful.screen.focused())
end

function stumpy.cycle_stacks(direction)
   -- Move the currently focused client through the different stacks
   -- (1 -> 2 -> ...).  Direction = +1 or -1 controls the direction of
   -- the cycle.

   local t = awful.screen.focused().selected_tag
   if t.layout ~= stumpy then return nil end
   local clients = t and t:clients() or {}

   local focused = client.focus
   if not focused or not focused.slot then return end

   local idstack = stack_id(focused.slot)
   idstack = stack_id(idstack + direction)
   push_stack_front(focused,idstack)
   awful.layout.arrange(awful.screen.focused())
end

function stumpy.move_client(direction)
   -- Move the focused client in the given direction ("left", "up",
   -- "right", "down").

   local t = awful.screen.focused().selected_tag
   if t.layout ~= stumpy then return nil end
   local clients = t and t:clients() or {}

   local focused = client.focus
   if not focused or not focused.slot then return end

   local idstack = stack_id(focused.slot)
   local idnew = nil
   if direction == "left" then
      if idstack == 2 or idstack == 4 then
	 idnew = idstack - 1
      end
   elseif direction == "up" then
      if idstack == 3 or idstack == 4 then
	 idnew = idstack - 2
      end
   elseif direction == "right" then
      if idstack == 1 or idstack == 3 then
	 idnew = idstack + 1
      end
   elseif direction == "down" then
      if idstack == 1 or idstack == 2 then
	 idnew = idstack + 2
      end
   end
   if idnew then
      push_stack_front(focused,idnew)
      awful.layout.arrange(awful.screen.focused())
   end
end

function stumpy.arrange(p)
   -- Arrange managed clients

   if stumpy.debug then
      print("called arrange")
   end

   local area = p.workarea
   local clients = p.clients

   -- calculate the window positions
   local w = area.width / 2
   local h = area.height / 2
   local positions = {
      [1] = { x = area.x,     y = area.y },
      [2] = { x = area.x + w, y = area.y },
      [3] = { x = area.x,     y = area.y + h },
      [4] = { x = area.x + w, y = area.y + h },
   }

   -- Assign a slot to every client that does not have one.
   for _, c in ipairs(clients) do
      -- do not assign a slot if this is not one of the tiled clients
      local tiled = not (c.floating or c.maximized or c.maximized_horizontal or c.maximized_vertical)
      if not c.slot and tiled then
	 if not unmanaged then
	    if c.slot_previous then
	       -- If the client already had a slot, try to assign it
	       try_assign_slot(c,c.slot_previous)
	    elseif (client.focus == c) then
	       -- If the client is focused, judge by its position where it belongs
	       -- and place it in the front of the stack.
	       local g = c:geometry()
	       local id = stack_id_from_position(g.x + g.width/2,g.y + g.height/2)
	       push_stack_front(c,id)
	    else
	       -- place the client in the back of the least used stack
	       c.slot = next_empty_slot()
	    end
	 end
      end
   end

   -- make sure the stacks are tidy
   for i = 1, nstack do
      tidy_stack(i)
   end

   -- position the clients
   for _, c in ipairs(clients) do
      if c.slot then
	 if positions[c.slot] then
	    p.geometries[c] = {
	       x = positions[c.slot].x,
	       y = positions[c.slot].y,
	       width = w,
	       height = h,
	    }
	 else
	    -- slot is set but not 1-nstack -> position outside the work area
	    p.geometries[c] = {
	       x = area.x + area.width + 10,
	       y = area.y + area.height + 10,
	       width = w,
	       height = h,
	    }
	 end
      end
   end

   -- show overlay messages on top of each panel
   for i = 1, nstack do
      local stack = list_clients_in_stack(nil,i)
      local str = ""
      for j = 1, #stack do
	 if stumpy.debug then
	    str = str .. tostring(stack[j].slot) .. ": " .. tostring(stack[j])
	    if j < #stack then
	       str = str .. "\n"
	    end
	 else
	    str = str .. tostring(stack[j].slot)
	    if j < #stack then
	       str = str .. " "
	    end
	 end
      end
      show_message(awful.screen.focused(),str,2,i)
   end
end

function stumpy.on_manage(c)
   -- Manage a newly created client c.

   local t = c.first_tag
   if not t then return end
   if t.layout ~= stumpy then return end

   if stumpy.debug then
      print("called on_manage")
   end

   local clients = t:clients()

   -- If the next empty slot is visible (1 to nstack), use it
   local slot = next_empty_slot()
   if slot > 0 and slot <= nstack then
      c.slot = slot
      return
   end

   -- If there is no free slot, put in front of the stack where the previously
   -- focused client was.
   local pc = awful.client.focus.history.get(awful.screen.focused(), 1)
   if pc and pc.slot then
      push_stack_front(c,stack_id(pc.slot))
   else
      -- Let arrange handle this one.
      c.slot = nil
   end
end

function stumpy.on_unmanage(cin)
   -- Manage a destroyed created client c. Try to keep the focus in
   -- the same stack. Otherwise, find a visible window and focus that.
   -- If none of that works, let the system decide where the focus
   -- goes.

   if not cin then return end
   local t = last_tag[cin]
   if not t or t.layout ~= stumpy then return end
   local clients = t and t:clients() or {}

   if stumpy.debug then
      print("called on_unmanage")
   end

   local stack = list_clients_in_stack(cin)
   if stack and #stack > 0 then
      client.focus = stack[1]
   else
      for _, c in ipairs(clients) do
	 local tiled = not (c.floating or c.maximized or c.maximized_horizontal or c.maximized_vertical)
	 if tiled and c.slot and c.slot > 0 and c.slot <= nstack then
	    client.focus = c
	    return
	 end
      end
   end

end

-- When a client changes tags or becomes floating or maximized in any
-- way, remove its slot and save it in case we want it back later.
function stumpy.on_tagged(c,t)
   if c.slot then
      c.slot_previous = c.slot
      c.slot = nil
   end
   last_tag[c] = t
end
function stumpy.on_change_floating(c)
   if c.floating then
      c.slot_previous = c.slot
      c.slot = nil
   end
end
function stumpy.on_change_maximized(c)
   if c.maximized then
      c.slot_previous = c.slot
      c.slot = nil
   end
end
function stumpy.on_change_maximized_horizontal(c)
   if c.maximized_horizontal then
      c.slot_previous = c.slot
      c.slot = nil
   end
end
function stumpy.on_change_maximized_vertical(c)
   if c.maximized_vertical then
      c.slot_previous = c.slot
      c.slot = nil
   end
end

-- Set up all the signals
function stumpy.setup()
   client.connect_signal("manage", stumpy.on_manage)
   client.connect_signal("unmanage", stumpy.on_unmanage)
   client.connect_signal("tagged", stumpy.on_tagged)
   client.connect_signal("property::floating", stumpy.on_change_floating)
   client.connect_signal("property::maximized", stumpy.on_change_maximized)
   client.connect_signal("property::maximized_vertical", stumpy.on_change_maximized_vertical)
   client.connect_signal("property::maximized_horizontal", stumpy.on_change_maximized_horizontal)
end

return stumpy
