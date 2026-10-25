AUCTIONARY 2.0 (2.0.1) - START GUIDE
============================


WHAT IT DOES
------------

Shopping
  Search, shopping lists, buy view. A single result opens directly;
  typos are corrected when nothing is found.

Selling
  Click an item in the bag grid, check the suggested price, post.
  Favourites get a star, good-to-sell items a green dot.
  Scam sell protection: auctions far below the usual price (default:
  under 50%) are not undercut; the price follows the next normal one.
  The gold coin next to "Post next" buys the cheapest auction when it
  is a bargain.

Cancelling
  Shows your auctions and marks which ones were undercut.
  Cancel selected, the next undercut, all undercut, or all auctions of
  one item. Cancelling works while the scan is still running.

Settings/Info
  All switches, background colour, status.

Full Scan
  Button at the right end of the tab bar.

Tooltips
  Vendor, Auction, Average, Age, Mats Cost, Disenchant, Prospect, Mill.


GOOD TO KNOW BEFORE YOU START
-----------------------------

* Scan first.
  Prices, averages and the typo search all depend on scan data.
  The more scans over several days, the better the averages.

* The quick full scan has a 15-minute cooldown set by the client.
  The button shows the countdown. Shift-click scans page by page
  instead (slow).

* A full scan when the auction house opens can be switched on in
  Settings/Info (it is off at the start).

* Buying, posting and cancelling need one click (or Enter) each.
  The client ignores these actions otherwise, so a quantity purchase is
  one click per stack.

* Enter posts in the Selling tab while an item is ready, so Enter does
  not open chat there. Switch it off in Settings/Info if that bothers
  you.

* Double-click to cancel is off by default and acts without
  confirmation when on.

* A green dot in the Selling tab means "good time to sell".
  It appears in the top-left corner of a bag item when the latest
  scanned price (today or yesterday) is at least 10% above that item's
  average. Hovering shows by how many percent.

* Values are estimates.
  Disenchant, Prospect and Mill use known drop chances and current
  asking prices, not what actually sells.

* Your own auctions are ignored when prices are saved.

* Items that cannot be disenchanted are only detected automatically on
  a character with Enchanting.

* Scan data is per account; two accounts do not share it.


SHORTCUTS
---------

* Shift-click an item anywhere while Shopping is open: search for it.

* Selling: right-click a bag item to make it a favourite.
  "History" without a selected item lists everything you posted.

* Cancelling: shift-click hides an item for the session.
  Alt + click, or holding Alt while moving over rows, selects more than
  one auction; "Cancel Selected" cancels them all together.


INSTALLING AND UPDATING
-----------------------

* The Auctionary folder goes into Interface\AddOns. It replaces Auctionary 1.x;
  prices, lists and settings of 1.x are taken over at the first login.

* After an update that adds files, restart the game completely;
  otherwise /reload is enough.

* /aury (or /auctionary) lists the chat commands.

* It runs alongside TradeSkillMaster. Running it together with other
  auction house addons works but crowds the tab bar.


MEMORY
------

* The price history keeps the last 21 days. Fewer days use less memory:
  Settings/Info, second page (arrow at the bottom right), "Price history".

* Memory that is no longer needed is freed behind every loading screen,
  after a full scan and after closing the auction house.
  /aury mem shows how much the addon uses right now.


AUTHOR AND LICENCE
------------------

* Made by Feralpaw. Copyright (c) 2026 Feralpaw.
* Free to use, share and change under the MIT licence (LICENSE.txt).
* If you want to support my projects, send gold to Banksty in game.
