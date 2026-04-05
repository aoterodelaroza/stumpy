**Stumpy** is a layout for the Awesome window manager. It is a static
2x2 grid layout based on the behavior of StumpWM (or, at least, the
way I remember its behavior was).

Recommended tweaks to the `rc.lua`:

~~~lua
...
-- Load the package
local stumpy = require("stumpy")
stumpy.setup()
...
-- Set the layout
   awful.key({modkey}, "3", function () awful.layout.set(stumpy) end, {description = "Set stumpy layout", group = "layout"}),
...
-- Key bindings
   awful.key({modkey}, "h",
      function ()
	 awful.client.focus.bydirection("left")
	 if client.focus then client.focus:raise() end
      end, {description = "focus client left", group = "client"}),
   awful.key({modkey,"Control"}, "h",
      function ()
	 local t = awful.screen.focused().selected_tag
	 if t.layout == stumpy then
	    stumpy.move_client("left")
	 end
      end, {description = "move focused client left", group = "client"}),
   awful.key({modkey}, "j",
      function ()
	 awful.client.focus.bydirection("down")
	 if client.focus then client.focus:raise() end
      end, {description = "focus client down", group = "client"}),
   awful.key({modkey,"Control"}, "j",
      function ()
	 local t = awful.screen.focused().selected_tag
	 if t.layout == stumpy then
	    stumpy.move_client("down")
	 end
      end, {description = "move focused client down", group = "client"}),
   awful.key({modkey}, "k",
      function ()
	 awful.client.focus.bydirection("up")
	 if client.focus then client.focus:raise() end
      end, {description = "focus client up", group = "client"}),
   awful.key({modkey,"Control"}, "k",
      function ()
	 local t = awful.screen.focused().selected_tag
	 if t.layout == stumpy then
	    stumpy.move_client("up")
	 end
      end, {description = "move focused client up", group = "client"}),
   awful.key({modkey}, "l",
      function ()
	 awful.client.focus.bydirection("right")
	 if client.focus then client.focus:raise() end
      end, {description = "focus client right", group = "client"}),
   awful.key({modkey,"Control"}, "l",
      function ()
	 local t = awful.screen.focused().selected_tag
	 if t.layout == stumpy then
	    stumpy.move_client("right")
	 end
      end, {description = "move focused client right", group = "client"}),

   awful.key({modkey}, "n",
      function()
	 local t = awful.screen.focused().selected_tag
	 if t.layout == stumpy then
	    stumpy.cycle_clients_in_stack(1)
	 else
	    awful.client.focus.byidx(1)
	    if client.focus then client.focus:raise() end
	 end
      end, {description = "focus next client",group="client"}),
   awful.key({modkey}, "p",
      function()
	 local t = awful.screen.focused().selected_tag
	 if t.layout == stumpy then
	    stumpy.cycle_clients_in_stack(-1)
	 else
	    awful.client.focus.byidx(-1)
	    if client.focus then client.focus:raise() end
	 end
      end, {description = "focus previous client",group="client"}),
   awful.key({modkey},"Tab",
      function ()
	 local t = awful.screen.focused().selected_tag
	 if t.layout == stumpy then
	    stumpy.swap_clients_in_stack()
	 else
	    awful.client.focus.history.previous()
	    if client.focus then client.focus:raise() end
	 end
      end,{description="cycle focused",group="client"}),

   awful.key({modkey}, "o",
      function (c)
	 local t = awful.screen.focused().selected_tag
	 if t.layout == stumpy then
	    stumpy.cycle_stacks(1)
	 else
	    awful.client.swap.byidx(1)
	 end
      end,
      {description = "swap with next client", group = "client"}),
   awful.key({modkey,"Shift"}, "o",
      function (c)
	 local t = awful.screen.focused().selected_tag
	 if t.layout == stumpy then
	    stumpy.cycle_stacks(-1)
	 else
	    awful.client.swap.byidx(-1)
	 end
      end,
      {description = "swap with previous client", group = "client"}),
~~~

Stumpy is made available under the GNU/GPL v3 license. See the LICENSE
file in the root of the distribution for more details.
